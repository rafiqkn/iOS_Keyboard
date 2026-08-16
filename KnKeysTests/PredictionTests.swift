import XCTest
import UIKit

final class TextContextParserTests: XCTestCase {
    func testParsesPartialWordAndPreviousWord() {
        let context = TextContextParser.parse(before: "please hel", after: "!")

        XCTAssertEqual(context?.currentWord, "hel")
        XCTAssertEqual(context?.previousWord, "please")
        XCTAssertEqual(context?.replacementCount, 3)
        XCTAssertEqual(context?.textAfterCursor, "!")
    }

    func testParsesNextWordContextAfterSpace() {
        let context = TextContextParser.parse(before: "hello ", after: nil)

        XCTAssertEqual(context?.currentWord, "")
        XCTAssertEqual(context?.previousWord, "hello")
        XCTAssertEqual(context?.replacementCount, 0)
    }

    func testHandlesPunctuationAndSentenceCapitalization() {
        let context = TextContextParser.parse(before: "Hello. wor", after: nil)

        XCTAssertEqual(context?.currentWord, "wor")
        XCTAssertFalse(context?.shouldCapitalize == true)
    }

    func testNilBeforeContextReturnsNil() {
        XCTAssertNil(TextContextParser.parse(before: nil, after: nil))
    }
}

final class InsertionRetractionPolicyTests: XCTestCase {
    func testRetractsWhenContextEndsWithInsertedText() {
        XCTAssertTrue(InsertionRetractionPolicy.isRetractable(
            insertedText: "a",
            contextBefore: "hello a"
        ))
    }

    func testRefusesWhenContextDoesNotEndWithInsertedText() {
        XCTAssertFalse(InsertionRetractionPolicy.isRetractable(
            insertedText: "a",
            contextBefore: "hello ab"
        ))
    }

    func testHandlesDoubleSpacePeriodRetraction() {
        XCTAssertTrue(InsertionRetractionPolicy.isRetractable(
            insertedText: ". ",
            contextBefore: "Hi. "
        ))
    }

    func testNilInsertedTextIsNotRetractable() {
        XCTAssertFalse(InsertionRetractionPolicy.isRetractable(
            insertedText: nil,
            contextBefore: "hello"
        ))
    }

    func testEmptyInsertedTextIsNotRetractable() {
        XCTAssertFalse(InsertionRetractionPolicy.isRetractable(
            insertedText: "",
            contextBefore: "hello"
        ))
    }

    func testNilContextWithNonEmptyInsertedIsNotRetractable() {
        XCTAssertFalse(InsertionRetractionPolicy.isRetractable(
            insertedText: "a",
            contextBefore: nil
        ))
    }
}

final class WordPredictionEngineTests: XCTestCase {
    private let dictionary = FakePredictionDictionary(words: [
        DictionaryWord(word: "hello", frequencyRank: 1),
        DictionaryWord(word: "help", frequencyRank: 2),
        DictionaryWord(word: "helicopter", frequencyRank: 3),
        DictionaryWord(word: "world", frequencyRank: 4),
        DictionaryWord(word: "you", frequencyRank: 5),
        DictionaryWord(word: "there", frequencyRank: 6)
    ], bigrams: ["hello": ["world", "there"]])

    func testPrefixPredictionReturnsAtMostThreeCandidates() {
        let engine = BasicWordPredictionEngine(dictionary: dictionary)
        let context = PredictionContext(
            currentWord: "he",
            previousWord: nil,
            textBeforeCursor: "he",
            textAfterCursor: "",
            replacementCount: 2,
            shouldCapitalize: false
        )

        let predictions = engine.predict(for: context)

        XCTAssertLessThanOrEqual(predictions.count, 3)
        XCTAssertTrue(predictions.allSatisfy { $0.word.hasPrefix("he") })
        XCTAssertEqual(predictions.first?.word, "hello")
    }

    func testContextPredictionUsesPreviousWord() {
        let engine = BasicWordPredictionEngine(dictionary: dictionary)
        let context = PredictionContext(
            currentWord: "",
            previousWord: "hello",
            textBeforeCursor: "hello ",
            textAfterCursor: "",
            replacementCount: 0,
            shouldCapitalize: false
        )

        XCTAssertEqual(engine.predict(for: context).map(\.word), ["world", "there"])
    }

    func testPredictionAppliesCapitalization() {
        let engine = BasicWordPredictionEngine(dictionary: dictionary)
        let context = PredictionContext(
            currentWord: "he",
            previousWord: nil,
            textBeforeCursor: "He",
            textAfterCursor: "",
            replacementCount: 2,
            shouldCapitalize: true
        )

        XCTAssertEqual(engine.predict(for: context).first?.word, "Hello")
    }

    func testEmptyContextProducesNoCandidates() {
        let engine = BasicWordPredictionEngine(dictionary: dictionary)
        let context = PredictionContext(
            currentWord: "",
            previousWord: nil,
            textBeforeCursor: "",
            textAfterCursor: "",
            replacementCount: 0,
            shouldCapitalize: true
        )
        XCTAssertTrue(engine.predict(for: context).isEmpty)
    }

    func testTrieStoresOnlyTopThreeFrequencyRankedWords() {
        let dictionary = LocalWordPredictionDictionary(bundle: Bundle(for: Self.self))
        let words = dictionary.words(withPrefix: "t", limit: 10)

        XCTAssertEqual(words.count, 3)
        XCTAssertEqual(words.map(\.frequencyRank), words.map(\.frequencyRank).sorted())
    }

    func testPrefixPredictionBenchmark() {
        let dictionary = LocalWordPredictionDictionary(bundle: Bundle(for: Self.self))

        measure {
            for _ in 0..<10_000 {
                _ = dictionary.words(withPrefix: "th", limit: 3)
            }
        }
    }

    func testTrieRanksOutOfOrderInput() {
        let dictionary = LocalWordPredictionDictionary(words: [
            DictionaryWord(word: "hello", frequencyRank: 30),
            DictionaryWord(word: "help", frequencyRank: 10),
            DictionaryWord(word: "helicopter", frequencyRank: 20),
            DictionaryWord(word: "hero", frequencyRank: 5)
        ])
        let predictions = BasicWordPredictionEngine(dictionary: dictionary).predict(for: PredictionContext(
            currentWord: "he",
            previousWord: nil,
            textBeforeCursor: "he",
            textAfterCursor: "",
            replacementCount: 2,
            shouldCapitalize: false
        ))

        XCTAssertEqual(predictions.map(\.word), ["hero", "help", "helicopter"])
    }
}

@MainActor
final class TapTypingPerformanceTests: XCTestCase {
    func testCharacterInsertionBenchmark() {
        let proxy = BenchmarkTextProxy()

        measure {
            for _ in 0..<10_000 {
                proxy.insertText("a")
            }
            proxy.reset()
        }
    }

    func testBackspaceBenchmark() {
        let proxy = BenchmarkTextProxy()

        measure {
            proxy.reset(to: String(repeating: "a", count: 10_000))
            for _ in 0..<10_000 {
                proxy.deleteBackward()
            }
        }
    }

    func testDownInsertRetractCycleBenchmark() {
        let proxy = BenchmarkTextProxy()

        measure {
            for _ in 0..<10_000 {
                proxy.insertText("a")
                if InsertionRetractionPolicy.isRetractable(
                    insertedText: "a",
                    contextBefore: proxy.documentContextBeforeInput
                ) {
                    proxy.deleteBackward()
                }
            }
        }
    }

    func testPredictionOffBenchmark() {
        let predictionEnabled = false
        let before: String? = "please hel"

        measure {
            for _ in 0..<10_000 {
                if predictionEnabled {
                    _ = TextContextParser.parse(before: before, after: nil)
                }
            }
        }
    }

    func testPredictionOnBenchmark() {
        let engine = BasicWordPredictionEngine(
            dictionary: LocalWordPredictionDictionary(bundle: Bundle(for: Self.self))
        )
        let before: String? = "please hel"

        measure {
            for _ in 0..<10_000 {
                guard let context = TextContextParser.parse(before: before, after: nil) else { continue }
                _ = engine.predict(for: context)
            }
        }
    }

    func testCandidateUpdateBenchmark() {
        let view = QwertyKeyboardView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        view.update(
            state: KeyboardState(),
            theme: .light,
            size: view.bounds.size,
            returnKeyTitle: "return"
        )

        measure {
            for index in 0..<1_000 {
                view.showCandidates(.predictions(["the", "this", index.isMultiple(of: 2) ? "that" : "there"]))
            }
        }
    }

    func testKeyHighlightWithShadowBenchmark() {
        let key = KeyboardKeyControl(descriptor: KeyboardKeyDescriptor(.character("a"), title: "a"))
        measure {
            for _ in 0..<10_000 {
                key.isHighlighted = true
                key.isHighlighted = false
            }
        }
    }

    func testKeyHighlightWithoutShadowComparisonBenchmark() {
        let key = KeyboardKeyControl(descriptor: KeyboardKeyDescriptor(.character("a"), title: "a"))
        key.layer.shadowOpacity = 0
        measure {
            for _ in 0..<10_000 {
                key.isHighlighted = true
                key.isHighlighted = false
            }
        }
    }
}

private struct FakePredictionDictionary: WordPredictionDictionaryProviding {
    let words: [DictionaryWord]
    let bigrams: [String: [String]]

    func words(withPrefix prefix: String, limit: Int) -> [DictionaryWord] {
        Array(words.filter { $0.word.hasPrefix(prefix) }.prefix(limit))
    }

    func nextWords(after previousWord: String, limit: Int) -> [DictionaryWord] {
        let requested = bigrams[previousWord] ?? []
        return Array(requested.compactMap { word in words.first { $0.word == word } }.prefix(limit))
    }
}

private final class BenchmarkTextProxy {
    private var storage = ""

    var documentContextBeforeInput: String? { storage }

    func insertText(_ text: String) {
        storage.append(contentsOf: text)
    }

    func deleteBackward() {
        guard !storage.isEmpty else { return }
        storage.removeLast()
    }

    func reset(to value: String = "") {
        storage = value
    }
}
