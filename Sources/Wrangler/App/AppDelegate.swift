// Sources/Wrangler/App/AppDelegate.swift
//
// NSApplicationDelegate that manages the menu bar status item
// and boots the engine coordinator. The menu bar provides quick
// access to window actions, settings, and quit.

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    let engine = EngineCoordinator()
    let configManager = ConfigManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        if !PermissionManager.isAccessibilityGranted {
            PermissionManager.requestWithPrompt()
        }

        engine.start(configManager: configManager)

        let hasLaunchedKey = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            // Open settings on first launch so user knows the app is running
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.openSettings()
            }
        }

        // Watch for config changes that affect menu bar visibility
        configManager.$config
            .map(\.general.hideMenuBarIcon)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.refreshMenuBar()
            }
            .store(in: &cancellables)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Keep running as a menu bar app after settings window closes
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    func setupMenuBar() {
        guard !configManager.config.general.hideMenuBarIcon else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.split.2x2",
                accessibilityDescription: "Wrangler"
            )
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Center Window", action: #selector(centerWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Maximize Window", action: #selector(maximizeWindow), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Move to Next Display", action: #selector(nextDisplay), keyEquivalent: "")
        menu.addItem(withTitle: "Move to Previous Display", action: #selector(previousDisplay), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show Grid Overlay", action: #selector(showOverlay), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())

        // Tile windows submenu — tile all windows of the frontmost app on a monitor
        let tileMenu = NSMenu()
        for display in engine.displayDetector.displays {
            let item = NSMenuItem(
                title: "Tile on \(display.name)",
                action: #selector(tileOnDisplay(_:)),
                keyEquivalent: ""
            )
            item.representedObject = display.id
            tileMenu.addItem(item)
        }
        let tileItem = NSMenuItem(title: "Tile App Windows", action: nil, keyEquivalent: "")
        tileItem.submenu = tileMenu
        menu.addItem(tileItem)
        menu.addItem(NSMenuItem.separator())

        // Reset All Pins
        if !configManager.config.appPins.isEmpty {
            menu.addItem(withTitle: "Reset All Pins", action: #selector(resetPins), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
        }

        // Custom zones submenu
        if !configManager.config.customZones.isEmpty {
            let zonesMenu = NSMenu()
            for zone in configManager.config.customZones {
                let item = NSMenuItem(title: zone.name, action: #selector(triggerCustomZone(_:)), keyEquivalent: "")
                item.representedObject = zone.id
                zonesMenu.addItem(item)
            }
            let zonesItem = NSMenuItem(title: "Custom Zones", action: nil, keyEquivalent: "")
            zonesItem.submenu = zonesMenu
            menu.addItem(zonesItem)
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Wrangler", action: #selector(quitApp), keyEquivalent: "q")

        statusItem?.menu = menu
    }

    func refreshMenuBar() {
        if configManager.config.general.hideMenuBarIcon {
            statusItem = nil
        } else if statusItem == nil {
            setupMenuBar()
        }
    }

    @objc private func centerWindow() {
        engine.handleAction(.center, config: configManager.config)
    }

    @objc private func maximizeWindow() {
        engine.handleAction(.maximize, config: configManager.config)
    }

    @objc private func nextDisplay() {
        engine.handleAction(.nextDisplay, config: configManager.config)
    }

    @objc private func previousDisplay() {
        engine.handleAction(.previousDisplay, config: configManager.config)
    }

    @objc private func showOverlay() {
        engine.toggleOverlay(configManager: configManager)
    }

    @objc private func tileOnDisplay(_ sender: NSMenuItem) {
        guard let displayID = sender.representedObject as? UInt32 else { return }
        // Get the frontmost app before Wrangler steals focus
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let displayConfig = configManager.config.displays.first { $0.displayID == displayID }
        let columns = displayConfig?.columns ?? 4
        let rows = displayConfig?.rows ?? 4
        let fullGrid = GridPosition(column: 0, row: 0, columnSpan: columns, rowSpan: rows)
        engine.batchTileWindowsForPID(frontApp.processIdentifier, in: fullGrid, onDisplay: displayID, config: configManager.config)
    }

    @objc private func triggerCustomZone(_ sender: NSMenuItem) {
        guard let zoneID = sender.representedObject as? UUID else { return }
        engine.snapToCustomZone(id: zoneID, config: configManager.config)
    }

    @objc private func resetPins() {
        engine.resetAllPins(config: configManager.config)
    }

    @objc private func openSettings() {
        NSApp.activate()
        // Find the settings window by title and bring it forward, or create it
        if let window = NSApp.windows.first(where: { $0.title == "Wrangler Settings" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Trigger SwiftUI to open the window via environment action
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            // Fallback for older macOS
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
