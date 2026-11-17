//
//  MacTerminalScroller.swift
//
#if os(macOS)
import AppKit

/// The terminal's vertical scroller. In the legacy mode it is a plain `NSScroller`. In the slim
/// mode it draws only a rounded knob, with no track or border, so the terminal's own background
/// shows through, and it reports hover so the view can reveal the knob.
final class TerminalScroller: NSScroller {
    var isSlim = false {
        didSet { needsDisplay = true }
    }
    /// Asked at draw time, so a change of theme colour shows on the next draw.
    var knobColor: () -> NSColor = { NSColor.secondaryLabelColor }
    var onHoverChanged: ((Bool) -> Void)?
    var onTrackingFinished: (() -> Void)?
    private var hoverArea: NSTrackingArea?

    override var isOpaque: Bool { isSlim ? false : super.isOpaque }

    override func draw(_ dirtyRect: NSRect) {
        guard isSlim else {
            super.draw(dirtyRect)
            return
        }
        guard isEnabled else { return }
        let knob = rect(for: .knob)
        guard knob.height > 0 else { return }
        let width = min(5, bounds.width)
        let slim = NSRect(x: bounds.midX - width / 2, y: knob.minY + 2, width: width, height: max(width, knob.height - 4))
        knobColor().setFill()
        NSBezierPath(roundedRect: slim, xRadius: width / 2, yRadius: width / 2).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        onHoverChanged?(true)
        // NSScroller tracks the drag inside mouseDown and returns when the button comes up.
        super.mouseDown(with: event)
        onTrackingFinished?()
    }
}
#endif
