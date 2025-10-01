//
//  DepthScaleModels.swift
//  Volcy
//
//  Models for depth-to-millimeter conversion and calibration
//

import Foundation
import CoreGraphics
import simd

// MARK: - Scaled Depth Map

struct ScaledDepthMap {
    let depthMM: [[Double]]           // Depth in millimeters [height][width]
    let confidence: [[Float]]          // Confidence per pixel [0-1]
    let scale: DepthScale
    let width: Int
    let height: Int

    subscript(x: Int, y: Int) -> Double {
        depthMM[y][x]
    }

    func depth(at point: CGPoint) -> Double? {
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return depthMM[y][x]
    }
}

// MARK: - Depth Scale

struct DepthScale {
    enum ScaleMethod {
        case arKitIntrinsics   // ARKit depth + camera intrinsics (preferred)
        case calibrationDot    // 10mm calibration dot (fallback)
        case stereo            // Stereo matching (rear camera fallback)
    }

    let method: ScaleMethod
    let pixelsPerMM: Double?        // For calibration dot
    let confidence: Double           // 0.0 - 1.0
    let intrinsics: CameraIntrinsics?

    var description: String {
        switch method {
        case .arKitIntrinsics:
            return "ARKit depth (preferred)"
        case .calibrationDot:
            return "Calibration dot"
        case .stereo:
            return "Stereo matching"
        }
    }
}

// MARK: - Calibration Dot

struct CalibrationDot {
    let center: CGPoint              // Center in image coordinates
    let radiusPixels: Double         // Detected radius in pixels
    let confidence: Double           // Detection confidence [0-1]
    let knownDiameterMM: Double = 10.0 // Physical diameter in mm

    var pixelsPerMM: Double {
        radiusPixels * 2.0 / knownDiameterMM
    }
}

// MARK: - Depth Conversion Parameters

struct DepthConversionParams {
    let intrinsics: CameraIntrinsics
    let depthScale: Float            // ARKit depth scale factor
    let minDepthMM: Double = 100.0   // Minimum valid depth
    let maxDepthMM: Double = 500.0   // Maximum valid depth

    /// Convert depth value at pixel (x, y) to millimeters
    /// Formula: depth_mm = Z * 1000 (Z in meters from ARKit)
    /// Real-world size: size_mm = (size_px * Z * 1000) / fx
    func depthToMM(depthValue: Float, at point: CGPoint) -> Double? {
        guard depthValue > 0 else { return nil }

        // Convert ARKit depth (meters) to millimeters
        let depthMM = Double(depthValue) * 1000.0

        // Validate range
        guard depthMM >= minDepthMM && depthMM <= maxDepthMM else {
            return nil
        }

        return depthMM
    }

    /// Convert pixel distance to millimeters at given depth
    func pixelToMM(pixels: Double, atDepthMM depth: Double) -> Double {
        // Real-world size = (pixel_size * depth) / focal_length
        // Using fx for horizontal, fy for vertical (we use average)
        let avgFocalLength = (intrinsics.focalLengthX + intrinsics.focalLengthY) / 2.0
        return (pixels * depth) / avgFocalLength
    }

    /// Convert millimeters to pixels at given depth
    func mmToPixel(mm: Double, atDepthMM depth: Double) -> Double {
        let avgFocalLength = (intrinsics.focalLengthX + intrinsics.focalLengthY) / 2.0
        return (mm * avgFocalLength) / depth
    }
}

// MARK: - Local Plane Fit

struct LocalPlaneFit {
    let normal: simd_float3          // Plane normal vector
    let point: simd_float3           // Point on plane
    let inliers: Int                 // Number of inlier points
    let rmse: Double                 // Root mean squared error

    /// Calculate elevation of a point above the plane
    func elevation(of point: simd_float3) -> Double {
        // Distance from point to plane
        let d = simd_dot(normal, point - self.point)
        return abs(Double(d))
    }

    /// Project point onto plane
    func project(point: simd_float3) -> simd_float3 {
        let d = simd_dot(normal, point - self.point)
        return point - normal * d
    }
}

// MARK: - Depth Quality Metrics

struct DepthQualityMetrics {
    let meanConfidence: Double       // Average confidence across region
    let validPixelRatio: Double      // % of valid depth pixels
    let uniformity: Double           // Consistency of depth values
    let noiseLevel: Double           // Standard deviation of local neighborhoods

    var isHighQuality: Bool {
        meanConfidence > 0.7 &&
        validPixelRatio > 0.9 &&
        uniformity > 0.8 &&
        noiseLevel < 2.0  // mm
    }

    var qualityDescription: String {
        if isHighQuality {
            return "High quality"
        } else if meanConfidence < 0.5 {
            return "Low confidence"
        } else if validPixelRatio < 0.7 {
            return "Sparse depth data"
        } else if uniformity < 0.6 {
            return "Inconsistent depth"
        } else {
            return "Moderate quality"
        }
    }
}

// MARK: - Calibration Dot Detection

struct DotDetectionParams {
    let minRadiusPixels: Double = 10.0
    let maxRadiusPixels: Double = 100.0
    let circularityThreshold: Double = 0.85  // How circular the shape must be
    let contrastThreshold: Double = 0.3      // Minimum contrast with background

    func isValidDot(radius: Double, circularity: Double, contrast: Double) -> Bool {
        radius >= minRadiusPixels &&
        radius <= maxRadiusPixels &&
        circularity >= circularityThreshold &&
        contrast >= contrastThreshold
    }
}

// MARK: - Scale Repeatability Test

struct ScaleRepeatabilityTest {
    let measurements: [Double]        // Multiple diameter measurements (mm)

    var mean: Double {
        measurements.reduce(0, +) / Double(measurements.count)
    }

    var standardDeviation: Double {
        let mean = self.mean
        let squaredDiffs = measurements.map { pow($0 - mean, 2) }
        return sqrt(squaredDiffs.reduce(0, +) / Double(measurements.count))
    }

    var coefficientOfVariation: Double {
        standardDeviation / mean
    }

    /// Acceptance: diameter repeatability ≤ ±0.6mm
    var meetsAcceptanceCriteria: Bool {
        standardDeviation <= 0.6
    }
}
