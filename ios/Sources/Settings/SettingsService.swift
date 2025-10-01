//
//  SettingsService.swift
//  Volcy
//
//  Settings and privacy controls
//

import Foundation

class SettingsServiceImpl: SettingsService {

    private let persistenceService: PersistenceService
    private let userDefaults = UserDefaults.standard

    // Keys
    private let iCloudBackupKey = "iCloudBackupEnabled"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let scanReminderKey = "scanReminderEnabled"

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    // MARK: - SettingsService Protocol

    var iCloudBackupEnabled: Bool {
        userDefaults.bool(forKey: iCloudBackupKey)
    }

    var notificationsEnabled: Bool {
        userDefaults.bool(forKey: notificationsEnabledKey)
    }

    var scanReminderEnabled: Bool {
        userDefaults.bool(forKey: scanReminderKey)
    }

    func toggleiCloudBackup() async throws {
        let newValue = !iCloudBackupEnabled
        userDefaults.set(newValue, forKey: iCloudBackupKey)
    }

    func toggleNotifications() async throws {
        let newValue = !notificationsEnabled
        userDefaults.set(newValue, forKey: notificationsEnabledKey)

        // Request notification permission if enabling
        if newValue {
            try await requestNotificationPermission()
        }
    }

    func toggleScanReminder() async throws {
        let newValue = !scanReminderEnabled
        userDefaults.set(newValue, forKey: scanReminderKey)
    }

    func exportUserData() async throws -> Data {
        // Export all user data as JSON
        return try await persistenceService.exportAllData()
    }

    func deleteAllUserData() async throws {
        // Confirm with user first (handled by UI)
        try await persistenceService.deleteAllData()

        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleID)
        }
    }

    // MARK: - Private Methods

    private func requestNotificationPermission() async throws {
        let center = UNUserNotificationCenter.current()

        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        let granted = try await center.requestAuthorization(options: options)

        if !granted {
            throw SettingsError.notificationPermissionDenied
        }
    }
}

// MARK: - Supporting Types

enum SettingsError: LocalizedError {
    case notificationPermissionDenied
    case exportFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notificationPermissionDenied:
            return "Notification permission denied. Please enable in Settings."
        case .exportFailed:
            return "Failed to export data"
        case .deleteFailed:
            return "Failed to delete data"
        }
    }
}

import UserNotifications
