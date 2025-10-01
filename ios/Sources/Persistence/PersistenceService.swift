//
//  PersistenceService.swift
//  Volcy
//
//  Core Data persistence implementation
//

import Foundation
import CoreData
import UIKit

class PersistenceServiceImpl: PersistenceService {

    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    init() {
        container = NSPersistentContainer(name: "Volcy")

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data store failed to load: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        context = container.viewContext
    }

    // MARK: - Save

    func saveContext() {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }

    // MARK: - Fetch Operations

    func fetchScans(limit: Int) async throws -> [ScanEntity] {
        let request = NSFetchRequest<ScanEntity>(entityName: "Scan")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit

        return try context.fetch(request)
    }

    func fetchLesions(for scanId: UUID) async throws -> [LesionEntity] {
        let request = NSFetchRequest<LesionEntity>(entityName: "Lesion")
        request.predicate = NSPredicate(format: "scanId == %@", scanId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        return try context.fetch(request)
    }

    func fetchUserProfile() async throws -> UserProfileEntity? {
        let request = NSFetchRequest<UserProfileEntity>(entityName: "UserProfile")
        request.fetchLimit = 1

        let results = try context.fetch(request)
        return results.first
    }

    func fetchRegimenEvents(from startDate: Date, to endDate: Date) async throws -> [RegimenEventEntity] {
        let request = NSFetchRequest<RegimenEventEntity>(entityName: "RegimenEvent")
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as CVarArg, endDate as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        return try context.fetch(request)
    }

    // MARK: - Create Operations

    func createUserProfile(skinType: String, fitzpatrick: Int) async throws -> UserProfileEntity {
        let profile = UserProfileEntity(context: context)
        profile.id = UUID()
        profile.skinType = skinType
        profile.fitzpatrick = Int16(fitzpatrick)
        profile.createdAt = Date()
        profile.isOnboarded = true

        try context.save()
        return profile
    }

    func createScan(
        timestamp: Date,
        mode: String,
        distanceMM: Double,
        imagePath: String,
        depthPath: String?,
        clarityScore: Int
    ) async throws -> ScanEntity {
        let scan = ScanEntity(context: context)
        scan.id = UUID()
        scan.timestamp = timestamp
        scan.mode = mode
        scan.distanceMM = distanceMM
        scan.imagePath = imagePath
        scan.depthPath = depthPath
        scan.clarityScore = Int16(clarityScore)

        try context.save()
        return scan
    }

    func createLesion(metrics: LesionMetrics, scanId: UUID) async throws -> LesionEntity {
        let lesion = LesionEntity(context: context)
        lesion.id = metrics.lesionId
        lesion.stableId = "\(metrics.lesionId)"
        lesion.scanId = scanId
        lesion.lesionClass = metrics.lesionClass.rawValue
        lesion.diameterMM = metrics.diameterMM
        lesion.elevationMM = metrics.elevationMM
        lesion.volumeMM3 = metrics.volumeMM3
        lesion.erythemaDeltaAstar = metrics.erythemaDeltaAstar
        lesion.deltaE = metrics.deltaE
        lesion.confidence = metrics.confidence
        lesion.createdAt = metrics.timestamp

        try context.save()
        return lesion
    }

    func createRegimenEvent(products: [String], notes: String?) async throws -> RegimenEventEntity {
        let event = RegimenEventEntity(context: context)
        event.id = UUID()
        event.timestamp = Date()
        event.products = products as NSObject
        event.notes = notes

        try context.save()
        return event
    }

    // MARK: - Delete Operations

    func deleteScan(_ scanId: UUID) async throws {
        let request = NSFetchRequest<ScanEntity>(entityName: "Scan")
        request.predicate = NSPredicate(format: "id == %@", scanId as CVarArg)

        let scans = try context.fetch(request)
        for scan in scans {
            context.delete(scan)
        }

        try context.save()
    }

    func deleteAllData() async throws {
        // Delete all entities
        let entityNames = ["UserProfile", "Scan", "Lesion", "RegionSummary", "RegimenEvent"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            try context.execute(deleteRequest)
        }

        try context.save()
    }

    // MARK: - Export Operations

    func exportAllData() async throws -> Data {
        let profile = try await fetchUserProfile()
        let scans = try await fetchScans(limit: 10000)
        let events = try await fetchRegimenEvents(from: Date.distantPast, to: Date())

        let exportData: [String: Any] = [
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "profile": profile?.toDictionary() ?? [:],
            "scans": scans.map { $0.toDictionary() },
            "regimen_events": events.map { $0.toDictionary() }
        ]

        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
}

// MARK: - Entity Extensions for Export

extension UserProfileEntity {
    func toDictionary() -> [String: Any] {
        return [
            "id": id?.uuidString ?? "",
            "skin_type": skinType ?? "",
            "fitzpatrick": fitzpatrick,
            "created_at": createdAt?.ISO8601Format() ?? ""
        ]
    }
}

extension ScanEntity {
    func toDictionary() -> [String: Any] {
        return [
            "id": id?.uuidString ?? "",
            "timestamp": timestamp?.ISO8601Format() ?? "",
            "mode": mode ?? "",
            "distance_mm": distanceMM,
            "clarity_score": clarityScore
        ]
    }
}

extension RegimenEventEntity {
    func toDictionary() -> [String: Any] {
        return [
            "id": id?.uuidString ?? "",
            "timestamp": timestamp?.ISO8601Format() ?? "",
            "products": products as? [String] ?? [],
            "notes": notes ?? ""
        ]
    }
}

// MARK: - Core Data Entity Definitions (to be created in .xcdatamodeld)

/*
 Create these entities in Xcode's Core Data Model Editor:

 UserProfile:
 - id: UUID
 - skinType: String
 - fitzpatrick: Int16
 - createdAt: Date
 - isOnboarded: Bool

 Scan:
 - id: UUID
 - timestamp: Date
 - mode: String
 - distanceMM: Double
 - imagePath: String
 - depthPath: String?
 - clarityScore: Int16

 Lesion:
 - id: UUID
 - stableId: String (indexed)
 - scanId: UUID (indexed)
 - lesionClass: String
 - name: String?
 - uvX: Double
 - uvY: Double
 - diameterMM: Double
 - elevationMM: Double
 - volumeMM3: Double
 - erythemaDeltaAstar: Double
 - deltaE: Double
 - confidence: Double
 - createdAt: Date

 RegionSummary:
 - id: UUID
 - scanId: UUID
 - region: String
 - papuleCount: Int16
 - pustuleCount: Int16
 - noduleCount: Int16
 - comedoneCount: Int16
 - pihPieCount: Int16
 - scarCount: Int16
 - inflamedAreaMM2: Double
 - meanDiameterMM: Double
 - createdAt: Date

 RegimenEvent:
 - id: UUID
 - timestamp: Date
 - products: Transformable ([String])
 - notes: String?
 */

// Placeholder entity types (will be generated by Xcode)
typealias UserProfileEntity = NSManagedObject
typealias ScanEntity = NSManagedObject
typealias LesionEntity = NSManagedObject
typealias RegionSummaryEntity = NSManagedObject
typealias RegimenEventEntity = NSManagedObject
