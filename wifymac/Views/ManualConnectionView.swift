import SwiftUI

struct ManualConnectionView: View {
    let credentials: WiFiCredentials
    @State private var passwordCopied = false
    @State private var ssidCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manual Connection")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Network Name (SSID):")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text(credentials.ssid)
                        .font(.body)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    Button(action: {
                        ClipboardHelper.copyToClipboard(credentials.ssid)
                        ssidCopied = true

                        // Reset the copied state after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            ssidCopied = false
                        }
                    }) {
                        Label(ssidCopied ? "Copied!" : "Copy", systemImage: ssidCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let password = credentials.password {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(password)
                            .font(.body)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)

                        Button(action: {
                            ClipboardHelper.copyToClipboard(password)
                            passwordCopied = true

                            // Reset the copied state after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                passwordCopied = false
                            }
                        }) {
                            Label(passwordCopied ? "Copied!" : "Copy", systemImage: passwordCopied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Button("Open Wi-Fi Settings") {
                WiFiService.shared.openNetworkPreferences()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 400)
    }
}