// Sources/Wrangler/Views/GridPreviewView.swift
//
// Visual preview of a display's grid layout. Draws a scaled
// representation of the display with grid lines showing the
// configured columns and rows.

import SwiftUI

struct GridPreviewView: View {
    let columns: Int
    let rows: Int
    let gap: Int
    let displaySize: CGSize

    private let previewWidth: CGFloat = 240

    var body: some View {
        let aspectRatio = displaySize.height / displaySize.width
        let previewHeight = previewWidth * aspectRatio

        Canvas { context, size in
            let gapF = CGFloat(gap) * (previewWidth / displaySize.width)
            let totalGapX = gapF * CGFloat(columns - 1)
            let totalGapY = gapF * CGFloat(rows - 1)
            let cellW = (size.width - totalGapX) / CGFloat(columns)
            let cellH = (size.height - totalGapY) / CGFloat(rows)

            for col in 0..<columns {
                for row in 0..<rows {
                    let x = CGFloat(col) * (cellW + gapF)
                    let y = CGFloat(row) * (cellH + gapF)
                    let rect = CGRect(x: x, y: y, width: cellW, height: cellH)
                    let path = Path(roundedRect: rect, cornerRadius: 2)
                    context.fill(path, with: .color(.accentColor.opacity(0.25)))
                    context.stroke(path, with: .color(.accentColor.opacity(0.7)), lineWidth: 1)
                }
            }
        }
        .frame(width: previewWidth, height: previewHeight)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
