import Foundation
import Vision
import CoreImage
import AppKit

/// Processes QR codes from images and camera frames to extract WiFi credentials.
class QRCodeProcessingService {
    static let shared = QRCodeProcessingService()

    private init() {}

    /// Processes a QR code from an image file.
    /// - Parameters:
    ///   - url: The URL of the image file to process.
    ///   - completion: Callback with extracted credentials or `nil` if no valid QR code found.
    func processQRCodeImage(_ url: URL, completion: @escaping (WiFiCredentials?) -> Void) {
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }

        detectQRCodeFromCGImage(cgImage, completion: completion)
    }

    /// Processes a QR code from a camera video frame.
    /// - Parameters:
    ///   - pixelBuffer: The pixel buffer from the camera frame.
    ///   - completion: Callback with extracted credentials or `nil` if no valid QR code found.
    func processQRCodeFromCameraFrame(_ pixelBuffer: CVPixelBuffer, completion: @escaping (WiFiCredentials?) -> Void) {
        detectQRCodeFromPixelBuffer(pixelBuffer, completion: completion)
    }

    /// Detects and parses QR codes from a CGImage using Vision framework.
    private func detectQRCodeFromCGImage(_ cgImage: CGImage, completion: @escaping (WiFiCredentials?) -> Void) {
        let request = createBarcodeRequest(completion: completion)
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    /// Detects and parses QR codes from a CVPixelBuffer using Vision framework.
    private func detectQRCodeFromPixelBuffer(_ pixelBuffer: CVPixelBuffer, completion: @escaping (WiFiCredentials?) -> Void) {
        let request = createBarcodeRequest(completion: completion)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    /// Creates a barcode detection request configured for WiFi QR codes.
    private func createBarcodeRequest(completion: @escaping (WiFiCredentials?) -> Void) -> VNDetectBarcodesRequest {
        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNBarcodeObservation] else {
                completion(nil)
                return
            }

            // Find and parse WiFi QR codes
            for result in results where result.symbology == .qr {
                if let payloadString = result.payloadStringValue,
                   let credentials = WiFiCredentials.parse(from: payloadString) {
                    completion(credentials)
                    return
                }
            }

            completion(nil)
        }

        request.symbologies = [.qr]
        return request
    }
}
