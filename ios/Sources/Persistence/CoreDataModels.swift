//
//  CoreDataModels.swift
//  Volcy
//
//  Core Data entity definitions and models
//

import Foundation
import CoreData

// MARK: - Core Data Stack

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Volcy")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data store failed to load: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Entity Schemas

/*
 Core Data Entities (to be created in .xcdatamodeld):

 1. UserProfile
    - id: UUID (primary key)
    - skinType: String
    - fitzpatrick: Int16
    - createdAt: Date
    - isOnboarded: Bool
    - scans: [Scan] (relationship)

 2. Scan
    - id: UUID (primary key)
    - timestamp: Date
    - mode: String (front/rear)
    - distanceMM: Double
    - pose: Transformable (simd_float4x4)
    - qcFlags: String (JSON)
    - imagePath: String
    - depthPath: String?
    - intrinsics: Transformable (CameraIntrinsics)
    - lightingStats: Transformable (LightingStats)
    - clarityScore: Int16
    - user: UserProfile (relationship)
    - lesions: [Lesion] (relationship)
    - regionSummary: RegionSummary (relationship)

 3. Lesion
    - id: UUID (primary key)
    - stableId: String (indexed)
    - scanId: UUID (indexed)
    - class: String
    - name: String?
    - uvX: Double
    - uvY: Double
    - bbox: Transformable (CGRect)
    - maskPath: String?
    - diameterMM: Double
    - elevationMM: Double
    - volumeMM3: Double
    - erythemaDeltaAstar: Double
    - deltaE: Double
    - confidence: Double
    - createdAt: Date
    - scan: Scan (relationship)

 4. RegionSummary
    - id: UUID (primary key)
    - scanId: UUID (indexed)
    - region: String
    - papuleCount: Int16
    - pustuleCount: Int16
    - noduleCount: Int16
    - comedoneCount: Int16
    - pihPieCount: Int16
    - scarCount: Int16
    - inflamedAreaMM2: Double
    - meanDiameterMM: Double
    - meanElevationMM: Double
    - meanErythemaDeltaAstar: Double
    - createdAt: Date
    - scan: Scan (relationship)

 5. RegimenEvent
    - id: UUID (primary key)
    - userId: UUID (indexed)
    - timestamp: Date
    - products: Transformable ([String])
    - notes: String?
    - user: UserProfile (relationship)
*/

// MARK: - Model Extensions

extension UserProfile {
    var scansArray: [Scan] {
        let set = scans as? Set<Scan> ?? []
        return set.sorted { $0.timestamp > $1.timestamp }
    }

    static func create(in context: NSManagedObjectContext,
                      skinType: String,
                      fitzpatrick: Int) -> UserProfile {
        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.skinType = skinType
        profile.fitzpatrick = Int16(fitzpatrick)
        profile.createdAt = Date()
        profile.isOnboarded = true
        return profile
    }
}

extension Scan {
    var lesionsArray: [Lesion] {
        let set = lesions as? Set<Lesion> ?? []
        return set.sorted { $0.createdAt < $1.createdAt }
    }

    static func create(in context: NSManagedObjectContext,
                      user: UserProfile,
                      capturedFrame: CapturedFrame) -> Scan {
        let scan = Scan(context: context)
        scan.id = UUID()
        scan.timestamp = capturedFrame.timestamp
        scan.mode = "front" // TODO: Detect mode
        scan.distanceMM = 280.0 // TODO: Calculate from QC
        scan.imagePath = "" // TODO: Save image and set path
        scan.depthPath = nil // TODO: Save depth and set path
        scan.clarityScore = 0 // TODO: Calculate
        scan.user = user
        return scan
    }
}

extension Lesion {
    static func create(in context: NSManagedObjectContext,
                      scan: Scan,
                      detected: DetectedLesion,
                      metrics: LesionMetrics) -> Lesion {
        let lesion = Lesion(context: context)
        lesion.id = UUID()
        lesion.stableId = detected.generateStableId()
        lesion.scanId = scan.id
        lesion.`class` = detected.class.rawValue
        lesion.name = nil
        lesion.uvX = Double(detected.uvPosition.x)
        lesion.uvY = Double(detected.uvPosition.y)
        lesion.diameterMM = metrics.diameterMM
        lesion.elevationMM = metrics.elevationMM
        lesion.volumeMM3 = metrics.volumeMM3
        lesion.erythemaDeltaAstar = metrics.erythemaDeltaAstar
        lesion.deltaE = metrics.deltaE
        lesion.confidence = metrics.confidence
        lesion.createdAt = Date()
        lesion.scan = scan
        return lesion
    }
}

extension RegionSummary {
    static func create(in context: NSManagedObjectContext,
                      scan: Scan,
                      region: String,
                      summary: RegionSummaryData) -> RegionSummary {
        let regionSummary = RegionSummary(context: context)
        regionSummary.id = UUID()
        regionSummary.scanId = scan.id
        regionSummary.region = region
        regionSummary.papuleCount = Int16(summary.papuleCount)
        regionSummary.pustuleCount = Int16(summary.pustuleCount)
        regionSummary.noduleCount = Int16(summary.noduleCount)
        regionSummary.comedoneCount = Int16(summary.comedoneCount)
        regionSummary.pihPieCount = Int16(summary.pihPieCount)
        regionSummary.scarCount = Int16(summary.scarCount)
        regionSummary.inflamedAreaMM2 = summary.inflamedAreaMM2
        regionSummary.meanDiameterMM = summary.meanDiameterMM
        regionSummary.meanElevationMM = summary.meanElevationMM
        regionSummary.meanErythemaDeltaAstar = summary.meanErythemaDeltaAstar
        regionSummary.createdAt = Date()
        regionSummary.scan = scan
        return regionSummary
    }
}

extension RegimenEvent {
    static func create(in context: NSManagedObjectContext,
                      user: UserProfile,
                      products: [String],
                      notes: String?) -> RegimenEvent {
        let event = RegimenEvent(context: context)
        event.id = UUID()
        event.userId = user.id
        event.timestamp = Date()
        event.products = products as NSObject
        event.notes = notes
        event.user = user
        return event
    }
}

// MARK: - Supporting Models

struct RegionSummaryData {
    let papuleCount: Int
    let pustuleCount: Int
    let noduleCount: Int
    let comedoneCount: Int
    let pihPieCount: Int
    let scarCount: Int
    let inflamedAreaMM2: Double
    let meanDiameterMM: Double
    let meanElevationMM: Double
    let meanErythemaDeltaAstar: Double
}
