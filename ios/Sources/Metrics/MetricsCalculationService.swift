//
//  MetricsCalculationService.swift
//  Volcy
//
//  Calculate per-lesion metrics: diameter, elevation, volume, redness, etc.
//

import Foundation
import CoreGraphics
import simd

/// Comprehensive metrics calculation service
class MetricsCalculationService: MetricsService {

    private let planeFitter = PlaneFitter()
    private let depthQualityEvaluator = DepthQualityEvaluator()

    // MARK: - MetricsService Protocol

    func calculateMetrics(
        lesion: DetectedLesionInfo,
        depthMap: ScaledDepthMap,
        image: CGImage,
        mask: [[Bool]]
    ) -> LesionMetrics {
        // 1. Diameter measurements
        let (maxFeretDiameter, equivalentDiameter, areaMM2) = calculateDiameters(
            lesion: lesion,
            depthMap: depthMap,
            mask: mask
        )

        // 2. Elevation measurement
        let (elevationMM, volumeMM3, plane) = calculateElevation(
            lesion: lesion,
            depthMap: depthMap,
            mask: mask
        )

        // 3. Redness (Δa*)
        let erythemaDeltaAstar = calculateRedness(
            lesion: lesion,
            image: image,
            mask: mask
        )

        // 4. Shape metrics
        let (perimeter, circularity, aspectRatio) = calculateShapeMetrics(
            lesion: lesion,
            mask: mask
        )

        // 5. Quality metrics
        let depthQuality = depthQualityEvaluator.evaluate(depthMap: depthMap, mask: mask)

        // 6. Overall confidence
        let confidence = calculateOverallConfidence(
            lesionConfidence: lesion.confidence,
            depthQuality: depthQuality
        )

        return LesionMetrics(
            lesionId: UUID(),
            timestamp: Date(),
            diameterMM: maxFeretDiameter,
            equivalentDiameterMM: equivalentDiameter,
            areaMM2: areaMM2,
            elevationMM: elevationMM,
            volumeMM3: volumeMM3,
            erythemaDeltaAstar: erythemaDeltaAstar,
            meanLstar: 0.0, // TODO: Calculate from image
            deltaE: 0.0, // TODO: Calculate color difference from baseline
            perimeter: perimeter,
            circularity: circularity,
            aspectRatio: aspectRatio,
            confidence: confidence,
            depthQuality: depthQuality,
            scaleMethod: depthMap.scale.method
        )
    }

    func calculateRegionSummary(lesions: [LesionMetrics], region: RegionSummary.FaceRegion) -> RegionSummary {
        // Count by class
        let papuleCount = lesions.filter { $0.lesionClass == .papule }.count
        let pustuleCount = lesions.filter { $0.lesionClass == .pustule }.count
        let noduleCount = lesions.filter { $0.lesionClass == .nodule }.count
        let comedoneCount = lesions.filter {
            $0.lesionClass == .comedoneOpen || $0.lesionClass == .comedoneClosed
        }.count
        let pihPieCount = lesions.filter {
            $0.lesionClass == .pih || $0.lesionClass == .pie
        }.count
        let scarCount = lesions.filter { $0.lesionClass == .scar }.count

        // Aggregate metrics
        let inflamedLesions = lesions.filter { [.papule, .pustule, .nodule, .pie].contains($0.lesionClass) }
        let inflamedAreaMM2 = inflamedLesions.reduce(0.0) { $0 + $1.areaMM2 }

        let meanDiameterMM = lesions.isEmpty ? 0.0 : lesions.reduce(0.0) { $0 + $1.diameterMM } / Double(lesions.count)
        let meanElevationMM = lesions.isEmpty ? 0.0 : lesions.reduce(0.0) { $0 + $1.elevationMM } / Double(lesions.count)
        let meanErythemaDeltaAstar = inflamedLesions.isEmpty ? 0.0 :
            inflamedLesions.reduce(0.0) { $0 + $1.erythemaDeltaAstar } / Double(inflamedLesions.count)

        return RegionSummary(
            region: region,
            scanId: UUID(), // Will be set by persistence layer
            timestamp: Date(),
            papuleCount: papuleCount,
            pustuleCount: pustuleCount,
            noduleCount: noduleCount,
            comedoneCount: comedoneCount,
            pihPieCount: pihPieCount,
            scarCount: scarCount,
            inflamedAreaMM2: inflamedAreaMM2,
            meanDiameterMM: meanDiameterMM,
            meanElevationMM: meanElevationMM,
            meanErythemaDeltaAstar: meanErythemaDeltaAstar
        )
    }

    // MARK: - Diameter Calculation

    private func calculateDiameters(
        lesion: DetectedLesionInfo,
        depthMap: ScaledDepthMap,
        mask: [[Bool]]
    ) -> (maxFeret: Double, equivalent: Double, area: Double) {
        // Extract contour points
        let contour = extractContour(from: mask, boundingBox: lesion.boundingBox)

        guard !contour.isEmpty else {
            return (0.0, 0.0, 0.0)
        }

        // Get depth at lesion center for scaling
        guard let centerDepth = depthMap.depth(at: lesion.center), centerDepth > 0 else {
            return (0.0, 0.0, 0.0)
        }

        // Calculate max Feret diameter (largest caliper distance)
        var maxDistance: Double = 0.0
        for i in 0..<contour.count {
            for j in (i+1)..<contour.count {
                let p1 = contour[i]
                let p2 = contour[j]
                let distance = hypot(p2.x - p1.x, p2.y - p1.y)
                maxDistance = max(maxDistance, distance)
            }
        }

        // Convert pixels to mm
        let intrinsics = depthMap.scale.intrinsics
        let avgFocalLength = intrinsics != nil ?
            (intrinsics!.focalLengthX + intrinsics!.focalLengthY) / 2.0 : 1000.0
        let maxFeretMM = (maxDistance * centerDepth) / avgFocalLength

        // Calculate area
        let pixelCount = Double(lesion.pixelCount)
        let pixelToMM2 = (centerDepth / avgFocalLength) * (centerDepth / avgFocalLength)
        let areaMM2 = pixelCount * pixelToMM2

        // Equivalent diameter (circle with same area)
        let equivalentDiameterMM = 2.0 * sqrt(areaMM2 / Double.pi)

        return (maxFeretMM, equivalentDiameterMM, areaMM2)
    }

    private func extractContour(from mask: [[Bool]], boundingBox: CGRect) -> [CGPoint] {
        var contour: [CGPoint] = []

        let minX = Int(boundingBox.minX)
        let maxX = Int(boundingBox.maxX)
        let minY = Int(boundingBox.minY)
        let maxY = Int(boundingBox.maxY)

        for y in minY...maxY {
            for x in minX...maxX {
                guard y < mask.count && x < mask[0].count else { continue }

                if mask[y][x] {
                    // Check if boundary pixel (has at least one non-mask neighbor)
                    let neighbors = [
                        (x + 1, y), (x - 1, y),
                        (x, y + 1), (x, y - 1)
                    ]

                    for (nx, ny) in neighbors {
                        if nx < 0 || nx >= mask[0].count || ny < 0 || ny >= mask.count || !mask[ny][nx] {
                            contour.append(CGPoint(x: x, y: y))
                            break
                        }
                    }
                }
            }
        }

        return contour
    }

    // MARK: - Elevation Calculation

    private func calculateElevation(
        lesion: DetectedLesionInfo,
        depthMap: ScaledDepthMap,
        mask: [[Bool]]
    ) -> (elevation: Double, volume: Double, plane: LocalPlaneFit?) {
        // Fit plane to boundary ring
        guard let plane = planeFitter.fitBoundaryPlane(depthMap: depthMap, mask: mask, dilationRadius: 5) else {
            return (0.0, 0.0, nil)
        }

        // Calculate elevation map
        let elevationMap = planeFitter.calculateElevationMap(depthMap: depthMap, plane: plane, mask: mask)

        // Calculate mean and max elevation
        var elevationSum: Double = 0.0
        var maxElevation: Double = 0.0
        var count = 0

        for y in 0..<elevationMap.count {
            for x in 0..<elevationMap[0].count {
                if mask[y][x] && elevationMap[y][x] > 0 {
                    elevationSum += elevationMap[y][x]
                    maxElevation = max(maxElevation, elevationMap[y][x])
                    count += 1
                }
            }
        }

        let meanElevation = count > 0 ? elevationSum / Double(count) : 0.0

        // Calculate volume (∑ height · pixel_area)
        var volume: Double = 0.0
        let intrinsics = depthMap.scale.intrinsics
        let avgFocalLength = intrinsics != nil ?
            (intrinsics!.focalLengthX + intrinsics!.focalLengthY) / 2.0 : 1000.0

        for y in 0..<elevationMap.count {
            for x in 0..<elevationMap[0].count {
                if mask[y][x] {
                    let height = elevationMap[y][x]
                    guard let depth = depthMap.depth(at: CGPoint(x: x, y: y)), depth > 0 else { continue }

                    // Pixel area in mm²
                    let pixelAreaMM2 = (depth / avgFocalLength) * (depth / avgFocalLength)
                    volume += height * pixelAreaMM2
                }
            }
        }

        return (meanElevation, volume, plane)
    }

    // MARK: - Redness Calculation

    private func calculateRedness(
        lesion: DetectedLesionInfo,
        image: CGImage,
        mask: [[Bool]]
    ) -> Double {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.0
        }

        let width = image.width

        // Sample lesion pixels
        var lesionAstarValues: [Double] = []

        for y in Int(lesion.boundingBox.minY)...Int(lesion.boundingBox.maxY) {
            for x in Int(lesion.boundingBox.minX)...Int(lesion.boundingBox.maxX) {
                guard y < mask.count && x < mask[0].count && mask[y][x] else { continue }

                let offset = (y * width + x) * 4
                let r = Double(bytes[offset])
                let g = Double(bytes[offset + 1])
                let b = Double(bytes[offset + 2])

                // Convert to LAB
                let lab = ErythemaMeasurement.rgbToLab(r: r, g: g, b: b)
                lesionAstarValues.append(lab.a)
            }
        }

        // Sample surrounding skin (boundary ring)
        var skinAstarValues: [Double] = []

        for y in max(0, Int(lesion.boundingBox.minY) - 10)...min(mask.count - 1, Int(lesion.boundingBox.maxY) + 10) {
            for x in max(0, Int(lesion.boundingBox.minX) - 10)...min(mask[0].count - 1, Int(lesion.boundingBox.maxX) + 10) {
                // Check if in boundary ring (near but not in lesion)
                let dx = Double(x) - lesion.center.x
                let dy = Double(y) - lesion.center.y
                let dist = sqrt(dx * dx + dy * dy)

                let lesionRadius = sqrt(Double(lesion.pixelCount) / Double.pi)
                if dist > lesionRadius && dist < lesionRadius + 10 {
                    let offset = (y * width + x) * 4
                    let r = Double(bytes[offset])
                    let g = Double(bytes[offset + 1])
                    let b = Double(bytes[offset + 2])

                    let lab = ErythemaMeasurement.rgbToLab(r: r, g: g, b: b)
                    skinAstarValues.append(lab.a)
                }
            }
        }

        guard !lesionAstarValues.isEmpty && !skinAstarValues.isEmpty else {
            return 0.0
        }

        let lesionMeanAstar = lesionAstarValues.reduce(0, +) / Double(lesionAstarValues.count)
        let skinMeanAstar = skinAstarValues.reduce(0, +) / Double(skinAstarValues.count)

        return lesionMeanAstar - skinMeanAstar
    }

    // MARK: - Shape Metrics

    private func calculateShapeMetrics(
        lesion: DetectedLesionInfo,
        mask: [[Bool]]
    ) -> (perimeter: Double, circularity: Double, aspectRatio: Double) {
        let contour = extractContour(from: mask, boundingBox: lesion.boundingBox)

        let perimeter = Double(contour.count)
        let area = Double(lesion.pixelCount)

        // Circularity = 4π·area / perimeter²
        let circularity = (4.0 * Double.pi * area) / (perimeter * perimeter)

        // Aspect ratio from bounding box
        let aspectRatio = lesion.boundingBox.width / lesion.boundingBox.height

        return (perimeter, circularity, aspectRatio)
    }

    // MARK: - Confidence Calculation

    private func calculateOverallConfidence(
        lesionConfidence: Double,
        depthQuality: DepthQualityMetrics
    ) -> Double {
        // Weight different confidence factors
        let weights: [Double] = [
            0.3, // Lesion detection confidence
            0.3, // Depth quality (mean confidence)
            0.2, // Valid pixel ratio
            0.2  // Uniformity
        ]

        let confidences: [Double] = [
            lesionConfidence,
            depthQuality.meanConfidence,
            depthQuality.validPixelRatio,
            depthQuality.uniformity
        ]

        let weightedSum = zip(weights, confidences).map { $0 * $1 }.reduce(0, +)

        return max(0.0, min(1.0, weightedSum))
    }
}

// MARK: - Healing Rate Calculator

class HealingRateCalculator {

    /// Calculate healing rate from time series of measurements
    func calculateHealingRate(
        measurements: [LesionMetrics],
        window: DateInterval
    ) -> HealingRate? {
        // Convert to timed measurements of area (could also use volume, diameter, etc.)
        let timedMeasurements = measurements
            .filter { window.contains($0.timestamp) }
            .map { HealingRate.TimedMeasurement(date: $0.timestamp, value: $0.areaMM2) }
            .sorted { $0.date < $1.date }

        return HealingRate.calculate(measurements: timedMeasurements, window: window)
    }
}

// MARK: - Helper Extensions

extension LesionMetrics {
    var lesionClass: LesionClass {
        // Infer class from metrics (simplified)
        // In production, this comes from segmentation
        if erythemaDeltaAstar > 5 && elevationMM > 0.5 {
            if volumeMM3 > 20 {
                return .nodule
            } else if erythemaDeltaAstar > 8 {
                return .pustule
            } else {
                return .papule
            }
        } else if erythemaDeltaAstar < 0 {
            return .pih
        } else {
            return .comedoneOpen
        }
    }
}
