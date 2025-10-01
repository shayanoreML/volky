//
//  CalibrationDotDetector.swift
//  Volcy
//
//  Detects 10mm calibration dot for depth scaling fallback
//

import Foundation
import CoreImage
import Vision
import CoreGraphics

/// Detects calibration dot (10mm circular sticker) in image
class CalibrationDotDetector {

    private let params = DotDetectionParams()

    /// Detect calibration dot in image
    func detect(in image: CGImage) -> CalibrationDot? {
        // Convert to CIImage for processing
        let ciImage = CIImage(cgImage: image)

        // Step 1: Convert to grayscale
        guard let grayscale = convertToGrayscale(ciImage) else {
            return nil
        }

        // Step 2: Edge detection
        guard let edges = detectEdges(grayscale) else {
            return nil
        }

        // Step 3: Find contours (simplified - using connected components)
        guard let cgEdges = renderToCGImage(edges) else {
            return nil
        }

        // Step 4: Detect circles using Hough transform (simplified)
        return detectCircle(in: cgEdges, originalImage: image)
    }

    // MARK: - Image Processing

    private func convertToGrayscale(_ image: CIImage) -> CIImage? {
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        filter?.setValue(image, forKey: kCIInputImageKey)
        return filter?.outputImage
    }

    private func detectEdges(_ image: CIImage) -> CIImage? {
        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(2.0, forKey: kCIInputIntensityKey) // Edge strength
        return filter?.outputImage
    }

    private func renderToCGImage(_ ciImage: CIImage) -> CGImage? {
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    // MARK: - Circle Detection (Simplified Hough)

    private func detectCircle(in edgeImage: CGImage, originalImage: CGImage) -> CalibrationDot? {
        let width = edgeImage.width
        let height = edgeImage.height

        guard let edgeData = edgeImage.dataProvider?.data,
              let edgeBytes = CFDataGetBytePtr(edgeData),
              let originalData = originalImage.dataProvider?.data,
              let originalBytes = CFDataGetBytePtr(originalData) else {
            return nil
        }

        // Find edge pixels
        var edgePixels: [(x: Int, y: Int)] = []
        for y in stride(from: 0, to: height, by: 2) { // Sample every 2nd pixel for performance
            for x in stride(from: 0, to: width, by: 2) {
                let offset = (y * width + x) * 4
                let intensity = edgeBytes[offset]
                if intensity > 128 { // Edge pixel
                    edgePixels.append((x, y))
                }
            }
        }

        guard edgePixels.count > 50 else {
            return nil // Not enough edges
        }

        // Simplified circle detection: find clusters of edge pixels
        // For production, use proper Hough Circle Transform
        let circles = findCircularClusters(edgePixels: edgePixels, imageSize: CGSize(width: width, height: height))

        // Find best candidate based on size and circularity
        let bestCircle = circles
            .filter { circle in
                params.isValidDot(
                    radius: circle.radius,
                    circularity: circle.circularity,
                    contrast: calculateContrast(at: circle.center, in: originalBytes, width: width, height: height)
                )
            }
            .max { $0.confidence < $1.confidence }

        return bestCircle
    }

    private func findCircularClusters(edgePixels: [(x: Int, y: Int)], imageSize: CGSize) -> [CalibrationDot] {
        var circles: [CalibrationDot] = []

        // Try different radius sizes
        let radiusRange = Int(params.minRadiusPixels)...Int(params.maxRadiusPixels)

        for radius in stride(from: radiusRange.lowerBound, to: radiusRange.upperBound, by: 5) {
            // Vote for circle centers using Hough transform (simplified)
            var votes: [CGPoint: Int] = [:]

            for edge in edgePixels {
                // For each edge point, vote for possible centers at radius distance
                for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 8) {
                    let cx = Double(edge.x) - Double(radius) * cos(angle)
                    let cy = Double(edge.y) - Double(radius) * sin(angle)

                    let center = CGPoint(x: Int(cx / 10) * 10, y: Int(cy / 10) * 10) // Quantize
                    votes[center, default: 0] += 1
                }
            }

            // Find local maxima
            let threshold = radius * 2 // Minimum votes needed
            for (center, voteCount) in votes where voteCount > threshold {
                // Check if this is a valid circle
                let circularity = calculateCircularity(
                    center: center,
                    radius: Double(radius),
                    edgePixels: edgePixels
                )

                if circularity >= params.circularityThreshold {
                    let dot = CalibrationDot(
                        center: center,
                        radiusPixels: Double(radius),
                        confidence: min(1.0, Double(voteCount) / Double(radius * 4)),
                        knownDiameterMM: 10.0
                    )
                    circles.append(dot)
                }
            }
        }

        return circles
    }

    private func calculateCircularity(center: CGPoint, radius: Double, edgePixels: [(x: Int, y: Int)]) -> Double {
        // Count edge pixels near expected circle boundary
        let tolerance = 3.0 // pixels

        var nearCount = 0
        for edge in edgePixels {
            let dx = Double(edge.x) - center.x
            let dy = Double(edge.y) - center.y
            let distance = sqrt(dx * dx + dy * dy)

            if abs(distance - radius) <= tolerance {
                nearCount += 1
            }
        }

        // Circularity = (actual edge pixels near boundary) / (expected perimeter pixels)
        let expectedPerimeter = 2 * Double.pi * radius
        return min(1.0, Double(nearCount) / expectedPerimeter * 4.0)
    }

    private func calculateContrast(at center: CGPoint, in bytes: UnsafePointer<UInt8>, width: Int, height: Int) -> Double {
        let cx = Int(center.x)
        let cy = Int(center.y)

        guard cx > 5 && cx < width - 5 && cy > 5 && cy < height - 5 else {
            return 0.0
        }

        // Sample center region
        var centerSum: Int = 0
        var surroundSum: Int = 0
        let centerRadius = 3
        let surroundRadius = 8

        for dy in -surroundRadius...surroundRadius {
            for dx in -surroundRadius...surroundRadius {
                let x = cx + dx
                let y = cy + dy
                let offset = (y * width + x) * 4
                let luminance = Int(bytes[offset])

                let dist = sqrt(Double(dx * dx + dy * dy))
                if dist <= Double(centerRadius) {
                    centerSum += luminance
                } else if dist <= Double(surroundRadius) {
                    surroundSum += luminance
                }
            }
        }

        let centerCount = centerRadius * centerRadius * 4
        let surroundCount = (surroundRadius * surroundRadius - centerRadius * centerRadius) * 4

        let centerMean = Double(centerSum) / Double(centerCount)
        let surroundMean = Double(surroundSum) / Double(surroundCount)

        return abs(centerMean - surroundMean) / 255.0
    }
}
