#if os(macOS)
import AppKit
import Testing

@testable import SwiftTerm

@MainActor
struct LineHeightTests {
    private func makeView() -> TerminalView {
        TerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 600),
                     font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
    }

    @Test func defaultMultiplierKeepsTheFontMetrics() {
        let view = makeView()
        let font = view.font
        let natural = ceil(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font))
        #expect(view.cellDimension.height == natural)
        #expect(view.glyphBaselineOffset() == ceil(CTFontGetDescent(font) + CTFontGetLeading(font)))
    }

    @Test func multiplierGrowsCellsAndReducesRows() {
        let view = makeView()
        let baseHeight = view.cellDimension.height
        let baseRows = view.terminal.rows
        let baseOffset = view.glyphBaselineOffset()

        view.lineHeightMultiplier = 1.5

        #expect(view.cellDimension.height > baseHeight)
        #expect(view.terminal.rows < baseRows)
        #expect(view.caretFrame.height == view.cellDimension.height)
        // The glyph moves up by half the added space, so it stays centred in the cell.
        let extra = view.cellDimension.height - baseHeight
        #expect(abs((view.glyphBaselineOffset() - baseOffset) - extra / 2) <= 1)
    }

    @Test func resettingTheMultiplierRestoresTheGrid() {
        let view = makeView()
        let baseRows = view.terminal.rows
        view.lineHeightMultiplier = 1.4
        view.lineHeightMultiplier = 1.0
        #expect(view.terminal.rows == baseRows)
    }
}
#endif
