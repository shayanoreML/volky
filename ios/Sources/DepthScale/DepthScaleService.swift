//
//  DepthScaleService.swift
//  Volcy
//
//  Depth-to-millimeter conversion with intrinsics and calibration dot fallback
//

import Foundation
import CoreVideo
import CoreGraphics
import Accelerate
import simd

/// Implementation of depth-to-millimeter conversion
class DepthScaleServiceImpl: DepthScaleService {

    // MARK: - Public Methods

    /// Convert depth map to millimeters using camera intrinsics (preferred method)
    func convertDepthToMM(depthMap: CVPixelBuffer, intrinsics: CameraIntrinsics) -> ScaledDepthMap {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return createEmptyDepthMap(width: width, height: height)
        }

        // ARKit provides depth in Float32 (meters)
        let depthBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.stride

        var depthMM: [[Double]] = Array(repeating: Array(repeating: 0.0, count: width), count: height)
        var confidence: [[Float]] = Array(repeating: Array(repeating: 0.0, count: width), count: height)

        // Convert each pixel
        for y in 0..<height {
            for x in 0..<width {
                let index = y * floatsPerRow + x
                let depthMeters = depthBuffer[index]

                if depthMeters > 0 && depthMeters < 5.0 { // Valid depth range (0-5m)
                    // Convert to millimeters
                    depthMM[y][x] = Double(depthMeters) * 1000.0

                    // Confidence based on depth value (closer = higher confidence)
                    confidence[y][x] = confidenceForDepth(depthMeters)
                } else {
                    depthMM[y][x] = 0.0
                    confidence[y][x] = 0.0
                }
            }
        }

        let scale = DepthScale(
            method: .arKitIntrinsics,
            pixelsPerMM: nil,
            confidence: calculateMeanConfidence(confidence),
            intrinsics: intrinsics
        )

        return ScaledDepthMap(
            depthMM: depthMM,
            confidence: confidence,
            scale: scale,
            width: width,
            height: height
        )
    }

    /// Detect calibration dot and create scaled depth map
    func detectCalibrationDot(in image: CGImage) -> CalibrationDot? {
        let detector = CalibrationDotDetector()
        return detector.detect(in: image)
    }

    /// Convert depth map using calibration dot scale (fallback method)
    func convertDepthUsingDot(depthMap: CVPixelBuffer, dot: CalibrationDot) -> ScaledDepthMap {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return createEmptyDepthMap(width: width, height: height)
        }

        let depthBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.stride

        var depthMM: [[Double]] = Array(repeating: Array(repeating: 0.0, count: width), count: height)
        var confidence: [[Float]] = Array(repeating: Array(repeating: 1.0, count: width), count: height)

        // Get dot depth for scaling
        let dotX = Int(dot.center.x)
        let dotY = Int(dot.center.y)
        let dotDepthIndex = dotY * floatsPerRow + dotX
        let dotDepthMeters = depthBuffer[dotDepthIndex]

        // Convert using pixel-to-mm ratio from dot
        let pixelsPerMM = dot.pixelsPerMM

        for y in 0..<height {
            for x in 0..<width {
                let index = y * floatsPerRow + x
                let depthMeters = depthBuffer[index]

                if depthMeters > 0 {
                    // Scale depth relative to dot depth
                    let relativeDepth = depthMeters / dotDepthMeters
                    depthMM[y][x] = Double(depthMeters) * 1000.0 * relativeDepth
                }
            }
        }

        let scale = DepthScale(
            method: .calibrationDot,
            pixelsPerMM: pixelsPerMM,
            confidence: Double(dot.confidence),
            intrinsics: nil
        )

        return ScaledDepthMap(
            depthMM: depthMM,
            confidence: confidence,
            scale: scale,
            width: width,
            height: height
        )
    }

    // MARK: - Private Helpers

    private func confidenceForDepth(_ depth: Float) -> Float {
        // Closer depths have higher confidence
        // Optimal range: 0.2m - 0.5m
        if depth < 0.2 {
            return 0.5 // Too close
        } else if depth <= 0.35 {
            return 1.0 // Optimal
        } else if depth <= 0.5 {
            return 0.8 // Good
        } else {
            return max(0.3, 1.0 - (depth - 0.5) / 2.0) // Decreasing confidence
        }
    }

    private func calculateMeanConfidence(_ confidence: [[Float]]) -> Double {
        var sum: Float = 0.0
        var count = 0

        for row in confidence {
            for value in row {
                if value > 0 {
                    sum += value
                    count += 1
                }
            }
        }

        return count > 0 ? Double(sum / Float(count)) : 0.0
    }

    private func createEmptyDepthMap(width: Int, height: Int) -> ScaledDepthMap {
        let depthMM: [[Double]] = Array(repeating: Array(repeating: 0.0, count: width), count: height)
        let confidence: [[Float]] = Array(repeating: Array(repeating: 0.0, count: width), count: height)

        let scale = DepthScale(
            method: .arKitIntrinsics,
            pixelsPerMM: nil,
            confidence: 0.0,
            intrinsics: nil
        )

        return ScaledDepthMap(
            depthMM: depthMM,
            confidence: confidence,
            scale: scale,
            width: width,
            height: height
        )
    }
}

// MARK: - Conversion Parameters Helper

extension DepthConversionParams {
    /// Convert pixel distance to millimeters at a specific depth
    func pixelDistanceToMM(pixels: Double, atPoint point: CGPoint, depthMap: ScaledDepthMap) -> Double {
        guard let depth = depthMap.depth(at: point), depth > 0 else {
            return 0.0
        }

        return pixelToMM(pixels: pixels, atDepthMM: depth)
    }

    /// Calculate area in mm² from pixel area
    func pixelAreaToMM2(pixelArea: Double, atPoint point: CGPoint, depthMap: ScaledDepthMap) -> Double {
        guard let depth = depthMap.depth(at: point), depth > 0 else {
            return 0.0
        }

        // Area scales with (distance / focal_length)²
        let avgFocalLength = (intrinsics.focalLengthX + intrinsics.focalLengthY) / 2.0
        let scaleFactor = depth / avgFocalLength
        return pixelArea * scaleFactor * scaleFactor
    }
}
