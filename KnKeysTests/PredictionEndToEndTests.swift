import XCTest
import UIKit

/// Drives the real TextContextParser, BasicWordPredictionEngine (bundled
/// lexicon) and QwertyKeyboardView through the same orchestration the
/// KeyboardViewController performs: stale-suggestion invalidation happens
/// BEFORE every mutation, and each mutation is followed by a synchronous
/// "textDidChange" that re-schedules predictions.
private final class SimulatedKeyboardFlow {
    private(set) var document = ""
    let engine: BasicWordPredictionEngine
    let view: QwertyKeyboardView

    private var generation = 0
    private var lastContext: String?
    private var latest: (replacementCount: Int, expectedSuffix: String, generation: Int)?

    init() {
        let dictionary = LocalWordPredictionDictionary(bundle: Bundle(for: Self.self))
        engine = BasicWordPredictionEngine(dictionary: dictionary)
        let frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        view = QwertyKeyboardView(frame: frame)
        view.update(
            state: KeyboardState(),
            theme: .light,
            size: frame.size,
            returnKeyTitle: "return"
        )
    }

    /// Mirrors KeyboardViewController.handle(.character): cancel stale
    /// predictions BEFORE the mutation, then let textDidChange re-schedule.
    func type(_ text: String) {
        cancelStale()
        document.append(contentsOf: text)
        refresh()
    }

    /// Mirrors KeyboardViewController textDidChange -> schedulePredictions.
    private func refresh() {
        guard document != lastContext else { return }
        lastContext = document
        generation += 1
        guard let context = TextContextParser.parse(before: document, after: nil) else {
            latest = nil
            view.showCandidates(.hidden, animated: false)
            return
        }
        let predictions = engine.predict(for: context)
        guard !predictions.isEmpty else {
            latest = nil
            view.showCandidates(.hidden, animated: false)
            return
        }
        latest = (context.replacementCount, context.currentWord, generation)
        view.showCandidates(.predictions(predictions.map(\.word)), animated: false)
    }

    private func cancelStale() {
        generation += 1
        lastContext = nil
        latest = nil
    }

    /// Simulates the host app changing the text out-of-band (e.g. undo)
    /// before the corresponding textDidChange callback has been delivered.
    func mutateDocumentExternally(_ text: String) {
        document.append(contentsOf: text)
    }

    /// Mirrors KeyboardViewController.applyPrediction. Returns whether the tap
    /// was accepted (any rejected tap must leave the document untouched). Only
    /// words actually shown in the bar can be tapped, matching the real UI.
    @discardableResult
    func tapSuggestion(_ word: String) -> Bool {
        guard view.visibleCandidateTitles.contains(word) else { return false }
        guard let record = latest, record.generation == generation else { return false }
        let currentWord = TextContextParser.parse(before: document, after: nil)?.currentWord ?? ""
        guard currentWord == record.expectedSuffix else {
            latest = nil
            view.showCandidates(.hidden, animated: false)
            return false
        }
        for _ in 0..<record.replacementCount { document.removeLast() }
        document.append(word + " ")
        latest = nil
        view.showCandidates(.hidden, animated: false)
        refresh()
        return true
    }

    func deleteBackward() {
        cancelStale()
        if !document.isEmpty { document.removeLast() }
        refresh()
    }

    var candidates: [String] { view.visibleCandidateTitles }
}

final class PredictionEndToEndTests: XCTestCase {
    private func makeFlow() -> SimulatedKeyboardFlow { SimulatedKeyboardFlow() }

    // MARK: First word — prefix suggestions

    func testPartialFirstWordShowsPrefixSuggestions() {
        let flow = makeFlow()
        flow.type("hel")

        XCTAssertTrue(flow.candidates.contains("hello"))
        XCTAssertTrue(flow.candidates.allSatisfy { $0.hasPrefix("hel") })
        XCTAssertTrue(flow.view.suggestionBarIsVisible)
    }

    func testFullFirstWordWithoutSpaceShowsPrefixSuggestions() {
        let flow = makeFlow()
        flow.type("hello")

        XCTAssertEqual(flow.candidates.first, "hello")
    }

    // MARK: Next word — bigram suggestions after space

    func testWordPlusSpaceEnablesNextWordSuggestions() {
        let flow = makeFlow()
        flow.type("hello ")

        XCTAssertEqual(flow.candidates, ["there", "world"])
    }

    func testHowSpaceSuggestsQuestionWords() {
        let flow = makeFlow()
        flow.type("how ")

        XCTAssertTrue(flow.candidates.contains("are"))
    }

    func testThankSpaceSuggestsYou() {
        let flow = makeFlow()
        flow.type("thank ")

        XCTAssertEqual(flow.candidates.first, "you")
    }

    // MARK: Typing the second word

    func testTypingSecondWordReplacesBigramSuggestionsWithPrefix() {
        let flow = makeFlow()
        flow.type("hello ")
        XCTAssertEqual(flow.candidates, ["there", "world"])

        flow.type("w")
        XCTAssertFalse(flow.candidates.isEmpty)
        XCTAssertTrue(flow.candidates.allSatisfy { $0.hasPrefix("w") })
    }

    // MARK: Tapping suggestions

    func testTappingFirstWordSuggestionEnablesNextWordContext() {
        let flow = makeFlow()
        flow.type("hel")
        XCTAssertTrue(flow.tapSuggestion("hello"))

        XCTAssertEqual(flow.document, "hello ")
        XCTAssertEqual(flow.candidates, ["there", "world"])
    }

    func testTappingNextWordSuggestionInsertsAndContinues() {
        let flow = makeFlow()
        flow.type("hello ")
        XCTAssertTrue(flow.tapSuggestion("there"))

        XCTAssertEqual(flow.document, "hello there ")
    }

    func testStaleRecordIsRejectedWhenDocumentChangedWithoutRefresh() {
        let flow = makeFlow()
        flow.type("hel")               // bar: [hell, hello], record built for "hel"
        flow.mutateDocumentExternally("p")   // host-side change before textDidChange arrives

        XCTAssertFalse(flow.tapSuggestion("hello"))
        XCTAssertEqual(flow.document, "help")
    }

    func testStaleRecordIsRejectedWhenMoreLettersWereTyped() {
        let flow = makeFlow()
        flow.type("hel")
        flow.type("l")                 // document "hell", bar refreshed for "hell"

        XCTAssertEqual(flow.document, "hell")
        XCTAssertTrue(flow.candidates.contains("hello"), "hello is still a valid prefix completion")
        XCTAssertTrue(flow.tapSuggestion("hello"))
        XCTAssertEqual(flow.document, "hello ")
    }

    // MARK: Backspace

    func testBackspaceFromNextWordContextRevertsToPrefixSuggestions() {
        let flow = makeFlow()
        flow.type("hello ")
        XCTAssertEqual(flow.candidates, ["there", "world"])

        flow.deleteBackward()
        XCTAssertEqual(flow.document, "hello")
        XCTAssertTrue(flow.candidates.contains("hello"))
    }

    // MARK: Full sentence flow

    func testFullSentenceFlowProducesSuggestionsAtEveryPoint() {
        let flow = makeFlow()

        flow.type("hel")
        XCTAssertTrue(flow.candidates.contains("hello"))

        flow.type("lo ")
        XCTAssertEqual(flow.candidates, ["there", "world"])

        flow.type("t")
        XCTAssertTrue(flow.candidates.allSatisfy { $0.hasPrefix("t") })
        XCTAssertEqual(flow.candidates.first, "the")
    }

    // MARK: Dictionary completeness for next-word suggestions

    func testEveryBigramTargetExistsInBundledLexicon() {
        let dictionary = LocalWordPredictionDictionary(bundle: Bundle(for: Self.self))
        let triggers = ["thank", "how", "good", "see", "i", "you", "we",
                        "please", "happy", "what", "where", "when", "talk",
                        "look", "going", "back", "need", "want", "love",
                        "hello", "goodnight", "the", "this", "that", "my",
                        "your", "for", "with", "have", "will", "would",
                        "can", "should", "could", "like", "go", "come",
                        "get", "make", "take", "know", "think", "say",
                        "find", "give", "tell", "ask", "call", "why",
                        "time", "open", "close", "send", "check", "wait",
                        "start", "stop", "work", "home", "morning",
                        "night", "yes", "no", "ok", "sure", "right",
                        "really", "just", "very", "much", "more", "soon",
                        "later", "today", "tomorrow", "sorry"]
        for trigger in triggers {
            let targets = dictionary.nextWords(after: trigger, limit: 3)
            XCTAssertFalse(
                targets.isEmpty,
                "Bigram trigger \(trigger) should yield at least one suggestion"
            )
        }
    }

    func testCommonNextWordPairsResolve() {
        let flow = makeFlow()
        flow.type("thank ")
        XCTAssertEqual(flow.candidates.first, "you")

        flow.type("so ")
        XCTAssertTrue(flow.candidates.contains("much"))

        flow.type("very ")
        XCTAssertTrue(flow.candidates.contains("good"))

        flow.type("i ")
        XCTAssertTrue(flow.candidates.contains("am"))

        flow.type("can ")
        XCTAssertTrue(flow.candidates.contains("be"))

        flow.type("you ")
        XCTAssertTrue(flow.candidates.contains("are"))

        flow.type("what ")
        XCTAssertEqual(flow.candidates.first, "is")

        flow.type("good ")
        XCTAssertTrue(flow.candidates.contains("morning"))

        flow.type("happy ")
        XCTAssertTrue(flow.candidates.contains("birthday"))
    }
}