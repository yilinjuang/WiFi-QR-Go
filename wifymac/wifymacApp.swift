//
//  WifyApp.swift
//  wifymac
//
//  Created by Yi-Lin Juang on 2025/3/17.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Center the window when the app launches
        if let window = NSApplication.shared.windows.first {
            // Get the screen frame
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero

            // Calculate the centered position
            let x = screenFrame.origin.x + (screenFrame.width - window.frame.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - window.frame.height) / 2

            // Set the window position
            window.setFrameOrigin(NSPoint(x: x, y: y))
            window.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct WifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Wify") {
                    let options: [NSApplication.AboutPanelOptionKey: Any] = [
                        .credits: NSAttributedString(
                            string: "Quickly connect to WiFi by scanning QR code",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        ),
                    ]

                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
        }
    }
}
