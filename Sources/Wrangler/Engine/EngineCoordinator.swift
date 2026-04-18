// Sources/Wrangler/Engine/EngineCoordinator.swift
//
// Ties together all engine components: receives hotkey actions,
// resolves the target window, calculates the grid frame, and
// applies the move/resize. Acts as the single entry point
// for all window management operations.

import AppKit
import Combine
import Foundation

final class EngineCoordinator: ObservableObject {

    private let windowManager = WindowManager()
    private let hotkeyListener = HotkeyListener()
    let displayDetector = DisplayDetector()

    private var configCancellable: AnyCancellable?
    private weak var configManager: ConfigManager?

    func start(configManager: ConfigManager) {
        self.configManager = configManager

        configCancellable = configManager.$config
            .sink { [weak self] config in
                self?.hotkeyListener.updateBindings(shortcuts: config.shortcuts)
            }

        hotkeyListener.start { [weak self] action in
            guard let self = self, let config = self.configManager?.config else { return }
            self.handleAction(action, config: config)
        }
    }

    func stop() {
        hotkeyListener.stop()
        configCancellable = nil
    }

    func handleAction(_ action: WranglerAction, config: WranglerConfig) {
        switch action {
        case .center:
            centerFocusedWindow()
        case .nextDisplay:
            moveFocusedWindowToNextDisplay(config: config)
        case .previousDisplay:
            moveFocusedWindowToPreviousDisplay(config: config)
        default:
            snapFocusedWindow(action: action, config: config)
        }
    }

    func isTrusted() -> Bool {
        windowManager.isTrusted()
    }

    // MARK: - Private

    private func snapFocusedWindow(action: WranglerAction, config: WranglerConfig) {
        guard case .success(let window) = windowManager.getFocusedWindow() else { return }
        guard let currentDisplayID = windowManager.displayID(for: window) else { return }

        let displayConfig = config.displays.first { $0.displayID == currentDisplayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let gridPos = GridCalculator.gridPosition(
            for: action, gridColumns: columns, gridRows: rows
        ) else { return }

        guard let visibleFrame = displayDetector.visibleFrame(for: currentDisplayID) else { return }

        let frame = GridCalculator.calculateFrame(
            for: gridPos, in: visibleFrame,
            gridColumns: columns, gridRows: rows, gap: gap
        )

        windowManager.setWindowFrame(window, frame: frame)
    }

    private func centerFocusedWindow() {
        guard case .success(let window) = windowManager.getFocusedWindow() else { return }
        guard let currentDisplayID = windowManager.displayID(for: window),
              let visibleFrame = displayDetector.visibleFrame(for: currentDisplayID),
              let windowFrame = windowManager.getWindowFrame(window) else { return }

        let centered = GridCalculator.centerFrame(
            windowSize: windowFrame.size, in: visibleFrame
        )
        windowManager.setWindowFrame(window, frame: centered)
    }

    private func moveFocusedWindowToNextDisplay(config: WranglerConfig) {
        moveFocusedWindowToDisplay(config: config, next: true)
    }

    private func moveFocusedWindowToPreviousDisplay(config: WranglerConfig) {
        moveFocusedWindowToDisplay(config: config, next: false)
    }

    private func moveFocusedWindowToDisplay(config: WranglerConfig, next: Bool) {
        guard case .success(let window) = windowManager.getFocusedWindow() else { return }
        guard let currentDisplayID = windowManager.displayID(for: window) else { return }

        let targetID: UInt32?
        if next {
            targetID = displayDetector.nextDisplay(after: currentDisplayID)
        } else {
            targetID = displayDetector.previousDisplay(before: currentDisplayID)
        }
        guard let targetDisplayID = targetID,
              targetDisplayID != currentDisplayID else { return }

        guard let sourceFrame = displayDetector.visibleFrame(for: currentDisplayID),
              let targetFrame = displayDetector.visibleFrame(for: targetDisplayID),
              let windowFrame = windowManager.getWindowFrame(window) else { return }

        // Map window's relative position from source display to target display
        let relX = (windowFrame.origin.x - sourceFrame.origin.x) / sourceFrame.width
        let relY = (windowFrame.origin.y - sourceFrame.origin.y) / sourceFrame.height
        let relW = windowFrame.width / sourceFrame.width
        let relH = windowFrame.height / sourceFrame.height

        let newFrame = CGRect(
            x: targetFrame.origin.x + relX * targetFrame.width,
            y: targetFrame.origin.y + relY * targetFrame.height,
            width: relW * targetFrame.width,
            height: relH * targetFrame.height
        )

        windowManager.setWindowFrame(window, frame: newFrame)
    }
}
