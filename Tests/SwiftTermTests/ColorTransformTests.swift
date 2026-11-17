#if os(macOS)
import AppKit
import Testing

@testable import SwiftTerm

@MainActor
struct ColorTransformTests {
    private func rgb(_ color: NSColor) -> [Int] {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        return [c.redComponent, c.greenComponent, c.blueComponent].map { Int(($0 * 255).rounded()) }
    }

    private func foreground(of view: TerminalView, row: Int, col: Int) -> NSColor? {
        let cell = view.terminal.buffer.lines[view.terminal.buffer.yBase + row][col]
        return view.getAttributes(cell.attribute, withUrl: false)?[.foregroundColor] as? NSColor
    }

    @Test func transformRecoloursCellsAlreadyOnScreen() {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.feed(text: "\u{1b}[38;2;255;0;0mX")
        #expect(foreground(of: view, row: 0, col: 0).map(rgb) == [255, 0, 0])

        view.colorTransform = { color, isForeground in
            guard isForeground, color.red == 0xFFFF, color.green == 0, color.blue == 0 else { return color }
            return Color(red: 0, green: 0, blue: 0xFFFF)
        }
        #expect(foreground(of: view, row: 0, col: 0).map(rgb) == [0, 0, 255])

        view.colorTransform = nil
        #expect(foreground(of: view, row: 0, col: 0).map(rgb) == [255, 0, 0])
    }

    @Test func transformSeesForegroundAndBackgroundSeparately() {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.colorTransform = { color, isForeground in
            isForeground ? Color(red: 0xFFFF, green: 0xFFFF, blue: 0xFFFF) : Color(red: 0, green: 0, blue: 0)
        }
        #expect(rgb(view.mapColor(color: .ansi256(code: 1), isFg: true, isBold: false)) == [255, 255, 255])
        #expect(rgb(view.mapColor(color: .ansi256(code: 1), isFg: false, isBold: false)) == [0, 0, 0])
    }

    @Test func identityTransformRendersTheSameColour() {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let plain = rgb(view.mapColor(color: .trueColor(red: 12, green: 34, blue: 56), isFg: true, isBold: false))
        view.colorTransform = { color, _ in color }
        #expect(rgb(view.mapColor(color: .trueColor(red: 12, green: 34, blue: 56), isFg: true, isBold: false)) == plain)
    }
}
#endif
