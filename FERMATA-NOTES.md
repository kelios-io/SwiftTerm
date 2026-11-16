# Fermata notes on this fork

This fork of SwiftTerm exists so Fermata can carry fixes and hooks that its Claude Code terminal sessions need. It is based on the `v1.12.0` tag, the version Fermata resolves today. Fermata's package reference is unchanged; switching to the fork is a separate decision. Line numbers below refer to `v1.12.0` and were read on 2026-11-16.

## Branches

`line-height` adds `lineHeightMultiplier` to the Mac and iOS `TerminalView`. The cell height becomes the font's natural height times the multiplier (`computeFontDimensions`, `Apple/AppleTerminalView.swift`). A new helper, `glyphBaselineOffset()`, returns the distance from the bottom of a cell to the baseline and adds half the extra space, so text stays centred. The CoreGraphics renderer, the caret (`Apple/CaretView.swift`) and both Metal call sites (`Apple/Metal/MetalTerminalRenderer.swift`) read the baseline from that one helper, because three copies of the old `ceil(descent + leading)` formula would drift apart. Box-drawing and block elements already size themselves from `cellDimension`, so they keep filling the whole cell and Claude Code's borders stay joined. Setting the property calls `resetFont()`, which recomputes the grid and resizes the PTY. `Tests/SwiftTermTests/LineHeightTests.swift` covers the default metrics, the taller grid and the reset.

`dirty-rows-when-scrolled` fixes a redraw bug that produces exactly the "typed text not painted, cursor advances" symptom. It is described below and carries a regression test that fails without the fix.

Tests run with `GITHUB_ACTIONS=true swift test`. Without that variable the package pulls in the benchmark target, which needs a system jemalloc that this machine does not have.

## The disappearing-text bug

`Terminal.updateRange` records changed rows relative to the top of the live screen (`buffer.y`, which is relative to `yBase`). `updateDisplay` in `Apple/AppleTerminalView.swift` (around line 1580 in v1.12.0) turns that range straight into a view rectangle, as if row 0 were the top of the viewport. The view draws from `yDisp` instead (`MacTerminalView.draw` passes `bufferOffset: displayBuffer.yDisp`). When the user scrolls back even one line with the wheel or trackpad, `yDisp` falls below `yBase`. The prompt stays on screen, so `ensureCaretIsVisible` does not snap back, and every keystroke invalidates a row two or three lines above the one Claude Code actually rewrote. AppKit honours partial invalidation on macOS 26 (a probe that marks one 16 point strip dirty receives exactly that strip in `draw`), so the prompt row is never repainted. The caret is a separate subview positioned from `yDisp` correctly, so it keeps moving. Any full refresh (scroll, resize, the end of a synchronized-output frame) paints the missing text.

The Metal path has the same mistake: it builds `metalDirtyRange` from `buffer.yDisp + rowStart` instead of `yBase + rowStart`.

The fix shifts the range by `yBase - yDisp` before building the rectangle and anchors the Metal range on `yBase`. It is about ten lines.

Synchronized output (DEC mode 2026) was the first suspect and does not lose rows on its own reading of the code. `beginSynchronizedOutput` (Terminal.swift around line 5448) snapshots the buffer, drawing reads the snapshot through `displayBuffer`, and `endSynchronizedOutput` calls `refresh(0, rows - 1)` and queues a display, so the next frame repaints everything. One consequence matters for the bug above: if Claude Code wraps every frame in 2026, that full refresh hides the scrolled-back bug most of the time, which fits a bug Roger has seen only twice. Claude Code 2.1.326 decides 2026 support from `TERM_PROGRAM` and a terminal query; Fermata clears `TERM_PROGRAM`, so whether it uses 2026 in Fermata depends on the query and has not been captured.

Two smaller risks in the same area. `metalDirtyRange` is overwritten, not merged, on each `updateDisplay`, so two updates before one Metal frame lose the first range (Fermata's session pane uses the CoreGraphics renderer, so this applies only to the POC window's Metal toggle). And `snapshotBuffer` copies every line including scrollback on each synchronized frame, which costs O(scrollback) per keystroke frame.

## Candidate improvements, ranked

Sizes are rough: S under 30 lines, M under 150, L larger. "Upstream" says whether the change is general enough to offer back.

1. Scrolled-back redraw fix. Done on `dirty-rows-when-scrolled`. S, low risk, upstreamable as a plain bug fix.

2. Font changes soft-reset the terminal. `resetFont()` calls `resize(cols:rows:)`, which calls `terminal.softReset()` (AppleTerminalView.swift around line 1928). Fermata's live font and size controls set `font`, so every change un-hides the cursor, clears application cursor mode, resets scroll margins and the current SGR attribute in Claude Code's session. It also sizes the grid with `frame.width` instead of `getEffectiveWidth`, so the column count is briefly wrong until the next layout. Fix: have `resetFont` call `processSizeChange(newSize:)`. S, low risk, upstreamable.

3. Overlay or hidden scroller. `scroller` is private and `scrollerStyle` is a hard-coded `.legacy` (MacTerminalView.swift lines 502 to 556), and `getEffectiveWidth` always subtracts its width. Fermata hides it and lives with the reserved strip as right padding. Make the style `.overlay` (or follow `NSScroller.preferredScrollerStyle`), stop reserving width for an overlay scroller, and expose `public var showsScroller`. Theming the knob needs a small `NSScroller` subclass. M, low risk, upstreamable.

4. Draw-time colour remapping. Today Fermata rewrites truecolor SGR bytes in `dataReceived`, so cells already on screen keep old colours after a theme switch. `mapColor` (AppleTerminalView.swift around line 222) is the single place every cell colour passes through, with `trueColors` as its cache. A `public var colorTransform: ((Attribute.Color, _ isForeground: Bool) -> TTColor?)?` consulted there, plus `resetCaches()` and a full redraw when it changes, recolours the whole scrollback at once and lets Fermata delete `TerminalRecolorer`. The Metal renderer calls the same mapping through the view. M, low to medium risk (hot path; the cache keeps it cheap), upstreamable as a generic hook.

5. Key interception hook. `keyDown` is `public override`, not `open` (MacTerminalView.swift line 903), so Fermata needs an app-wide `NSEvent` monitor for the Mac editing keys. Either make `keyDown` and `doCommand(by:)` `open`, or add `public var keyEventInterceptor: ((NSEvent) -> Bool)?` consulted first. S, low risk, upstreamable. Note that SwiftTerm 1.12 already implements the kitty keyboard protocol (`KittyKeyboardEncoder.swift`), and Claude Code 2.1.326 treats kitty keyboard as likely supported, so Shift+Enter and modified arrows may already arrive in kitty encoding. That is unverified in Fermata and worth checking before keeping the Ctrl-A style translations.

6. Notifications. OSC 777 is parsed (`Terminal.oscNotification`, Terminal.swift line 1751) and sent to `TerminalDelegate.notify`, but the Mac view does not implement that method, so the protocol extension's empty default wins and a subclass cannot override it. OSC 9 plain messages fall through to the fallback and are dropped; only OSC 9;4 progress is handled, by drawing SwiftTerm's own progress bar. Add `notify` to `TerminalViewDelegate` and forward it, and parse OSC 9 messages into the same call. This is how Fermata could surface "Claude needs you" from the terminal itself. S, low risk, upstreamable. Without a fork, `terminal.registerOscHandler(code:)` can catch 9 and 777 today, at the cost of re-implementing progress parsing for 9.

7. Inner padding. Fermata pads with an outer container whose colour must track the theme. A `public var contentInsets: NSEdgeInsets` applied in `getEffectiveWidth`, `processSizeChange`, `drawTerminalContents` (line origin), `calculateMouseHit` and `updateCursorPosition` would let the terminal paint its own padding. M, medium risk because every coordinate conversion must agree, upstreamable.

8. Line height. Done on `line-height`. S, low risk, upstreamable.

9. Bell. The default `bell` beeps (MacTerminalView.swift line 2420). Fermata can already supply a `terminalDelegate`, but `LocalProcessTerminalView` routes its own delegate methods, so check whether a visual bell or a "needs you" badge can be wired without a fork before patching. S.

10. Large redraw performance. Per row, `drawTerminalContents` builds an attributed string and CTLines on every draw, and there is no per-row cache on the CoreGraphics path. Combined with item 1's full invalidations and the per-frame scrollback copy in synchronized output, long Claude Code transcripts redraw more than needed. A row cache keyed on a line generation counter, and a snapshot that copies only the visible rows, are the two levers. L, medium risk, upstreamable but needs coordination with the maintainer's Metal work.

11. Ligatures and fallback glyphs. Glyph positions are forced to `startColumn + i * columnWidth` (AppleTerminalView.swift around line 1385), which assumes one glyph per cell. Ligatures, and fallback fonts that shape one character into several glyphs, land in the wrong columns. Nerd Font icons are drawn at the fallback font's natural size with no scaling to the cell. Proper support means mapping glyphs to cells with `CTRunGetStringIndices` and scaling oversized symbol glyphs. M to L, medium risk, upstreamable. Low priority for Claude Code, which draws few ligature-prone sequences.

12. Cursor styles and blink. `CaretView` supports bar, block and underline, steady or blinking, chosen by DECSCUSR. Claude Code mostly draws its own cursor, so little to gain beyond a public setting for blink rate. Skip unless a design asks for it.

13. OSC 8 hyperlinks already work (`oscHyperlink`, plus `linkReporting` and `requestOpenLink`). Nothing to fork for.

## What was not verified

The line-height change was verified by unit tests and the full suite (376 tests), not by looking at it in Fermata. The dirty-row fix was verified by a test that records invalidated rectangles; whether it is the exact cause of Roger's two sightings needs a reproduction (scroll back a line or two, then type in the prompt). Whether Claude Code enables synchronized output inside Fermata has not been captured.
