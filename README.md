# WiFi QR Go

A macOS application that scans Wi-Fi QR codes and connects to the corresponding Wi-Fi network.

## Installation

1. Install the app from the [App Store](https://apps.apple.com/app/wifi-qr-go/id6743514951)
2. Open WiFi QR Go from your Applications folder

## Usage

1. Launch the application
2. Grant camera permissions when prompted
3. Point your camera at a Wi-Fi QR code
4. Confirm the connection when prompted
5. The app will connect to the Wi-Fi network

## Why I Built This

I travel and work remotely a lot. Every new place—hotels, cafés, coworking spaces—means connecting to a new Wi-Fi network. As an Android and Mac user, I face a common hassle: Wi-Fi credentials don't sync between devices, so I have to reconnect manually on my Mac.

Modern Android phones can generate QR codes for connected networks. This macOS app lets you scan those codes and connect instantly—no typing long passwords or searching through networks.

I also built [Wify for Android](https://github.com/yilinjuang/wify), which extracts Wi-Fi details from printed text and generates QR codes. It complements this Mac app but isn't required.

## Features

- Scan Wi-Fi QR codes using your Mac's camera
- Import QR code images from your device
- One-click connection to detected networks
- Support for WPA/WPA2/WPA3 and open networks
- Native macOS interface
- Smart signal selection for reliable connections
- Copy network passwords to clipboard for manual connections

## Requirements

- macOS 11.0 (Big Sur) or later
- Mac with a built-in camera or connected webcam

## Privacy

- Only accesses the camera when the app is running
- Does not store or transmit Wi-Fi credentials
- Only connects to networks with user confirmation

## Technical Details

- Swift 5
- SwiftUI for the user interface
- AVFoundation for camera access
- Vision framework for QR code detection
- CoreWLAN for Wi-Fi connectivity

## Demo

https://github.com/user-attachments/assets/e979d7e9-d065-4e7e-964a-47d9541b1968

## License

MIT
