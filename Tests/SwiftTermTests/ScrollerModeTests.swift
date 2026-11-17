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

    @Test func slimScrollerReservesItsStripAndDrawsNoTrack() {
        let view = makeView()
        let legacyReserved = view.scrollerReservedWidth
        view.showsScroller = true
        #expect(view.scrollerMode == .slim)
        #expect(TerminalView.slimScrollerWidth == 10)
        #expect(view.scrollerReservedWidth == 10)
        #expect(view.scrollerReservedWidth < legacyReserved)
        #expect(view.getEffectiveWidth(size: view.frame.size) == view.frame.width - 10)
        let scroller = scroller(in: view) as? TerminalScroller
        #expect(scroller?.isSlim == true)
        #expect(scroller?.isHidden == false)
        #expect(view.terminal.cols == Int((view.frame.width - 10) / view.cellDimension.width))
    }

    @Test func reservedWidthFollowsTheMode() {
        let view = makeView()
        #expect(view.scrollerReservedWidth > 10)
        view.scrollerMode = .hidden
        #expect(view.scrollerReservedWidth == 0)
        view.scrollerMode = .slim
        #expect(view.scrollerReservedWidth == 10)
    }

    @Test func slimKnobIsHiddenWithNothingToScrollAndWhileOutputStaysAtTheBottom() {
        let view = makeView()
        view.scrollerMode = .slim
        #expect(!view.slimScrollerVisible)
        for i in 0..<200 { view.feed(text: "line \(i)\r\n") }
        #expect(view.canScroll)
        #expect(!view.slimScrollerVisible)
    }

    @Test func slimKnobShowsOnScrollAndFadesAfterADelay() async throws {
        let view = makeView()
        view.scrollerMode = .slim
        for i in 0..<200 { view.feed(text: "line \(i)\r\n") }

        view.scrollUp(lines: 3)
        #expect(view.slimScrollerVisible)

        try await Task.sleep(for: .seconds(TerminalView.slimScrollerFadeDelay + 0.3))
        #expect(!view.slimScrollerVisible)

        // Output arriving while scrolled back snaps the view to the bottom, which is a scroll too.
        view.scrollUp(lines: 3)
        try await Task.sleep(for: .seconds(TerminalView.slimScrollerFadeDelay + 0.3))
        #expect(!view.slimScrollerVisible)
        view.feed(text: "more\r\n")
        #expect(view.slimScrollerVisible)
    }

    @Test func slimKnobCanBeGrabbed() throws {
        let view = makeView()
        view.scrollerMode = .slim
        for i in 0..<200 { view.feed(text: "line \(i)\r\n") }
        view.scrollUp(lines: 50)
        view.layoutSubtreeIfNeeded()
        let found = scroller(in: view)
        let scroller = try #require(found)
        #expect(scroller.frame.width == 10)
        let knob = scroller.rect(for: .knob)
        #expect(knob.height > 0)
        let hit = scroller.convert(NSPoint(x: knob.midX, y: knob.midY), to: scroller.superview)
        #expect(scroller.testPart(hit) == .knob)

        // Only the knob is painted: no track, no border, the terminal background shows through.
        scroller.alphaValue = 1
        let rep = try #require(scroller.bitmapImageRepForCachingDisplay(in: scroller.bounds))
        scroller.cacheDisplay(in: scroller.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / scroller.bounds.width
        func alpha(at point: NSPoint) -> CGFloat {
            // Bitmap rows run top-down; the scroller is flipped like all NSScrollers.
            let y = scroller.isFlipped ? point.y : scroller.bounds.height - point.y
            return rep.colorAt(x: Int(point.x * scale), y: Int(y * scale))?.alphaComponent ?? 0
        }
        #expect(alpha(at: NSPoint(x: scroller.bounds.midX, y: knob.midY)) > 0)
        let outside = knob.maxY + 20 < scroller.bounds.height
            ? NSPoint(x: scroller.bounds.midX, y: knob.maxY + 20) : NSPoint(x: scroller.bounds.midX, y: max(0, knob.minY - 20))
        #expect(alpha(at: outside) == 0)
        #expect(alpha(at: NSPoint(x: 0.5, y: knob.midY)) == 0)
    }

    @Test func knobColourDefaultsToDimForegroundAndCanBeOverridden() {
        let view = makeView()
        view.scrollerMode = .slim
        view.nativeForegroundColor = .white
        let scroller = scroller(in: view) as? TerminalScroller
        #expect(scroller?.knobColor().alphaComponent == 0.3)
        view.scrollerKnobColor = .red
        #expect(scroller?.knobColor() == .red)
    }
}
#endif
