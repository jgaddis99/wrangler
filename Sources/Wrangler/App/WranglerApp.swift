// Sources/Wrangler/App/WranglerApp.swift
//
// Main entry point for the Wrangler window manager.
// Uses NSApplicationDelegateAdaptor to bridge AppKit for
// menu bar and engine management while using SwiftUI for
// the settings window.

import SwiftUI

@main
struct WranglerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                configManager: appDelegate.configManager,
                displayDetector: appDelegate.engine.displayDetector
            )
        }
    }
}
