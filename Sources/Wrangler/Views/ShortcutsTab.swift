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
            HStack {
                Image(systemName: action.iconName)
                    .frame(width: 20)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(action.displayName)
                        .font(.body)
                }

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

                if configManager.config.shortcuts[index].keyCombo != nil {
                    Button(action: {
                        configManager.config.shortcuts[index].keyCombo = nil
                        configManager.save()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear shortcut")
                }
            }
        }
    }
}
