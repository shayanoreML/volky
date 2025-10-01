//
//  CaptureView.swift
//  Volcy
//
//  Camera capture view with live QC overlays
//

import SwiftUI
import ARKit

struct CaptureView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CaptureViewModel()

    var body: some View {
        ZStack {
            // Camera preview
            ARKitPreviewView(captureService: viewModel.captureService)
                .ignoresSafeArea()

            // Overlays
            VStack {
                // Top bar
                topBar

                Spacer()

                // QC Status indicators
                if let qc = viewModel.qcGates {
                    qcStatusView(qc: qc)
                        .padding(.bottom, VolcySpacing.lg)
                }

                // Feedback message
                feedbackBanner

                // Shutter button
                shutterButton
                    .padding(.bottom, VolcySpacing.xxl)
            }
        }
        .task {
            await viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Mode indicator
            Text(viewModel.captureMode == .frontTrueDepth ? "Front" : "Rear")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, VolcySpacing.md)
                .padding(.vertical, VolcySpacing.sm)
                .background(Color.black.opacity(0.5))
                .cornerRadius(VolcyRadius.pill)

            // Camera switch (future feature)
//            Button(action: viewModel.switchCameraMode) {
//                Image(systemName: "camera.rotate")
//                    .font(.title3)
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(Color.black.opacity(0.5))
//                    .clipShape(Circle())
//            }
        }
        .padding()
    }

    private func qcStatusView(qc: QualityControlGates) -> some View {
        VStack(spacing: VolcySpacing.sm) {
            qcIndicator(
                icon: "angle.right.angle.left",
                label: "Pose",
                passed: qc.pose.passed
            )
            qcIndicator(
                icon: "ruler",
                label: "Distance",
                passed: qc.distance.passed
            )
            qcIndicator(
                icon: "light.max",
                label: "Lighting",
                passed: qc.lighting.passed
            )
            qcIndicator(
                icon: "camera.aperture",
                label: "Focus",
                passed: qc.blur.passed
            )
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(VolcyRadius.card)
        .padding(.horizontal)
    }

    private func qcIndicator(icon: String, label: String, passed: Bool) -> some View {
        HStack(spacing: VolcySpacing.md) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(passed ? VolcyColor.success : Color.white.opacity(0.3))
        }
    }

    private var feedbackBanner: some View {
        Text(viewModel.feedbackMessage)
            .font(.headline)
            .foregroundColor(viewModel.feedbackColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.7))
            .cornerRadius(VolcyRadius.button)
            .padding(.horizontal)
            .padding(.bottom, VolcySpacing.md)
    }

    private var shutterButton: some View {
        Button(action: {
            Task {
                await viewModel.capturePhoto()
            }
        }) {
            ZStack {
                Circle()
                    .fill(viewModel.isReadyToCapture ? VolcyColor.mint : Color.white.opacity(0.3))
                    .frame(width: 80, height: 80)

                if viewModel.isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                }
            }
        }
        .disabled(!viewModel.isReadyToCapture || viewModel.isProcessing)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - ARKit Preview View

struct ARKitPreviewView: UIViewRepresentable {
    let captureService: ARKitCaptureService

    func makeUIView(context: Context) -> ARSCNView {
        let scnView = ARSCNView()
        scnView.session = captureService.arSession ?? ARSession()
        scnView.automaticallyUpdatesLighting = true
        scnView.autoenablesDefaultLighting = true
        return scnView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update if needed
    }
}

// MARK: - Preview

#Preview {
    CaptureView()
}
