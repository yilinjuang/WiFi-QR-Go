import Foundation
import Vision
import CoreImage
import AppKit

class QRCodeProcessingService {
    static let shared = QRCodeProcessingService()

    private init() {}

    // Process QR code from an image file
    func processQRCodeImage(_ url: URL, completion: @escaping (WiFiCredentials?) -> Void) {
        guard let nsImage = NSImage(contentsOf: url) else {
            print("Failed to load image")
            completion(nil)
            return
        }

        // Convert NSImage to CGImage
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to convert to CGImage")
            completion(nil)
            return
        }

        detectQRCode(in: cgImage, completion: completion)
    }

    // Process QR code from a camera frame
    func processQRCodeFromCameraFrame(_ pixelBuffer: CVPixelBuffer, completion: @escaping (WiFiCredentials?) -> Void) {
        detectQRCode(in: pixelBuffer, completion: completion)
    }

    // Generic QR code detection from any Vision-compatible image
    private func detectQRCode(in image: Any, completion: @escaping (WiFiCredentials?) -> Void) {
        // Create a Vision request to detect barcodes
        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                print("Vision error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let results = request.results as? [VNBarcodeObservation] else {
                print("No barcode detected")
                completion(nil)
                return
            }

            // Look for QR codes
            for result in results where result.symbology == .qr {
                if let payloadString = result.payloadStringValue {
                    // Process the QR code content
                    if let credentials = WiFiCredentials.parse(from: payloadString) {
                        completion(credentials)
                        return
                    }
                }
            }

            completion(nil)
        }

        // Set the barcode types to QR code only
        request.symbologies = [.qr]

        // Create a handler to process the image
        let handler: VNImageRequestHandler

        // Use type-specific handling instead of conditional checks
        if CFGetTypeID(image as CFTypeRef) == CVPixelBufferGetTypeID() {
            handler = VNImageRequestHandler(cvPixelBuffer: image as! CVPixelBuffer, options: [:])
        } else if CFGetTypeID(image as CFTypeRef) == CGImage.typeID {
            handler = VNImageRequestHandler(cgImage: image as! CGImage, options: [:])
        } else {
            print("Unsupported image type")
            completion(nil)
            return
        }

        // Perform the request
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform Vision request: \(error.localizedDescription)")
            completion(nil)
        }
    }
}
