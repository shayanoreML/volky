//
//  PlaneFitter.swift
//  Volcy
//
//  RANSAC plane fitting for elevation measurement
//

import Foundation
import simd
import Accelerate

/// Fits local planes to depth data for elevation calculation
class PlaneFitter {

    // MARK: - Public Methods

    /// Fit plane to depth points around a region
    /// Uses RANSAC for robust fitting
    func fitPlane(to points: [simd_float3], iterations: Int = 100) -> LocalPlaneFit? {
        guard points.count >= 3 else { return nil }

        var bestFit: LocalPlaneFit?
        var bestInlierCount = 0
        let inlierThreshold: Float = 2.0 // 2mm tolerance

        // RANSAC iterations
        for _ in 0..<iterations {
            // Randomly sample 3 points
            let indices = (0..<points.count).shuffled().prefix(3)
            let sample = indices.map { points[$0] }

            // Fit plane to sample
            guard let plane = fitPlaneToThreePoints(sample[0], sample[1], sample[2]) else {
                continue
            }

            // Count inliers
            var inlierCount = 0
            var squaredErrorSum: Double = 0.0

            for point in points {
                let distance = abs(distanceToPlane(point: point, plane: plane))
                if distance <= inlierThreshold {
                    inlierCount += 1
                    squaredErrorSum += Double(distance * distance)
                }
            }

            // Update best fit
            if inlierCount > bestInlierCount {
                bestInlierCount = inlierCount
                let rmse = sqrt(squaredErrorSum / Double(inlierCount))

                bestFit = LocalPlaneFit(
                    normal: plane.normal,
                    point: plane.point,
                    inliers: inlierCount,
                    rmse: rmse
                )
            }
        }

        return bestFit
    }

    /// Fit plane to boundary ring around lesion (for elevation baseline)
    func fitBoundaryPlane(depthMap: ScaledDepthMap, mask: [[Bool]], dilationRadius: Int = 5) -> LocalPlaneFit? {
        // Extract boundary points (dilated mask - original mask)
        let boundaryPoints = extractBoundaryPoints(depthMap: depthMap, mask: mask, dilationRadius: dilationRadius)

        guard !boundaryPoints.isEmpty else { return nil }

        return fitPlane(to: boundaryPoints)
    }

    /// Calculate elevation map relative to plane
    func calculateElevationMap(depthMap: ScaledDepthMap, plane: LocalPlaneFit, mask: [[Bool]]) -> [[Double]] {
        var elevationMap = Array(repeating: Array(repeating: 0.0, count: depthMap.width), count: depthMap.height)

        for y in 0..<depthMap.height {
            for x in 0..<depthMap.width {
                guard mask[y][x] else { continue }

                let depth = depthMap.depthMM[y][x]
                guard depth > 0 else { continue }

                // Convert pixel to 3D point
                let point = simd_float3(Float(x), Float(y), Float(depth))

                // Calculate elevation above plane
                elevationMap[y][x] = plane.elevation(of: point)
            }
        }

        return elevationMap
    }

    // MARK: - Private Methods

    private func fitPlaneToThreePoints(_ p1: simd_float3, _ p2: simd_float3, _ p3: simd_float3) -> (normal: simd_float3, point: simd_float3)? {
        // Calculate plane from 3 points
        // Normal = (p2 - p1) × (p3 - p1)
        let v1 = p2 - p1
        let v2 = p3 - p1

        let normal = simd_cross(v1, v2)
        let length = simd_length(normal)

        guard length > 0.001 else { return nil } // Degenerate case

        let normalizedNormal = simd_normalize(normal)

        return (normalizedNormal, p1)
    }

    private func distanceToPlane(point: simd_float3, plane: (normal: simd_float3, point: simd_float3)) -> Float {
        // Distance = |normal · (point - planePoint)|
        return simd_dot(plane.normal, point - plane.point)
    }

    private func extractBoundaryPoints(depthMap: ScaledDepthMap, mask: [[Bool]], dilationRadius: Int) -> [simd_float3] {
        // Dilate mask to create boundary ring
        let dilatedMask = dilateMask(mask, radius: dilationRadius)

        var points: [simd_float3] = []

        for y in 0..<depthMap.height {
            for x in 0..<depthMap.width {
                // Boundary = dilated but not original
                if dilatedMask[y][x] && !mask[y][x] {
                    let depth = depthMap.depthMM[y][x]
                    if depth > 0 {
                        points.append(simd_float3(Float(x), Float(y), Float(depth)))
                    }
                }
            }
        }

        return points
    }

    private func dilateMask(_ mask: [[Bool]], radius: Int) -> [[Bool]] {
        let height = mask.count
        let width = mask[0].count

        var dilated = mask

        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] {
                    // Dilate around this pixel
                    for dy in -radius...radius {
                        for dx in -radius...radius {
                            let nx = x + dx
                            let ny = y + dy

                            if nx >= 0 && nx < width && ny >= 0 && ny < height {
                                let dist = sqrt(Double(dx * dx + dy * dy))
                                if dist <= Double(radius) {
                                    dilated[ny][nx] = true
                                }
                            }
                        }
                    }
                }
            }
        }

        return dilated
    }
}

// MARK: - Depth Quality Evaluator

class DepthQualityEvaluator {

    /// Calculate depth quality metrics for a region
    func evaluate(depthMap: ScaledDepthMap, mask: [[Bool]]) -> DepthQualityMetrics {
        var confidenceSum: Double = 0.0
        var validPixels = 0
        var totalMaskedPixels = 0
        var depthValues: [Double] = []

        for y in 0..<depthMap.height {
            for x in 0..<depthMap.width {
                if mask[y][x] {
                    totalMaskedPixels += 1

                    let depth = depthMap.depthMM[y][x]
                    let conf = depthMap.confidence[y][x]

                    if depth > 0 {
                        validPixels += 1
                        confidenceSum += Double(conf)
                        depthValues.append(depth)
                    }
                }
            }
        }

        let meanConfidence = validPixels > 0 ? confidenceSum / Double(validPixels) : 0.0
        let validPixelRatio = totalMaskedPixels > 0 ? Double(validPixels) / Double(totalMaskedPixels) : 0.0

        // Calculate uniformity (inverse of coefficient of variation)
        let uniformity = calculateUniformity(depthValues)

        // Calculate noise level (local standard deviation)
        let noiseLevel = calculateNoiseLevel(depthMap: depthMap, mask: mask)

        return DepthQualityMetrics(
            meanConfidence: meanConfidence,
            validPixelRatio: validPixelRatio,
            uniformity: uniformity,
            noiseLevel: noiseLevel
        )
    }

    private func calculateUniformity(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 1.0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)

        let coefficientOfVariation = mean > 0 ? stdDev / mean : 0.0

        // Uniformity = 1 - CV (clamped to [0, 1])
        return max(0.0, min(1.0, 1.0 - coefficientOfVariation))
    }

    private func calculateNoiseLevel(depthMap: ScaledDepthMap, mask: [[Bool]]) -> Double {
        // Calculate local standard deviations (3x3 neighborhoods)
        var localStdDevs: [Double] = []

        for y in 1..<(depthMap.height - 1) {
            for x in 1..<(depthMap.width - 1) {
                guard mask[y][x] else { continue }

                var neighborValues: [Double] = []
                for dy in -1...1 {
                    for dx in -1...1 {
                        let depth = depthMap.depthMM[y + dy][x + dx]
                        if depth > 0 {
                            neighborValues.append(depth)
                        }
                    }
                }

                if neighborValues.count >= 5 {
                    let mean = neighborValues.reduce(0, +) / Double(neighborValues.count)
                    let variance = neighborValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(neighborValues.count)
                    localStdDevs.append(sqrt(variance))
                }
            }
        }

        guard !localStdDevs.isEmpty else { return 0.0 }

        // Return median local std dev as noise measure
        let sorted = localStdDevs.sorted()
        return sorted[sorted.count / 2]
    }
}
