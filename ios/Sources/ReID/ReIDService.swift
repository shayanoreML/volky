//
//  ReIDService.swift
//  Volcy
//
//  Lesion re-identification across scans using UV mapping + Hungarian matching
//

import Foundation
import ARKit
import simd

class ReIDServiceImpl: ReIDService {

    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    // MARK: - ReIDService Protocol

    func buildUVMap(from faceAnchor: ARFaceAnchor) async throws -> UVFaceMap {
        let geometry = faceAnchor.geometry

        // Extract vertices and UV coordinates
        let vertices = geometry.vertices
        let textureCoordinates = geometry.textureCoordinates

        var uvCoordinates: [[simd_float2]] = []
        var triangles: [[Int]] = []

        // Convert to Swift arrays
        for i in 0..<geometry.vertexCount {
            let uv = textureCoordinates[Int(i)]
            uvCoordinates.append([uv])
        }

        // Extract triangle indices
        for i in stride(from: 0, to: geometry.triangleCount * 3, by: 3) {
            let indices = geometry.triangleIndices
            let triangle = [
                Int(indices[i]),
                Int(indices[i + 1]),
                Int(indices[i + 2])
            ]
            triangles.append(triangle)
        }

        return UVFaceMap(
            uvCoordinates: uvCoordinates,
            triangles: triangles,
            userId: UUID(), // Will be set by caller
            createdAt: Date()
        )
    }

    func matchLesions(
        current: [DetectedLesionInfo],
        previous: [LesionMetrics],
        uvMap: UVFaceMap
    ) -> [LesionMatch] {
        // Convert previous metrics to TrackedLesion format
        let trackedLesions = previous.map { metric in
            TrackedLesion(
                id: metric.lesionId,
                stableId: "\(metric.lesionId)",
                userId: UUID(),
                class: metric.lesionClass,
                name: nil,
                firstSeenAt: metric.timestamp,
                lastSeenAt: metric.timestamp,
                consecutiveScansTracked: 1,
                lastUVPosition: simd_float2(0.5, 0.5), // TODO: Store UV in metrics
                appearance: LesionAppearance(
                    embedding: [],
                    meanColor: (0, 0, 0),
                    texture: LesionAppearance.TextureFeatures(gabor: [], lbp: [])
                ),
                metricsHistory: [metric]
            )
        }

        // Use Hungarian matcher
        let matcher = HungarianMatcher()
        return matcher.match(
            current: convertToDetectedLesions(current),
            previous: trackedLesions,
            uvMap: uvMap
        )
    }

    // MARK: - Private Helpers

    private func convertToDetectedLesions(_ infos: [DetectedLesionInfo]) -> [DetectedLesion] {
        return infos.map { info in
            DetectedLesion(
                uvPosition: simd_float2(
                    Float(info.center.x) / 1000.0, // Normalize to [0, 1]
                    Float(info.center.y) / 1000.0
                ),
                class: info.class,
                boundingBox: info.boundingBox,
                maskPath: nil,
                appearance: LesionAppearance(
                    embedding: [],
                    meanColor: (0, 0, 0),
                    texture: LesionAppearance.TextureFeatures(gabor: [], lbp: [])
                ),
                geometry: LesionGeometry(
                    centerUV: simd_float2(Float(info.center.x), Float(info.center.y)),
                    sizeMM: sqrt(Double(info.pixelCount)) * 0.1, // Rough estimate
                    orientation: 0.0,
                    aspectRatio: info.boundingBox.width / info.boundingBox.height
                ),
                confidence: info.confidence,
                scanId: UUID(),
                timestamp: Date()
            )
        }
    }
}
