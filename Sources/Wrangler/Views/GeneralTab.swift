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

            Section("Grid Overlay") {
                HStack {
                    Text("Overlay shortcut:")
                    ShortcutRecorderView(keyCombo: $configManager.config.general.overlayShortcut)
                        .frame(width: 140)
                        .onChange(of: configManager.config.general.overlayShortcut) { _, _ in
                            configManager.save()
                        }
                }

                Toggle("Auto-show overlay when dragging windows", isOn: $configManager.config.general.autoShowOverlay)
                    .onChange(of: configManager.config.general.autoShowOverlay) { _, _ in
                        configManager.save()
                    }
            }

            Section("Behavior") {
                Toggle("Show live preview on display during drag", isOn: $configManager.config.general.showLivePreview)
                    .onChange(of: configManager.config.general.showLivePreview) { _, _ in configManager.save() }

                HStack {
                    Text("Auto-hide overlay delay:")
                    Slider(value: $configManager.config.general.autoHideOverlayDelay, in: 1...10, step: 0.5)
                        .onChange(of: configManager.config.general.autoHideOverlayDelay) { _, _ in configManager.save() }
                    Text("\(configManager.config.general.autoHideOverlayDelay, specifier: "%.1f")s")
                        .monospacedDigit()
                        .frame(width: 35)
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
            Section {
                Button("Restore All Defaults") {
                    configManager.resetToDefaults()
                }
                .foregroundColor(.red)
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
