// Sources/Wrangler/Views/ShortcutsTab.swift
//
// Shortcuts settings tab: lists all available window actions
// with configurable keyboard shortcuts and enable/disable toggles.

import SwiftUI

struct ShortcutsTab: View {
    @ObservedObject var configManager: ConfigManager

    private static let halves: [WranglerAction] = [.snapLeft, .snapRight, .snapTopHalf, .snapBottomHalf]
    private static let quarters: [WranglerAction] = [.snapTopLeft, .snapTopRight, .snapBottomLeft, .snapBottomRight]
    private static let actions: [WranglerAction] = [.maximize, .center]
    private static let displayMovement: [WranglerAction] = [.nextDisplay, .previousDisplay]

    /// Fixed width for the action label so all shortcut recorders align.
    private let labelWidth: CGFloat = 160

    var body: some View {
        Form {
            Section("Halves") {
                ForEach(Self.halves) { action in
                    shortcutRow(for: action)
                }
            }
            Section("Quarters") {
                ForEach(Self.quarters) { action in
                    shortcutRow(for: action)
                }
            }
            Section("Actions") {
                ForEach(Self.actions) { action in
                    shortcutRow(for: action)
                }
            }
            Section("Display Movement") {
                ForEach(Self.displayMovement) { action in
                    shortcutRow(for: action)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func shortcutRow(for action: WranglerAction) -> some View {
        let index = configManager.config.shortcuts.firstIndex { $0.action == action }

        if let index = index {
            HStack(spacing: 8) {
                Image(systemName: action.iconName)
                    .frame(width: 24, alignment: .center)
                    .foregroundColor(.accentColor)
                    .imageScale(.medium)

                Text(action.displayName)
                    .frame(width: labelWidth, alignment: .leading)

                Spacer()

                ShortcutRecorderView(
                    keyCombo: Binding(
                        get: { configManager.config.shortcuts[index].keyCombo },
                        set: { newValue in
                            configManager.config.shortcuts[index].keyCombo = newValue
                            configManager.save()
                        }
                    )
                )
                .frame(width: 140)

                Toggle("", isOn: Binding(
                    get: { configManager.config.shortcuts[index].enabled },
                    set: { newValue in
                        configManager.config.shortcuts[index].enabled = newValue
                        configManager.save()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(configManager.config.shortcuts[index].enabled ? "Disable shortcut" : "Enable shortcut")

                Button(action: {
                    configManager.config.shortcuts[index].keyCombo = nil
                    configManager.save()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
                .opacity(configManager.config.shortcuts[index].keyCombo != nil ? 1 : 0)
                .disabled(configManager.config.shortcuts[index].keyCombo == nil)
            }
            .padding(.vertical, 2)
        }
    }
}
