// Sources/Wrangler/Views/GeneralTab.swift
//
// General settings tab: launch at login, window target mode,
// global activation shortcut, and menu bar visibility toggle.

import ServiceManagement
import SwiftUI

struct GeneralTab: View {
    @ObservedObject var configManager: ConfigManager

    var body: some View {
        Form {
            Section("System") {
                Toggle("Launch at login", isOn: $configManager.config.general.launchAtLogin)
                    .onChange(of: configManager.config.general.launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                        configManager.save()
                    }
            }

            Section("Window Target") {
                Picker("Which window to manage:", selection: $configManager.config.general.windowTarget) {
                    Text("Front-most active window").tag(WindowTarget.frontMost)
                    Text("Window under mouse cursor").tag(WindowTarget.underCursor)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: configManager.config.general.windowTarget) { _, _ in
                    configManager.save()
                }
            }

            Section("Menu Bar") {
                Toggle("Hide menu bar icon", isOn: $configManager.config.general.hideMenuBarIcon)
                    .disabled(true)
                    .onChange(of: configManager.config.general.hideMenuBarIcon) { _, _ in
                        configManager.save()
                    }
                Text("Hiding the menu bar icon is disabled in v0.1 to prevent lockout.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Accessibility") {
                HStack {
                    if PermissionManager.isAccessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Accessibility permission granted")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility permission required")
                        Button("Grant Permission") {
                            PermissionManager.requestWithPrompt()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Wrangler: Failed to set launch at login: \(error)")
        }
    }
}
