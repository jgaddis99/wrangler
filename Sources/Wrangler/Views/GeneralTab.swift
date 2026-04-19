// Sources/Wrangler/Views/GeneralTab.swift
//
// General settings tab: launch at login, window target mode,
// global activation shortcut, and menu bar visibility toggle.
// Uses SettingsCard for consistent card styling across tabs.

import ServiceManagement
import SwiftUI

struct GeneralTab: View {
    @ObservedObject var configManager: ConfigManager

    /// Consistent width for leading labels in HStack rows.
    private let labelWidth: CGFloat = 170

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // System
                SettingsCard("System") {
                    Toggle("Launch at login", isOn: $configManager.config.general.launchAtLogin)
                        .onChange(of: configManager.config.general.launchAtLogin) { _, newValue in
                            setLaunchAtLogin(newValue)
                            configManager.save()
                        }
                }

                // Window Target
                SettingsCard("Window Target") {
                    Picker("Which window to manage:", selection: $configManager.config.general.windowTarget) {
                        Text("Front-most active window").tag(WindowTarget.frontMost)
                        Text("Window under mouse cursor").tag(WindowTarget.underCursor)
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: configManager.config.general.windowTarget) { _, _ in
                        configManager.save()
                    }
                }

                // Grid Overlay
                SettingsCard("Grid Overlay") {
                    HStack {
                        Text("Overlay shortcut")
                            .frame(width: labelWidth, alignment: .leading)
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
                        .help("Automatically display the grid overlay when you start dragging a window")

                    HStack {
                        Text("Reset pins shortcut")
                            .frame(width: labelWidth, alignment: .leading)
                        ShortcutRecorderView(keyCombo: $configManager.config.general.resetPinsShortcut)
                            .frame(width: 140)
                            .onChange(of: configManager.config.general.resetPinsShortcut) { _, _ in
                                configManager.save()
                            }
                    }
                    .help("Shortcut to reset all pinned apps to their designated grid positions")
                }

                // Behavior
                SettingsCard("Behavior") {
                    Toggle("Show live preview on display during drag", isOn: $configManager.config.general.showLivePreview)
                        .onChange(of: configManager.config.general.showLivePreview) { _, _ in configManager.save() }
                        .help("Highlight the target zone on the display while dragging a window")

                    HStack {
                        Text("Auto-hide overlay delay")
                            .frame(width: labelWidth, alignment: .leading)
                        Slider(value: $configManager.config.general.autoHideOverlayDelay, in: 1...10, step: 0.5)
                            .onChange(of: configManager.config.general.autoHideOverlayDelay) { _, _ in configManager.save() }
                        Text("\(configManager.config.general.autoHideOverlayDelay, specifier: "%.1f")s")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                    .help("Seconds of inactivity before the overlay hides itself")
                }

                // Menu Bar
                SettingsCard("Menu Bar") {
                    Toggle("Hide menu bar icon", isOn: $configManager.config.general.hideMenuBarIcon)
                        .disabled(true)
                        .onChange(of: configManager.config.general.hideMenuBarIcon) { _, _ in
                            configManager.save()
                        }
                    Text("Hiding the menu bar icon is disabled in v0.1 to prevent lockout.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Accessibility
                SettingsCard("Accessibility") {
                    HStack(spacing: 8) {
                        if PermissionManager.isAccessibilityGranted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .imageScale(.large)
                            Text("Accessibility permission granted")
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .imageScale(.large)
                            Text("Accessibility permission required")
                            Spacer()
                            Button("Grant Permission") {
                                PermissionManager.requestWithPrompt()
                            }
                        }
                    }
                }

                // Reset
                HStack {
                    Spacer()
                    Button("Restore All Defaults") {
                        configManager.resetToDefaults()
                    }
                    .foregroundStyle(.red)
                    .controlSize(.small)
                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Spacer(minLength: 0)
        }
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
