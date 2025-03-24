import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    var previewLayer: AVCaptureVideoPreviewLayer?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        guard let previewLayer = previewLayer else {
            return view
        }

        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = previewLayer
        view.wantsLayer = true

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let previewLayer = previewLayer {
            previewLayer.frame = nsView.bounds
        }
    }
}