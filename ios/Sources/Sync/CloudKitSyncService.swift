//
//  CloudKitSyncService.swift
//  Volcy
//
//  CloudKit metrics-only sync (no photos/depth)
//

import Foundation
import CloudKit

class CloudKitSyncService: SyncService {

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let persistenceService: PersistenceService

    // Record types
    private let metricsRecordType = "ScanMetrics"
    private let lesionRecordType = "LesionMetrics"

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
        self.container = CKContainer(identifier: "iCloud.com.volcy.app")
        self.privateDatabase = container.privateCloudDatabase
    }

    // MARK: - SyncService Protocol

    func syncIfNeeded() async {
        // Check if sync needed (last sync > 1 hour ago)
        let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? Date.distantPast
        let hourAgo = Date().addingTimeInterval(-3600)

        guard lastSync < hourAgo else { return }

        do {
            try await forceSyncMetrics()
        } catch {
            print("Sync failed: \(error)")
        }
    }

    func forceSyncMetrics() async throws {
        // Fetch local scans
        let scans = try await persistenceService.fetchScans(limit: 100)

        for scan in scans {
            try await uploadScanMetrics(scan)
        }

        // Update last sync date
        UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
    }

    // MARK: - Upload Methods

    private func uploadScanMetrics(_ scan: ScanEntity) async throws {
        // Create CloudKit record for scan
        let recordID = CKRecord.ID(recordName: scan.id?.uuidString ?? UUID().uuidString)
        let record = CKRecord(recordType: metricsRecordType, recordID: recordID)

        // Set fields (metrics only, no photos!)
        record["timestamp"] = scan.timestamp
        record["mode"] = scan.mode
        record["distanceMM"] = scan.distanceMM
        record["clarityScore"] = scan.clarityScore

        // Fetch lesions for this scan
        if let scanId = scan.id {
            let lesions = try await persistenceService.fetchLesions(for: scanId)
            let lesionMetrics = lesions.map { lesionToDict($0) }
            record["lesions"] = lesionMetrics as CKRecordValue
        }

        // Save to CloudKit
        try await privateDatabase.save(record)
    }

    private func lesionToDict(_ lesion: LesionEntity) -> [String: Any] {
        return [
            "stable_id": lesion.value(forKey: "stableId") as? String ?? "",
            "class": lesion.value(forKey: "lesionClass") as? String ?? "",
            "diameter_mm": lesion.value(forKey: "diameterMM") as? Double ?? 0.0,
            "elevation_mm": lesion.value(forKey: "elevationMM") as? Double ?? 0.0,
            "volume_mm3": lesion.value(forKey: "volumeMM3") as? Double ?? 0.0,
            "erythema_delta_astar": lesion.value(forKey: "erythemaDeltaAstar") as? Double ?? 0.0,
            "confidence": lesion.value(forKey: "confidence") as? Double ?? 0.0
        ]
    }

    // MARK: - Download Methods (for web dashboard)

    func fetchMetricsFromCloud(from startDate: Date, to endDate: Date) async throws -> [CloudMetricsRecord] {
        let predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@",
            startDate as CVarArg,
            endDate as CVarArg
        )

        let query = CKQuery(recordType: metricsRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        var records: [CloudMetricsRecord] = []
        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                if let metricsRecord = CloudMetricsRecord(from: record) {
                    records.append(metricsRecord)
                }
            case .failure(let error):
                print("Failed to fetch record: \(error)")
            }
        }

        return records
    }
}

// MARK: - Supporting Types

struct CloudMetricsRecord {
    let id: String
    let timestamp: Date
    let mode: String
    let distanceMM: Double
    let clarityScore: Int
    let lesions: [[String: Any]]

    init?(from record: CKRecord) {
        guard let timestamp = record["timestamp"] as? Date,
              let mode = record["mode"] as? String,
              let distanceMM = record["distanceMM"] as? Double,
              let clarityScore = record["clarityScore"] as? Int else {
            return nil
        }

        self.id = record.recordID.recordName
        self.timestamp = timestamp
        self.mode = mode
        self.distanceMM = distanceMM
        self.clarityScore = clarityScore
        self.lesions = record["lesions"] as? [[String: Any]] ?? []
    }

    func toJSON() -> [String: Any] {
        return [
            "id": id,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "mode": mode,
            "distance_mm": distanceMM,
            "clarity_score": clarityScore,
            "lesions": lesions
        ]
    }
}

enum SyncError: LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case uploadFailed
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to iCloud"
        case .networkUnavailable:
            return "Network unavailable"
        case .uploadFailed:
            return "Failed to upload metrics"
        case .downloadFailed:
            return "Failed to download metrics"
        }
    }
}
