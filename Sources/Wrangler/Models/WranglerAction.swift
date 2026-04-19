// Sources/Wrangler/Models/WranglerAction.swift
//
// Defines all window management actions available in Wrangler.
// Each action maps to a user-triggerable operation like snapping
// a window to a grid zone, centering, or moving between displays.

import Foundation

enum WranglerAction: String, Codable, CaseIterable, Identifiable {
    case snapLeft
    case snapRight
    case snapTopHalf
    case snapBottomHalf
    case snapTopLeft
    case snapTopRight
    case snapBottomLeft
    case snapBottomRight
    case snapLeftThird
    case snapCenterThird
    case snapRightThird
    case growLeft
    case growRight
    case growUp
    case growDown
    case maximize
    case center
    case nextDisplay
    case previousDisplay
    case autoTileDisplay
    case undoSnap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .snapLeft: "Snap Left"
        case .snapRight: "Snap Right"
        case .snapTopHalf: "Snap Top"
        case .snapBottomHalf: "Snap Bottom"
        case .snapTopLeft: "Snap Top Left"
        case .snapTopRight: "Snap Top Right"
        case .snapBottomLeft: "Snap Bottom Left"
        case .snapBottomRight: "Snap Bottom Right"
        case .snapLeftThird: "Left Third"
        case .snapCenterThird: "Center Third"
        case .snapRightThird: "Right Third"
        case .growLeft: "Grow Left"
        case .growRight: "Grow Right"
        case .growUp: "Grow Up"
        case .growDown: "Grow Down"
        case .maximize: "Maximize"
        case .center: "Center"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        case .autoTileDisplay: "Auto-Tile Display"
        case .undoSnap: "Undo Snap"
        }
    }

    var iconName: String {
        switch self {
        case .snapLeft: "rectangle.lefthalf.filled"
        case .snapRight: "rectangle.righthalf.filled"
        case .snapTopHalf: "rectangle.tophalf.filled"
        case .snapBottomHalf: "rectangle.bottomhalf.filled"
        case .snapTopLeft: "rectangle.topthird.inset.filled"
        case .snapTopRight: "rectangle.topthird.inset.filled"
        case .snapBottomLeft: "rectangle.bottomthird.inset.filled"
        case .snapBottomRight: "rectangle.bottomthird.inset.filled"
        case .snapLeftThird: "rectangle.leadingthird.inset.filled"
        case .snapCenterThird: "rectangle.center.inset.filled"
        case .snapRightThird: "rectangle.trailingthird.inset.filled"
        case .growLeft: "arrow.left.to.line"
        case .growRight: "arrow.right.to.line"
        case .growUp: "arrow.up.to.line"
        case .growDown: "arrow.down.to.line"
        case .maximize: "rectangle.fill"
        case .center: "rectangle.center.inset.filled"
        case .nextDisplay: "rectangle.righthalf.inset.arrow.right"
        case .previousDisplay: "rectangle.lefthalf.inset.arrow.left"
        case .autoTileDisplay: "square.grid.2x2"
        case .undoSnap: "arrow.uturn.backward"
        }
    }
}
