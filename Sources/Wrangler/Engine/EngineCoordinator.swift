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
    private var capturedAppPID: pid_t?        // App PID captured before overlay opens

    func start(configManager: ConfigManager) {
        self.configManager = configManager

        // Load bindings immediately before starting the listener
        hotkeyListener.updateBindings(
            shortcuts: configManager.config.shortcuts,
            customZones: configManager.config.customZones,
            overlayShortcut: configManager.config.general.overlayShortcut,
            resetPinsShortcut: configManager.config.general.resetPinsShortcut
        )
        let bindingCount = configManager.config.shortcuts.filter { $0.enabled && $0.keyCombo != nil }.count
        wranglerLog("Wrangler: Loaded \(bindingCount) hotkey bindings")

        configCancellable = configManager.$config
            .dropFirst() // Skip the initial value since we loaded manually above
            .sink { [weak self] config in
                self?.hotkeyListener.updateBindings(
                    shortcuts: config.shortcuts,
                    customZones: config.customZones,
                    overlayShortcut: config.general.overlayShortcut,
                    resetPinsShortcut: config.general.resetPinsShortcut
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
            case .resetPins:
                guard let config = self.configManager?.config else { return }
                self.resetAllPins(config: config)
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
        case .snapLeft:
            moveWindowInGrid(direction: .left, config: config)
        case .snapRight:
            moveWindowInGrid(direction: .right, config: config)
        case .snapTopHalf:
            moveWindowInGrid(direction: .up, config: config)
        case .snapBottomHalf:
            moveWindowInGrid(direction: .down, config: config)
        case .growLeft:
            growWindowInGrid(direction: .left, config: config)
        case .growRight:
            growWindowInGrid(direction: .right, config: config)
        case .growUp:
            growWindowInGrid(direction: .up, config: config)
        case .growDown:
            growWindowInGrid(direction: .down, config: config)
        case .autoTileDisplay:
            autoTileCurrentDisplay(config: config)
        default:
            snapFocusedWindow(action: action, config: config)
        }
    }

    func isTrusted() -> Bool {
        windowManager.isTrusted()
    }

    // MARK: - Private

    private enum GridDirection { case left, right, up, down }

    /// Snaps the focused window to a single grid cell and moves it directionally.
    /// First press: snaps to the nearest single cell. Subsequent presses: move one cell.
    private func moveWindowInGrid(direction: GridDirection, config: WranglerConfig) {
        guard case .success(let window) = windowManager.getFocusedWindow() else { return }
        guard let currentDisplayID = windowManager.displayID(for: window) else { return }

        let displayConfig = config.displays.first { $0.displayID == currentDisplayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: currentDisplayID),
              let windowFrame = windowManager.getWindowFrame(window) else { return }

        // Calculate cell dimensions
        let gapF = CGFloat(gap)
        let totalGapX = gapF * CGFloat(columns - 1)
        let totalGapY = gapF * CGFloat(rows - 1)
        let cellWidth = (visibleFrame.width - totalGapX) / CGFloat(columns)
        let cellHeight = (visibleFrame.height - totalGapY) / CGFloat(rows)

        // Find which cell the window currently occupies (nearest cell to window center)
        let centerX = windowFrame.origin.x + windowFrame.width / 2
        let centerY = windowFrame.origin.y + windowFrame.height / 2
        var col = Int((centerX - visibleFrame.origin.x) / (cellWidth + gapF))
        var row = Int((centerY - visibleFrame.origin.y) / (cellHeight + gapF))
        col = max(0, min(col, columns - 1))
        row = max(0, min(row, rows - 1))

        // Move one cell in the direction, crossing to adjacent monitor at edges
        var targetDisplayID = currentDisplayID
        var targetCol = col
        var targetRow = row

        switch direction {
        case .left:
            if col > 0 {
                targetCol = col - 1
            } else if let adjDisplay = displayDetector.adjacentDisplay(from: currentDisplayID, direction: .left) {
                targetDisplayID = adjDisplay
                let adjConfig = config.displays.first { $0.displayID == adjDisplay }
                targetCol = (adjConfig?.columns ?? 4) - 1
                targetRow = min(row, (adjConfig?.rows ?? 4) - 1)
            }
        case .right:
            if col < columns - 1 {
                targetCol = col + 1
            } else if let adjDisplay = displayDetector.adjacentDisplay(from: currentDisplayID, direction: .right) {
                targetDisplayID = adjDisplay
                targetCol = 0
                let adjConfig = config.displays.first { $0.displayID == adjDisplay }
                targetRow = min(row, (adjConfig?.rows ?? 4) - 1)
            }
        case .up:
            if row > 0 {
                targetRow = row - 1
            } else if let adjDisplay = displayDetector.adjacentDisplay(from: currentDisplayID, direction: .up) {
                targetDisplayID = adjDisplay
                let adjConfig = config.displays.first { $0.displayID == adjDisplay }
                targetRow = (adjConfig?.rows ?? 4) - 1
                targetCol = min(col, (adjConfig?.columns ?? 4) - 1)
            }
        case .down:
            if row < rows - 1 {
                targetRow = row + 1
            } else if let adjDisplay = displayDetector.adjacentDisplay(from: currentDisplayID, direction: .down) {
                targetDisplayID = adjDisplay
                targetRow = 0
                let adjConfig = config.displays.first { $0.displayID == adjDisplay }
                targetCol = min(col, (adjConfig?.columns ?? 4) - 1)
            }
        }

        let targetConfig = config.displays.first { $0.displayID == targetDisplayID }
        let targetColumns = targetConfig?.columns ?? 4
        let targetRows = targetConfig?.rows ?? 4
        let targetGap = targetConfig?.gap ?? 0

        guard let targetFrame = displayDetector.visibleFrame(for: targetDisplayID) else { return }

        let position = GridPosition(column: targetCol, row: targetRow, columnSpan: 1, rowSpan: 1)
        let frame = GridCalculator.calculateFrame(
            for: position, in: targetFrame,
            gridColumns: targetColumns, gridRows: targetRows, gap: targetGap
        )
        windowManager.setWindowFrame(window, frame: frame)
    }

    /// Grows the focused window by one grid cell in the specified direction.
    /// Determines the window's current grid span and extends it.
    private func growWindowInGrid(direction: GridDirection, config: WranglerConfig) {
        guard case .success(let window) = windowManager.getFocusedWindow() else { return }
        guard let currentDisplayID = windowManager.displayID(for: window) else { return }

        let displayConfig = config.displays.first { $0.displayID == currentDisplayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: currentDisplayID),
              let windowFrame = windowManager.getWindowFrame(window) else { return }

        let gapF = CGFloat(gap)
        let totalGapX = gapF * CGFloat(columns - 1)
        let totalGapY = gapF * CGFloat(rows - 1)
        let cellWidth = (visibleFrame.width - totalGapX) / CGFloat(columns)
        let cellHeight = (visibleFrame.height - totalGapY) / CGFloat(rows)

        // Determine current grid position and span from the window frame
        var col = Int(round((windowFrame.origin.x - visibleFrame.origin.x) / (cellWidth + gapF)))
        var row = Int(round((windowFrame.origin.y - visibleFrame.origin.y) / (cellHeight + gapF)))
        var colSpan = max(1, Int(round(windowFrame.width / cellWidth)))
        var rowSpan = max(1, Int(round(windowFrame.height / cellHeight)))

        col = max(0, min(col, columns - 1))
        row = max(0, min(row, rows - 1))

        // Grow in the specified direction
        switch direction {
        case .left:
            if col > 0 { col -= 1; colSpan += 1 }
        case .right:
            if col + colSpan < columns { colSpan += 1 }
        case .up:
            if row > 0 { row -= 1; rowSpan += 1 }
        case .down:
            if row + rowSpan < rows { rowSpan += 1 }
        }

        // Clamp span to grid bounds
        colSpan = min(colSpan, columns - col)
        rowSpan = min(rowSpan, rows - row)

        let position = GridPosition(column: col, row: row, columnSpan: colSpan, rowSpan: rowSpan)
        let frame = GridCalculator.calculateFrame(
            for: position, in: visibleFrame,
            gridColumns: columns, gridRows: rows, gap: gap
        )
        windowManager.setWindowFrame(window, frame: frame)
    }

    private func autoTileCurrentDisplay(config: WranglerConfig) {
        // Get the display the focused window is on
        guard case .success(let focusedWindow) = windowManager.getFocusedWindow(),
              let displayID = windowManager.displayID(for: focusedWindow) else { return }

        // Get ALL visible windows on this display from all running apps
        var allWindows: [AXUIElement] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            let windows = windowManager.getAllWindows(forPID: app.processIdentifier)
            for window in windows {
                if let wDisplayID = windowManager.displayID(for: window), wDisplayID == displayID {
                    allWindows.append(window)
                }
            }
        }
        guard !allWindows.isEmpty else { return }

        let displayConfig = config.displays.first { $0.displayID == displayID }
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: displayID) else { return }

        // Calculate optimal grid layout for N windows
        let n = allWindows.count
        let tileCols = optimalColumns(for: n)
        let tileRows = Int(ceil(Double(n) / Double(tileCols)))

        let gapF = CGFloat(gap)
        let totalGapX = gapF * CGFloat(max(0, tileCols - 1))
        let totalGapY = gapF * CGFloat(max(0, tileRows - 1))
        let tileWidth = (visibleFrame.width - totalGapX) / CGFloat(tileCols)
        let tileHeight = (visibleFrame.height - totalGapY) / CGFloat(tileRows)

        for (index, window) in allWindows.enumerated() {
            let col = index % tileCols
            let row = index / tileCols
            let frame = CGRect(
                x: visibleFrame.origin.x + CGFloat(col) * (tileWidth + gapF),
                y: visibleFrame.origin.y + CGFloat(row) * (tileHeight + gapF),
                width: tileWidth,
                height: tileHeight
            )
            windowManager.setWindowFrame(window, frame: frame)
        }
        wranglerLog("Wrangler: Auto-tiled \(n) windows in \(tileCols)x\(tileRows) grid on display \(displayID)")
    }

    /// Calculates the optimal number of columns for tiling N windows.
    private func optimalColumns(for windowCount: Int) -> Int {
        switch windowCount {
        case 1: return 1
        case 2: return 2
        case 3: return 3
        case 4: return 2
        case 5...6: return 3
        case 7...9: return 3
        case 10...12: return 4
        default: return Int(ceil(sqrt(Double(windowCount))))
        }
    }

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

    // MARK: - App Pins

    func resetAllPins(config: WranglerConfig) {
        for pin in config.appPins {
            // Find the app by bundle ID
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == pin.bundleID }) else {
                continue
            }
            let windows = windowManager.getAllWindows(forPID: app.processIdentifier)
            guard !windows.isEmpty else { continue }

            // Resolve display ID (with name fallback)
            let targetDisplayID: UInt32
            if displayDetector.displays.contains(where: { $0.id == pin.displayID }) {
                targetDisplayID = pin.displayID
            } else if let match = displayDetector.displays.first(where: { $0.name == pin.displayName }) {
                targetDisplayID = match.id
            } else {
                continue
            }

            let displayConfig = config.displays.first { $0.displayID == targetDisplayID }
            let columns = displayConfig?.columns ?? 4
            let rows = displayConfig?.rows ?? 4
            let gap = displayConfig?.gap ?? 0

            guard let visibleFrame = displayDetector.visibleFrame(for: targetDisplayID) else { continue }

            let frame = GridCalculator.calculateFrame(
                for: pin.gridPosition, in: visibleFrame,
                gridColumns: columns, gridRows: rows, gap: gap
            )

            // If multiple windows, tile them in the zone
            if windows.count == 1 {
                windowManager.setWindowFrame(windows[0], frame: frame)
            } else {
                let tileCols = min(windows.count, max(1, pin.columnSpan))
                let tileRows = Int(ceil(Double(windows.count) / Double(tileCols)))
                let tileWidth = frame.width / CGFloat(tileCols)
                let tileHeight = frame.height / CGFloat(tileRows)
                for (index, window) in windows.enumerated() {
                    let col = index % tileCols
                    let row = index / tileCols
                    let f = CGRect(
                        x: frame.origin.x + CGFloat(col) * tileWidth,
                        y: frame.origin.y + CGFloat(row) * tileHeight,
                        width: tileWidth,
                        height: tileHeight
                    )
                    windowManager.setWindowFrame(window, frame: f)
                }
            }
            wranglerLog("Wrangler: Reset pin '\(pin.appName)' to \(pin.column),\(pin.row)")
        }
        wranglerLog("Wrangler: Reset all pins (\(config.appPins.count) pins)")
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

    /// Tile all windows of the captured app evenly within the selected grid zone.
    func batchTileWindows(in position: GridPosition, onDisplay displayID: UInt32, config: WranglerConfig) {
        guard let pid = capturedAppPID else {
            wranglerLog("Wrangler: No captured app PID for batch tile")
            return
        }
        let windows = windowManager.getAllWindows(forPID: pid)
        guard !windows.isEmpty else {
            wranglerLog("Wrangler: No windows found for PID \(pid)")
            return
        }

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

    /// Tile all windows of a specific app PID into a grid zone. Used by menu bar.
    func batchTileWindowsForPID(_ pid: pid_t, in position: GridPosition, onDisplay displayID: UInt32, config: WranglerConfig) {
        let windows = windowManager.getAllWindows(forPID: pid)
        guard !windows.isEmpty else { return }

        let displayConfig = config.displays.first { $0.displayID == displayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let gap = displayConfig?.gap ?? 0

        guard let visibleFrame = displayDetector.visibleFrame(for: displayID) else { return }

        let zoneFrame = GridCalculator.calculateFrame(
            for: position, in: visibleFrame,
            gridColumns: columns, gridRows: rows, gap: gap
        )

        let windowCount = windows.count
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
        wranglerLog("Wrangler: Menu batch-tiled \(windowCount) windows for PID \(pid)")
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

        // Capture the focused window and app BEFORE showing the overlay panel,
        // because once the panel appears it may steal AX focus.
        if case .success(let window) = windowManager.getFocusedWindow() {
            capturedWindow = window
        }
        capturedAppPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        wranglerLog("Wrangler: Captured window and app PID=\(capturedAppPID ?? -1) for overlay")

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
        capturedAppPID = nil
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
        snapPreview.showPreview(frame: frame, style: .zoneFill)
    }

    func gridOverlayView(_ view: GridOverlayView, hoveredDisplay displayID: UInt32?) {
        if let displayID = displayID {
            // Show a glowing border rim around the actual physical monitor
            guard let visibleFrame = displayDetector.visibleFrame(for: displayID) else { return }
            snapPreview.showPreview(frame: visibleFrame, style: .monitorRim)
        } else {
            snapPreview.hidePreview()
        }
    }

    func gridOverlayViewDragEnded(_ view: GridOverlayView) {
        snapPreview.hidePreview()
    }
}
