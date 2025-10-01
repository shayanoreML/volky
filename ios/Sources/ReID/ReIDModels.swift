//
//  ReIDModels.swift
//  Volcy
//
//  Models for lesion re-identification and tracking
//

import Foundation
import CoreGraphics
import simd

// MARK: - UV Face Map

struct UVFaceMap {
    let uvCoordinates: [[simd_float2]]  // UV coordinates for each vertex
    let triangles: [[Int]]               // Triangle indices
    let userId: UUID
    let createdAt: Date

    /// Map 3D point to UV coordinates
    func mapToUV(point: simd_float3, transform: simd_float4x4) -> simd_float2? {
        // Find closest triangle and compute barycentric coordinates
        // Return UV coordinates
        // TODO: Implement barycentric interpolation
        return nil
    }

    /// Map UV coordinates back to 3D point
    func mapFrom UV(uv: simd_float2, depthMap: ScaledDepthMap) -> simd_float3? {
        // TODO: Implement inverse UV mapping
        return nil
    }
}

// MARK: - Detected Lesion

struct DetectedLesion {
    let uvPosition: simd_float2         // Canonical UV position [0-1, 0-1]
    let class: LesionClass
    let boundingBox: CGRect
    let maskPath: String?               // Path to saved mask
    let appearance: LesionAppearance
    let geometry: LesionGeometry
    let confidence: Double              // Detection confidence [0-1]
    let scanId: UUID
    let timestamp: Date

    /// Create unique stable ID based on UV position and class
    func generateStableId() -> String {
        let uvStr = String(format: "%.3f_%.3f", uvPosition.x, uvPosition.y)
        return "\(class.rawValue)_\(uvStr)"
    }
}

// MARK: - Lesion Class

enum LesionClass: String, Codable, CaseIterable {
    case papule = "papule"
    case pustule = "pustule"
    case nodule = "nodule"
    case comedoneOpen = "comedone_open"
    case comedoneClosed = "comedone_closed"
    case pih = "pih"          // Post-inflammatory hyperpigmentation
    case pie = "pie"          // Post-inflammatory erythema
    case scar = "scar"
    case mole = "mole"        // Masked out, not tracked

    var isInflamed: Bool {
        switch self {
        case .papule, .pustule, .nodule, .pie:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .papule: return "Papule"
        case .pustule: return "Pustule"
        case .nodule: return "Nodule/Cyst"
        case .comedoneOpen: return "Open Comedone"
        case .comedoneClosed: return "Closed Comedone"
        case .pih: return "PIH"
        case .pie: return "PIE"
        case .scar: return "Scar"
        case .mole: return "Mole"
        }
    }
}

// MARK: - Lesion Appearance

struct LesionAppearance {
    let embedding: [Float]              // 64-D appearance embedding
    let meanColor: (r: Double, g: Double, b: Double)
    let texture: TextureFeatures

    struct TextureFeatures {
        let gabor: [Float]              // Gabor filter responses
        let lbp: [Float]                // Local binary patterns
    }

    /// Compute appearance distance between two lesions
    static func distance(_ a: LesionAppearance, _ b: LesionAppearance) -> Double {
        // Cosine distance on embeddings
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0

        for i in 0..<min(a.embedding.count, b.embedding.count) {
            dotProduct += a.embedding[i] * b.embedding[i]
            normA += a.embedding[i] * a.embedding[i]
            normB += b.embedding[i] * b.embedding[i]
        }

        let cosineSim = dotProduct / (sqrt(normA) * sqrt(normB))
        return Double(1.0 - cosineSim)  // Distance = 1 - similarity
    }
}

// MARK: - Lesion Geometry

struct LesionGeometry {
    let centerUV: simd_float2
    let sizeMM: Double
    let orientation: Double             // Radians
    let aspectRatio: Double
}

// MARK: - Lesion Match

struct LesionMatch {
    let currentLesion: DetectedLesion
    let previousLesion: UUID?           // UUID of matched previous lesion
    let matchScore: Double              // [0-1], higher = better match
    let matchType: MatchType

    enum MatchType {
        case tracked                    // Successfully matched
        case new                        // New lesion
        case lost                       // Previously tracked, now disappeared
    }

    var isTracked: Bool {
        matchType == .tracked
    }
}

// MARK: - Hungarian Matcher

struct HungarianMatcher {
    let uvWeight: Double = 0.6
    let appearanceWeight: Double = 0.3
    let classWeight: Double = 0.1
    let maxMatchDistance: Double = 0.5  // Maximum cost for valid match

    /// Match current detections to previous lesions
    /// Returns array of matches using Hungarian algorithm
    func match(current: [DetectedLesion],
              previous: [TrackedLesion],
              uvMap: UVFaceMap) -> [LesionMatch] {
        guard !current.isEmpty && !previous.isEmpty else {
            // All current lesions are new
            return current.map {
                LesionMatch(currentLesion: $0, previousLesion: nil, matchScore: 0, matchType: .new)
            }
        }

        // Build cost matrix
        let costMatrix = buildCostMatrix(current: current, previous: previous)

        // Solve assignment problem (simplified - full Hungarian algorithm needed)
        let assignments = solveAssignment(costMatrix: costMatrix)

        // Build matches
        var matches: [LesionMatch] = []
        for (i, j) in assignments {
            let score = 1.0 - costMatrix[i][j]  // Convert cost to score
            if costMatrix[i][j] <= maxMatchDistance {
                matches.append(LesionMatch(
                    currentLesion: current[i],
                    previousLesion: previous[j].id,
                    matchScore: score,
                    matchType: .tracked
                ))
            } else {
                matches.append(LesionMatch(
                    currentLesion: current[i],
                    previousLesion: nil,
                    matchScore: 0,
                    matchType: .new
                ))
            }
        }

        // Add unmatched current lesions as new
        let matchedIndices = Set(assignments.map { $0.0 })
        for (i, lesion) in current.enumerated() where !matchedIndices.contains(i) {
            matches.append(LesionMatch(
                currentLesion: lesion,
                previousLesion: nil,
                matchScore: 0,
                matchType: .new
            ))
        }

        return matches
    }

    /// Build cost matrix for assignment problem
    private func buildCostMatrix(current: [DetectedLesion], previous: [TrackedLesion]) -> [[Double]] {
        var matrix: [[Double]] = []

        for currLesion in current {
            var row: [Double] = []
            for prevLesion in previous {
                let cost = computeMatchCost(current: currLesion, previous: prevLesion)
                row.append(cost)
            }
            matrix.append(row)
        }

        return matrix
    }

    /// Compute match cost between current and previous lesion
    /// cost = 0.6·UV_dist + 0.3·appearance_dist + 0.1·class_penalty
    private func computeMatchCost(current: DetectedLesion, previous: TrackedLesion) -> Double {
        // UV distance
        let uvDist = simd_distance(current.uvPosition, previous.lastUVPosition)

        // Appearance distance
        let appearanceDist = LesionAppearance.distance(
            current.appearance,
            previous.appearance
        )

        // Class penalty
        let classPenalty = current.class == previous.class ? 0.0 : 1.0

        let cost = uvWeight * Double(uvDist) +
                   appearanceWeight * appearanceDist +
                   classWeight * classPenalty

        return cost
    }

    /// Solve assignment problem (simplified greedy approach)
    /// TODO: Implement full Hungarian algorithm for optimal assignment
    private func solveAssignment(costMatrix: [[Double]]) -> [(Int, Int)] {
        var assignments: [(Int, Int)] = []
        var usedRows = Set<Int>()
        var usedCols = Set<Int>()

        // Greedy: repeatedly pick minimum cost assignment
        while usedRows.count < costMatrix.count && usedCols.count < costMatrix[0].count {
            var minCost = Double.infinity
            var minPos: (Int, Int)?

            for (i, row) in costMatrix.enumerated() where !usedRows.contains(i) {
                for (j, cost) in row.enumerated() where !usedCols.contains(j) {
                    if cost < minCost {
                        minCost = cost
                        minPos = (i, j)
                    }
                }
            }

            if let pos = minPos {
                assignments.append(pos)
                usedRows.insert(pos.0)
                usedCols.insert(pos.1)
            } else {
                break
            }
        }

        return assignments
    }
}

// MARK: - Tracked Lesion

struct TrackedLesion {
    let id: UUID
    let stableId: String                // User-facing stable ID
    let userId: UUID
    let `class`: LesionClass
    let name: String?                   // User-assigned name (e.g., "Volcy")

    // Tracking state
    let firstSeenAt: Date
    let lastSeenAt: Date
    let consecutiveScansTracked: Int
    let lastUVPosition: simd_float2
    let appearance: LesionAppearance

    // History
    let metricsHistory: [LesionMetrics]

    var isConsistentlyTracked: Bool {
        consecutiveScansTracked >= 3
    }

    /// Acceptance: ≥90% weekly continuity for persistent lesions
    func weeklyContinuity(over weeks: Int = 1) -> Double {
        let expectedScans = weeks * 7  // Assuming daily scans
        let actualScans = consecutiveScansTracked
        return Double(actualScans) / Double(expectedScans)
    }
}
