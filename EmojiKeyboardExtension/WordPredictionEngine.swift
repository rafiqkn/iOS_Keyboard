import Foundation

final class LocalWordPredictionDictionary: WordPredictionDictionaryProviding {
    private final class TrieNode {
        var children: [Character: TrieNode] = [:]
        var topWords: [DictionaryWord] = []
    }

    private let root = TrieNode()
    private var wordsByValue: [String: DictionaryWord] = [:]
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

    init(bundle: Bundle = .main, resourceName: String = "english_prediction_words") {
        guard let url = bundle.url(forResource: resourceName, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        var seen = Set<String>()
        let words = contents.split(whereSeparator: \.isNewline).enumerated().compactMap { rank, line -> DictionaryWord? in
            let word = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard word.count >= 2,
                  word.allSatisfy({ $0.isLetter }),
                  seen.insert(word).inserted else { return nil }
            return DictionaryWord(word: word, frequencyRank: rank)
        }
        insert(words: words)
    }

    init(words: [DictionaryWord]) {
        insert(words: words)
    }

    private func insert(words: [DictionaryWord]) {
        for word in words {
            wordsByValue[word.word] = word
            insert(word)
        }
    }

    func words(withPrefix prefix: String, limit: Int) -> [DictionaryWord] {
        guard limit > 0, !prefix.isEmpty else { return [] }
        var node = root
        for character in prefix {
            guard let next = node.children[character] else { return [] }
            node = next
        }
        if limit >= node.topWords.count { return node.topWords }
        return Array(node.topWords.prefix(limit))
    }

    func nextWords(after previousWord: String, limit: Int) -> [DictionaryWord] {
        guard limit > 0, let requested = bigrams[previousWord] else { return [] }
        return requested.prefix(limit).compactMap { wordsByValue[$0] }
    }

    private func insert(_ word: DictionaryWord) {
        var node = root
        for character in word.word {
            let child: TrieNode
            if let existing = node.children[character] {
                child = existing
            } else {
                child = TrieNode()
                node.children[character] = child
            }
            node = child
            let insertionIndex = node.topWords.firstIndex {
                $0.frequencyRank > word.frequencyRank
            } ?? node.topWords.count
            if insertionIndex < 3 || node.topWords.count < 3 {
                node.topWords.insert(word, at: insertionIndex)
                if node.topWords.count > 3 {
                    node.topWords.removeLast()
                }
            }
        }
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
            candidates = dictionary.words(withPrefix: context.currentWord, limit: 3)
        } else if let previousWord = context.previousWord {
            candidates = dictionary.nextWords(after: previousWord, limit: 3)
        } else {
            return []
        }

        let shouldCapitalize = context.shouldCapitalize
        return candidates.map { candidate in
            let word = shouldCapitalize
                ? candidate.word.prefix(1).uppercased() + candidate.word.dropFirst()
                : candidate.word
            return WordPrediction(word: word, score: 1 / Double(candidate.frequencyRank + 1))
        }
    }
}
