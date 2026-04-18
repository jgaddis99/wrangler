// Sources/Wrangler/App/WranglerApp.swift
//
// Main entry point for the Wrangler window manager.
// Configures the SwiftUI app lifecycle and connects
// the AppDelegate for menu bar and engine management.

import SwiftUI

@main
struct WranglerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Wrangler v0.1")
                .frame(width: 300, height: 200)
        }
    }
}
