# Visual Grid Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a floating visual overlay panel that shows all displays with their grids, allowing click-drag zone selection to snap windows, save custom zones with shortcut bindings, and auto-show on window drag.

**Architecture:** The overlay is a non-activating `NSPanel` with a custom `NSView` that draws scaled display previews with grid lines. Mouse drag events map panel coordinates to real display grid cells. A separate transparent `NSWindow` per display shows a live preview rectangle during drag. Custom zones are persisted in config alongside predefined shortcuts using a new `HotkeyBinding` enum that wraps both `WranglerAction` and `UUID` (custom zone ID) without changing the existing WranglerAction enum.

**Tech Stack:** AppKit (NSPanel, NSView, custom drawing), CoreGraphics, Accessibility API (AXObserver for drag detection).

**Spec:** `docs/superpowers/specs/2026-04-18-grid-overlay-design.md`

---

## File Structure

```
Sources/Wrangler/
├── Models/
│   ├── CustomZone.swift             # NEW — custom zone data model
│   └── HotkeyBinding.swift          # NEW — unified binding type (predefined | customZone)
├── Engine/
│   ├── DragDetector.swift           # NEW — AXObserver for auto-show on window drag
│   └── EngineCoordinator.swift      # MODIFY — custom zone snapping, overlay management
├── Views/
│   ├── GridOverlayPanel.swift       # NEW — main overlay NSPanel
│   ├── GridOverlayView.swift        # NEW — custom NSView with display/grid drawing + mouse
│   ├── SnapPreviewWindow.swift      # NEW — per-display translucent preview rectangle
│   └── ZoneSavePopover.swift        # NEW — popover for naming/binding custom zones
├── App/
│   └── AppDelegate.swift            # MODIFY — menu item, overlay management
└── Models/
    └── WranglerConfig.swift         # MODIFY — add customZones, overlayShortcut, autoShowOverlay
```

---

### Task 1: CustomZone Data Model + Config Changes

**Files:**
- Create: `Sources/Wrangler/Models/CustomZone.swift`
- Modify: `Sources/Wrangler/Models/WranglerConfig.swift`
- Test: `Tests/WranglerTests/ConfigTests.swift`

- [ ] **Step 1: Write failing test for CustomZone serialization**

Add to `Tests/WranglerTests/ConfigTests.swift`:
```swift
func testCustomZoneRoundTrip() throws {
    let zone = CustomZone(
        name: "Left Third",
        displayID: 1,
        column: 0, row: 0,
        columnSpan: 2, rowSpan: 4,
        keyCombo: KeyCombo(keyCode: 0x12, control: true, option: true, shift: false, command: false)
    )
    let data = try JSONEncoder().encode(zone)
    let decoded = try JSONDecoder().decode(CustomZone.self, from: data)
    XCTAssertEqual(decoded.name, "Left Third")
    XCTAssertEqual(decoded.column, 0)
    XCTAssertEqual(decoded.columnSpan, 2)
    XCTAssertEqual(decoded.id, zone.id)
}

func testConfigWithCustomZonesRoundTrip() throws {
    var config = WranglerConfig()
    config.customZones = [
        CustomZone(name: "Test Zone", displayID: 1, column: 0, row: 0, columnSpan: 2, rowSpan: 2, keyCombo: nil)
    ]
    config.general.autoShowOverlay = false

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(WranglerConfig.self, from: data)
    XCTAssertEqual(decoded.customZones.count, 1)
    XCTAssertEqual(decoded.customZones[0].name, "Test Zone")
    XCTAssertFalse(decoded.general.autoShowOverlay)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/jasong/projects/personal-lasso && xcodegen generate
xcodebuild test -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```
Expected: Compilation errors — CustomZone and autoShowOverlay don't exist.

- [ ] **Step 3: Create CustomZone.swift**

```swift
// Sources/Wrangler/Models/CustomZone.swift
//
// A user-defined grid zone on a specific display. Stores the
// grid position (column, row, span) and an optional keyboard
// shortcut binding. Persisted in WranglerConfig.

import Foundation

struct CustomZone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var displayID: UInt32
    var column: Int
    var row: Int
    var columnSpan: Int
    var rowSpan: Int
    var keyCombo: KeyCombo?

    init(
        id: UUID = UUID(),
        name: String,
        displayID: UInt32,
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int,
        keyCombo: KeyCombo? = nil
    ) {
        self.id = id
        self.name = name
        self.displayID = displayID
        self.column = column
        self.row = row
        self.columnSpan = max(1, columnSpan)
        self.rowSpan = max(1, rowSpan)
        self.keyCombo = keyCombo
    }

    var gridPosition: GridPosition {
        GridPosition(column: column, row: row, columnSpan: columnSpan, rowSpan: rowSpan)
    }
}
```

- [ ] **Step 4: Modify WranglerConfig.swift**

Add `overlayShortcut`, `autoShowOverlay` to GeneralConfig and `customZones` to WranglerConfig:

In `GeneralConfig`, add after `hideMenuBarIcon`:
```swift
var overlayShortcut: KeyCombo? = KeyCombo(keyCode: 0x31, control: true, option: true, shift: false, command: false) // Ctrl+Alt+Space
var autoShowOverlay: Bool = true
```

In `WranglerConfig`, add after `shortcuts`:
```swift
var customZones: [CustomZone] = []
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/jasong/projects/personal-lasso && xcodegen generate
xcodebuild test -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|BUILD)" | tail -10
```
Expected: All tests pass including the two new ones.

- [ ] **Step 6: Commit**

```bash
git add Sources/Wrangler/Models/CustomZone.swift Sources/Wrangler/Models/WranglerConfig.swift Tests/WranglerTests/ConfigTests.swift
git commit -m "feat: add CustomZone data model and config fields for overlay"
```

---

### Task 2: HotkeyBinding Type + Listener Refactor

**Files:**
- Create: `Sources/Wrangler/Models/HotkeyBinding.swift`
- Modify: `Sources/Wrangler/Engine/HotkeyListener.swift`
- Modify: `Sources/Wrangler/Engine/EngineCoordinator.swift`

- [ ] **Step 1: Create HotkeyBinding.swift**

```swift
// Sources/Wrangler/Models/HotkeyBinding.swift
//
// Unified binding type for the hotkey listener. Wraps both
// predefined WranglerAction shortcuts and custom zone UUIDs
// so both can be registered in a single binding list.

import Foundation

enum HotkeyBinding: Equatable {
    case predefined(WranglerAction)
    case customZone(UUID)
}
```

- [ ] **Step 2: Update HotkeyListener to use HotkeyBinding**

In `HotkeyListener.swift`, change the type alias and bindings:

Replace:
```swift
typealias ActionHandler = (WranglerAction) -> Void
```
With:
```swift
typealias ActionHandler = (HotkeyBinding) -> Void
```

Replace:
```swift
private var _bindings: [(KeyCombo, WranglerAction)] = []
```
With:
```swift
private var _bindings: [(KeyCombo, HotkeyBinding)] = []
```

Replace the `updateBindings` method:
```swift
func updateBindings(shortcuts: [ActionShortcut], customZones: [CustomZone] = []) {
    var newBindings: [(KeyCombo, HotkeyBinding)] = []

    for shortcut in shortcuts {
        guard shortcut.enabled, let combo = shortcut.keyCombo else { continue }
        newBindings.append((combo, .predefined(shortcut.action)))
    }
    for zone in customZones {
        guard let combo = zone.keyCombo else { continue }
        newBindings.append((combo, .customZone(zone.id)))
    }

    bindingsLock.lock()
    _bindings = newBindings
    bindingsLock.unlock()
    wranglerLog("Wrangler: HotkeyListener has \(newBindings.count) bindings (\(shortcuts.filter { $0.enabled && $0.keyCombo != nil }.count) predefined, \(customZones.filter { $0.keyCombo != nil }.count) custom)")
}
```

Update `currentBindings` return type:
```swift
private func currentBindings() -> [(KeyCombo, HotkeyBinding)] {
```

Remove the `print` loop at the end of `updateBindings` (debug output no longer needed).

- [ ] **Step 3: Update EngineCoordinator to handle HotkeyBinding**

In `EngineCoordinator.swift`, update the `start` method:

Change the initial binding load:
```swift
hotkeyListener.updateBindings(shortcuts: configManager.config.shortcuts, customZones: configManager.config.customZones)
```

Change the Combine sink:
```swift
configCancellable = configManager.$config
    .dropFirst()
    .sink { [weak self] config in
        self?.hotkeyListener.updateBindings(shortcuts: config.shortcuts, customZones: config.customZones)
        wranglerLog("Wrangler: Updated hotkey bindings")
    }
```

Change the handler closure:
```swift
hotkeyListener.start { [weak self] binding in
    guard let self = self, let config = self.configManager?.config else { return }
    switch binding {
    case .predefined(let action):
        wranglerLog("Wrangler: Action triggered: \(action.displayName)")
        self.handleAction(action, config: config)
    case .customZone(let zoneID):
        wranglerLog("Wrangler: Custom zone triggered: \(zoneID)")
        self.snapToCustomZone(id: zoneID, config: config)
    }
}
```

Add the `snapToCustomZone` method:
```swift
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
```

Also add a public method for snapping to an arbitrary grid position (used by the overlay):
```swift
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
```

- [ ] **Step 4: Build and test**

```bash
cd /Users/jasong/projects/personal-lasso && xcodegen generate
xcodebuild test -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|BUILD)" | tail -10
```
Expected: All tests pass, BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Sources/Wrangler/Models/HotkeyBinding.swift Sources/Wrangler/Engine/HotkeyListener.swift Sources/Wrangler/Engine/EngineCoordinator.swift
git commit -m "feat: add HotkeyBinding type and custom zone snapping support"
```

---

### Task 3: Grid Overlay Panel + View

**Files:**
- Create: `Sources/Wrangler/Views/GridOverlayPanel.swift`
- Create: `Sources/Wrangler/Views/GridOverlayView.swift`

- [ ] **Step 1: Create GridOverlayPanel.swift**

```swift
// Sources/Wrangler/Views/GridOverlayPanel.swift
//
// Non-activating floating NSPanel that hosts the GridOverlayView.
// Does not steal focus from the window being snapped. Shows all
// connected displays with grid overlays for click-drag zone selection.

import AppKit

final class GridOverlayPanel: NSPanel {

    let overlayView: GridOverlayView

    init(displays: [DisplayDetector.DetectedDisplay], configs: [DisplayConfig]) {
        overlayView = GridOverlayView(displays: displays, configs: configs)

        // Calculate panel size from display arrangement
        let panelSize = GridOverlayView.calculatePanelSize(for: displays)

        super.init(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        title = ""
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = NSColor(white: 0.1, alpha: 0.95)

        contentView = overlayView
        center()
    }

    func updateDisplays(_ displays: [DisplayDetector.DetectedDisplay], configs: [DisplayConfig]) {
        overlayView.updateDisplays(displays, configs: configs)
        let panelSize = GridOverlayView.calculatePanelSize(for: displays)
        setContentSize(panelSize)
    }

    func showOverlay() {
        overlayView.clearSelection()
        makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hideOverlay() {
        orderOut(nil)
    }
}
```

- [ ] **Step 2: Create GridOverlayView.swift**

```swift
// Sources/Wrangler/Views/GridOverlayView.swift
//
// Custom NSView that draws scaled display previews with grid lines.
// Handles mouse drag to select grid zones. Maps panel coordinates
// back to real display IDs and grid positions.

import AppKit

protocol GridOverlayViewDelegate: AnyObject {
    func gridOverlayView(_ view: GridOverlayView, didSelectZone position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayView(_ view: GridOverlayView, didRightClickZone position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayView(_ view: GridOverlayView, dragUpdated position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayViewDragEnded(_ view: GridOverlayView)
}

final class GridOverlayView: NSView {

    weak var delegate: GridOverlayViewDelegate?

    private var displays: [DisplayDetector.DetectedDisplay] = []
    private var configs: [DisplayConfig] = []
    private var displayRects: [(displayID: UInt32, rect: NSRect, columns: Int, rows: Int)] = []

    // Drag state
    private var isDragging = false
    private var isRightClick = false
    private var isShiftDrag = false
    private var dragDisplayID: UInt32?
    private var dragStartCell: (col: Int, row: Int)?
    private var dragCurrentCell: (col: Int, row: Int)?

    private let padding: CGFloat = 20
    private let displayGap: CGFloat = 10

    static let maxPanelWidth: CGFloat = 800
    static let headerHeight: CGFloat = 40

    init(displays: [DisplayDetector.DetectedDisplay], configs: [DisplayConfig]) {
        super.init(frame: .zero)
        updateDisplays(displays, configs: configs)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func updateDisplays(_ displays: [DisplayDetector.DetectedDisplay], configs: [DisplayConfig]) {
        self.displays = displays
        self.configs = configs
        recalculateLayout()
        needsDisplay = true
    }

    func clearSelection() {
        isDragging = false
        dragStartCell = nil
        dragCurrentCell = nil
        dragDisplayID = nil
        needsDisplay = true
    }

    // MARK: - Layout

    static func calculatePanelSize(for displays: [DisplayDetector.DetectedDisplay]) -> NSSize {
        guard !displays.isEmpty else { return NSSize(width: 400, height: 300) }

        // Find the bounding box of all displays in real coordinates
        let allFrames = displays.map(\.frame)
        let minX = allFrames.map(\.minX).min()!
        let minY = allFrames.map(\.minY).min()!
        let maxX = allFrames.map(\.maxX).max()!
        let maxY = allFrames.map(\.maxY).max()!

        let totalWidth = maxX - minX
        let totalHeight = maxY - minY
        let aspect = totalHeight / totalWidth

        let panelWidth = min(maxPanelWidth, totalWidth * 0.3)
        let panelHeight = panelWidth * aspect + headerHeight + 40
        return NSSize(width: panelWidth + 40, height: max(panelHeight, 200))
    }

    private func recalculateLayout() {
        displayRects = []
        guard !displays.isEmpty else { return }

        let allFrames = displays.map(\.frame)
        let minX = allFrames.map(\.minX).min()!
        let minY = allFrames.map(\.minY).min()!
        let maxX = allFrames.map(\.maxX).max()!
        let maxY = allFrames.map(\.maxY).max()!

        let totalWidth = maxX - minX
        let totalHeight = maxY - minY

        let availableWidth = bounds.width - padding * 2
        let availableHeight = bounds.height - padding * 2 - Self.headerHeight
        let scale = min(availableWidth / totalWidth, availableHeight / totalHeight)

        let scaledTotalWidth = totalWidth * scale
        let scaledTotalHeight = totalHeight * scale
        let offsetX = padding + (availableWidth - scaledTotalWidth) / 2
        let offsetY = padding + (availableHeight - scaledTotalHeight) / 2

        for display in displays {
            let config = configs.first { $0.displayID == display.id }
            let columns = config?.columns ?? 4
            let rows = config?.rows ?? 4

            let rect = NSRect(
                x: offsetX + (display.frame.origin.x - minX) * scale,
                y: offsetY + (maxY - display.frame.origin.y - display.frame.height) * scale,
                width: display.frame.width * scale,
                height: display.frame.height * scale
            )
            displayRects.append((displayID: display.id, rect: rect, columns: columns, rows: rows))
        }
    }

    override func layout() {
        super.layout()
        recalculateLayout()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw header with focused app name
        let headerRect = NSRect(x: 0, y: bounds.height - Self.headerHeight, width: bounds.width, height: Self.headerHeight)
        drawHeader(in: headerRect)

        // Draw each display
        for entry in displayRects {
            drawDisplay(entry)
        }
    }

    private func drawHeader(in rect: NSRect) {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        let str = NSAttributedString(string: appName, attributes: attrs)
        let textSize = str.size()
        let point = NSPoint(x: (rect.width - textSize.width) / 2, y: rect.origin.y + (rect.height - textSize.height) / 2)
        str.draw(at: point)
    }

    private func drawDisplay(_ entry: (displayID: UInt32, rect: NSRect, columns: Int, rows: Int)) {
        let rect = entry.rect

        // Display background
        NSColor(white: 0.15, alpha: 1.0).setFill()
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        bgPath.fill()

        // Display border
        NSColor(white: 0.3, alpha: 1.0).setStroke()
        bgPath.lineWidth = 1
        bgPath.stroke()

        // Grid cells
        let cellW = rect.width / CGFloat(entry.columns)
        let cellH = rect.height / CGFloat(entry.rows)

        // Draw grid lines
        NSColor(white: 0.35, alpha: 1.0).setStroke()
        for col in 1..<entry.columns {
            let x = rect.origin.x + CGFloat(col) * cellW
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: rect.origin.y))
            path.line(to: NSPoint(x: x, y: rect.maxY))
            path.lineWidth = 0.5
            path.stroke()
        }
        for row in 1..<entry.rows {
            let y = rect.origin.y + CGFloat(row) * cellH
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.origin.x, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            path.lineWidth = 0.5
            path.stroke()
        }

        // Draw selection highlight
        if let startCell = dragStartCell, let currentCell = dragCurrentCell, dragDisplayID == entry.displayID {
            let minCol = min(startCell.col, currentCell.col)
            let maxCol = max(startCell.col, currentCell.col)
            let minRow = min(startCell.row, currentCell.row)
            let maxRow = max(startCell.row, currentCell.row)

            let selRect = NSRect(
                x: rect.origin.x + CGFloat(minCol) * cellW,
                y: rect.origin.y + CGFloat(minRow) * cellH,
                width: CGFloat(maxCol - minCol + 1) * cellW,
                height: CGFloat(maxRow - minRow + 1) * cellH
            )
            NSColor.systemBlue.withAlphaComponent(0.3).setFill()
            let selPath = NSBezierPath(roundedRect: selRect, xRadius: 2, yRadius: 2)
            selPath.fill()
            NSColor.systemBlue.withAlphaComponent(0.7).setStroke()
            selPath.lineWidth = 2
            selPath.stroke()
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isShiftDrag = event.modifierFlags.contains(.shift)
        isRightClick = false
        startDrag(at: point)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isRightClick = true
        isShiftDrag = false
        startDrag(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateDrag(at: point)
    }

    override func rightMouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateDrag(at: point)
    }

    override func mouseUp(with event: NSEvent) {
        endDrag()
    }

    override func rightMouseUp(with event: NSEvent) {
        endDrag()
    }

    private func startDrag(at point: NSPoint) {
        guard let (displayID, col, row) = hitTestGrid(point) else { return }
        isDragging = true
        dragDisplayID = displayID
        dragStartCell = (col, row)
        dragCurrentCell = (col, row)
        needsDisplay = true
    }

    private func updateDrag(at point: NSPoint) {
        guard isDragging, let displayID = dragDisplayID else { return }

        // Only update if still within the same display
        if let (hitDisplay, col, row) = hitTestGrid(point), hitDisplay == displayID {
            dragCurrentCell = (col, row)

            let position = currentGridPosition()
            if let position = position {
                delegate?.gridOverlayView(self, dragUpdated: position, onDisplay: displayID)
            }
        }
        needsDisplay = true
    }

    private func endDrag() {
        guard isDragging, let displayID = dragDisplayID, let position = currentGridPosition() else {
            clearSelection()
            return
        }

        if isRightClick || isShiftDrag {
            delegate?.gridOverlayView(self, didRightClickZone: position, onDisplay: displayID)
        } else {
            delegate?.gridOverlayView(self, didSelectZone: position, onDisplay: displayID)
        }

        delegate?.gridOverlayViewDragEnded(self)
        clearSelection()
    }

    private func currentGridPosition() -> GridPosition? {
        guard let start = dragStartCell, let current = dragCurrentCell else { return nil }
        let minCol = min(start.col, current.col)
        let maxCol = max(start.col, current.col)
        let minRow = min(start.row, current.row)
        let maxRow = max(start.row, current.row)
        return GridPosition(
            column: minCol, row: minRow,
            columnSpan: maxCol - minCol + 1,
            rowSpan: maxRow - minRow + 1
        )
    }

    private func hitTestGrid(_ point: NSPoint) -> (displayID: UInt32, col: Int, row: Int)? {
        for entry in displayRects {
            if entry.rect.contains(point) {
                let cellW = entry.rect.width / CGFloat(entry.columns)
                let cellH = entry.rect.height / CGFloat(entry.rows)
                let col = Int((point.x - entry.rect.origin.x) / cellW)
                let row = Int((point.y - entry.rect.origin.y) / cellH)
                let clampedCol = min(max(0, col), entry.columns - 1)
                let clampedRow = min(max(0, row), entry.rows - 1)
                return (entry.displayID, clampedCol, clampedRow)
            }
        }
        return nil
    }
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/jasong/projects/personal-lasso && xcodegen generate
xcodebuild build -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug 2>&1 | tail -3
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Wrangler/Views/GridOverlayPanel.swift Sources/Wrangler/Views/GridOverlayView.swift
git commit -m "feat: add grid overlay panel with display previews and drag zone selection"
```

---

### Task 4: Snap Preview Window

**Files:**
- Create: `Sources/Wrangler/Views/SnapPreviewWindow.swift`

- [ ] **Step 1: Implement SnapPreviewWindow**

```swift
// Sources/Wrangler/Views/SnapPreviewWindow.swift
//
// A transparent borderless window that shows a semi-transparent
// rectangle on the actual display during grid overlay drag.
// Provides visual feedback of exactly where the window will land.

import AppKit

final class SnapPreviewWindow: NSWindow {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        let previewView = SnapPreviewView()
        contentView = previewView
    }

    func showPreview(frame: CGRect) {
        // Convert AX coordinates (top-left origin) to NSWindow coordinates (bottom-left origin)
        guard let mainScreen = NSScreen.screens.first else { return }
        let screenHeight = mainScreen.frame.height
        let nsY = screenHeight - frame.origin.y - frame.height
        let nsFrame = NSRect(x: frame.origin.x, y: nsY, width: frame.width, height: frame.height)

        setFrame(nsFrame, display: true)
        orderFront(nil)
    }

    func hidePreview() {
        orderOut(nil)
    }
}

final class SnapPreviewView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.systemBlue.withAlphaComponent(0.2).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        path.fill()

        NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/jasong/projects/personal-lasso && xcodegen generate
xcodebuild build -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug 2>&1 | tail -3
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/Wrangler/Views/SnapPreviewWindow.swift
git commit -m "feat: add snap preview window for live feedback during grid drag"
```

---

### Task 5: Zone Save Popover

**Files:**
- Create: `Sources/Wrangler/Views/ZoneSavePopover.swift`

- [ ] **Step 1: Implement ZoneSavePopover**

```swift
// Sources/Wrangler/Views/ZoneSavePopover.swift
//
// A small floating panel for naming a custom zone and assigning
// a keyboard shortcut. Appears after right-click-drag or
// Shift+drag on the grid overlay.

import AppKit
import SwiftUI

final class ZoneSavePopover {

    typealias SaveHandler = (String, KeyCombo?) -> Void

    static func show(
        relativeTo point: NSPoint,
        displayName: String,
        gridSummary: String,
        onSave: @escaping SaveHandler
    ) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Save Custom Zone"
        panel.level = .floating
        panel.isFloatingPanel = true

        let view = ZoneSaveView(
            displayName: displayName,
            gridSummary: gridSummary,
            onSave: { name, combo in
                onSave(name, combo)
                panel.close()
            },
            onCancel: {
                panel.close()
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
}

struct ZoneSaveView: View {
    let displayName: String
    let gridSummary: String
    let onSave: (String, KeyCombo?) -> Void
    let onCancel: () -> Void

    @State private var zoneName: String = ""
    @State private var keyCombo: KeyCombo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Display:")
                    .fontWeight(.medium)
                Text(displayName)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Zone:")
                    .fontWeight(.medium)
                Text(gridSummary)
                    .foregroundColor(.secondary)
            }

            TextField("Zone name", text: $zoneName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Shortcut:")
                    .fontWeight(.medium)
                ShortcutRecorderView(keyCombo: $keyCombo)
                    .frame(width: 140)
            }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(zoneName, keyCombo) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(zoneName.isEmpty)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/jasong/projects/personal-lasso && xcodegen generate
xcodebuild build -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug 2>&1 | tail -3
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/Wrangler/Views/ZoneSavePopover.swift
git commit -m "feat: add zone save popover for naming and binding custom zones"
```

---

### Task 6: DragDetector for Auto-Show

**Files:**
- Create: `Sources/Wrangler/Engine/DragDetector.swift`

- [ ] **Step 1: Implement DragDetector**

```swift
// Sources/Wrangler/Engine/DragDetector.swift
//
// Detects when the user starts dragging a window using the
// Accessibility API observer system. Fires a callback when
// a drag is detected and when it ends, enabling auto-show
// of the grid overlay.

import ApplicationServices
import Foundation

final class DragDetector {

    typealias DragHandler = (Bool) -> Void  // true = drag started, false = drag ended

    private var observer: AXObserver?
    private var handler: DragHandler?
    private var moveCount = 0
    private var moveTimer: Timer?
    private var isTracking = false
    private let moveThreshold = 3  // Number of move events to consider it a drag

    func start(handler: @escaping DragHandler) {
        self.handler = handler
        startObserving()
    }

    func stop() {
        stopObserving()
        handler = nil
    }

    private func startObserving() {
        // Observe the frontmost app's focused window
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier

        var obs: AXObserver?
        let result = AXObserverCreate(pid, { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let detector = Unmanaged<DragDetector>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                detector.handleWindowMoved()
            }
        }, &obs)

        guard result == .success, let observer = obs else { return }
        self.observer = observer

        let appElement = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(observer, appElement, kAXMovedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(observer, appElement, kAXResizedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func stopObserving() {
        if let observer = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        moveTimer?.invalidate()
        moveTimer = nil
    }

    private func handleWindowMoved() {
        moveCount += 1

        if moveCount >= moveThreshold && !isTracking {
            isTracking = true
            handler?(true) // Drag started
        }

        // Reset the "drag ended" timer
        moveTimer?.invalidate()
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.dragEnded()
        }
    }

    private func dragEnded() {
        if isTracking {
            isTracking = false
            handler?(false) // Drag ended
        }
        moveCount = 0
    }

    /// Call when the frontmost app changes to re-register the observer
    func reobserve() {
        stopObserving()
        startObserving()
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/jasong/projects/personal-lasso && xcodegen generate
xcodebuild build -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug 2>&1 | tail -3
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/Wrangler/Engine/DragDetector.swift
git commit -m "feat: add DragDetector for auto-show overlay on window drag"
```

---

### Task 7: Integration Wiring

**Files:**
- Modify: `Sources/Wrangler/Engine/EngineCoordinator.swift`
- Modify: `Sources/Wrangler/App/AppDelegate.swift`
- Modify: `Sources/Wrangler/Views/GeneralTab.swift`

- [ ] **Step 1: Add overlay management to EngineCoordinator**

Add properties and methods to `EngineCoordinator.swift`:

```swift
// Add properties after displayDetector
private var overlayPanel: GridOverlayPanel?
private let snapPreview = SnapPreviewWindow()
private let dragDetector = DragDetector()
private var overlayIsOpen = false

// Add overlay methods
func showOverlay(configManager: ConfigManager) {
    guard !overlayIsOpen else { return }
    let displays = displayDetector.displays
    let configs = configManager.config.displays

    if overlayPanel == nil {
        overlayPanel = GridOverlayPanel(displays: displays, configs: configs)
        overlayPanel?.overlayView.delegate = self
    } else {
        overlayPanel?.updateDisplays(displays, configs: configs)
    }

    overlayPanel?.showOverlay()
    overlayIsOpen = true
}

func hideOverlay() {
    overlayPanel?.hideOverlay()
    snapPreview.hidePreview()
    overlayIsOpen = false
}

func toggleOverlay(configManager: ConfigManager) {
    if overlayIsOpen {
        hideOverlay()
    } else {
        showOverlay(configManager: configManager)
    }
}

func startDragDetection(configManager: ConfigManager) {
    guard configManager.config.general.autoShowOverlay else { return }
    dragDetector.start { [weak self] isDragging in
        guard let self = self else { return }
        if isDragging {
            self.showOverlay(configManager: configManager)
        } else {
            if self.overlayIsOpen {
                // Give user a moment to interact with the overlay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.overlayIsOpen else { return }
                    self.hideOverlay()
                }
            }
        }
    }
}
```

Also update the `start` method to start drag detection:
```swift
// Add at the end of start(configManager:)
startDragDetection(configManager: configManager)
```

Update the `stop` method:
```swift
func stop() {
    hotkeyListener.stop()
    dragDetector.stop()
    hideOverlay()
    configCancellable = nil
}
```

- [ ] **Step 2: Add GridOverlayViewDelegate conformance to EngineCoordinator**

Add at the bottom of `EngineCoordinator.swift`:

```swift
extension EngineCoordinator: GridOverlayViewDelegate {

    func gridOverlayView(_ view: GridOverlayView, didSelectZone position: GridPosition, onDisplay displayID: UInt32) {
        guard let config = configManager?.config else { return }
        snapFocusedWindowToPosition(position, onDisplay: displayID, config: config)
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
```

- [ ] **Step 3: Update AppDelegate**

Add "Show Grid Overlay" menu item and handle the overlay shortcut.

In `setupMenuBar()`, add before the "Settings..." item:
```swift
menu.addItem(withTitle: "Show Grid Overlay", action: #selector(showOverlay), keyEquivalent: "")
menu.addItem(NSMenuItem.separator())
```

Add the handler method:
```swift
@objc private func showOverlay() {
    engine.toggleOverlay(configManager: configManager)
}
```

In the `start` call in `applicationDidFinishLaunching`, also register the overlay shortcut. Add a handler in the `hotkeyListener.start` closure in EngineCoordinator — actually, simpler approach: add the overlay shortcut as a special binding.

In `EngineCoordinator.start(configManager:)`, add after the hotkey handler setup:
```swift
// Register overlay shortcut
if let overlayCombo = configManager.config.general.overlayShortcut {
    hotkeyListener.addExtraBinding(combo: overlayCombo) { [weak self] in
        guard let self = self, let cm = self.configManager else { return }
        DispatchQueue.main.async {
            self.toggleOverlay(configManager: cm)
        }
    }
}
```

Actually, the simpler approach: handle the overlay shortcut in the HotkeyBinding system. But that would require adding a new case. Instead, let's handle it directly in the HotkeyListener's callback matching — check for the overlay shortcut first:

In `EngineCoordinator.start`, modify the handler to check for overlay shortcut:
```swift
hotkeyListener.start { [weak self] binding in
    guard let self = self, let config = self.configManager?.config else { return }
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
```

This requires adding `.overlay` to `HotkeyBinding`:
```swift
enum HotkeyBinding: Equatable {
    case predefined(WranglerAction)
    case customZone(UUID)
    case overlay
}
```

And in `HotkeyListener.updateBindings`, add the overlay shortcut:
```swift
func updateBindings(shortcuts: [ActionShortcut], customZones: [CustomZone] = [], overlayShortcut: KeyCombo? = nil) {
    var newBindings: [(KeyCombo, HotkeyBinding)] = []

    if let overlayCombo = overlayShortcut {
        newBindings.append((overlayCombo, .overlay))
    }

    for shortcut in shortcuts {
        guard shortcut.enabled, let combo = shortcut.keyCombo else { continue }
        newBindings.append((combo, .predefined(shortcut.action)))
    }
    for zone in customZones {
        guard let combo = zone.keyCombo else { continue }
        newBindings.append((combo, .customZone(zone.id)))
    }

    bindingsLock.lock()
    _bindings = newBindings
    bindingsLock.unlock()
    wranglerLog("Wrangler: HotkeyListener has \(newBindings.count) bindings")
}
```

Update the calls in EngineCoordinator to pass overlayShortcut:
```swift
hotkeyListener.updateBindings(
    shortcuts: configManager.config.shortcuts,
    customZones: configManager.config.customZones,
    overlayShortcut: configManager.config.general.overlayShortcut
)
```

And in the Combine sink:
```swift
self?.hotkeyListener.updateBindings(
    shortcuts: config.shortcuts,
    customZones: config.customZones,
    overlayShortcut: config.general.overlayShortcut
)
```

- [ ] **Step 4: Update GeneralTab with overlay settings**

Add a new section in `GeneralTab.swift` after the "System" section:

```swift
Section("Grid Overlay") {
    HStack {
        Text("Overlay shortcut:")
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
}
```

- [ ] **Step 5: Build and test**

```bash
cd /Users/jasong/projects/personal-lasso && xcodegen generate
xcodebuild test -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|BUILD)" | tail -10
```
Expected: All tests pass, BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: wire grid overlay — panel, preview, drag detection, save zones, settings"
```

- [ ] **Step 7: Manual test checklist**

1. Launch Wrangler, grant accessibility permission if needed
2. Press Ctrl+Alt+Space — overlay panel should appear showing both displays with grids
3. Left-click-drag on the overlay — should highlight cells and show blue preview on actual display
4. Release — focused window should snap to the selected zone
5. Overlay stays open — try snapping another window
6. Press Esc — overlay dismisses
7. Right-click-drag on overlay — save popover should appear
8. Enter a name and optional shortcut, click Save
9. Press the saved shortcut — window should snap to that zone
10. Menu bar → "Show Grid Overlay" — should toggle overlay
11. Drag a window — overlay should auto-show (if enabled)
12. Settings > General > Grid Overlay — shortcut recorder and auto-show toggle work

---

## Summary

| Task | What It Builds | Key Files |
|------|---------------|-----------|
| 1 | CustomZone data model + config | `CustomZone.swift`, `WranglerConfig.swift` |
| 2 | HotkeyBinding refactor | `HotkeyBinding.swift`, `HotkeyListener.swift`, `EngineCoordinator.swift` |
| 3 | Overlay panel + grid view | `GridOverlayPanel.swift`, `GridOverlayView.swift` |
| 4 | Live preview window | `SnapPreviewWindow.swift` |
| 5 | Zone save popover | `ZoneSavePopover.swift` |
| 6 | Drag detector | `DragDetector.swift` |
| 7 | Integration wiring | `EngineCoordinator.swift`, `AppDelegate.swift`, `GeneralTab.swift` |
