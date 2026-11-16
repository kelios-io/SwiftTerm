#if os(macOS)
import AppKit
import Testing

@testable import SwiftTerm

@MainActor
struct ScrollerModeTests {
    private func makeView() -> TerminalView {
        TerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 600),
                     font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
    }

    private func scroller(in view: TerminalView) -> NSScroller? {
        view.subviews.compactMap { $0 as? NSScroller }.first
    }

    @Test func defaultKeepsTheLegacyScrollerAndItsWidth() {
        let view = makeView()
        #expect(view.scrollerMode == .legacy)
        #expect(view.showsScroller)
        #expect(scroller(in: view)?.scrollerStyle == .legacy)
        #expect(view.getEffectiveWidth(size: view.frame.size) < view.frame.width)
    }

    @Test func hiddenScrollerGivesItsWidthBackToTheGrid() {
        let view = makeView()
        let legacyCols = view.terminal.cols
        view.showsScroller = false
        #expect(view.scrollerMode == .hidden)
        #expect(scroller(in: view)?.isHidden == true)
        #expect(view.getEffectiveWidth(size: view.frame.size) == view.frame.width)
        #expect(view.terminal.cols == Int(view.frame.width / view.cellDimension.width))
        #expect(view.terminal.cols >= legacyCols)
    }

    @Test func overlayScrollerReservesNoWidth() {
        let view = makeView()
        view.showsScroller = true
        #expect(view.scrollerMode == .overlay)
        #expect(scroller(in: view)?.isHidden == false)
        #expect(scroller(in: view)?.scrollerStyle == .overlay)
        #expect(view.getEffectiveWidth(size: view.frame.size) == view.frame.width)
    }
}
#endif
