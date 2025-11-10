import AVFoundation
import Vision
import SwiftUI

/// Manages camera capture session and WiFi QR code detection.
class CameraManager: NSObject, ObservableObject {
    @Published var error: Error?
    @Published var isAuthorized = false

    /// Callback invoked when a WiFi QR code is detected in the camera feed
    var onWiFiQRCodeDetected: ((WiFiCredentials) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoOutput = AVCaptureVideoDataOutput()

    override init() {
        super.init()
        checkPermissions()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            self.setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    }
                }
            }
        case .denied, .restricted:
            self.isAuthorized = false
        @unknown default:
            self.isAuthorized = false
        }
    }

    func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Try to get front camera first, fallback to any available camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                         ?? AVCaptureDevice.default(for: .video) else {
            error = NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera available"])
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return }
            session.addInput(input)

            guard session.canAddOutput(videoOutput) else { return }
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

            self.captureSession = session

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        } catch {
            self.error = error
        }
    }

    func stopSession() {
        self.captureSession?.stopRunning()
    }

    /// Returns the camera preview layer for displaying in the UI.
    /// The layer is created lazily and reused.
    /// - Returns: The preview layer, or `nil` if no capture session exists.
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }

        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill

            // Mirror horizontally for intuitive user experience
            layer.connection?.automaticallyAdjustsVideoMirroring = false
            layer.connection?.isVideoMirrored = true

            previewLayer = layer
        }

        return previewLayer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        QRCodeProcessingService.shared.processQRCodeFromCameraFrame(pixelBuffer) { [weak self] credentials in
            guard let credentials = credentials else { return }

            DispatchQueue.main.async {
                self?.onWiFiQRCodeDetected?(credentials)
            }
        }
    }
}
