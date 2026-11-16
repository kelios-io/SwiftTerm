#if os(macOS)
import AppKit
import Testing

@testable import SwiftTerm

@MainActor
struct FontChangeTests {
    private func makeView() -> TerminalView {
        TerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 600),
                     font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
    }

    /// A font change must not soft-reset the program's terminal state.
    @Test func modesSurviveAFontSizeChange() {
        let view = makeView()
        let terminal = view.terminal!
        view.feed(text: "\u{1b}[?25l\u{1b}[?1h")
        #expect(terminal.cursorHidden)
        #expect(terminal.applicationCursor)
        let rows = terminal.rows

        view.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)

        #expect(terminal.rows < rows)
        #expect(terminal.cursorHidden)
        #expect(terminal.applicationCursor)
    }

    /// Scroll margins are reset by a grid resize, as in xterm, but not by a font change that keeps the grid.
    @Test func scrollMarginsSurviveAFontChangeThatKeepsTheGrid() {
        let view = makeView()
        let terminal = view.terminal!
        view.feed(text: "\u{1b}[5;10r")
        #expect(terminal.buffer.scrollTop == 4)
        #expect(terminal.buffer.scrollBottom == 9)

        view.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)

        #expect(terminal.buffer.scrollTop == 4)
        #expect(terminal.buffer.scrollBottom == 9)
    }

    /// The column count leaves room for the scroller, the same as a frame resize does.
    @Test func fontChangeMeasuresTheEffectiveWidth() {
        let view = makeView()
        view.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        let expected = Int(view.getEffectiveWidth(size: view.frame.size) / view.cellDimension.width)
        #expect(view.terminal.cols == expected)
    }
}
#endif
