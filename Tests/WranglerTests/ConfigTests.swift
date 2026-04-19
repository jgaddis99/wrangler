// Tests for WranglerConfig, DisplayConfig, and ActionShortcut
// JSON serialization round-trips and default values.

import XCTest
@testable import Wrangler

final class ConfigTests: XCTestCase {

    func testDefaultConfigHasAllActions() {
        let config = WranglerConfig()
        let actionCount = WranglerAction.allCases.count
        XCTAssertEqual(config.shortcuts.count, actionCount)
    }

    func testDefaultConfigHasNoDisplays() {
        let config = WranglerConfig()
        XCTAssertTrue(config.displays.isEmpty)
    }

    func testDefaultGeneralConfig() {
        let config = WranglerConfig()
        XCTAssertFalse(config.general.launchAtLogin)
        XCTAssertEqual(config.general.windowTarget, .frontMost)
        XCTAssertNil(config.general.globalShortcut)
        XCTAssertFalse(config.general.hideMenuBarIcon)
    }

    func testConfigRoundTrip() throws {
        var config = WranglerConfig()
        config.general.launchAtLogin = true
        config.general.windowTarget = .underCursor
        config.displays = [
            DisplayConfig(displayID: 1, name: "Main", columns: 6, rows: 3, gap: 5)
        ]
        config.shortcuts[0].keyCombo = KeyCombo(
            keyCode: 0x7B, control: true, option: true, shift: false, command: false
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(WranglerConfig.self, from: data)

        XCTAssertEqual(decoded.general.launchAtLogin, true)
        XCTAssertEqual(decoded.general.windowTarget, .underCursor)
        XCTAssertEqual(decoded.displays.count, 1)
        XCTAssertEqual(decoded.displays[0].name, "Main")
        XCTAssertEqual(decoded.displays[0].columns, 6)
        XCTAssertEqual(decoded.displays[0].gap, 5)
        XCTAssertEqual(decoded.shortcuts[0].keyCombo?.keyCode, 0x7B)
    }

    func testDisplayConfigDefaults() {
        let display = DisplayConfig(displayID: 42, name: "Test")
        XCTAssertEqual(display.columns, 4)
        XCTAssertEqual(display.rows, 4)
        XCTAssertEqual(display.gap, 0)
    }

    func testActionShortcutDefaultEnabled() {
        let shortcut = ActionShortcut(action: .maximize, keyCombo: nil, enabled: true)
        XCTAssertTrue(shortcut.enabled)
        XCTAssertNil(shortcut.keyCombo)
    }

    func testDefaultShortcutsHaveKeyCombos() {
        let config = WranglerConfig()
        let withCombos = config.shortcuts.filter { $0.keyCombo != nil }
        XCTAssertEqual(withCombos.count, config.shortcuts.count, "All default shortcuts should have key combos")
    }

    func testCustomZoneRoundTrip() throws {
        let zone = CustomZone(
            name: "Left Third",
            displayID: 1,
            displayName: "Main Display",
            column: 0, row: 0,
            columnSpan: 2, rowSpan: 4,
            keyCombo: KeyCombo(keyCode: 0x12, control: true, option: true, shift: false, command: false)
        )
        let data = try JSONEncoder().encode(zone)
        let decoded = try JSONDecoder().decode(CustomZone.self, from: data)
        XCTAssertEqual(decoded.name, "Left Third")
        XCTAssertEqual(decoded.displayName, "Main Display")
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

    func testCustomZoneNilKeyComboRoundTrip() throws {
        let zone = CustomZone(name: "No Shortcut", displayID: 1, column: 0, row: 0, columnSpan: 2, rowSpan: 2, keyCombo: nil)
        let data = try JSONEncoder().encode(zone)
        let decoded = try JSONDecoder().decode(CustomZone.self, from: data)
        XCTAssertNil(decoded.keyCombo)
        XCTAssertEqual(decoded.name, "No Shortcut")
    }

    func testCustomZoneSpanClamping() {
        let zone = CustomZone(name: "Test", displayID: 1, column: 0, row: 0, columnSpan: 0, rowSpan: -1, keyCombo: nil)
        XCTAssertEqual(zone.columnSpan, 1, "columnSpan should be clamped to minimum 1")
        XCTAssertEqual(zone.rowSpan, 1, "rowSpan should be clamped to minimum 1")
    }

    func testCustomZoneGridPosition() {
        let zone = CustomZone(name: "Test", displayID: 1, column: 2, row: 1, columnSpan: 3, rowSpan: 2, keyCombo: nil)
        let pos = zone.gridPosition
        XCTAssertEqual(pos.column, 2)
        XCTAssertEqual(pos.row, 1)
        XCTAssertEqual(pos.columnSpan, 3)
        XCTAssertEqual(pos.rowSpan, 2)
    }

    // MARK: - AppPin Tests

    func testAppPinRoundTrip() throws {
        let pin = AppPin(bundleID: "com.test.app", appName: "Test", displayID: 1, displayName: "Main", column: 2, row: 1, columnSpan: 2, rowSpan: 2)
        let data = try JSONEncoder().encode(pin)
        let decoded = try JSONDecoder().decode(AppPin.self, from: data)
        XCTAssertEqual(decoded.bundleID, "com.test.app")
        XCTAssertEqual(decoded.columnSpan, 2)
        XCTAssertEqual(decoded.id, pin.id)
    }

    func testAppPinSpanClamping() {
        let pin = AppPin(bundleID: "com.test", appName: "Test", displayID: 1, displayName: "Main", column: 0, row: 0, columnSpan: 0, rowSpan: -1)
        XCTAssertEqual(pin.columnSpan, 1)
        XCTAssertEqual(pin.rowSpan, 1)
    }
}
