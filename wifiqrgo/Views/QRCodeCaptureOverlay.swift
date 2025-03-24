import SwiftUI

struct QRCodeCaptureOverlay: View {
    var toastMessage: ToastMessage?

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

                // Instruction text or toast message at the bottom
                VStack {
                    Spacer()

                    // Use the same visual format for both default instruction and toast messages
                    HStack(spacing: 12) {
                        if let toast = toastMessage, toast.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: toastMessage?.icon ?? "qrcode.viewfinder")
                                .font(.system(size: 18))
                        }

                        Text(toastMessage?.message ?? "Scan a Wifi QR code")
                            .font(.headline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.6))
                    )
                    .foregroundColor(toastMessage?.color ?? .white)
                    .transition(.opacity)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct ToastMessage: Equatable {
    let message: String
    let icon: String
    let color: Color
    let isLoading: Bool

    init(message: String, icon: String, color: Color, isLoading: Bool = false) {
        self.message = message
        self.icon = icon
        self.color = color
        self.isLoading = isLoading
    }

    // No default icons in factory methods - require explicit icon parameter
    static func success(message: String, icon: String) -> ToastMessage {
        ToastMessage(message: message, icon: icon, color: .green)
    }

    static func info(message: String, icon: String) -> ToastMessage {
        ToastMessage(message: message, icon: icon, color: .cyan)
    }

    static func warning(message: String, icon: String) -> ToastMessage {
        ToastMessage(message: message, icon: icon, color: .orange)
    }

    static func connecting(message: String) -> ToastMessage {
        ToastMessage(message: message, icon: "", color: .yellow, isLoading: true)
    }
}

#Preview {
    ZStack {
        Color.gray
        QRCodeCaptureOverlay(toastMessage: ToastMessage.connecting(message: "Connecting to WiFi..."))
    }
}