//
//  QualityControlService.swift
//  Volcy
//
//  Quality control service for live capture validation
//

import Foundation
import ARKit
import CoreImage
import Accelerate

/// Service for evaluating capture quality in real-time
class QualityControlService {

    // MARK: - Public Methods

    /// Evaluate all quality gates for a given frame
    func evaluateQuality(
        frame: ARFrame,
        configuration: CaptureConfiguration,
        baselineTransform: simd_float4x4?
    ) -> QualityControlGates {
        let pose = evaluatePose(frame: frame, baseline: baselineTransform)
        let distance = evaluateDistance(frame: frame, configuration: configuration)
        let lighting = evaluateLighting(frame: frame)
        let blur = evaluateBlur(frame: frame)

        return QualityControlGates(
            pose: pose,
            distance: distance,
            lighting: lighting,
            blur: blur
        )
    }

    /// Calculate lighting statistics for storage
    func calculateLightingStats(from frame: ARFrame) -> LightingStats {
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)

        return LightingStats(
            glarePercentage: calculateGlarePercentage(image: ciImage),
            whiteBalanceDeltaE: calculateWhiteBalanceDeltaE(frame: frame),
            meanLuminance: calculateMeanLuminance(image: ciImage),
            histogramClipping: detectHistogramClipping(image: ciImage),
            timestamp: Date()
        )
    }

    // MARK: - Pose Evaluation

    private func evaluatePose(frame: ARFrame, baseline: simd_float4x4?) -> PoseQC {
        let transform = frame.camera.transform

        // If no baseline, use current orientation
        guard let baseline = baseline else {
            return PoseQC(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
        }

        // Calculate relative rotation from baseline
        let relativeTransform = simd_mul(simd_inverse(baseline), transform)
        let rotation = extractEulerAngles(from: relativeTransform)

        return PoseQC(
            yawDegrees: Double(rotation.yaw),
            pitchDegrees: Double(rotation.pitch),
            rollDegrees: Double(rotation.roll)
        )
    }

    private func extractEulerAngles(from transform: simd_float4x4) -> (yaw: Float, pitch: Float, roll: Float) {
        // Extract rotation matrix
        let m = transform

        // Calculate Euler angles (in radians, then convert to degrees)
        let pitch = asin(-m[2][0])
        let yaw = atan2(m[2][1], m[2][2])
        let roll = atan2(m[1][0], m[0][0])

        return (
            yaw: yaw * 180.0 / .pi,
            pitch: pitch * 180.0 / .pi,
            roll: roll * 180.0 / .pi
        )
    }

    // MARK: - Distance Evaluation

    private func evaluateDistance(frame: ARFrame, configuration: CaptureConfiguration) -> DistanceQC {
        var estimatedDistance: Double = 0.0

        // Try to get distance from face anchor (front camera)
        if let faceAnchor = frame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor {
            let faceTransform = faceAnchor.transform
            let cameraTransform = frame.camera.transform

            // Calculate distance between camera and face
            let facePosition = simd_make_float3(faceTransform.columns.3)
            let cameraPosition = simd_make_float3(cameraTransform.columns.3)
            estimatedDistance = Double(simd_distance(cameraPosition, facePosition)) * 1000.0 // Convert to mm
        }
        // For world tracking (rear camera), estimate from depth map
        else if let depthMap = frame.sceneDepth?.depthMap ?? frame.smoothedSceneDepth?.depthMap {
            estimatedDistance = estimateDistanceFromDepthMap(depthMap)
        }
        // Fallback: use focal length estimation
        else {
            estimatedDistance = estimateDistanceFromFocalLength(frame: frame)
        }

        return DistanceQC(currentDistanceMM: estimatedDistance)
    }

    private func estimateDistanceFromDepthMap(_ depthMap: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)

        guard let floatBuffer = baseAddress?.assumingMemoryBound(to: Float32.self) else {
            return 280.0 // Default fallback
        }

        // Sample center region (50% of image)
        let centerX = width / 2
        let centerY = height / 2
        let sampleSize = min(width, height) / 4

        var validDepths: [Float] = []
        for y in (centerY - sampleSize)..<(centerY + sampleSize) {
            for x in (centerX - sampleSize)..<(centerX + sampleSize) {
                let index = y * width + x
                let depth = floatBuffer[index]
                if depth > 0 && depth < 1.0 { // Valid depth range (meters)
                    validDepths.append(depth)
                }
            }
        }

        guard !validDepths.isEmpty else {
            return 280.0
        }

        // Median depth for robustness
        validDepths.sort()
        let median = validDepths[validDepths.count / 2]
        return Double(median) * 1000.0 // Convert to mm
    }

    private func estimateDistanceFromFocalLength(frame: ARFrame) -> Double {
        // Rough estimation based on typical face size
        // Average face width ≈ 140mm
        // focal_length = (pixel_width × distance) / real_width
        let imageResolution = frame.camera.imageResolution
        let assumedFaceWidthMM = 140.0
        let assumedFacePixelWidth = imageResolution.width * 0.6 // Face occupies ~60% of frame

        let intrinsics = frame.camera.intrinsics
        let focalLength = Double(intrinsics[0][0]) // fx

        let estimatedDistance = (assumedFaceWidthMM * focalLength) / assumedFacePixelWidth
        return estimatedDistance
    }

    // MARK: - Lighting Evaluation

    private func evaluateLighting(frame: ARFrame) -> LightingQC {
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)

        let glarePercentage = calculateGlarePercentage(image: ciImage)
        let whiteBalanceDeltaE = calculateWhiteBalanceDeltaE(frame: frame)
        let meanLuminance = calculateMeanLuminance(image: ciImage)
        let histogramClipping = detectHistogramClipping(image: ciImage)

        return LightingQC(
            glarePercentage: glarePercentage,
            whiteBalanceDeltaE: whiteBalanceDeltaE,
            histogramClipping: histogramClipping,
            meanLuminance: meanLuminance
        )
    }

    private func calculateGlarePercentage(image: CIImage) -> Double {
        // Detect specular highlights (very bright pixels)
        // Threshold: pixels with luminance > 240 (out of 255)

        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
            return 0.0
        }

        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height

        var glareCount = 0

        // Sample every 4th pixel for performance
        let stride = 4
        let data = cgImage.dataProvider?.data
        guard let bytes = CFDataGetBytePtr(data) else { return 0.0 }

        for y in stride(from: 0, to: height, by: stride) {
            for x in stride(from: 0, to: width, by: stride) {
                let offset = (y * width + x) * 4
                let r = bytes[offset]
                let g = bytes[offset + 1]
                let b = bytes[offset + 2]

                // Convert to luminance (Y in YUV)
                let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)

                if luminance > 240.0 {
                    glareCount += 1
                }
            }
        }

        let sampledPixels = (width / stride) * (height / stride)
        return (Double(glareCount) / Double(sampledPixels)) * 100.0
    }

    private func calculateWhiteBalanceDeltaE(frame: ARFrame) -> Double {
        // Use ARKit's light estimation if available
        if let lightEstimate = frame.lightEstimate {
            let colorTemperature = lightEstimate.ambientColorTemperature

            // Ideal color temperature range: 4000K - 7000K (daylight/indoor)
            // Outside this range indicates poor white balance
            let idealTemp: CGFloat = 5500.0 // D65 standard
            let deltaTemp = abs(colorTemperature - idealTemp)

            // Convert temp difference to rough ΔE approximation
            // Large temp difference = large color shift
            let deltaE = min(deltaTemp / 100.0, 50.0) // Cap at 50
            return Double(deltaE)
        }

        return 5.0 // Default acceptable value
    }

    private func calculateMeanLuminance(image: CIImage) -> Double {
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
            return 128.0
        }

        let width = cgImage.width
        let height = cgImage.height

        var totalLuminance: Double = 0.0
        var count = 0

        let stride = 8 // Sample every 8th pixel
        let data = cgImage.dataProvider?.data
        guard let bytes = CFDataGetBytePtr(data) else { return 128.0 }

        for y in stride(from: 0, to: height, by: stride) {
            for x in stride(from: 0, to: width, by: stride) {
                let offset = (y * width + x) * 4
                let r = bytes[offset]
                let g = bytes[offset + 1]
                let b = bytes[offset + 2]

                let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
                totalLuminance += luminance
                count += 1
            }
        }

        return totalLuminance / Double(count)
    }

    private func detectHistogramClipping(image: CIImage) -> Bool {
        // Check if histogram shows clipping (too many pixels at 0 or 255)
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
            return false
        }

        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height

        var darkCount = 0
        var brightCount = 0

        let stride = 8
        let data = cgImage.dataProvider?.data
        guard let bytes = CFDataGetBytePtr(data) else { return false }

        for y in stride(from: 0, to: height, by: stride) {
            for x in stride(from: 0, to: width, by: stride) {
                let offset = (y * width + x) * 4
                let r = bytes[offset]
                let g = bytes[offset + 1]
                let b = bytes[offset + 2]

                if r < 10 && g < 10 && b < 10 {
                    darkCount += 1
                } else if r > 245 && g > 245 && b > 245 {
                    brightCount += 1
                }
            }
        }

        let sampledPixels = (width / stride) * (height / stride)
        let darkRatio = Double(darkCount) / Double(sampledPixels)
        let brightRatio = Double(brightCount) / Double(sampledPixels)

        // Clipping if >5% of pixels are at extremes
        return darkRatio > 0.05 || brightRatio > 0.05
    }

    // MARK: - Blur Evaluation

    private func evaluateBlur(frame: ARFrame) -> BlurQC {
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let variance = calculateVarianceOfLaplacian(image: ciImage)

        return BlurQC(varianceOfLaplacian: variance)
    }

    private func calculateVarianceOfLaplacian(image: CIImage) -> Double {
        // Convert to grayscale
        guard let grayscale = CIFilter(name: "CIPhotoEffectNoir", parameters: [
            kCIInputImageKey: image
        ])?.outputImage else {
            return 150.0 // Default acceptable value
        }

        // Apply Laplacian filter (edge detection)
        // Higher variance = sharper image
        guard let cgImage = CIContext().createCGImage(grayscale, from: grayscale.extent) else {
            return 150.0
        }

        // Simple Laplacian approximation using brightness variance
        let width = cgImage.width
        let height = cgImage.height

        let data = cgImage.dataProvider?.data
        guard let bytes = CFDataGetBytePtr(data) else { return 150.0 }

        var laplacianValues: [Double] = []
        let stride = 4

        for y in stride(from: 1, to: height - 1, by: stride) {
            for x in stride(from: 1, to: width - 1, by: stride) {
                let center = Double(bytes[(y * width + x) * 4])
                let top = Double(bytes[((y - 1) * width + x) * 4])
                let bottom = Double(bytes[((y + 1) * width + x) * 4])
                let left = Double(bytes[(y * width + (x - 1)) * 4])
                let right = Double(bytes[(y * width + (x + 1)) * 4])

                // Laplacian kernel: -4*center + top + bottom + left + right
                let laplacian = abs(-4 * center + top + bottom + left + right)
                laplacianValues.append(laplacian)
            }
        }

        guard !laplacianValues.isEmpty else { return 150.0 }

        // Calculate variance
        let mean = laplacianValues.reduce(0, +) / Double(laplacianValues.count)
        let variance = laplacianValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(laplacianValues.count)

        return variance
    }
}
