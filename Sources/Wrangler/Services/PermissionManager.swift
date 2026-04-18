// Sources/Wrangler/Services/PermissionManager.swift
//
// Checks and prompts for macOS Accessibility API permission.
// Shows an alert on first launch if permission is not granted,
// with a button to open System Settings directly.

import AppKit
import ApplicationServices

enum PermissionManager {

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static func promptIfNeeded() {
        guard !isAccessibilityGranted else { return }

        let alert = NSAlert()
        alert.messageText = "Wrangler Needs Accessibility Permission"
        alert.informativeText = """
            Wrangler needs Accessibility access to manage your windows. \
            Please grant permission in System Settings, then relaunch Wrangler.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    static func requestWithPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
