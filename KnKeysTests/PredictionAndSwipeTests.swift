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

    func testPrefixPredictionBenchmark() {
        let engine = BasicWordPredictionEngine(dictionary: LocalWordPredictionDictionary())
        let context = PredictionContext(
            currentWord: "th",
            previousWord: nil,
            textBeforeCursor: "th",
            textAfterCursor: "",
            replacementCount: 2,
            shouldCapitalize: false
        )

        measure {
            for _ in 0..<1_000 {
                _ = engine.predict(for: context)
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

final class SwipeTypingEngineTests: XCTestCase {
    func testCandidateGeneratorMatchesOrderedPathSequence() {
        let dictionary = FakeSwipeDictionary(words: [
            DictionaryWord(word: "hello", frequencyRank: 1),
            DictionaryWord(word: "help", frequencyRank: 2),
            DictionaryWord(word: "world", frequencyRank: 3)
        ])
        let path = makePath(sequence: "helo")
        let generator = BasicSwipeCandidateGenerator(dictionary: dictionary)

        let candidates = generator.candidates(for: path)

        XCTAssertEqual(candidates.map(\.word), ["hello"])
    }

    func testRankerPrefersGeometricallyCloserCandidate() {
        let dictionary = FakeSwipeDictionary(words: [
            DictionaryWord(word: "hello", frequencyRank: 100),
            DictionaryWord(word: "help", frequencyRank: 1)
        ])
        let path = makePath(sequence: "helo")
        let ranker = BasicSwipeCandidateRanker()

        let ranked = ranker.rank(dictionary.allWords, for: path)

        XCTAssertEqual(ranked.first?.word, "hello")
    }

    func testEngineRejectsEmptyPath() {
        let dictionary = FakeSwipeDictionary(words: [])
        let engine = SwipeTypingEngine(
            generator: BasicSwipeCandidateGenerator(dictionary: dictionary),
            ranker: BasicSwipeCandidateRanker()
        )
        XCTAssertNil(engine.recognize(path: SwipePath(points: [], keyGeometries: [:])))
    }

    func testDictionaryWordSignatureCollapsesRepeatedLetters() {
        let word = DictionaryWord(word: "letter", frequencyRank: 1)
        XCTAssertEqual(word.signature, Array("leter"))
    }

    func testSwipeRecognitionBenchmark() {
        let dictionary = FakeSwipeDictionary(words: (0..<300).map { index in
            DictionaryWord(word: "hello\(index)", frequencyRank: index)
        })
        let path = makePath(sequence: "helo")
        let ranker = BasicSwipeCandidateRanker()

        measure {
            for _ in 0..<100 {
                _ = ranker.rank(dictionary.allWords, for: path)
            }
        }
    }

    private func makePath(sequence: String) -> SwipePath {
        var geometries: [Character: SwipeKeyGeometry] = [:]
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        for (index, letter) in letters.enumerated() {
            let frame = CGRect(x: CGFloat(index % 10) * 40, y: CGFloat(index / 10) * 50, width: 36, height: 44)
            geometries[letter] = SwipeKeyGeometry(letter: letter, frame: frame)
        }
        let points = Array(sequence).enumerated().compactMap { index, letter -> SwipePathPoint? in
            guard let geometry = geometries[letter] else { return nil }
            return SwipePathPoint(
                position: geometry.center,
                timestamp: Double(index) * 0.05,
                letter: letter
            )
        }
        return SwipePath(points: points, keyGeometries: geometries)
    }
}

private struct FakeSwipeDictionary: SwipeDictionaryProviding {
    let allWords: [DictionaryWord]

    init(words: [DictionaryWord]) { allWords = words }

    func words(startingWith first: Character, endingWith last: Character) -> [DictionaryWord] {
        allWords.filter { $0.word.first == first && $0.word.last == last }
    }
}
