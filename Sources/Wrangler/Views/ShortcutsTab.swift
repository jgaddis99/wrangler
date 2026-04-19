// Sources/Wrangler/Views/ShortcutsTab.swift
//
// Shortcuts settings tab: lists all available window actions
// with configurable keyboard shortcuts and enable/disable toggles.
// Uses a two-column layout to fit all shortcuts without scrolling.

import SwiftUI

struct ShortcutsTab: View {
    @ObservedObject var configManager: ConfigManager

    private static let halves: [WranglerAction] = [.snapLeft, .snapRight, .snapTopHalf, .snapBottomHalf]
    private static let quarters: [WranglerAction] = [.snapTopLeft, .snapTopRight, .snapBottomLeft, .snapBottomRight]
    private static let thirds: [WranglerAction] = [.snapLeftThird, .snapCenterThird, .snapRightThird]
    private static let resize: [WranglerAction] = [.growLeft, .growRight, .growUp, .growDown]
    private static let actions: [WranglerAction] = [.maximize, .center, .autoTileDisplay, .undoSnap]
    private static let displayMovement: [WranglerAction] = [.nextDisplay, .previousDisplay]

    var body: some View {
        VStack(spacing: 0) {
            // Two-column layout keeps everything visible without scrolling
            HStack(alignment: .top, spacing: 12) {
                // Left column
                VStack(spacing: 8) {
                    shortcutSection("Halves", actions: Self.halves)
                    shortcutSection("Quarters", actions: Self.quarters)
                    shortcutSection("Actions", actions: Self.actions)
                }

                // Right column
                VStack(spacing: 8) {
                    shortcutSection("Thirds", actions: Self.thirds)
                    shortcutSection("Resize", actions: Self.resize)
                    shortcutSection("Display Movement", actions: Self.displayMovement)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func shortcutSection(_ title: String, actions: [WranglerAction]) -> some View {
        SettingsListCard(title) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { idx, action in
                if idx > 0 {
                    Divider()
                        .padding(.horizontal, 8)
                }
                shortcutRow(for: action)
            }
        }
    }

    @ViewBuilder
    private func shortcutRow(for action: WranglerAction) -> some View {
        let index = configManager.config.shortcuts.firstIndex { $0.action == action }

        if let index = index {
            HStack(spacing: 4) {
                Image(systemName: action.iconName)
                    .frame(width: 16, alignment: .center)
                    .foregroundColor(.accentColor)
                    .imageScale(.small)
                    .font(.system(size: 10))

                Text(action.displayName)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Spacer(minLength: 4)

                ShortcutRecorderView(
                    keyCombo: Binding(
                        get: { configManager.config.shortcuts[index].keyCombo },
                        set: { newValue in
                            configManager.config.shortcuts[index].keyCombo = newValue
                            configManager.save()
                        }
                    )
                )
                .frame(width: 100)

                Toggle("", isOn: Binding(
                    get: { configManager.config.shortcuts[index].enabled },
                    set: { newValue in
                        configManager.config.shortcuts[index].enabled = newValue
                        configManager.save()
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(configManager.config.shortcuts[index].enabled ? "Disable shortcut" : "Enable shortcut")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
        }
    }
}
