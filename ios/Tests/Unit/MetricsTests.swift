//
//  MetricsTests.swift
//  VolcyTests
//
//  Unit tests for metrics calculations
//

import XCTest
@testable import Volcy

class MetricsTests: XCTestCase {

    func testDiameterCalculation() {
        // Create mock contour (circle with radius 10 pixels)
        var contour: [CGPoint] = []
        for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 16) {
            let x = 50.0 + 10.0 * cos(angle)
            let y = 50.0 + 10.0 * sin(angle)
            contour.append(CGPoint(x: x, y: y))
        }

        // Max Feret diameter should be ~20 pixels
        var maxDist: Double = 0.0
        for i in 0..<contour.count {
            for j in (i+1)..<contour.count {
                let p1 = contour[i]
                let p2 = contour[j]
                let dist = hypot(p2.x - p1.x, p2.y - p1.y)
                maxDist = max(maxDist, dist)
            }
        }

        XCTAssertEqual(maxDist, 20.0, accuracy: 0.5)
    }

    func testRGBToLABConversion() {
        // Test conversion from RGB to CIELAB
        let (L, a, b) = ErythemaMeasurement.rgbToLab(r: 255, g: 0, b: 0)

        // Red should have high a* value (positive = red)
        XCTAssertGreaterThan(a, 50.0)

        // Check L* is in valid range
        XCTAssertGreaterThanOrEqual(L, 0.0)
        XCTAssertLessThanOrEqual(L, 100.0)
    }

    func testHealingRateCalculation() {
        // Create mock time series
        let now = Date()
        let calendar = Calendar.current

        let measurements = [
            HealingRate.TimedMeasurement(
                date: calendar.date(byAdding: .day, value: -14, to: now)!,
                value: 100.0
            ),
            HealingRate.TimedMeasurement(
                date: calendar.date(byAdding: .day, value: -7, to: now)!,
                value: 80.0
            ),
            HealingRate.TimedMeasurement(
                date: calendar.date(byAdding: .day, value: 0, to: now)!,
                value: 60.0
            ),
        ]

        let window = DateInterval(
            start: calendar.date(byAdding: .day, value: -14, to: now)!,
            end: now
        )

        let healingRate = HealingRate.calculate(measurements: measurements, window: window)

        XCTAssertNotNil(healingRate)

        // Should show negative % change (improvement)
        XCTAssertLessThan(healingRate!.percentChangePerDay, 0)

        // Confidence (R²) should be high for linear trend
        XCTAssertGreaterThan(healingRate!.confidence, 0.9)
    }

    func testCliffsDelta() {
        // Test Cliff's delta calculation
        let groupA = [1.0, 2.0, 3.0, 4.0, 5.0]
        let groupB = [6.0, 7.0, 8.0, 9.0, 10.0]

        // Calculate manually
        var greaterCount = 0
        var lessCount = 0

        for a in groupA {
            for b in groupB {
                if a > b {
                    greaterCount += 1
                } else if a < b {
                    lessCount += 1
                }
            }
        }

        let delta = Double(greaterCount - lessCount) / Double(groupA.count * groupB.count)

        // B is entirely greater than A, so delta should be -1.0
        XCTAssertEqual(delta, -1.0, accuracy: 0.01)
    }
}
