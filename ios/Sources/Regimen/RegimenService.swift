//
//  RegimenService.swift
//  Volcy
//
//  Regimen tracking and A/B comparison with Cliff's delta
//

import Foundation

class RegimenServiceImpl: RegimenService {

    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    // MARK: - RegimenService Protocol

    func logRegimenEvent(products: [String], notes: String?) async throws {
        _ = try await persistenceService.createRegimenEvent(products: products, notes: notes)
    }

    func compareRegimens(windowA: DateInterval, windowB: DateInterval) async throws -> RegimenComparison {
        // Fetch scans in both windows
        let scansA = try await fetchScansInWindow(windowA)
        let scansB = try await fetchScansInWindow(windowB)

        guard !scansA.isEmpty && !scansB.isEmpty else {
            throw RegimenError.insufficientData
        }

        // Calculate aggregate metrics for each window
        let metricsA = aggregateMetrics(from: scansA)
        let metricsB = aggregateMetrics(from: scansB)

        // Calculate effect sizes using Cliff's delta
        let clarityEffect = calculateCliffsDelta(
            groupA: scansA.map { Double($0.clarityScore) },
            groupB: scansB.map { Double($0.clarityScore) }
        )

        let inflamedAreaEffect = calculateCliffsDelta(
            groupA: metricsA.inflamedAreas,
            groupB: metricsB.inflamedAreas
        )

        let lesionCountEffect = calculateCliffsDelta(
            groupA: metricsA.lesionCounts,
            groupB: metricsB.lesionCounts
        )

        return RegimenComparison(
            windowA: windowA,
            windowB: windowB,
            metricsA: metricsA.summary,
            metricsB: metricsB.summary,
            clarityEffect: clarityEffect,
            inflamedAreaEffect: inflamedAreaEffect,
            lesionCountEffect: lesionCountEffect,
            interpretation: interpretEffects(
                clarity: clarityEffect,
                area: inflamedAreaEffect,
                count: lesionCountEffect
            )
        )
    }

    // MARK: - Private Helpers

    private func fetchScansInWindow(_ window: DateInterval) async throws -> [ScanEntity] {
        let allScans = try await persistenceService.fetchScans(limit: 10000)
        return allScans.filter { scan in
            guard let timestamp = scan.timestamp else { return false }
            return window.contains(timestamp)
        }
    }

    private func aggregateMetrics(from scans: [ScanEntity]) -> AggregatedMetrics {
        var inflamedAreas: [Double] = []
        var lesionCounts: [Double] = []
        var clarityScores: [Double] = []

        for scan in scans {
            clarityScores.append(Double(scan.clarityScore))
            // TODO: Fetch actual lesion data
            // For now, use placeholder
            inflamedAreas.append(0.0)
            lesionCounts.append(0.0)
        }

        let summary = MetricsSummary(
            meanClarityScore: clarityScores.mean,
            meanInflamedArea: inflamedAreas.mean,
            meanLesionCount: lesionCounts.mean,
            scanCount: scans.count
        )

        return AggregatedMetrics(
            summary: summary,
            inflamedAreas: inflamedAreas,
            lesionCounts: lesionCounts
        )
    }

    /// Calculate Cliff's delta (non-parametric effect size)
    /// δ = (# pairs where A > B - # pairs where A < B) / (n_A × n_B)
    /// Range: [-1, 1] where:
    /// - |δ| < 0.15: negligible
    /// - 0.15 ≤ |δ| < 0.33: small
    /// - 0.33 ≤ |δ| < 0.47: medium
    /// - |δ| ≥ 0.47: large
    private func calculateCliffsDelta(groupA: [Double], groupB: [Double]) -> EffectSize {
        guard !groupA.isEmpty && !groupB.isEmpty else {
            return EffectSize(delta: 0.0, magnitude: .negligible)
        }

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

        let totalPairs = groupA.count * groupB.count
        let delta = Double(greaterCount - lessCount) / Double(totalPairs)

        let magnitude: EffectMagnitude
        let absDelta = abs(delta)

        if absDelta < 0.15 {
            magnitude = .negligible
        } else if absDelta < 0.33 {
            magnitude = .small
        } else if absDelta < 0.47 {
            magnitude = .medium
        } else {
            magnitude = .large
        }

        return EffectSize(delta: delta, magnitude: magnitude)
    }

    private func interpretEffects(
        clarity: EffectSize,
        area: EffectSize,
        count: EffectSize
    ) -> String {
        var interpretation: [String] = []

        // Clarity interpretation
        if clarity.magnitude != .negligible {
            let direction = clarity.delta > 0 ? "improved" : "worsened"
            interpretation.append("Clarity Score \(direction) (\(clarity.magnitude.rawValue) effect)")
        }

        // Inflamed area interpretation (negative delta = improvement)
        if area.magnitude != .negligible {
            let direction = area.delta < 0 ? "decreased" : "increased"
            interpretation.append("Inflamed area \(direction) (\(area.magnitude.rawValue) effect)")
        }

        // Lesion count interpretation (negative delta = improvement)
        if count.magnitude != .negligible {
            let direction = count.delta < 0 ? "decreased" : "increased"
            interpretation.append("Lesion count \(direction) (\(count.magnitude.rawValue) effect)")
        }

        if interpretation.isEmpty {
            return "No significant changes detected between windows."
        }

        return interpretation.joined(separator: ". ") + "."
    }
}

// MARK: - Supporting Types

struct AggregatedMetrics {
    let summary: MetricsSummary
    let inflamedAreas: [Double]
    let lesionCounts: [Double]
}

struct MetricsSummary {
    let meanClarityScore: Double
    let meanInflamedArea: Double
    let meanLesionCount: Double
    let scanCount: Int
}

struct RegimenComparison {
    let windowA: DateInterval
    let windowB: DateInterval
    let metricsA: MetricsSummary
    let metricsB: MetricsSummary
    let clarityEffect: EffectSize
    let inflamedAreaEffect: EffectSize
    let lesionCountEffect: EffectSize
    let interpretation: String
}

struct EffectSize {
    let delta: Double
    let magnitude: EffectMagnitude
}

enum EffectMagnitude: String {
    case negligible = "negligible"
    case small = "small"
    case medium = "medium"
    case large = "large"
}

enum RegimenError: LocalizedError {
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Insufficient data to compare regimens"
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }
}
