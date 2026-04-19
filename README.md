# Wrangler

A powerful macOS window manager that snaps windows to configurable grids, tiles app windows with one click, and keeps your desktop organized across multiple displays.

Built for power users who live in terminals and need fast, keyboard-driven window management.

## Features

**Grid Snapping**
- Snap windows to halves, quarters, thirds, or any custom grid zone
- Move windows one cell at a time with directional arrow keys
- Grow/shrink windows by extending grid cells in any direction
- Cross-monitor movement — arrow keys wrap to the adjacent display at grid edges

**Visual Grid Overlay**
- Floating overlay shows all displays with desktop wallpapers and grid lines
- Click and drag to select any zone — window snaps on release
- Live preview highlights the exact area on your actual monitor
- Cmd+drag to batch-tile all windows of the focused app into a zone
- Right-click drag to save a custom zone with a keyboard shortcut

**Auto-Tile**
- One shortcut tiles every visible window on the current display into an optimal grid
- Smart layout picks the best column/row arrangement based on window count

**App Pinning**
- Pin specific apps to fixed grid zones (Slack always bottom-right, Mail always top-left)
- One shortcut resets all pinned apps to their designated positions

**Custom Zones**
- Save any grid region as a named zone with a dedicated shortcut
- Manage zones in Settings — rename, rebind, or delete

**Undo**
- Undo the last snap to restore the previous window position

## Default Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Alt+Arrow` | Move window one grid cell |
| `Ctrl+Alt+Shift+Arrow` | Grow window one cell in that direction |
| `Ctrl+Alt+U/I/J/K` | Snap to quarter (spatial 2x2 on keyboard) |
| `Ctrl+Alt+1/2/3` | Snap to left/center/right third |
| `Ctrl+Alt+Enter` | Maximize |
| `Ctrl+Alt+C` | Center |
| `Ctrl+Alt+T` | Auto-tile all windows on current display |
| `Ctrl+Alt+Z` | Undo last snap |
| `Ctrl+Alt+Space` | Open grid overlay |
| `Ctrl+Alt+R` | Reset all pinned apps |
| `Ctrl+Cmd+Left/Right` | Move window to previous/next display |

All shortcuts are fully customizable in Settings.

Shortcuts use `Ctrl+Alt` as the base modifier, which maps to the same physical keys on both Mac and Windows/PC keyboards.

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permission (required for window management)

## Building from Source

**Prerequisites:**
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

**Setup:**

```bash
# Clone
git clone https://github.com/jgaddis99/wrangler.git
cd wrangler

# Create local signing config
cat > Local.xcconfig << 'EOF'
DEVELOPMENT_TEAM = YOUR_TEAM_ID
EOF

# Build
just build
# or manually:
xcodegen generate && xcodebuild build -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug

# Run tests
just test

# Build DMG for distribution
just dmg
```

To find your team ID: `security find-identity -v -p codesigning | grep "Apple Development"`

**Note:** Accessibility permission must be granted in System Settings > Privacy & Security > Accessibility. You may need to toggle it off and back on after rebuilding.

## Support

If Wrangler saves you time, consider buying me a coffee:

[Donate via PayPal](https://paypal.me/jgaddis99)

## License

MIT
