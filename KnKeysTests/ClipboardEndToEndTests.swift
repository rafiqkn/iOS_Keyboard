import XCTest

/// End-to-end coverage for the clipboard pipeline:
/// copy (pasteboard snapshot) → sweep → shared store → panel render →
/// row tap → text insertion action.
final class ClipboardEndToEndTests: XCTestCase {
    private var store: ClipboardHistoryStore!
    private var recorder: ClipboardDelegateRecorder!

    override func setUp() {
        super.setUp()
        store = ClipboardHistoryStore(defaults: UserDefaults(suiteName: "clipboard.e2e.store"))
        store.clear()
        recorder = ClipboardDelegateRecorder()
        ClipboardPasteboardSync.resetObservation()
    }

    override func tearDown() {
        store.clear()
        store = nil
        recorder = nil
        ClipboardPasteboardSync.resetObservation()
        super.tearDown()
    }

    private func makePanel() -> ClipboardKeyboardView {
        let view = ClipboardKeyboardView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 294),
            store: store
        )
        view.delegate = recorder
        return view
    }

    // MARK: - copy → sweep → store

    func testCopyInAnotherAppLandsInHistoryOnNextSweep() {
        ClipboardPasteboardSync.sweep(.init(changeCount: 7, text: "shared link"), store: store)

        XCTAssertEqual(store.load().map(\.text), ["shared link"])
    }

    func testSweepIgnoresUnchangedPasteboard() {
        ClipboardPasteboardSync.sweep(.init(changeCount: 3, text: "once"), store: store)
        ClipboardPasteboardSync.sweep(.init(changeCount: 3, text: "once"), store: store)

        XCTAssertEqual(store.load().count, 1, "same changeCount must not re-add")
    }

    func testSweepSkipsUnreadablePasteboardWithoutFullAccess() {
        ClipboardPasteboardSync.sweep(.init(changeCount: 9, text: nil), store: store)

        XCTAssertTrue(store.load().isEmpty)
    }

    func testSweepIgnoresWhitespaceOnlyClipboard() {
        ClipboardPasteboardSync.sweep(.init(changeCount: 2, text: "   \n\t "), store: store)

        XCTAssertTrue(store.load().isEmpty)
    }

    func testSweepTrimsAndDedupesRecopiedText() {
        ClipboardPasteboardSync.sweep(.init(changeCount: 1, text: "  hello  "), store: store)
        ClipboardPasteboardSync.sweep(.init(changeCount: 2, text: "second"), store: store)
        ClipboardPasteboardSync.sweep(.init(changeCount: 3, text: "hello"), store: store)

        XCTAssertEqual(store.load().map(\.text), ["hello", "second"], "re-copy moves to front, no duplicate")
    }

    func testTwentyFifthAndTwentySixthCopiesKeepFifoWindow() {
        for index in 1...26 {
            ClipboardPasteboardSync.sweep(.init(changeCount: index, text: "item \(index)"), store: store)
        }

        let texts = store.load().map(\.text)
        XCTAssertEqual(texts.count, ClipboardHistoryKeys.maxRecords)
        XCTAssertEqual(texts.first, "item 26")
        XCTAssertEqual(texts.last, "item 2", "oldest record evicted FIFO")
    }

    // MARK: - store → panel

    func testPanelShowsEmptyStateBeforeAnythingIsCopied() {
        let panel = makePanel()
        panel.reloadHistory()

        XCTAssertTrue(panel.isShowingEmptyState)
        XCTAssertTrue(panel.visibleItemTexts.isEmpty)
    }

    func testPanelRendersCapturedClipboardNewestFirst() {
        ClipboardPasteboardSync.sweep(.init(changeCount: 1, text: "first copy"), store: store)
        ClipboardPasteboardSync.sweep(.init(changeCount: 2, text: "second copy"), store: store)

        let panel = makePanel()
        panel.reloadHistory()

        XCTAssertFalse(panel.isShowingEmptyState)
        XCTAssertEqual(panel.visibleItemTexts, ["second copy", "first copy"])
    }

    // MARK: - panel → insertion

    func testTappingHistoryRowRequestsInsertionOfThatText() {
        ClipboardPasteboardSync.sweep(.init(changeCount: 1, text: "old note"), store: store)
        ClipboardPasteboardSync.sweep(.init(changeCount: 2, text: "fresh note"), store: store)
        let panel = makePanel()
        panel.reloadHistory()

        panel.simulateSelection(at: 1)

        XCTAssertEqual(recorder.actions, [.character("old note")])
    }

    func testKeyboardButtonReturnsToTextKeyboard() {
        let panel = makePanel()
        panel.reloadHistory()

        panel.perform(NSSelectorFromString("keyboardButtonTapped"))

        XCTAssertEqual(recorder.textKeyboardRequests, 1)
    }

    // MARK: - full round trip

    func testFullRoundTripFromCopyToInsertedText() {
        // 1. user copies in another app, 2. keyboard appears and sweeps
        ClipboardPasteboardSync.sweep(.init(changeCount: 42, text: "one-time code 8891"), store: store)

        // 3. user opens the clipboard panel
        let panel = makePanel()
        panel.reloadHistory()
        XCTAssertEqual(panel.visibleItemTexts, ["one-time code 8891"])

        // 4. user taps the record
        panel.simulateSelection(at: 0)

        // 5. keyboard inserts exactly the stored text
        XCTAssertEqual(recorder.actions, [.character("one-time code 8891")])

        // 6. history is unchanged by insertion (still available for reuse)
        XCTAssertEqual(store.load().map(\.text), ["one-time code 8891"])
    }

    func testPasteBarButtonTargetsNewestRecord() {
        ClipboardPasteboardSync.sweep(.init(changeCount: 1, text: "older"), store: store)
        ClipboardPasteboardSync.sweep(.init(changeCount: 2, text: "newest"), store: store)

        // The suggestion-bar paste button inserts store.load().first
        XCTAssertEqual(store.load().first?.text, "newest")
    }
}

private final class ClipboardDelegateRecorder: ClipboardKeyboardViewDelegate {
    var actions: [KeyboardKeyAction] = []
    var textKeyboardRequests = 0

    func clipboardKeyboardView(_ view: ClipboardKeyboardView, didTrigger action: KeyboardKeyAction) {
        actions.append(action)
    }

    func clipboardKeyboardViewRequestedTextKeyboard(_ view: ClipboardKeyboardView) {
        textKeyboardRequests += 1
    }
}