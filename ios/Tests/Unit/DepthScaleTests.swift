//
//  DepthScaleTests.swift
//  VolcyTests
//
//  Unit tests for depth-to-mm conversion
//

import XCTest
@testable import Volcy

class DepthScaleTests: XCTestCase {

    var depthScaleService: DepthScaleServiceImpl!

    override func setUp() {
        super.setUp()
        depthScaleService = DepthScaleServiceImpl()
    }

    func testDepthConversion() {
        // Test intrinsics-based depth conversion
        let intrinsics = CameraIntrinsics(
            from: matrix_float3x3([
                simd_float3(1000, 0, 512),
                simd_float3(0, 1000, 384),
                simd_float3(0, 0, 1)
            ]),
            dimensions: CGSize(width: 1024, height: 768)
        )

        // Create mock depth map
        let mockDepthMap = createMockDepthMap(width: 100, height: 100, depthMeters: 0.28)

        let scaledDepthMap = depthScaleService.convertDepthToMM(depthMap: mockDepthMap, intrinsics: intrinsics)

        // Verify conversion
        XCTAssertEqual(scaledDepthMap.width, 100)
        XCTAssertEqual(scaledDepthMap.height, 100)

        // Check depth value (0.28m = 280mm)
        let centerDepth = scaledDepthMap.depth(at: CGPoint(x: 50, y: 50))
        XCTAssertEqual(centerDepth, 280.0, accuracy: 0.1)
    }

    func testPixelToMMConversion() {
        let intrinsics = CameraIntrinsics(
            from: matrix_float3x3([
                simd_float3(1000, 0, 512),
                simd_float3(0, 1000, 384),
                simd_float3(0, 0, 1)
            ]),
            dimensions: CGSize(width: 1024, height: 768)
        )

        let params = DepthConversionParams(intrinsics: intrinsics, depthScale: 1.0)

        // At 280mm depth, 10 pixels should equal ~2.8mm
        let mm = params.pixelToMM(pixels: 10.0, atDepthMM: 280.0)

        XCTAssertEqual(mm, 2.8, accuracy: 0.1)
    }

    func testScaleRepeatability() {
        // Test repeatability criterion: ≤±0.6mm
        let measurements = [5.2, 5.4, 5.1, 5.3, 5.5, 5.2, 5.4]

        let test = ScaleRepeatabilityTest(measurements: measurements)

        XCTAssertLessThanOrEqual(test.standardDeviation, 0.6)
        XCTAssertTrue(test.meetsAcceptanceCriteria)
    }

    // MARK: - Helper Methods

    private func createMockDepthMap(width: Int, height: Int, depthMeters: Float) -> CVPixelBuffer {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_DepthFloat32,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Failed to create pixel buffer")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let baseAddress = CVPixelBufferGetBaseAddress(buffer)!
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)

        // Fill with constant depth
        for i in 0..<(width * height) {
            floatBuffer[i] = depthMeters
        }

        return buffer
    }
}
