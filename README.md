# Wify for Mac

A macOS application that scans Wi-Fi QR codes and connects to the corresponding Wi-Fi network.

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

## Usage

1. Launch the application
2. Grant camera permissions when prompted
3. Point your camera at a Wi-Fi QR code
4. Confirm the connection when prompted
5. The app will connect to the Wi-Fi network

## Technical Details

The application is built using:

- Swift 5
- SwiftUI for the user interface
- AVFoundation for camera access
- Vision framework for QR code detection
- CoreWLAN for Wi-Fi connectivity

## Privacy

This application:

- Only accesses the camera when the app is running
- Does not store or transmit Wi-Fi credentials
- Only connects to networks with user confirmation

## Development

- Xcode 14.0 or later recommended for development
- No external dependencies required

## License

MIT
