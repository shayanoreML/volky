//
//  CaptureViewModel.swift
//  Volcy
//
//  ViewModel for capture flow with live QC feedback
//

import Foundation
import SwiftUI
import Combine
import ARKit

/// ViewModel managing capture session and user interaction
@MainActor
class CaptureViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isSessionActive: Bool = false
    @Published var qcGates: QualityControlGates?
    @Published var isReadyToCapture: Bool = false
    @Published var feedbackMessage: String = "Initializing..."
    @Published var feedbackColor: Color = .white
    @Published var captureMode: CaptureConfiguration.CaptureMode = .frontTrueDepth
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let captureService: ARKitCaptureService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(captureService: ARKitCaptureService) {
        self.captureService = captureService
        setupObservers()
    }

    convenience init() {
        let service = ARKitCaptureService()
        self.init(captureService: service)
    }

    // MARK: - Public Methods

    func startSession() async {
        do {
            try await captureService.startSession()
            isSessionActive = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            isSessionActive = false
        }
    }

    func stopSession() {
        captureService.stopSession()
        isSessionActive = false
        qcGates = nil
        isReadyToCapture = false
        feedbackMessage = "Session stopped"
    }

    func capturePhoto() async {
        guard isReadyToCapture else {
            errorMessage = "Quality checks not passed"
            return
        }

        isProcessing = true
        feedbackMessage = "Capturing..."

        do {
            let frame = try await captureService.captureFrame()
            // TODO: Process captured frame (segmentation, metrics, etc.)
            // For now, just indicate success
            feedbackMessage = "✓ Scan complete!"
            feedbackColor = VolcyColor.success

            // Auto-dismiss after brief delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            // Navigate to results (handled by parent view)
        } catch {
            errorMessage = error.localizedDescription
            feedbackMessage = "Capture failed"
            feedbackColor = VolcyColor.error
        }

        isProcessing = false
    }

    func switchCameraMode() {
        stopSession()
        captureMode = captureMode == .frontTrueDepth ? .rearProMode : .frontTrueDepth

        Task {
            // Recreate service with new mode
            let newService = ARKitCaptureService(configuration: CaptureConfiguration(mode: captureMode))
            // TODO: Update captureService reference
            await startSession()
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe QC state changes
        captureService.$currentQC
            .receive(on: DispatchQueue.main)
            .sink { [weak self] qc in
                self?.qcGates = qc
                self?.updateFeedback(for: qc)
            }
            .store(in: &cancellables)

        // Observe ready state
        captureService.$isReadyToCapture
            .receive(on: DispatchQueue.main)
            .assign(to: &$isReadyToCapture)

        // Observe session state
        captureService.$sessionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleSessionStateChange(state)
            }
            .store(in: &cancellables)
    }

    private func updateFeedback(for qc: QualityControlGates?) {
        guard let qc = qc else {
            feedbackMessage = "Initializing..."
            feedbackColor = .white
            return
        }

        if qc.allPassed {
            feedbackMessage = "✓ Ready to scan"
            feedbackColor = VolcyColor.success
        } else {
            feedbackMessage = qc.userFeedback
            feedbackColor = VolcyColor.warning
        }
    }

    private func handleSessionStateChange(_ state: CaptureSessionState) {
        switch state {
        case .notConfigured:
            feedbackMessage = "Not configured"
        case .configuring:
            feedbackMessage = "Starting camera..."
        case .ready:
            feedbackMessage = "Ready"
        case .running:
            feedbackMessage = "Position your face"
        case .failed(let error):
            errorMessage = error.localizedDescription
            feedbackMessage = "Camera error"
            feedbackColor = VolcyColor.error
        }
    }
}
