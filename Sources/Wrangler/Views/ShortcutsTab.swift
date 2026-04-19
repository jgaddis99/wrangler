// Sources/Wrangler/Views/ShortcutsTab.swift
//
// Shortcuts settings tab: lists all available window actions
// with configurable keyboard shortcuts and enable/disable toggles.
// Uses a compact row layout to fit all 12 shortcuts without scrolling.

import SwiftUI

struct ShortcutsTab: View {
    @ObservedObject var configManager: ConfigManager

    private static let halves: [WranglerAction] = [.snapLeft, .snapRight, .snapTopHalf, .snapBottomHalf]
    private static let quarters: [WranglerAction] = [.snapTopLeft, .snapTopRight, .snapBottomLeft, .snapBottomRight]
    private static let thirds: [WranglerAction] = [.snapLeftThird, .snapCenterThird, .snapRightThird]
    private static let resize: [WranglerAction] = [.growLeft, .growRight, .growUp, .growDown]
    private static let actions: [WranglerAction] = [.maximize, .center, .autoTileDisplay]
    private static let displayMovement: [WranglerAction] = [.nextDisplay, .previousDisplay]

    /// Fixed width for the action label so all shortcut recorders align.
    private let labelWidth: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                shortcutSection("Halves", actions: Self.halves)
                shortcutSection("Quarters", actions: Self.quarters)
                shortcutSection("Thirds", actions: Self.thirds)
                shortcutSection("Resize", actions: Self.resize)
                shortcutSection("Actions", actions: Self.actions)
                shortcutSection("Display Movement", actions: Self.displayMovement)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func shortcutSection(_ title: String, actions: [WranglerAction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { idx, action in
                    if idx > 0 {
                        Divider()
                            .padding(.horizontal, 10)
                    }
                    shortcutRow(for: action)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func shortcutRow(for action: WranglerAction) -> some View {
        let index = configManager.config.shortcuts.firstIndex { $0.action == action }

        if let index = index {
            HStack(spacing: 6) {
                Image(systemName: action.iconName)
                    .frame(width: 20, alignment: .center)
                    .foregroundColor(.accentColor)
                    .imageScale(.small)

                Text(action.displayName)
                    .font(.system(size: 12))
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
                .frame(width: 130)

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

                Button(action: {
                    configManager.config.shortcuts[index].keyCombo = nil
                    configManager.save()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
                .opacity(configManager.config.shortcuts[index].keyCombo != nil ? 1 : 0)
                .disabled(configManager.config.shortcuts[index].keyCombo == nil)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
}
