import SwiftUI
import AppKit

struct LaunchScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Wi-Fi QR Scanner")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Scan and connect to Wi-Fi networks")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    LaunchScreen()
}