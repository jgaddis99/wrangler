// Sources/Wrangler/Views/ShortcutsTab.swift
//
// Shortcuts settings tab: lists all available window actions
// with configurable keyboard shortcuts and enable/disable toggles.

import SwiftUI

struct ShortcutsTab: View {
    @ObservedObject var configManager: ConfigManager

    var body: some View {
        Form {
            Section("Window Actions") {
                ForEach(WranglerAction.allCases) { action in
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
            }
        }
    }
}
