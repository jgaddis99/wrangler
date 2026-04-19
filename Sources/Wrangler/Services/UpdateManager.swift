// Sources/Wrangler/Services/UpdateManager.swift
//
// Manages automatic update checking via the Sparkle framework.
// Provides a controller for the Settings UI and a method to
// check for updates on demand.

import Foundation
import Sparkle

final class UpdateManager: ObservableObject {
    let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
}
