import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Wify")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A simple macOS application that scans Wi-Fi QR codes and connects to networks.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

#Preview {
    AboutView()
}