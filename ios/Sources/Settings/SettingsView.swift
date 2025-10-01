//
//  SettingsView.swift
//  Volcy
//
//  Settings UI with privacy controls
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var container: DIContainer

    @State private var iCloudBackup = false
    @State private var notifications = false
    @State private var scanReminder = false
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var exportedData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                VolcyColor.canvas.ignoresSafeArea()

                List {
                    // Account Section
                    Section("Account") {
                        NavigationLink("Profile") {
                            Text("Profile - Coming Soon")
                        }

                        NavigationLink("Subscription") {
                            Text("Subscription - Coming Soon")
                        }
                    }
                    .listRowBackground(VolcyColor.surface)

                    // Notifications Section
                    Section("Notifications") {
                        Toggle("Enable Notifications", isOn: $notifications)
                            .onChange(of: notifications) { _, newValue in
                                Task {
                                    try? await container.settingsService.toggleNotifications()
                                }
                            }

                        Toggle("Daily Scan Reminder", isOn: $scanReminder)
                            .onChange(of: scanReminder) { _, newValue in
                                Task {
                                    try? await container.settingsService.toggleScanReminder()
                                }
                            }
                            .disabled(!notifications)
                    }
                    .listRowBackground(VolcyColor.surface)

                    // Privacy Section
                    Section("Privacy & Data") {
                        Toggle("iCloud Backup", isOn: $iCloudBackup)
                            .onChange(of: iCloudBackup) { _, newValue in
                                Task {
                                    try? await container.settingsService.toggleiCloudBackup()
                                }
                            }

                        Button("Export All Data") {
                            Task {
                                await exportData()
                            }
                        }

                        NavigationLink("Privacy Policy") {
                            PrivacyPolicyView()
                        }
                    }
                    .listRowBackground(VolcyColor.surface)

                    // Danger Zone
                    Section("Danger Zone") {
                        Button("Delete All Data", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    }
                    .listRowBackground(VolcyColor.surface)

                    // About Section
                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(VolcyColor.textSecondary)
                        }

                        NavigationLink("Science") {
                            Text("Science - Coming Soon")
                        }

                        NavigationLink("Support") {
                            Text("Support - Coming Soon")
                        }
                    }
                    .listRowBackground(VolcyColor.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(VolcyColor.mint)
                }
            }
            .alert("Delete All Data?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAllData()
                    }
                }
            } message: {
                Text("This will permanently delete all your scans, metrics, and settings. This cannot be undone.")
            }
            .sheet(isPresented: $showingExportSheet) {
                if let data = exportedData {
                    ShareSheet(items: [data])
                }
            }
            .task {
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        iCloudBackup = container.settingsService.iCloudBackupEnabled
        notifications = container.settingsService.notificationsEnabled
        scanReminder = container.settingsService.scanReminderEnabled
    }

    private func exportData() async {
        do {
            let data = try await container.settingsService.exportUserData()
            exportedData = data
            showingExportSheet = true
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func deleteAllData() async {
        do {
            try await container.settingsService.deleteAllUserData()
            dismiss()
        } catch {
            print("Delete failed: \(error)")
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VolcySpacing.lg) {
                Text("Privacy Policy")
                    .font(.system(size: VolcyTypography.h1Size, weight: .bold))
                    .foregroundColor(VolcyColor.textPrimary)

                Group {
                    privacySection(
                        title: "Data Collection",
                        content: "Volcy processes all images and depth data on your device. We never upload your photos or depth maps to our servers."
                    )

                    privacySection(
                        title: "Metrics Only Sync",
                        content: "Only numerical metrics (diameter, elevation, redness) are synced to CloudKit for viewing on the web dashboard. Your media stays on your device."
                    )

                    privacySection(
                        title: "On-Device ML",
                        content: "All machine learning inference happens on your iPhone using Core ML. Your images never leave your device for processing."
                    )

                    privacySection(
                        title: "Data Control",
                        content: "You can export all your data as JSON or delete everything at any time from Settings."
                    )

                    privacySection(
                        title: "No Tracking",
                        content: "Volcy does not use any third-party analytics or advertising. We respect your privacy."
                    )
                }
            }
            .padding(VolcySpacing.lg)
        }
        .background(VolcyColor.canvas)
    }

    private func privacySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: VolcySpacing.sm) {
            Text(title)
                .font(.system(size: VolcyTypography.h3Size, weight: .semibold))
                .foregroundColor(VolcyColor.textPrimary)

            Text(content)
                .font(.system(size: VolcyTypography.bodySize))
                .foregroundColor(VolcyColor.textSecondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
