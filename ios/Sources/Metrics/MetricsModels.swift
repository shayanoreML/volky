//
//  MetricsModels.swift
//  Volcy
//
//  Models for lesion metrics calculation
//

import Foundation
import CoreGraphics
import simd

// MARK: - Lesion Metrics

struct LesionMetrics {
    let lesionId: UUID
    let timestamp: Date

    // Dimensional metrics
    let diameterMM: Double              // Max Feret diameter
    let equivalentDiameterMM: Double    // Diameter of equivalent circle
    let areaMM2: Double                 // Surface area
    let elevationMM: Double             // Height above local plane
    let volumeMM3: Double               // Volume proxy (∑h·area_px)

    // Color/appearance metrics
    let erythemaDeltaAstar: Double      // Redness: Δa* (lesion - skin ring)
    let meanLstar: Double               // Lightness
    let deltaE: Double                  // Color difference from baseline

    // Shape metrics
    let perimeter: Double               // Boundary length
    let circularity: Double             // 4π·area / perimeter²
    let aspectRatio: Double             // Major/minor axis ratio

    // Confidence and quality
    let confidence: Double              // Overall metric confidence [0-1]
    let depthQuality: DepthQualityMetrics
    let scaleMethod: DepthScale.ScaleMethod

    /// Acceptance criteria check
    var meetsQualityStandards: Bool {
        confidence >= 0.7 &&
        depthQuality.isHighQuality
    }
}

// MARK: - Diameter Calculation

struct DiameterMeasurement {
    enum Method {
        case maxFeret      // Maximum caliper distance
        case minFeret      // Minimum caliper distance
        case equivalent    // Diameter of circle with same area
    }

    let method: Method
    let valueMM: Double
    let endPoints: (CGPoint, CGPoint)?  // For Feret diameter

    /// Calculate max Feret diameter from contour points
    static func maxFeret(contour: [CGPoint], pixelsPerMM: Double) -> DiameterMeasurement {
        var maxDist: Double = 0
        var maxPair: (CGPoint, CGPoint) = (contour[0], contour[0])

        for i in 0..<contour.count {
            for j in (i+1)..<contour.count {
                let p1 = contour[i]
                let p2 = contour[j]
                let dist = hypot(p2.x - p1.x, p2.y - p1.y)
                if dist > maxDist {
                    maxDist = dist
                    maxPair = (p1, p2)
                }
            }
        }

        let diameterMM = maxDist / pixelsPerMM
        return DiameterMeasurement(method: .maxFeret, valueMM: diameterMM, endPoints: maxPair)
    }

    /// Calculate equivalent diameter from area
    static func equivalent(areaMM2: Double) -> DiameterMeasurement {
        let radius = sqrt(areaMM2 / .pi)
        let diameter = radius * 2.0
        return DiameterMeasurement(method: .equivalent, valueMM: diameter, endPoints: nil)
    }
}

// MARK: - Elevation Measurement

struct ElevationMeasurement {
    let meanElevationMM: Double         // Average elevation
    let maxElevationMM: Double          // Peak elevation
    let volumeMM3: Double               // Volume proxy
    let planeFit: LocalPlaneFit         // Reference plane
    let heightMap: [[Double]]           // Elevation grid

    /// Acceptance: elevation repeatability ≤ ±0.5mm (depth)
    var meetsAcceptanceCriteria: Bool {
        planeFit.rmse <= 0.5
    }
}

// MARK: - Erythema (Redness) Measurement

struct ErythemaMeasurement {
    let deltaAstar: Double              // Δa* (lesion - skin ring)
    let lesionMeanAstar: Double         // Mean a* in lesion
    let skinMeanAstar: Double           // Mean a* in surrounding skin
    let specularMaskRatio: Double       // % of pixels masked for specular

    /// Acceptance: redness repeatability Δa* ≤ ±2.0
    var meetsAcceptanceCriteria: Bool {
        abs(deltaAstar) >= 2.0  // Meaningful redness difference
    }

    /// RGB to CIELAB conversion (simplified)
    static func rgbToLab(r: Double, g: Double, b: Double) -> (L: Double, a: Double, b: Double) {
        // Convert RGB [0-255] to sRGB [0-1]
        let rNorm = r / 255.0
        let gNorm = g / 255.0
        let bNorm = b / 255.0

        // sRGB to linear RGB
        func toLinear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let rLin = toLinear(rNorm)
        let gLin = toLinear(gNorm)
        let bLin = toLinear(bNorm)

        // Linear RGB to XYZ (D65 illuminant)
        let x = rLin * 0.4124564 + gLin * 0.3575761 + bLin * 0.1804375
        let y = rLin * 0.2126729 + gLin * 0.7151522 + bLin * 0.0721750
        let z = rLin * 0.0193339 + gLin * 0.1191920 + bLin * 0.9503041

        // XYZ to LAB
        let xn = 0.95047  // D65 white point
        let yn = 1.00000
        let zn = 1.08883

        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0/3.0) : (7.787 * t + 16.0/116.0)
        }

        let fx = f(x / xn)
        let fy = f(y / yn)
        let fz = f(z / zn)

        let L = 116.0 * fy - 16.0
        let a = 500.0 * (fx - fy)
        let b = 200.0 * (fy - fz)

        return (L, a, b)
    }

    /// Calculate Δa* between lesion and surrounding skin
    static func calculate(lesionRGB: [(r: Double, g: Double, b: Double)],
                         skinRGB: [(r: Double, g: Double, b: Double)],
                         specularMask: [Bool]) -> ErythemaMeasurement {
        // Filter out specular highlights
        let validLesionRGB = lesionRGB.enumerated()
            .filter { !specularMask[$0.offset] }
            .map { $0.element }

        // Convert to LAB and get mean a*
        let lesionAstar = validLesionRGB.map { rgbToLab(r: $0.r, g: $0.g, b: $0.b).a }
        let skinAstar = skinRGB.map { rgbToLab(r: $0.r, g: $0.g, b: $0.b).a }

        let lesionMeanA = lesionAstar.reduce(0, +) / Double(lesionAstar.count)
        let skinMeanA = skinAstar.reduce(0, +) / Double(skinAstar.count)
        let deltaA = lesionMeanA - skinMeanA

        let specularRatio = Double(specularMask.filter { $0 }.count) / Double(specularMask.count)

        return ErythemaMeasurement(
            deltaAstar: deltaA,
            lesionMeanAstar: lesionMeanA,
            skinMeanAstar: skinMeanA,
            specularMaskRatio: specularRatio
        )
    }
}

// MARK: - Healing Rate

struct HealingRate {
    let percentChangePerDay: Double     // % change/day
    let window: DateInterval            // Time window (7-14 days)
    let measurements: [TimedMeasurement]
    let confidence: Double              // Fit quality [0-1]

    struct TimedMeasurement {
        let date: Date
        let value: Double               // Could be area, volume, diameter, etc.
    }

    /// Calculate robust slope (healing rate) over time window
    static func calculate(measurements: [TimedMeasurement], window: DateInterval) -> HealingRate? {
        guard measurements.count >= 3 else { return nil }

        // Filter to window
        let filtered = measurements.filter { window.contains($0.date) }
        guard filtered.count >= 3 else { return nil }

        // Convert dates to days from start
        let startDate = filtered.first!.date
        let points: [(x: Double, y: Double)] = filtered.map {
            let days = $0.date.timeIntervalSince(startDate) / 86400.0
            return (days, $0.value)
        }

        // Linear regression
        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
        let sumX2 = points.reduce(0) { $0 + $1.x * $1.x }

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n

        // Calculate R² (confidence)
        let meanY = sumY / n
        let ssTotal = points.reduce(0) { $0 + pow($1.y - meanY, 2) }
        let ssResidual = points.reduce(0) { $0 + pow($1.y - (slope * $1.x + intercept), 2) }
        let rSquared = 1.0 - (ssResidual / ssTotal)

        // Convert to % change per day
        let initialValue = intercept
        let percentPerDay = (slope / initialValue) * 100.0

        return HealingRate(
            percentChangePerDay: percentPerDay,
            window: window,
            measurements: filtered,
            confidence: rSquared
        )
    }
}

// MARK: - Region Summary

struct RegionSummary {
    enum FaceRegion: String, CaseIterable {
        case tZone = "T-zone"           // Forehead, nose
        case uZone = "U-zone"           // Cheeks, chin
        case leftCheek = "Left Cheek"
        case rightCheek = "Right Cheek"
        case forehead = "Forehead"
        case chin = "Chin"
    }

    let region: FaceRegion
    let scanId: UUID
    let timestamp: Date

    // Counts by class
    let papuleCount: Int
    let pustuleCount: Int
    let noduleCount: Int
    let comedoneCount: Int
    let pihPieCount: Int
    let scarCount: Int

    // Aggregate metrics
    let inflamedAreaMM2: Double         // Total inflamed area
    let meanDiameterMM: Double          // Average lesion size
    let meanElevationMM: Double         // Average elevation
    let meanErythemaDeltaAstar: Double  // Average redness

    var totalLesionCount: Int {
        papuleCount + pustuleCount + noduleCount + comedoneCount + pihPieCount + scarCount
    }

    var inflamedCount: Int {
        papuleCount + pustuleCount + noduleCount
    }
}
