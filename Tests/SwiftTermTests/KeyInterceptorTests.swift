#if os(macOS)
import AppKit
import Testing

@testable import SwiftTerm

private final class SendRecorder: TerminalViewDelegate {
    var sent: [[UInt8]] = []
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func send(source: TerminalView, data: ArraySlice<UInt8>) { sent.append(Array(data)) }
    func scrolled(source: TerminalView, position: Double) {}
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
    func bell(source: TerminalView) {}
    func clipboardCopy(source: TerminalView, content: Data) {}
    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}

@MainActor
struct KeyInterceptorTests {
    private func key(_ characters: String, keyCode: UInt16, flags: NSEvent.ModifierFlags = [], window: NSWindow?) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                         windowNumber: window?.windowNumber ?? 0, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
    }

    @Test func interceptedKeysNeverReachTheProcess() {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let recorder = SendRecorder()
        view.terminalDelegate = recorder
        var seen: [UInt16] = []
        view.keyEventInterceptor = { event in
            seen.append(event.keyCode)
            return event.keyCode == 0
        }

        view.keyDown(with: key("a", keyCode: 0, window: nil))
        #expect(recorder.sent.isEmpty)

        view.keyDown(with: key("b", keyCode: 11, window: nil))
        #expect(recorder.sent.flatMap { $0 } == Array("b".utf8))
        #expect(seen == [0, 11])
    }

    @Test func commandKeysReachTheInterceptorOnlyWhenFirstResponder() {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        var calls = 0
        view.keyEventInterceptor = { _ in calls += 1; return true }
        let commandLeft = key("\u{F702}", keyCode: 123, flags: [.command], window: window)

        window.makeFirstResponder(nil)
        #expect(view.performKeyEquivalent(with: commandLeft) == false)
        #expect(calls == 0)

        window.makeFirstResponder(view)
        #expect(view.performKeyEquivalent(with: commandLeft))
        #expect(calls == 1)
    }
}
#endif

#if os(macOS)
@MainActor
struct ShiftEnterTests {
    private func shiftReturn() -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.shift], timestamp: 0,
                         windowNumber: 0, context: nil, characters: "\r",
                         charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
    }

    private func bytesForShiftReturn(after setup: String) -> [UInt8] {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let recorder = SendRecorder()
        view.terminalDelegate = recorder
        if !setup.isEmpty { view.feed(text: setup) }
        recorder.sent = []
        view.keyDown(with: shiftReturn())
        return recorder.sent.flatMap { $0 }
    }

    /// Without the kitty keyboard protocol, Shift+Return is indistinguishable from Return.
    @Test func legacyShiftReturnIsPlainCarriageReturn() {
        #expect(bytesForShiftReturn(after: "") == [0x0d])
    }

    /// With kitty "disambiguate" pushed (CSI > 1 u), Shift+Return is CSI 13 ; 2 u.
    @Test func kittyShiftReturnIsDistinct() {
        #expect(bytesForShiftReturn(after: "\u{1b}[>1u") == Array("\u{1b}[13;2u".utf8))
    }
}
#endif
