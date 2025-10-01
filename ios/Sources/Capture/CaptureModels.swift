//
//  CaptureModels.swift
//  Volcy
//
//  Models for camera capture and quality control
//

import Foundation
import ARKit
import AVFoundation
import CoreImage

// MARK: - Capture Configuration

struct CaptureConfiguration {
    enum CaptureMode {
        case frontTrueDepth    // Daily scans (28cm, TrueDepth)
        case rearProMode       // High-detail (LiDAR + Apple Watch shutter)
    }

    let mode: CaptureMode
    let targetDistanceMM: Double = 280.0 // 28cm
    let distanceToleranceMM: Double = 10.0 // ±1cm
    let maxPoseDeviationDegrees: Double = 3.0
}

// MARK: - Quality Control Gates

struct QualityControlGates {
    var pose: PoseQC
    var distance: DistanceQC
    var lighting: LightingQC
    var blur: BlurQC

    var allPassed: Bool {
        pose.passed && distance.passed && lighting.passed && blur.passed
    }

    var userFeedback: String {
        if !pose.passed { return pose.hint }
        if !distance.passed { return distance.hint }
        if !lighting.passed { return lighting.hint }
        if !blur.passed { return blur.hint }
        return "Ready to scan"
    }
}

// MARK: - Pose QC

struct PoseQC {
    let yawDegrees: Double
    let pitchDegrees: Double
    let rollDegrees: Double
    let maxDeviation: Double = 3.0

    var passed: Bool {
        abs(yawDegrees) <= maxDeviation &&
        abs(pitchDegrees) <= maxDeviation &&
        abs(rollDegrees) <= maxDeviation
    }

    var hint: String {
        if abs(yawDegrees) > maxDeviation {
            return yawDegrees > 0 ? "Turn slightly left" : "Turn slightly right"
        }
        if abs(pitchDegrees) > maxDeviation {
            return pitchDegrees > 0 ? "Tilt down slightly" : "Tilt up slightly"
        }
        if abs(rollDegrees) > maxDeviation {
            return rollDegrees > 0 ? "Level device" : "Level device"
        }
        return ""
    }
}

// MARK: - Distance QC

struct DistanceQC {
    let currentDistanceMM: Double
    let targetDistanceMM: Double = 280.0
    let toleranceMM: Double = 10.0

    var passed: Bool {
        abs(currentDistanceMM - targetDistanceMM) <= toleranceMM
    }

    var hint: String {
        let diff = currentDistanceMM - targetDistanceMM
        if diff > toleranceMM {
            return "Move closer"
        } else if diff < -toleranceMM {
            return "Move back slightly"
        }
        return ""
    }
}

// MARK: - Lighting QC

struct LightingQC {
    let glarePercentage: Double         // % of pixels with specular highlights
    let whiteBalanceDeltaE: Double      // ΔE from baseline
    let histogramClipping: Bool         // Over/under exposed
    let meanLuminance: Double           // Y channel mean

    var passed: Bool {
        glarePercentage < 5.0 &&           // < 5% glare
        whiteBalanceDeltaE < 10.0 &&       // Reasonable WB
        !histogramClipping &&               // No clipping
        meanLuminance > 30 && meanLuminance < 220 // Not too dark/bright
    }

    var hint: String {
        if glarePercentage >= 5.0 {
            return "Reduce glare"
        }
        if whiteBalanceDeltaE >= 10.0 {
            return "Adjust lighting"
        }
        if histogramClipping {
            return meanLuminance > 220 ? "Too bright" : "Too dark"
        }
        return ""
    }
}

// MARK: - Blur QC

struct BlurQC {
    let varianceOfLaplacian: Double
    let threshold: Double = 100.0  // Empirical threshold for blur detection

    var passed: Bool {
        varianceOfLaplacian > threshold
    }

    var hint: String {
        passed ? "" : "Hold steady"
    }
}

// MARK: - Captured Frame

struct CapturedFrame {
    let image: CIImage
    let depthMap: CVPixelBuffer?
    let timestamp: Date
    let intrinsics: CameraIntrinsics
    let transform: simd_float4x4
    let qc: QualityControlGates
    let lightingStats: LightingStats
}

// MARK: - Camera Intrinsics

struct CameraIntrinsics {
    let focalLengthX: Double  // fx in pixels
    let focalLengthY: Double  // fy in pixels
    let principalPointX: Double // cx in pixels
    let principalPointY: Double // cy in pixels
    let imageWidth: Int
    let imageHeight: Int

    init(from intrinsics: matrix_float3x3, dimensions: CGSize) {
        self.focalLengthX = Double(intrinsics[0][0])
        self.focalLengthY = Double(intrinsics[1][1])
        self.principalPointX = Double(intrinsics[2][0])
        self.principalPointY = Double(intrinsics[2][1])
        self.imageWidth = Int(dimensions.width)
        self.imageHeight = Int(dimensions.height)
    }
}

// MARK: - Lighting Stats

struct LightingStats {
    let glarePercentage: Double
    let whiteBalanceDeltaE: Double
    let meanLuminance: Double
    let histogramClipping: Bool
    let timestamp: Date
}

// MARK: - Capture Session State

enum CaptureSessionState {
    case notConfigured
    case configuring
    case ready
    case running
    case failed(Error)
}

// MARK: - Capture Errors

enum CaptureError: LocalizedError {
    case cameraNotAvailable
    case depthNotSupported
    case authorizationDenied
    case sessionInterrupted
    case qualityControlFailed(String)

    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera not available"
        case .depthNotSupported:
            return "Depth sensing not supported on this device"
        case .authorizationDenied:
            return "Camera access denied"
        case .sessionInterrupted:
            return "Camera session interrupted"
        case .qualityControlFailed(let reason):
            return "Quality check failed: \(reason)"
        }
    }
}
