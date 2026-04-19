// Sources/Wrangler/Engine/EngineCoordinator.swift
//
// Ties together all engine components: receives hotkey actions,
// resolves the target window, calculates the grid frame, and
// applies the move/resize. Acts as the single entry point
// for all window management operations.

import AppKit
import ApplicationServices
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

    // Overlay management
    private var overlayPanel: GridOverlayPanel?
    private let snapPreview = SnapPreviewWindow()
    private let dragDetector = DragDetector()
    private var overlayIsOpen = false
    private var overlayTriggeredManually = false
    private var capturedWindow: AXUIElement?  // Window captured before overlay opens

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

        startDragDetection(configManager: configManager)
    }

    func stop() {
        hotkeyListener.stop()
        dragDetector.stop()
        hideOverlay()
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

        // Fall back to display name if the stored displayID no longer matches
        let targetDisplayID: UInt32
        if displayDetector.displays.contains(where: { $0.id == zone.displayID }) {
            targetDisplayID = zone.displayID
        } else if let match = displayDetector.displays.first(where: { $0.name == zone.displayName }) {
            targetDisplayID = match.id
        } else {
            return // Display not found
        }

        let displayConfig = config.displays.first { $0.displayID == targetDisplayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: targetDisplayID) else { return }

        let frame = GridCalculator.calculateFrame(
            for: zone.gridPosition, in: visibleFrame,
            gridColumns: columns, gridRows: rows, gap: gap
        )
        windowManager.setWindowFrame(window, frame: frame)
    }

    /// Tile all windows of the focused app evenly within the selected grid zone.
    func batchTileWindows(in position: GridPosition, onDisplay displayID: UInt32, config: WranglerConfig) {
        let windows = windowManager.getAllWindowsOfFocusedApp()
        guard !windows.isEmpty else { return }

        let displayConfig = config.displays.first { $0.displayID == displayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: displayID) else { return }

        // Calculate the full zone frame
        let zoneFrame = GridCalculator.calculateFrame(
            for: position, in: visibleFrame,
            gridColumns: columns, gridRows: rows, gap: gap
        )

        let windowCount = windows.count
        // Calculate how to subdivide: fill columns first, then wrap to rows
        let tileCols = min(windowCount, max(1, position.columnSpan))
        let tileRows = Int(ceil(Double(windowCount) / Double(tileCols)))

        let tileWidth = zoneFrame.width / CGFloat(tileCols)
        let tileHeight = zoneFrame.height / CGFloat(tileRows)

        for (index, window) in windows.enumerated() {
            let col = index % tileCols
            let row = index / tileCols
            let frame = CGRect(
                x: zoneFrame.origin.x + CGFloat(col) * tileWidth,
                y: zoneFrame.origin.y + CGFloat(row) * tileHeight,
                width: tileWidth,
                height: tileHeight
            )
            windowManager.setWindowFrame(window, frame: frame)
        }
        wranglerLog("Wrangler: Batch-tiled \(windowCount) windows into \(tileCols)x\(tileRows) grid")
    }

    func snapFocusedWindowToPosition(_ position: GridPosition, onDisplay displayID: UInt32, config: WranglerConfig) {
        // Use the captured window if available (overlay steals AX focus), else get current
        let window: AXUIElement
        if let captured = capturedWindow {
            window = captured
        } else {
            guard case .success(let focused) = windowManager.getFocusedWindow() else { return }
            window = focused
        }

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

    func showOverlay(configManager: ConfigManager, manual: Bool = false) {
        guard !overlayIsOpen else { return }

        // Capture the focused window BEFORE showing the overlay panel,
        // because once the panel appears it may steal AX focus.
        if case .success(let window) = windowManager.getFocusedWindow() {
            capturedWindow = window
            wranglerLog("Wrangler: Captured focused window for overlay snap")
        }

        wranglerLog("Wrangler: Showing overlay (manual=\(manual))")
        let displays = displayDetector.displays
        let configs = configManager.config.displays

        if overlayPanel == nil {
            overlayPanel = GridOverlayPanel(displays: displays, configs: configs)
            overlayPanel?.overlayView.delegate = self
        } else {
            overlayPanel?.updateDisplays(displays, configs: configs)
        }

        overlayTriggeredManually = manual
        overlayPanel?.showOverlay()
        overlayIsOpen = true
    }

    func hideOverlay() {
        wranglerLog("Wrangler: Hiding overlay")
        overlayPanel?.hideOverlay()
        snapPreview.hidePreview()
        overlayIsOpen = false
        overlayTriggeredManually = false
        capturedWindow = nil
    }

    func toggleOverlay(configManager: ConfigManager) {
        if overlayIsOpen {
            hideOverlay()
        } else {
            showOverlay(configManager: configManager, manual: true)
        }
    }

    func startDragDetection(configManager: ConfigManager) {
        guard configManager.config.general.autoShowOverlay else { return }
        dragDetector.start { [weak self] isDragging in
            guard let self = self, let cm = self.configManager else { return }
            if isDragging {
                self.showOverlay(configManager: cm, manual: false)
            } else {
                // Only auto-hide if the overlay was auto-shown (not manually triggered)
                // and the mouse is NOT over the overlay panel
                if self.overlayIsOpen && !self.overlayTriggeredManually {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        guard let self = self, self.overlayIsOpen, !self.overlayTriggeredManually else { return }
                        // Don't hide if mouse is hovering over the overlay
                        if let panel = self.overlayPanel, let window = panel as NSWindow? {
                            let mouseLocation = NSEvent.mouseLocation
                            if window.frame.contains(mouseLocation) {
                                return // Mouse is over overlay, keep it open
                            }
                        }
                        self.hideOverlay()
                    }
                }
            }
        }
    }
}

// MARK: - GridOverlayViewDelegate

extension EngineCoordinator: GridOverlayViewDelegate {

    func gridOverlayView(_ view: GridOverlayView, didSelectZone position: GridPosition, onDisplay displayID: UInt32) {
        guard let config = configManager?.config else { return }
        snapFocusedWindowToPosition(position, onDisplay: displayID, config: config)
        hideOverlay()
    }

    func gridOverlayView(_ view: GridOverlayView, didBatchSelectZone position: GridPosition, onDisplay displayID: UInt32) {
        guard let config = configManager?.config else { return }
        batchTileWindows(in: position, onDisplay: displayID, config: config)
        hideOverlay()
    }

    func gridOverlayView(_ view: GridOverlayView, didRightClickZone position: GridPosition, onDisplay displayID: UInt32) {
        let displayName = displayDetector.displays.first { $0.id == displayID }?.name ?? "Unknown"
        let gridSummary = "Col \(position.column)-\(position.column + position.columnSpan - 1), Row \(position.row)-\(position.row + position.rowSpan - 1)"

        ZoneSavePopover.show(
            relativeTo: NSEvent.mouseLocation,
            displayName: displayName,
            gridSummary: gridSummary
        ) { [weak self] name, keyCombo in
            guard let self = self, let configManager = self.configManager else { return }
            let zone = CustomZone(
                name: name,
                displayID: displayID,
                displayName: displayName,
                column: position.column,
                row: position.row,
                columnSpan: position.columnSpan,
                rowSpan: position.rowSpan,
                keyCombo: keyCombo
            )
            configManager.config.customZones.append(zone)
            configManager.save()
            wranglerLog("Wrangler: Saved custom zone '\(name)' on display \(displayName)")
        }
    }

    func gridOverlayView(_ view: GridOverlayView, dragUpdated position: GridPosition, onDisplay displayID: UInt32) {
        guard let config = configManager?.config else { return }
        let displayConfig = config.displays.first { $0.displayID == displayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: displayID) else { return }

        let frame = GridCalculator.calculateFrame(
            for: position, in: visibleFrame,
            gridColumns: columns, gridRows: rows, gap: gap
        )
        snapPreview.showPreview(frame: frame)
    }

    func gridOverlayViewDragEnded(_ view: GridOverlayView) {
        snapPreview.hidePreview()
    }
}
