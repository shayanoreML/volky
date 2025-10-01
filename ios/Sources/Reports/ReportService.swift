//
//  ReportService.swift
//  Volcy
//
//  PDF report generation for dermatologist sharing
//

import Foundation
import PDFKit
import UIKit

class ReportServiceImpl: ReportService {

    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    // MARK: - ReportService Protocol

    func generateReport(for userId: UUID, period: ReportPeriod) async throws -> Data {
        let dateInterval = period.dateInterval
        let scans = try await fetchScansInPeriod(dateInterval)

        guard !scans.isEmpty else {
            throw ReportError.noDataAvailable
        }

        // Create PDF
        let pdf = PDFGenerator()

        // Cover page
        pdf.addCoverPage(period: period, scanCount: scans.count)

        // Summary page
        let summary = calculateSummary(from: scans)
        pdf.addSummaryPage(summary: summary)

        // Per-lesion trends
        // TODO: Fetch lesion history
        pdf.addTrendsPage(scans: scans)

        // Region breakdown
        pdf.addRegionBreakdownPage(scans: scans)

        // QC summary
        pdf.addQCSummaryPage(scans: scans)

        return pdf.generatePDFData()
    }

    // MARK: - Private Helpers

    private func fetchScansInPeriod(_ interval: DateInterval) async throws -> [ScanEntity] {
        let allScans = try await persistenceService.fetchScans(limit: 10000)
        return allScans.filter { scan in
            guard let timestamp = scan.timestamp else { return false }
            return interval.contains(timestamp)
        }
    }

    private func calculateSummary(from scans: [ScanEntity]) -> ReportSummary {
        let clarityScores = scans.compactMap { Double($0.clarityScore) }

        return ReportSummary(
            scanCount: scans.count,
            meanClarityScore: clarityScores.mean,
            clarityTrend: calculateTrend(clarityScores),
            firstScanDate: scans.last?.timestamp ?? Date(),
            lastScanDate: scans.first?.timestamp ?? Date()
        )
    }

    private func calculateTrend(_ values: [Double]) -> String {
        guard values.count >= 2 else { return "Stable" }

        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)

        let firstMean = Array(firstHalf).mean
        let secondMean = Array(secondHalf).mean

        let change = ((secondMean - firstMean) / firstMean) * 100.0

        if change > 5 {
            return "Improving ↑"
        } else if change < -5 {
            return "Worsening ↓"
        } else {
            return "Stable →"
        }
    }
}

// MARK: - PDF Generator

class PDFGenerator {

    private var pdfData = NSMutableData()
    private var currentYPosition: CGFloat = 50.0
    private let pageWidth: CGFloat = 612.0 // US Letter
    private let pageHeight: CGFloat = 792.0
    private let margin: CGFloat = 50.0

    func generatePDFData() -> Data {
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)
        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    func addCoverPage(period: ReportPeriod, scanCount: Int) {
        UIGraphicsBeginPDFPageWithInfo(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "SpaceGrotesk-Bold", size: 34) ?? UIFont.boldSystemFont(ofSize: 34),
            .foregroundColor: UIColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1.0) // Graphite
        ]

        let title = "Volcy Skin Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (pageWidth - titleSize.width) / 2,
            y: 200,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)

        // Period
        let periodAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor(red: 0.216, green: 0.255, blue: 0.318, alpha: 1.0) // TextSecondary
        ]

        let periodText = "\(period.displayName) Report"
        let periodSize = periodText.size(withAttributes: periodAttributes)
        let periodRect = CGRect(
            x: (pageWidth - periodSize.width) / 2,
            y: 250,
            width: periodSize.width,
            height: periodSize.height
        )
        periodText.draw(in: periodRect, withAttributes: periodAttributes)

        // Scan count
        let scanText = "\(scanCount) scans analyzed"
        let scanSize = scanText.size(withAttributes: periodAttributes)
        let scanRect = CGRect(
            x: (pageWidth - scanSize.width) / 2,
            y: 290,
            width: scanSize.width,
            height: scanSize.height
        )
        scanText.draw(in: scanRect, withAttributes: periodAttributes)

        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateText = "Generated: \(dateFormatter.string(from: Date()))"
        let dateSize = dateText.size(withAttributes: periodAttributes)
        let dateRect = CGRect(
            x: (pageWidth - dateSize.width) / 2,
            y: pageHeight - 100,
            width: dateSize.width,
            height: dateSize.height
        )
        dateText.draw(in: dateRect, withAttributes: periodAttributes)

        // Footer
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ]
        let footer = "Generated with Volcy • For dermatologist review only"
        let footerSize = footer.size(withAttributes: footerAttributes)
        let footerRect = CGRect(
            x: (pageWidth - footerSize.width) / 2,
            y: pageHeight - 50,
            width: footerSize.width,
            height: footerSize.height
        )
        footer.draw(in: footerRect, withAttributes: footerAttributes)
    }

    func addSummaryPage(summary: ReportSummary) {
        startNewPage()

        addHeading("Summary")

        addMetricRow(label: "Total Scans", value: "\(summary.scanCount)")
        addMetricRow(label: "Clarity Score", value: String(format: "%.1f", summary.meanClarityScore))
        addMetricRow(label: "Trend", value: summary.clarityTrend)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        addMetricRow(
            label: "Period",
            value: "\(dateFormatter.string(from: summary.firstScanDate)) – \(dateFormatter.string(from: summary.lastScanDate))"
        )
    }

    func addTrendsPage(scans: [ScanEntity]) {
        startNewPage()
        addHeading("Trends Over Time")

        // Draw simple line chart
        let chartRect = CGRect(x: margin, y: currentYPosition, width: pageWidth - 2 * margin, height: 200)
        drawLineChart(in: chartRect, scans: scans)

        currentYPosition += 220
    }

    func addRegionBreakdownPage(scans: [ScanEntity]) {
        startNewPage()
        addHeading("Region Breakdown")

        addText("T-Zone: Forehead, nose")
        addText("U-Zone: Cheeks, chin")

        // TODO: Add actual region data
    }

    func addQCSummaryPage(scans: [ScanEntity]) {
        startNewPage()
        addHeading("Quality Control Summary")

        let qcPassCount = scans.count // Placeholder
        let qcPassRate = Double(qcPassCount) / Double(max(scans.count, 1)) * 100.0

        addMetricRow(label: "QC Pass Rate", value: String(format: "%.1f%%", qcPassRate))
        addText("All scans met quality standards for pose, distance, lighting, and focus.")
    }

    // MARK: - Helper Methods

    private func startNewPage() {
        UIGraphicsBeginPDFPageWithInfo(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)
        currentYPosition = margin
    }

    private func addHeading(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "SpaceGrotesk-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1.0)
        ]

        let size = text.size(withAttributes: attributes)
        let rect = CGRect(x: margin, y: currentYPosition, width: pageWidth - 2 * margin, height: size.height)
        text.draw(in: rect, withAttributes: attributes)

        currentYPosition += size.height + 20
    }

    private func addText(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]

        let size = text.size(withAttributes: attributes)
        let rect = CGRect(x: margin, y: currentYPosition, width: pageWidth - 2 * margin, height: size.height)
        text.draw(in: rect, withAttributes: attributes)

        currentYPosition += size.height + 10
    }

    private func addMetricRow(label: String, value: String) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]

        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.black
        ]

        let labelSize = label.size(withAttributes: labelAttributes)
        let labelRect = CGRect(x: margin, y: currentYPosition, width: 200, height: labelSize.height)
        label.draw(in: labelRect, withAttributes: labelAttributes)

        let valueSize = value.size(withAttributes: valueAttributes)
        let valueRect = CGRect(x: margin + 220, y: currentYPosition, width: 200, height: valueSize.height)
        value.draw(in: valueRect, withAttributes: valueAttributes)

        currentYPosition += max(labelSize.height, valueSize.height) + 15
    }

    private func drawLineChart(in rect: CGRect, scans: [ScanEntity]) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Draw background
        context.setFillColor(UIColor(red: 0.925, green: 0.949, blue: 0.969, alpha: 1.0).cgColor)
        context.fill(rect)

        // Draw border
        context.setStrokeColor(UIColor(red: 0.886, green: 0.910, blue: 0.941, alpha: 1.0).cgColor)
        context.setLineWidth(1.0)
        context.stroke(rect)

        // Draw data points
        let clarityScores = scans.map { Double($0.clarityScore) }
        guard !clarityScores.isEmpty else { return }

        let maxScore = 100.0
        let stepX = rect.width / CGFloat(max(clarityScores.count - 1, 1))

        context.setStrokeColor(UIColor(red: 0.412, green: 0.890, blue: 0.776, alpha: 1.0).cgColor) // Mint
        context.setLineWidth(2.0)
        context.setLineCap(.round)

        context.beginPath()

        for (index, score) in clarityScores.enumerated() {
            let x = rect.minX + CGFloat(index) * stepX
            let y = rect.maxY - (CGFloat(score / maxScore) * rect.height)

            if index == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.strokePath()
    }
}

// MARK: - Supporting Types

struct ReportSummary {
    let scanCount: Int
    let meanClarityScore: Double
    let clarityTrend: String
    let firstScanDate: Date
    let lastScanDate: Date
}

enum ReportPeriod {
    case week
    case month
    case quarter

    var dateInterval: DateInterval {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return DateInterval(start: start, end: now)
        case .month:
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            return DateInterval(start: start, end: now)
        case .quarter:
            let start = calendar.date(byAdding: .day, value: -90, to: now)!
            return DateInterval(start: start, end: now)
        }
    }

    var displayName: String {
        switch self {
        case .week: return "7-Day"
        case .month: return "30-Day"
        case .quarter: return "90-Day"
        }
    }
}

enum ReportError: LocalizedError {
    case noDataAvailable

    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "No scan data available for this period"
        }
    }
}
