// Sources/Wrangler/Engine/EngineCoordinator.swift
//
// Ties together all engine components: receives hotkey actions,
// resolves the target window, calculates the grid frame, and
// applies the move/resize. Acts as the single entry point
// for all window management operations.

import AppKit
import Combine
import Foundation
import os.log

private let logger = Logger(subsystem: "com.jasong.Wrangler", category: "Engine")

final class EngineCoordinator: ObservableObject {

    private let windowManager = WindowManager()
    private let hotkeyListener = HotkeyListener()
    let displayDetector = DisplayDetector()

    private var configCancellable: AnyCancellable?
    private weak var configManager: ConfigManager?

    func start(configManager: ConfigManager) {
        self.configManager = configManager

        // Load bindings immediately before starting the listener
        hotkeyListener.updateBindings(
            shortcuts: configManager.config.shortcuts,
            customZones: configManager.config.customZones,
            overlayShortcut: configManager.config.general.overlayShortcut
        )
        let bindingCount = configManager.config.shortcuts.filter { $0.enabled && $0.keyCombo != nil }.count
        wranglerLog("Wrangler: Loaded \(bindingCount) hotkey bindings")

        configCancellable = configManager.$config
            .dropFirst() // Skip the initial value since we loaded manually above
            .sink { [weak self] config in
                self?.hotkeyListener.updateBindings(
                    shortcuts: config.shortcuts,
                    customZones: config.customZones,
                    overlayShortcut: config.general.overlayShortcut
                )
                wranglerLog("Wrangler: Updated hotkey bindings")
            }

        hotkeyListener.start { [weak self] binding in
            guard let self = self, let config = self.configManager?.config else {
                wranglerLog("Wrangler: ERROR — self or configManager is nil")
                return
            }
            switch binding {
            case .predefined(let action):
                wranglerLog("Wrangler: Action triggered: \(action.displayName)")
                self.handleAction(action, config: config)
            case .customZone(let zoneID):
                wranglerLog("Wrangler: Custom zone triggered: \(zoneID)")
                self.snapToCustomZone(id: zoneID, config: config)
            case .overlay:
                guard let cm = self.configManager else { return }
                self.toggleOverlay(configManager: cm)
            }
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

    // MARK: - Custom Zones

    func snapToCustomZone(id: UUID, config: WranglerConfig) {
        guard let zone = config.customZones.first(where: { $0.id == id }) else { return }
        guard case .success(let window) = windowManager.getFocusedWindow() else { return }

        let displayConfig = config.displays.first { $0.displayID == zone.displayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: zone.displayID) else { return }

        let frame = GridCalculator.calculateFrame(
            for: zone.gridPosition, in: visibleFrame,
            gridColumns: columns, gridRows: rows, gap: gap
        )
        windowManager.setWindowFrame(window, frame: frame)
    }

    func snapFocusedWindowToPosition(_ position: GridPosition, onDisplay displayID: UInt32, config: WranglerConfig) {
        guard case .success(let window) = windowManager.getFocusedWindow() else { return }

        let displayConfig = config.displays.first { $0.displayID == displayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: displayID) else { return }

        let frame = GridCalculator.calculateFrame(
            for: position, in: visibleFrame,
            gridColumns: columns, gridRows: rows, gap: gap
        )
        windowManager.setWindowFrame(window, frame: frame)
    }

    // MARK: - Overlay

    func toggleOverlay(configManager: ConfigManager) {
        wranglerLog("Wrangler: Overlay toggle (not yet implemented)")
    }
}
