// CloudKit JS integration
// Documentation: https://developer.apple.com/documentation/cloudkitjs

declare global {
  interface Window {
    CloudKit: any;
  }
}

interface CloudKitConfig {
  containers: [{
    containerIdentifier: string;
    apiTokenAuth: {
      apiToken: string;
      persist: boolean;
    };
    environment: 'development' | 'production';
  }];
}

class CloudKitService {
  private container: any;
  private database: any;
  private initialized = false;

  async initialize() {
    if (this.initialized) return;

    // Load CloudKit JS library
    await this.loadCloudKitJS();

    // Configure CloudKit
    const config: CloudKitConfig = {
      containers: [{
        containerIdentifier: process.env.NEXT_PUBLIC_CLOUDKIT_CONTAINER || 'iCloud.com.volcy.app',
        apiTokenAuth: {
          apiToken: process.env.NEXT_PUBLIC_CLOUDKIT_API_TOKEN || '',
          persist: true,
        },
        environment: (process.env.NEXT_PUBLIC_CLOUDKIT_ENVIRONMENT as 'development' | 'production') || 'development',
      }],
    };

    window.CloudKit.configure(config);

    this.container = window.CloudKit.getDefaultContainer();
    this.database = this.container.privateCloudDatabase;
    this.initialized = true;
  }

  private loadCloudKitJS(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (window.CloudKit) {
        resolve();
        return;
      }

      const script = document.createElement('script');
      script.src = 'https://cdn.apple-cloudkit.com/ck/2/cloudkit.js';
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('Failed to load CloudKit JS'));
      document.head.appendChild(script);
    });
  }

  async fetchMetrics(startDate: Date, endDate: Date) {
    await this.initialize();

    // Query for ScanMetrics records
    const query = {
      recordType: 'ScanMetrics',
      filterBy: [{
        fieldName: 'timestamp',
        comparator: 'BETWEEN',
        fieldValue: {
          value: [startDate.toISOString(), endDate.toISOString()],
        },
      }],
      sortBy: [{
        fieldName: 'timestamp',
        ascending: false,
      }],
    };

    try {
      const response = await this.database.performQuery(query);

      return response.records.map((record: any) => ({
        id: record.recordName,
        timestamp: new Date(record.fields.timestamp.value),
        mode: record.fields.mode.value,
        distanceMM: record.fields.distanceMM.value,
        clarityScore: record.fields.clarityScore.value,
        lesions: record.fields.lesions?.value || [],
      }));
    } catch (error) {
      console.error('Failed to fetch metrics:', error);
      throw error;
    }
  }

  async signIn() {
    await this.initialize();

    return new Promise((resolve, reject) => {
      this.container.setUpAuth()
        .then((userIdentity: any) => {
          if (userIdentity) {
            resolve(userIdentity);
          } else {
            // User needs to sign in
            this.container.whenUserSignsIn()
              .then(resolve)
              .catch(reject);
          }
        })
        .catch(reject);
    });
  }

  async signOut() {
    await this.initialize();
    return this.container.signOut();
  }

  async getCurrentUser() {
    await this.initialize();

    try {
      const userIdentity = await this.container.fetchCurrentUserIdentity();
      return userIdentity;
    } catch (error) {
      return null;
    }
  }
}

export const cloudKit = new CloudKitService();
