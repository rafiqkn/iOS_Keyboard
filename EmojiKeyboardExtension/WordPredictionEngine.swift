import Foundation

final class LocalWordPredictionDictionary: WordPredictionDictionaryProviding {
    private let words: [DictionaryWord]
    private let bigrams: [String: [String]] = [
        "thank": ["you"],
        "how": ["are", "do", "can"],
        "good": ["morning", "night", "luck"],
        "see": ["you", "the"],
        "i": ["am", "have", "think", "want"],
        "you": ["are", "can", "have", "know"],
        "we": ["are", "can", "have", "need"],
        "please": ["let", "send", "check"],
        "happy": ["birthday", "to"],
        "what": ["is", "are", "do"],
        "where": ["is", "are", "do"],
        "when": ["is", "are", "can"],
        "talk": ["to", "about"],
        "look": ["at", "for", "like"],
        "going": ["to", "home"],
        "back": ["to", "home"],
        "need": ["to", "help"],
        "want": ["to", "you"],
        "love": ["you", "this"],
        "hello": ["there", "world"],
        "goodnight": ["everyone"]
    ]

    init(bundle: Bundle = .main, resourceName: String = "english_swipe_words") {
        guard let url = bundle.url(forResource: resourceName, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            words = []
            return
        }
        var seen = Set<String>()
        words = contents.split(whereSeparator: \.isNewline).enumerated().compactMap { rank, line in
            let word = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard word.count >= 2,
                  word.allSatisfy({ $0.isLetter }),
                  seen.insert(word).inserted else { return nil }
            return DictionaryWord(word: word, frequencyRank: rank)
        }
    }

    func words(withPrefix prefix: String, limit: Int) -> [DictionaryWord] {
        guard !prefix.isEmpty else { return [] }
        return words.lazy.filter { $0.word.hasPrefix(prefix) }.prefix(limit).map { $0 }
    }

    func nextWords(after previousWord: String, limit: Int) -> [DictionaryWord] {
        let requested = bigrams[previousWord.lowercased()] ?? []
        guard !requested.isEmpty else { return [] }
        let requestedSet = Set(requested)
        return words.filter { requestedSet.contains($0.word) }
            .sorted {
                let left = requested.firstIndex(of: $0.word) ?? .max
                let right = requested.firstIndex(of: $1.word) ?? .max
                return left < right
            }
            .prefix(limit)
            .map { $0 }
    }
}

final class BasicWordPredictionEngine: WordPredicting {
    private let dictionary: WordPredictionDictionaryProviding

    init(dictionary: WordPredictionDictionaryProviding = LocalWordPredictionDictionary()) {
        self.dictionary = dictionary
    }

    func predict(for context: PredictionContext) -> [WordPrediction] {
        let candidates: [DictionaryWord]
        if !context.currentWord.isEmpty {
            candidates = dictionary.words(withPrefix: context.currentWord, limit: 40)
        } else if let previousWord = context.previousWord {
            candidates = dictionary.nextWords(after: previousWord, limit: 10)
        } else {
            return []
        }

        return candidates.map { candidate in
            let prefixScore = context.currentWord.isEmpty ? 0.65 : 1
            let frequencyScore = 1 / (1 + log10(Double(candidate.frequencyRank + 2)))
            let completionLength = max(0, candidate.word.count - context.currentWord.count)
            let lengthScore = 1 / Double(completionLength + 1)
            let score = prefixScore * 0.6 + frequencyScore * 0.25 + lengthScore * 0.15
            let word = context.shouldCapitalize
                ? candidate.word.prefix(1).uppercased() + candidate.word.dropFirst()
                : candidate.word
            return WordPrediction(word: word, score: score)
        }
        .sorted { $0.score > $1.score }
        .prefix(3)
        .map { $0 }
    }
}
