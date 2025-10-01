//
//  ClassicalSegmentationService.swift
//  Volcy
//
//  Classical computer vision segmentation (placeholder for Core ML)
//  Uses color thresholding, edge detection, and morphological operations
//

import Foundation
import CoreImage
import CoreGraphics
import Vision
import Accelerate

/// Classical segmentation implementation (to be replaced with Core ML UNet)
class ClassicalSegmentationService: SegmentationService {

    private let context = CIContext()

    // MARK: - SegmentationService Protocol

    func segment(image: CIImage) async throws -> SegmentationMask {
        // Step 1: Detect face region
        let faceRegion = try await detectFaceRegion(in: image)

        // Step 2: Convert to LAB color space for skin/lesion detection
        guard let labImage = convertToLAB(image) else {
            throw SegmentationError.processingFailed("LAB conversion failed")
        }

        // Step 3: Detect potential lesions using color thresholding
        let lesionMask = detectLesionsByColor(labImage, faceRegion: faceRegion)

        // Step 4: Refine with morphological operations
        let refinedMask = refine Mask(lesionMask)

        // Step 5: Extract connected components as individual lesions
        let detectedLesions = extractLesions(from: refinedMask, image: image)

        return SegmentationMask(
            width: Int(image.extent.width),
            height: Int(image.extent.height),
            mask: refinedMask,
            lesions: detectedLesions,
            confidence: 0.6 // Classical methods have lower confidence
        )
    }

    // MARK: - Face Detection

    private func detectFaceRegion(in image: CIImage) async throws -> CGRect {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw SegmentationError.processingFailed("CGImage creation failed")
        }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try handler.perform([request])

        guard let results = request.results, !results.isEmpty else {
            // No face detected, use full image
            return image.extent
        }

        // Convert normalized coordinates to image coordinates
        let observation = results[0]
        let boundingBox = observation.boundingBox

        let x = boundingBox.origin.x * image.extent.width
        let y = boundingBox.origin.y * image.extent.height
        let width = boundingBox.width * image.extent.width
        let height = boundingBox.height * image.extent.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Color Space Conversion

    private func convertToLAB(_ image: CIImage) -> CIImage? {
        // CIFilter doesn't have direct RGB->LAB, so we approximate
        // using YCbCr which separates luminance and chrominance

        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(1.2, forKey: kCIInputSaturationKey) // Enhance for better detection

        return filter?.outputImage
    }

    // MARK: - Lesion Detection by Color

    private func detectLesionsByColor(_ image: CIImage, faceRegion: CGRect) -> [[Bool]] {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return []
        }

        let width = cgImage.width
        let height = cgImage.height

        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }

        var mask = Array(repeating: Array(repeating: false, count: width), count: height)

        // Redness threshold (elevated a* in LAB space)
        // For RGB, we use empirical thresholds
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Double(bytes[offset])
                let g = Double(bytes[offset + 1])
                let b = Double(bytes[offset + 2])

                // Check if point is in face region
                let point = CGPoint(x: x, y: y)
                guard faceRegion.contains(point) else {
                    continue
                }

                // Detect lesions by color criteria
                if isLesionColor(r: r, g: g, b: b) {
                    mask[y][x] = true
                }
            }
        }

        return mask
    }

    private func isLesionColor(r: Double, g: Double, b: Double) -> Bool {
        // Criteria for inflammatory lesions (papules, pustules)
        // 1. Elevated redness: R > G and R > B
        // 2. Not too dark (shadow) or too bright (specular)
        // 3. Specific red/yellow tones

        let luminance = 0.299 * r + 0.587 * g + 0.114 * b

        // Check luminance range
        guard luminance > 30 && luminance < 220 else {
            return false
        }

        // Check redness (R significantly higher than G and B)
        let redness = r - (g + b) / 2.0
        if redness > 15 {
            return true // Red/inflamed lesion
        }

        // Check yellowness (pustule)
        let yellowness = (r + g) / 2.0 - b
        if yellowness > 20 && r > g * 0.8 {
            return true
        }

        // Check brownness (PIH)
        let brownness = min(r, g) - b
        if brownness > 10 && r / g > 0.8 && r / g < 1.2 {
            return true
        }

        return false
    }

    // MARK: - Morphological Operations

    private func refineMask(_ mask: [[Bool]]) -> [[Bool]] {
        // Apply morphological operations to clean up mask
        // 1. Opening (erosion + dilation) to remove noise
        // 2. Closing (dilation + erosion) to fill holes

        let opened = morphologicalOpen(mask, kernelSize: 3)
        let closed = morphologicalClose(opened, kernelSize: 5)

        return closed
    }

    private func morphologicalOpen(_ mask: [[Bool]], kernelSize: Int) -> [[Bool]] {
        let eroded = erode(mask, kernelSize: kernelSize)
        return dilate(eroded, kernelSize: kernelSize)
    }

    private func morphologicalClose(_ mask: [[Bool]], kernelSize: Int) -> [[Bool]] {
        let dilated = dilate(mask, kernelSize: kernelSize)
        return erode(dilated, kernelSize: kernelSize)
    }

    private func erode(_ mask: [[Bool]], kernelSize: Int) -> [[Bool]] {
        let height = mask.count
        let width = mask[0].count
        var result = mask

        let radius = kernelSize / 2

        for y in radius..<(height - radius) {
            for x in radius..<(width - radius) {
                // Check if all neighbors in kernel are true
                var allTrue = true
                outer: for dy in -radius...radius {
                    for dx in -radius...radius {
                        if !mask[y + dy][x + dx] {
                            allTrue = false
                            break outer
                        }
                    }
                }
                result[y][x] = allTrue
            }
        }

        return result
    }

    private func dilate(_ mask: [[Bool]], kernelSize: Int) -> [[Bool]] {
        let height = mask.count
        let width = mask[0].count
        var result = mask

        let radius = kernelSize / 2

        for y in radius..<(height - radius) {
            for x in radius..<(width - radius) {
                if mask[y][x] {
                    // Set all neighbors in kernel to true
                    for dy in -radius...radius {
                        for dx in -radius...radius {
                            result[y + dy][x + dx] = true
                        }
                    }
                }
            }
        }

        return result
    }

    // MARK: - Connected Components

    private func extractLesions(from mask: [[Bool]], image: CIImage) -> [DetectedLesionInfo] {
        let height = mask.count
        let width = mask[0].count

        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        var lesions: [DetectedLesionInfo] = []

        // Find connected components using flood fill
        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] && !visited[y][x] {
                    let component = floodFill(mask: mask, visited: &visited, startX: x, startY: y)

                    // Filter by size (remove noise)
                    if component.count > 10 && component.count < 5000 {
                        let lesion = createLesionInfo(from: component, width: width, height: height)
                        lesions.append(lesion)
                    }
                }
            }
        }

        return lesions
    }

    private func floodFill(mask: [[Bool]], visited: inout [[Bool]], startX: Int, startY: Int) -> [(x: Int, y: Int)] {
        let height = mask.count
        let width = mask[0].count

        var component: [(x: Int, y: Int)] = []
        var stack: [(x: Int, y: Int)] = [(startX, startY)]

        while !stack.isEmpty {
            let (x, y) = stack.removeLast()

            guard x >= 0 && x < width && y >= 0 && y < height else { continue }
            guard mask[y][x] && !visited[y][x] else { continue }

            visited[y][x] = true
            component.append((x, y))

            // Add 4-connected neighbors
            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))
        }

        return component
    }

    private func createLesionInfo(from component: [(x: Int, y: Int)], width: Int, height: Int) -> DetectedLesionInfo {
        // Calculate bounding box
        let minX = component.map { $0.x }.min() ?? 0
        let maxX = component.map { $0.x }.max() ?? 0
        let minY = component.map { $0.y }.min() ?? 0
        let maxY = component.map { $0.y }.max() ?? 0

        let boundingBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Calculate center
        let centerX = Double(component.map { $0.x }.reduce(0, +)) / Double(component.count)
        let centerY = Double(component.map { $0.y }.reduce(0, +)) / Double(component.count)

        // Classify lesion type based on size and shape
        let area = component.count
        let perimeter = estimatePerimeter(component)
        let circularity = 4 * Double.pi * Double(area) / (perimeter * perimeter)

        let lesionClass = classifyLesion(area: area, circularity: circularity)

        return DetectedLesionInfo(
            class: lesionClass,
            boundingBox: boundingBox,
            center: CGPoint(x: centerX, y: centerY),
            pixelCount: area,
            confidence: 0.6 // Classical method confidence
        )
    }

    private func estimatePerimeter(_ component: [(x: Int, y: Int)]) -> Double {
        // Count boundary pixels (pixels with at least one non-component neighbor)
        var boundaryCount = 0

        let componentSet = Set(component.map { "\($0.x),\($0.y)" })

        for (x, y) in component {
            let neighbors = [
                (x + 1, y), (x - 1, y),
                (x, y + 1), (x, y - 1)
            ]

            for (nx, ny) in neighbors {
                if !componentSet.contains("\(nx),\(ny)") {
                    boundaryCount += 1
                    break
                }
            }
        }

        return Double(boundaryCount)
    }

    private func classifyLesion(area: Int, circularity: Double) -> LesionClass {
        // Simple heuristic classification
        // TODO: Replace with ML model

        if circularity > 0.7 {
            // Circular lesions
            if area < 50 {
                return .papule // Small, round
            } else if area < 200 {
                return .pustule // Medium, round
            } else {
                return .nodule // Large, round
            }
        } else {
            // Irregular lesions
            if area < 100 {
                return .comedoneOpen // Small, irregular
            } else {
                return .pih // Larger, irregular (PIH/PIE/scar)
            }
        }
    }
}

// MARK: - Supporting Types

struct SegmentationMask {
    let width: Int
    let height: Int
    let mask: [[Bool]]
    let lesions: [DetectedLesionInfo]
    let confidence: Double
}

struct DetectedLesionInfo {
    let `class`: LesionClass
    let boundingBox: CGRect
    let center: CGPoint
    let pixelCount: Int
    let confidence: Double
}

enum SegmentationError: LocalizedError {
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .processingFailed(let message):
            return "Segmentation failed: \(message)"
        }
    }
}
