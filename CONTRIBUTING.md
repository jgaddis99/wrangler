# Contributing to Wrangler

Thanks for your interest in contributing. Wrangler is a macOS window manager built in Swift with SwiftUI and AppKit.

## Getting Started

1. Fork the repo and clone it
2. Create `Local.xcconfig` with your Apple Development team ID:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```
3. Run `just build` (requires [xcodegen](https://github.com/yonaskolb/XcodeGen))
4. Grant Accessibility permission in System Settings

## What We're Looking For

**Bug fixes** — if something crashes or behaves wrong, fix it and submit a PR.

**Features on the roadmap:**
- Workspace profiles (save/restore named window layouts)
- Virtual desktop (Spaces) support
- Window snap animation
- Shortcut conflict detection
- Auto-tile whitelist/blacklist (choose which apps get tiled)
- Snap-to-two-thirds layouts

**Not looking for:**
- Major architecture rewrites
- New dependencies without discussion first
- Cosmetic-only changes (unless they fix a real UX problem)

## How to Submit

1. Create a branch off `master`
2. Make your changes — keep diffs small and focused
3. Run `just test` to make sure nothing breaks
4. Open a PR with a clear description of what and why

## Code Style

- Follow existing patterns in the codebase
- Swift, SwiftUI views for settings, AppKit for the overlay and menu bar
- Type-hint everything
- No force unwraps (`!`) — use `guard let` or `if let`
- Keep files focused — one responsibility per file

## Reporting Bugs

Open an issue with:
- What you expected to happen
- What actually happened
- macOS version and display setup (number of monitors, resolution)
- Steps to reproduce

## Questions?

Open an issue. No Slack, no Discord — keep it simple.
