# Wrangler — Visual Grid Overlay

## Overview

A floating visual overlay panel that shows scaled representations of all connected displays
with their grid configurations. Users click-drag on the panel to select grid zones and snap
windows to them. A translucent preview rectangle appears on the actual display during drag
to show exactly where the window will land.

## Triggers

1. **Dedicated hotkey** — default Ctrl+Alt+Space, configurable in General settings
2. **Menu bar item** — "Show Grid Overlay" added to the Wrangler menu
3. **Auto-show on window drag** — when the user starts dragging a window, the overlay
   fades in automatically. Fades out if the drag ends without interacting with the overlay.
   Can be toggled off in General settings.

## Overlay Panel

A non-activating `NSPanel` (does not steal focus from the window being snapped) containing:

- Scaled-down preview of each connected display, arranged to match their physical layout
- Grid lines drawn over each display preview matching that display's column/row configuration
- Currently focused app name and icon shown at the top of the panel
- Solid dark fill as the display background (desktop wallpaper is a future nice-to-have)

### Interaction Modes

**Snap mode (left-click-drag):**
- Drag across grid cells to highlight a zone (can span multiple cells)
- On mouse release, the focused window snaps to the selected zone
- The next window in the app comes forward automatically
- Overlay stays open for arranging multiple windows in sequence
- Esc or clicking outside the panel dismisses it

**Save mode (right-click-drag OR Shift+left-drag):**
- Drag across grid cells to highlight a zone (same visual as snap mode)
- On mouse release, a save popover appears with:
  - Text field for zone name (e.g., "Left Third", "Coding Area")
  - Display name (read-only, auto-filled)
  - Grid position summary (e.g., "Columns 1-2, Rows 0-3")
  - Shortcut recorder button to assign a hotkey
  - Save / Cancel buttons
- Saved zones are persisted in config and registered as hotkey bindings

## Live Preview Overlay

During any drag on the panel, a translucent overlay appears on the actual target display:

- One borderless, transparent, non-activating, always-on-top `NSWindow` per display
- Shows a semi-transparent blue rectangle (20% opacity, 2px border) at the exact pixel
  frame where the window will land
- Updates in real-time as the drag crosses grid cell boundaries
- Disappears immediately on mouse release after the snap completes
- No interaction occurs on the preview window — all mouse events stay on the panel

## Auto-Show on Window Drag

Detection uses the Accessibility API observer system:

- Register `AXObserver` on the focused app for `kAXWindowMovedNotification`
- When rapid successive move notifications fire (indicating a drag), fade in the overlay
- When notifications stop (drag ended), wait 0.5 seconds:
  - If no interaction with the overlay occurred, fade it out
  - If the user interacted, keep it open in multi-snap mode

Edge cases:
- If overlay is already open from hotkey, drag detection is a no-op
- Auto-show is configurable (toggle in General settings, default: on)

## Data Model

### CustomZone (new)

```
CustomZone: Codable, Identifiable, Equatable
├── id: UUID
├── name: String
├── displayID: UInt32
├── column: Int
├── row: Int
├── columnSpan: Int
├── rowSpan: Int
└── keyCombo: KeyCombo?
```

### Config Changes

```
WranglerConfig (modified)
├── general: GeneralConfig
│   ├── ... (existing fields)
│   ├── overlayShortcut: KeyCombo?  (default: Ctrl+Alt+Space)
│   └── autoShowOverlay: Bool       (default: true)
├── displays: [DisplayConfig]
├── shortcuts: [ActionShortcut]
└── customZones: [CustomZone]        (NEW)
```

### WranglerAction Changes

Add a case for custom zones:
```
enum WranglerAction
├── ... (existing cases)
└── customZone(UUID)   — triggers a saved custom zone by ID
```

Since WranglerAction gains an associated value, it can no longer be CaseIterable with
a simple conformance. The predefined actions list must be maintained separately.

## File Changes

### New Files

| File | Purpose |
|------|---------|
| `Views/GridOverlayPanel.swift` | Main NSPanel with display previews and grid drag interaction |
| `Views/SnapPreviewWindow.swift` | Per-display translucent preview rectangle during drag |
| `Views/ZoneSavePopover.swift` | Popover for naming and binding a custom zone |
| `Models/CustomZone.swift` | CustomZone data model |
| `Engine/DragDetector.swift` | AXObserver wrapper for detecting window drags |

### Modified Files

| File | Changes |
|------|---------|
| `Models/WranglerConfig.swift` | Add `customZones`, `overlayShortcut`, `autoShowOverlay` |
| `Models/WranglerAction.swift` | Add `.customZone(UUID)` case, refactor CaseIterable |
| `Engine/EngineCoordinator.swift` | Handle custom zone snapping, wire drag detection, manage overlay |
| `Engine/HotkeyListener.swift` | Register custom zone bindings alongside predefined ones |
| `App/AppDelegate.swift` | Add "Show Grid Overlay" menu item, wire overlay hotkey |
| `Views/GeneralTab.swift` | Add overlay shortcut config and auto-show toggle |

## Out of Scope

- Desktop wallpaper as display preview background (future polish)
- Interactive grid preview in the Displays settings tab
- Drag-to-reorder saved custom zones
- Export/import of custom zone configurations
- Window animation during snap
