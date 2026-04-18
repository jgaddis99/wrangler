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

        // Watch for config changes that affect menu bar visibility
        configManager.$config
            .map(\.general.hideMenuBarIcon)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.refreshMenuBar()
            }
            .store(in: &cancellables)
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

    @objc private func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
