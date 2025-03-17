import SwiftUI

struct QRCodeCaptureOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .mask(
                        // Create a hole in the middle
                        Rectangle()
                            .overlay(
                                // This creates the transparent center with rounded corners
                                RoundedRectangle(cornerRadius: 12)
                                    .frame(
                                        width: min(geometry.size.width * 0.7, 300),
                                        height: min(geometry.size.width * 0.7, 300)
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )

                // Capture box
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(
                        width: min(geometry.size.width * 0.7, 300),
                        height: min(geometry.size.width * 0.7, 300)
                    )

                // Instruction text at the bottom
                VStack {
                    Spacer()
                    Text("Scan a Wifi QR code")
                        .font(.headline)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        QRCodeCaptureOverlay()
    }
}