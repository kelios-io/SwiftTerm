#if os(macOS)
import AppKit
import Testing

@testable import SwiftTerm

/// Records what the view asks AppKit to redraw.
private final class InvalidationRecordingView: TerminalView {
    var invalidated: [NSRect] = []
    override func setNeedsDisplay(_ invalidRect: NSRect) {
        invalidated.append(invalidRect)
        super.setNeedsDisplay(invalidRect)
    }
}

@MainActor
struct ScrolledRedrawTests {
    /// A line written while the viewport is scrolled back must be invalidated where it is shown,
    /// not where it would be if the view were at the bottom.
    @Test func changedLineIsInvalidatedWhereItIsShownWhenScrolledBack() {
        let view = InvalidationRecordingView(frame: CGRect(x: 0, y: 0, width: 600, height: 400),
                                             font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
        let terminal = view.terminal!
        for i in 0..<200 { view.feed(text: "line \(i)\r\n") }
        view.updateDisplay(notifyAccessibility: false)

        view.scrollUp(lines: 2)
        #expect(terminal.buffer.yBase - terminal.buffer.yDisp == 2)

        // Park the cursor on screen row 10, flush, then type there.
        view.feed(text: "\u{1b}[11;1H")
        view.updateDisplay(notifyAccessibility: false)
        view.invalidated = []
        view.feed(text: "TYPED")
        view.updateDisplay(notifyAccessibility: false)

        let shownRow = terminal.buffer.yBase + 10 - terminal.buffer.yDisp
        let cellHeight = view.cellDimension.height
        let shownRect = NSRect(x: 0, y: view.frame.height - CGFloat(shownRow + 1) * cellHeight,
                               width: view.frame.width, height: cellHeight)
        #expect(view.invalidated.contains { $0.contains(shownRect) })
    }
}
#endif
