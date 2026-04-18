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
}
