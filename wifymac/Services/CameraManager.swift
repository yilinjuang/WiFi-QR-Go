import AVFoundation
import Vision
import SwiftUI

class CameraManager: NSObject, ObservableObject {
    @Published var error: Error?
    @Published var isAuthorized = false

    // Callback for when a WiFi QR code is detected
    var onWiFiQRCodeDetected: ((WiFiCredentials) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput = AVCaptureVideoDataOutput()

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

        // Get front camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            // Fallback to any available camera if front camera is not available
            guard let device = AVCaptureDevice.default(for: .video) else {
                error = NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera available"])
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
            } catch {
                self.error = error
                return
            }

            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            }

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

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = self.captureSession else {
            return nil
        }

        if self.previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill

            // Mirror the preview horizontally for a more intuitive user experience
            layer.connection?.automaticallyAdjustsVideoMirroring = false
            layer.connection?.isVideoMirrored = true

            self.previewLayer = layer
        }

        return self.previewLayer
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Use the QRCodeProcessingService to detect QR codes
        QRCodeProcessingService.shared.processQRCodeFromCameraFrame(pixelBuffer) { [weak self] credentials in
            if let credentials = credentials {
                DispatchQueue.main.async {
                    // Notify about the detected QR code
                    self?.onWiFiQRCodeDetected?(credentials)
                }
            }
        }
    }
}
