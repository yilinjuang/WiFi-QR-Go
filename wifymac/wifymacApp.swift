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
    @State private var isShowingSplash = true
    @State private var showingAbout = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .frame(minWidth: 500, minHeight: 400)
                    .onAppear {
                        NSWindow.allowsAutomaticWindowTabbing = false
                    }

                if isShowingSplash {
                    LaunchScreen()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    isShowingSplash = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Help") {
                Button("About Wify") {
                    showingAbout = true
                }
            }
        }
    }
}
