//
//  WifyApp.swift
//  wifymac
//
//  Created by Yi-Lin Juang on 2025/3/17.
//

import SwiftUI
import AppKit

@main
struct WifyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 500, minHeight: 400)
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
