# Wrangler — macOS Window Manager

## Overview

Wrangler is a native macOS window management app that replaces Lasso. It snaps windows to
configurable per-display grids via keyboard shortcuts, with a menu bar presence and a
preferences window for configuration. Built in Swift using the Accessibility API.

## Version Roadmap

- **v0.1 (MVP):** Grid snapping, display detection, hotkeys, basic settings, menu bar
- **v0.2:** Batch-tile windows by app, app-specific hotkeys, Spotlight-style picker
- **v0.3:** Workspace profiles (named layouts, one-key restore, cross-virtual-desktop)
- **v0.4:** Modifier+drag move/resize, wallpaper previews, menu bar popover, predefined sizes

---

## v0.1 MVP Design

### Architecture

Two-process model:

**Wrangler.app** (main process — SwiftUI + AppKit hybrid):
- Settings/preferences window (SwiftUI views hosted in AppKit NSWindow)
- Menu bar status item (NSStatusItem)
- Manages user configuration
- Persists settings to `~/Library/Application Support/Wrangler/config.json`

**WranglerEngine** (XPC service bundled inside the app bundle):
- Listens for global hotkeys via CGEvent taps
- Queries and manipulates windows via Accessibility API (AXUIElement)
- Detects displays via NSScreen / CGDisplay
- Performs grid math and window positioning
- Runs independently of the UI — hotkeys work even if settings window is closed

**Communication:** XPC protocol. App sends configuration updates and commands to engine.
Engine sends state back (display info, window positions).

### Display & Grid System

- Display detection via `NSScreen.screens`
- Listens for `NSApplication.didChangeScreenParametersNotification` to handle
  monitor connect/disconnect/wake
- Each display gets a `DisplayConfig`:
  - `displayID`: CGDirectDisplayID
  - `name`: Human-readable display name
  - `columns`: Grid column count (default 4)
  - `rows`: Grid row count (default 4)
  - `gap`: Pixel gap between windows (default 0)
- Grid positions are zero-indexed `(column, row)`
- Window frame calculated from display's `visibleFrame` (excludes menu bar and dock)
- Windows can span multiple grid cells (e.g., 2 columns x 1 row)

### Window Management

Uses macOS Accessibility API (AXUIElement):
- `AXUIElementCopyAttributeValue` to read window position/size
- `AXUIElementSetAttributeValue` to set position/size
- Requires Accessibility permission (System Settings > Privacy > Accessibility)
- App prompts for permission on first launch if not granted

Target window selection (configurable):
- Front-most active window (default)
- Window under mouse cursor (alternative)

### Hotkey System

Global hotkeys via CGEvent tap (`CGEventTapCreate`):
- Runs on a dedicated thread in the engine
- User-configurable key combinations per action
- Default actions for v0.1:
  - Snap window to grid position (one shortcut per position, or directional)
  - Move window to next display
  - Move window to previous display
  - Center window on current display
  - Maximize window on current display
  - Activate Wrangler (global shortcut, default Ctrl+Space)

Hotkey recording in settings UI via `NSEvent.addLocalMonitorForEvents`.

### Settings Window

Native macOS preferences window with tabs:

**General tab:**
- Launch at login toggle (via `SMAppService`)
- Window target mode: front-most vs. under cursor
- Global activation shortcut config
- Hide menu bar icon toggle

**Displays tab:**
- Auto-detected display list with names and sizes
- Per-display grid config (columns, rows steppers)
- Per-display gap/padding config
- Visual grid preview per display

**Shortcuts tab:**
- List of all actions with "Record Shortcut" buttons
- Enable/disable toggle per shortcut

### Menu Bar

- NSStatusItem with a small icon (lasso/rope motif)
- Click opens a menu with:
  - Quick actions (center, maximize, move to display)
  - Open Settings
  - Quit Wrangler
- Configurable: user can hide it

### Permissions

On first launch:
- Check for Accessibility API permission
- If not granted, show an alert explaining why it's needed with a button to open
  System Settings > Privacy & Security > Accessibility
- Engine functionality is gated on this permission

### Data Model

```
Config
├── general
│   ├── launchAtLogin: Bool
│   ├── windowTarget: .frontMost | .underCursor
│   ├── globalShortcut: KeyCombo
│   └── hideMenuBarIcon: Bool
├── displays: [DisplayConfig]
│   ├── displayID: CGDirectDisplayID
│   ├── name: String
│   ├── columns: Int
│   ├── rows: Int
│   └── gap: Int
└── shortcuts: [ActionShortcut]
    ├── action: Action enum
    ├── keyCombo: KeyCombo
    └── enabled: Bool
```

Persisted as JSON at `~/Library/Application Support/Wrangler/config.json`.

### Technology Stack

- **Language:** Swift (latest stable)
- **UI Framework:** SwiftUI for settings views, AppKit for window hosting and menu bar
- **Build System:** Xcode project / Swift Package Manager
- **Minimum macOS:** 14.0 (Sonoma) — leverages modern SwiftUI and SMAppService
- **Signing:** Developer ID for distribution, runs fine unsigned for personal use

### Project Structure

```
Wrangler/
├── Wrangler/                    # Main app target
│   ├── App/
│   │   ├── WranglerApp.swift    # App entry point
│   │   └── AppDelegate.swift    # NSApplicationDelegate for menu bar
│   ├── Views/
│   │   ├── SettingsView.swift   # Main settings window
│   │   ├── GeneralTab.swift     # General settings tab
│   │   ├── DisplaysTab.swift    # Display config tab
│   │   └── ShortcutsTab.swift   # Hotkey config tab
│   ├── Models/
│   │   ├── Config.swift         # Configuration data model
│   │   ├── DisplayConfig.swift  # Per-display grid config
│   │   └── KeyCombo.swift       # Keyboard shortcut representation
│   └── Resources/
│       └── Assets.xcassets      # App icon, menu bar icon
├── WranglerEngine/              # XPC service target
│   ├── EngineService.swift      # XPC service entry point
│   ├── WindowManager.swift      # AXUIElement window manipulation
│   ├── DisplayDetector.swift    # NSScreen monitoring
│   ├── HotkeyListener.swift     # CGEvent tap hotkey system
│   └── GridCalculator.swift     # Grid math for window positioning
├── WranglerShared/              # Shared framework
│   ├── XPCProtocol.swift        # XPC interface definition
│   └── SharedTypes.swift        # Types used by both targets
└── docs/
    └── superpowers/specs/
        └── 2026-04-17-wrangler-design.md
```

### Out of Scope for v0.1

- Batch window tiling by app
- Spotlight-style picker overlay
- Workspace profiles / saved layouts
- Cross-virtual-desktop (Spaces) management
- Modifier+drag move/resize
- Desktop wallpaper previews
- iCloud sync
- Auto-update system
- Dock position visualization
- Predefined window sizes
- Window animation (snap instantly for v0.1)
