#if os(macOS)
import AppKit
import Testing

@testable import SwiftTerm

private final class NotificationRecorder: TerminalViewDelegate {
    var notes: [(title: String, body: String)] = []
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func send(source: TerminalView, data: ArraySlice<UInt8>) {}
    func scrolled(source: TerminalView, position: Double) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
    func bell(source: TerminalView) {}
    func clipboardCopy(source: TerminalView, content: Data) {}
    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
    func notify(source: TerminalView, title: String, body: String) { notes.append((title, body)) }
}

private final class NotifyingLocalView: LocalProcessTerminalView {
    var bodies: [String] = []
    override func notify(source: TerminalView, title: String, body: String) { bodies.append(body) }
}

@MainActor
struct NotificationForwardingTests {
    @Test func osc777AndPlainOsc9ReachTheDelegate() {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let recorder = NotificationRecorder()
        view.terminalDelegate = recorder

        view.feed(text: "\u{1b}]777;notify;Claude Code;Needs your approval\u{07}")
        view.feed(text: "\u{1b}]9;\n\nClaude is waiting for your input\u{07}")

        #expect(recorder.notes.count == 2)
        #expect(recorder.notes.first?.title == "Claude Code")
        #expect(recorder.notes.first?.body == "Needs your approval")
        #expect(recorder.notes.last?.title == "")
        #expect(recorder.notes.last?.body == "Claude is waiting for your input")
    }

    @Test func progressAndNumberedOsc9AreNotNotifications() {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let recorder = NotificationRecorder()
        view.terminalDelegate = recorder

        view.feed(text: "\u{1b}]9;4;1;50\u{07}")
        view.feed(text: "\u{1b}]9;1;100\u{07}")

        #expect(recorder.notes.isEmpty)
    }

    @Test func localProcessSubclassCanOverrideNotify() {
        let view = NotifyingLocalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.feed(text: "\u{1b}]777;notify;t;hello\u{07}")
        #expect(view.bodies == ["hello"])
    }
}
#endif
