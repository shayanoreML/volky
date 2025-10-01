//
//  ARKitCaptureService.swift
//  Volcy
//
//  ARKit-based capture service with TrueDepth/LiDAR support
//

import Foundation
import ARKit
import AVFoundation
import Combine
import CoreImage

/// ARKit-based capture service implementation
@MainActor
class ARKitCaptureService: NSObject, CaptureService, ObservableObject {

    // MARK: - Published State

    @Published private(set) var sessionState: CaptureSessionState = .notConfigured
    @Published private(set) var currentQC: QualityControlGates?
    @Published private(set) var previewImage: CIImage?
    @Published private(set) var isReadyToCapture: Bool = false

    // MARK: - Private Properties

    private var arSession: ARSession?
    private var configuration: CaptureConfiguration
    private let qcService: QualityControlService
    private var cancellables = Set<AnyCancellable>()
    private var baselineTransform: simd_float4x4?

    // MARK: - Initialization

    init(configuration: CaptureConfiguration = CaptureConfiguration(mode: .frontTrueDepth)) {
        self.configuration = configuration
        self.qcService = QualityControlService()
        super.init()
    }

    // MARK: - CaptureService Protocol

    func startSession() async throws {
        guard ARFaceTrackingConfiguration.isSupported || ARWorldTrackingConfiguration.isSupported else {
            sessionState = .failed(CaptureError.depthNotSupported)
            throw CaptureError.depthNotSupported
        }

        // Check camera authorization
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                sessionState = .failed(CaptureError.authorizationDenied)
                throw CaptureError.authorizationDenied
            }
        default:
            sessionState = .failed(CaptureError.authorizationDenied)
            throw CaptureError.authorizationDenied
        }

        sessionState = .configuring

        // Create and configure ARSession
        let session = ARSession()
        self.arSession = session
        session.delegate = self

        // Configure based on mode
        let arConfig: ARConfiguration
        switch configuration.mode {
        case .frontTrueDepth:
            let faceConfig = ARFaceTrackingConfiguration()
            if ARFaceTrackingConfiguration.supportsWorldTracking {
                faceConfig.isWorldTrackingEnabled = true
            }
            faceConfig.isLightEstimationEnabled = true
            arConfig = faceConfig

        case .rearProMode:
            let worldConfig = ARWorldTrackingConfiguration()
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                worldConfig.frameSemantics.insert(.sceneDepth)
            }
            worldConfig.isLightEstimationEnabled = true
            arConfig = worldConfig
        }

        // Start session
        session.run(arConfig, options: [.resetTracking, .removeExistingAnchors])

        sessionState = .running
    }

    func stopSession() {
        arSession?.pause()
        arSession = nil
        sessionState = .notConfigured
        currentQC = nil
        isReadyToCapture = false
    }

    func captureFrame() async throws -> CapturedFrame {
        guard let session = arSession,
              let currentFrame = session.currentFrame else {
            throw CaptureError.sessionInterrupted
        }

        guard let qc = currentQC, qc.allPassed else {
            throw CaptureError.qualityControlFailed(currentQC?.userFeedback ?? "Quality check failed")
        }

        // Extract data from ARFrame
        let image = CIImage(cvPixelBuffer: currentFrame.capturedImage)
        let depthMap = extractDepthMap(from: currentFrame)
        let intrinsics = extractIntrinsics(from: currentFrame)
        let lightingStats = qcService.calculateLightingStats(from: currentFrame)

        return CapturedFrame(
            image: image,
            depthMap: depthMap,
            timestamp: Date(),
            intrinsics: intrinsics,
            transform: currentFrame.camera.transform,
            qc: qc,
            lightingStats: lightingStats
        )
    }

    // MARK: - Private Methods

    private func extractDepthMap(from frame: ARFrame) -> CVPixelBuffer? {
        // Try scene depth first (LiDAR)
        if let sceneDepth = frame.sceneDepth {
            return sceneDepth.depthMap
        }

        // Try smooth depth (ARKit depth estimation)
        if let smoothDepth = frame.smoothedSceneDepth {
            return smoothDepth.depthMap
        }

        return nil
    }

    private func extractIntrinsics(from frame: ARFrame) -> CameraIntrinsics {
        let intrinsicsMatrix = frame.camera.intrinsics
        let imageResolution = frame.camera.imageResolution

        return CameraIntrinsics(
            from: intrinsicsMatrix,
            dimensions: imageResolution
        )
    }

    private func processFrame(_ frame: ARFrame) {
        // Update preview
        let image = CIImage(cvPixelBuffer: frame.capturedImage)
        self.previewImage = image

        // Run QC checks
        let qc = qcService.evaluateQuality(
            frame: frame,
            configuration: configuration,
            baselineTransform: baselineTransform
        )

        // Store baseline on first good frame
        if baselineTransform == nil && qc.pose.passed {
            baselineTransform = frame.camera.transform
        }

        self.currentQC = qc
        self.isReadyToCapture = qc.allPassed
    }
}

// MARK: - ARSessionDelegate

extension ARKitCaptureService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            processFrame(frame)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            sessionState = .failed(error)
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            sessionState = .failed(CaptureError.sessionInterrupted)
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            sessionState = .running
        }
    }
}
