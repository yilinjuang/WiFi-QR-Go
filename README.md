# Wify for Mac

A macOS application that scans Wi-Fi QR codes using the front camera and connects to the corresponding Wi-Fi network.

## Features

- Scans QR codes using the built-in front camera
- Parses Wi-Fi credentials from standard Wi-Fi QR codes
- Prompts for user confirmation before connecting
- Connects to Wi-Fi networks programmatically using CoreWLAN
- Fallback to manual connection via System Preferences if automatic connection fails

## Requirements

- macOS 12.0 or later
- Mac with a built-in camera or connected webcam
- Xcode 14.0 or later (for development)

## Usage

1. Launch the application
2. Grant camera permissions when prompted
3. Point your camera at a Wi-Fi QR code
4. Confirm the connection when prompted
5. The app will attempt to connect to the Wi-Fi network

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

## License

MIT License
