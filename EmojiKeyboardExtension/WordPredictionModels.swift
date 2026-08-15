import Foundation

struct PredictionContext: Equatable {
    let currentWord: String
    let previousWord: String?
    let textBeforeCursor: String
    let textAfterCursor: String
    let replacementCount: Int
    let shouldCapitalize: Bool
}

struct WordPrediction: Equatable {
    let word: String
    let score: Double
}

struct PredictionResult: Equatable {
    let predictions: [WordPrediction]
    let replacementCount: Int
    let expectedSuffix: String
}

protocol WordPredicting {
    func predict(for context: PredictionContext) -> [WordPrediction]
}

protocol WordPredictionDictionaryProviding {
    func words(withPrefix prefix: String, limit: Int) -> [DictionaryWord]
    func nextWords(after previousWord: String, limit: Int) -> [DictionaryWord]
}

enum TextContextParser {
    static func parse(before: String?, after: String?) -> PredictionContext? {
        guard let before else { return nil }
        let currentWord = trailingWord(in: before)
        let prefixBeforeCurrent = String(before.dropLast(currentWord.count))
        let previousWord = trailingWord(in: prefixBeforeCurrent.trimmingCharacters(in: .whitespacesAndNewlines))
        let trimmed = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldCapitalize = trimmed.isEmpty || trimmed.last.map { ".!?".contains($0) } == true
        return PredictionContext(
            currentWord: currentWord.lowercased(),
            previousWord: previousWord.isEmpty ? nil : previousWord.lowercased(),
            textBeforeCursor: before,
            textAfterCursor: after ?? "",
            replacementCount: currentWord.count,
            shouldCapitalize: shouldCapitalize
        )
    }

    private static func trailingWord(in text: String) -> String {
        var characters: [Character] = []
        for character in text.reversed() {
            guard character.isLetter || character == "'" else { break }
            characters.append(character)
        }
        return String(characters.reversed())
    }
}
