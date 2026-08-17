import Foundation

final class LocalWordPredictionDictionary: WordPredictionDictionaryProviding {
    private final class TrieNode {
        var children: [Character: TrieNode] = [:]
        var topWords: [DictionaryWord] = []
    }

    private let root = TrieNode()
    private var wordsByValue: [String: DictionaryWord] = [:]
    private let bigrams: [String: [String]] = [
        "about": ["the", "this", "that", "it", "you", "my", "your", "me", "us", "them", "him", "her", "what", "how", "when", "where", "why", "to", "for", "us", "work", "life", "time", "everything", "before", "after"],
        "after": ["the", "a", "my", "your", "this", "that", "it", "and", "for", "with", "i", "you", "we", "long", "now", "then", "again", "today", "work", "school", "home", "all", "everything"],
        "all": ["the", "my", "your", "this", "that", "of", "and", "for", "with", "i", "you", "we", "they", "so", "very", "good", "right", "together", "now", "more", "here", "there"],
        "and": ["the", "i", "you", "we", "then", "now", "so", "for", "with", "my", "your", "this", "that", "it", "not", "they", "he", "she", "more", "again"],
        "ask": ["the", "a", "your", "my", "this", "that", "it", "me", "you", "us", "them", "him", "her", "about", "what", "how", "when", "where", "why", "for", "out", "now"],
        "back": ["to", "home", "the", "my", "your", "in", "at", "from", "now", "again", "for", "with", "and", "there"],
        "before": ["the", "a", "my", "your", "this", "that", "it", "and", "for", "with", "i", "you", "we", "going", "long", "now", "then", "again", "today", "work", "school", "home"],
        "but": ["i", "you", "we", "the", "this", "that", "it", "not", "for", "with", "and", "so", "there", "here", "now", "then", "only", "also", "too", "really"],
        "call": ["the", "a", "your", "my", "this", "me", "you", "us", "them", "him", "her", "back", "now", "home", "and", "if", "what", "when", "where"],
        "can": ["be", "do", "get", "go", "have", "see", "take", "you", "we", "it", "help", "know", "make"],
        "check": ["the", "a", "your", "my", "this", "that", "it", "now", "and", "for", "out", "in", "on", "with", "again", "everything"],
        "close": ["the", "a", "your", "my", "this", "it", "now", "and", "for", "down", "up", "out"],
        "come": ["to", "the", "home", "back", "here", "in", "on", "and", "now", "with", "for", "up"],
        "could": ["be", "have", "you", "we", "they", "go", "come", "take", "see", "know", "say", "help"],
        "everything": ["is", "was", "will", "be", "and", "the", "my", "your", "i", "you", "we", "now", "again", "today", "good", "fine", "all", "here"],
        "find": ["the", "a", "your", "my", "this", "it", "out", "him", "her", "them", "you", "me", "us", "one", "way", "time"],
        "first": ["time", "day", "one", "the", "a", "my", "your", "and", "for", "with", "i", "you", "we", "go", "come", "see", "know", "love", "time"],
        "for": ["you", "me", "the", "a", "your", "my", "this", "now", "sure", "example", "us", "them", "him", "her"],
        "get": ["to", "the", "a", "your", "my", "this", "it", "back", "out", "up", "home", "ready", "one", "you", "me", "us"],
        "give": ["the", "a", "your", "my", "this", "it", "me", "you", "us", "them", "him", "her", "one", "up", "back", "out"],
        "go": ["to", "the", "home", "a", "your", "be", "out", "up", "now", "and", "back", "in", "on"],
        "going": ["to", "the", "my", "your", "home", "now", "and", "be", "get", "have", "see", "go", "out", "up", "back", "there", "here", "for", "with", "on", "in", "at", "this", "that", "it"],
        "good": ["morning", "night", "luck", "to", "for", "with", "and", "you", "i", "we", "day", "time"],
        "goodnight": ["everyone"],
        "happy": ["birthday", "to", "with", "for", "about", "you", "i", "we", "day", "new", "year", "life", "family", "time"],
        "have": ["a", "the", "been", "to", "you", "your", "my", "one", "some", "this", "it", "had", "has"],
        "hello": ["there", "world"],
        "here": ["is", "are", "and", "the", "my", "your", "this", "that", "it", "we", "you", "i", "now", "again", "today", "before", "after"],
        "home": ["and", "the", "my", "your", "now", "from", "to", "at", "for", "with", "today", "work", "again", "every"],
        "how": ["are", "do", "can", "about", "the", "your", "my", "long", "much", "many", "often", "old", "big", "good", "this", "that", "it", "we", "you", "i", "they", "he", "she"],
        "i": ["am", "have", "think", "want", "will", "would", "can", "should", "need", "know", "like", "love", "see", "go", "get", "take", "make", "say", "tell", "ask", "was", "had", "do", "did", "hope", "wish", "just", "really", "feel"],
        "just": ["a", "the", "my", "your", "this", "that", "it", "now", "one", "like", "want", "need", "know", "see", "go", "come", "get", "say", "tell", "ask", "i", "you", "we", "please"],
        "know": ["the", "you", "this", "that", "it", "what", "how", "where", "when", "if", "about", "him", "her", "them", "my", "your", "me", "us"],
        "later": ["and", "the", "my", "your", "this", "that", "it", "i", "you", "we", "see", "talk", "call", "go", "come", "home", "again", "today"],
        "like": ["to", "the", "you", "this", "that", "it", "my", "your", "go", "see", "know", "have", "a", "an"],
        "look": ["at", "for", "like", "the", "your", "my", "this", "good", "up", "out"],
        "love": ["you", "the", "this", "that", "it", "my", "your", "life", "family", "and", "so", "more", "everything"],
        "make": ["the", "a", "your", "my", "this", "it", "sure", "one", "good", "up", "me", "you", "us", "them"],
        "more": ["and", "the", "this", "that", "it", "you", "i", "we", "time", "work", "fun", "love", "again", "please", "for", "to"],
        "morning": ["and", "you", "i", "see", "good", "the", "now", "before", "after", "for", "with", "every", "today"],
        "much": ["more", "better", "the", "this", "that", "it", "you", "i", "we", "love", "thank", "for", "so", "very", "too"],
        "my": ["name", "friend", "family", "love", "life", "day", "home", "work", "phone", "email"],
        "need": ["to", "you", "help", "the", "a", "this", "go", "be", "have", "know", "get", "take"],
        "night": ["and", "you", "good", "the", "i", "now", "before", "after", "for", "with", "last", "every"],
        "no": ["i", "you", "we", "it", "this", "that", "and", "one", "more", "problem", "thank", "for", "to", "not"],
        "ok": ["thank", "yes", "no", "i", "you", "we", "and", "now", "good", "fine", "let", "please", "all"],
        "open": ["the", "a", "your", "my", "this", "it", "now", "and", "for", "up", "out", "in"],
        "out": ["the", "a", "my", "your", "this", "that", "it", "and", "now", "here", "there", "on", "in", "with", "for", "again", "together"],
        "please": ["let", "send", "check", "call", "tell", "give", "take", "make", "say", "go", "come", "see", "help", "look", "find", "know", "wait", "stop", "start", "open", "close"],
        "really": ["like", "love", "want", "need", "know", "see", "good", "bad", "the", "this", "that", "it", "i", "you", "we", "sorry", "thank"],
        "right": ["now", "here", "there", "and", "for", "with", "the", "my", "your", "this", "that", "it", "i", "you", "we"],
        "say": ["the", "you", "this", "that", "it", "sorry", "hello", "yes", "no", "me", "us", "them", "we", "they"],
        "see": ["you", "the", "this", "that", "it", "your", "my", "me", "us", "him", "her", "them", "what", "how", "where", "now", "again", "one"],
        "send": ["the", "a", "your", "my", "this", "it", "me", "you", "us", "them", "him", "her", "now", "back", "out", "up", "again", "more"],
        "should": ["be", "have", "not", "go", "do", "get", "take", "know", "see", "we", "you", "say"],
        "so": ["much", "very", "thank", "good", "sorry", "happy", "tired", "bad", "i", "you", "we", "long", "far"],
        "some": ["of", "the", "my", "your", "this", "that", "it", "and", "for", "with", "one", "more", "time", "people", "things", "everything", "here", "there", "now", "again"],
        "soon": ["and", "the", "my", "your", "this", "that", "it", "i", "you", "we", "see", "be", "home", "back", "again", "morning", "night"],
        "sorry": ["i", "you", "we", "for", "about", "the", "this", "that", "it", "so", "very", "really", "please", "again", "to", "but", "and"],
        "start": ["the", "a", "your", "my", "this", "that", "it", "now", "and", "at", "with", "by", "from", "again", "today", "morning", "night", "week", "day", "work", "over", "up", "out"],
        "stop": ["the", "a", "your", "my", "this", "that", "it", "now", "and", "at", "in", "on", "here", "there", "again", "for", "with", "by", "from", "when", "before", "after"],
        "sure": ["i", "you", "we", "it", "this", "that", "and", "about", "of", "to", "for", "can", "will", "would", "should"],
        "take": ["the", "a", "your", "my", "this", "it", "care", "time", "one", "you", "me", "us", "out", "up", "home"],
        "talk": ["to", "about", "the", "your", "my", "this", "that", "it", "now", "with", "and", "you", "me", "us", "them", "him", "her", "for", "later", "again", "more", "today", "work", "school", "life"],
        "tell": ["the", "a", "your", "my", "this", "that", "it", "me", "you", "us", "them", "him", "her", "about", "what", "how", "when", "where", "why"],
        "thank": ["you", "for", "so", "very", "much", "the", "my", "your", "all", "everything"],
        "that": ["is", "was", "will", "can", "would", "should", "have", "and"],
        "the": ["best", "same", "first", "only", "other", "way", "end", "day", "time", "one"],
        "there": ["is", "are", "was", "were", "will", "can", "would", "should", "be", "and", "the", "a", "in", "on", "at", "too", "again", "my", "your", "this", "that", "it", "we", "you", "they", "he", "she", "now"],
        "they": ["are", "can", "have", "will", "would", "should", "need", "like", "love", "want", "go", "get", "see", "make", "take", "say", "tell", "ask", "know", "were", "had", "did", "do", "just", "really", "could"],
        "think": ["the", "you", "this", "that", "it", "about", "so", "i", "we", "they", "he", "she", "is", "will", "can", "would", "should"],
        "this": ["is", "one", "day", "week", "time", "and"],
        "time": ["to", "the", "and", "for", "with", "go", "come", "now", "this", "my", "your", "it", "is", "was", "will", "would", "should", "can", "in", "at", "on", "again", "together"],
        "today": ["and", "the", "my", "your", "this", "that", "it", "i", "you", "we", "was", "is", "will", "have", "go", "come", "work", "school", "morning", "night", "again"],
        "tomorrow": ["and", "the", "my", "your", "this", "that", "it", "i", "you", "we", "will", "can", "go", "come", "see", "work", "school", "morning", "night", "again"],
        "too": ["much", "bad", "good", "late", "early", "many", "long", "far", "i", "you", "we", "often"],
        "up": ["to", "the", "a", "my", "your", "and", "now", "here", "there", "on", "in", "with", "for", "again", "together"],
        "very": ["good", "much", "well", "bad", "nice", "sorry", "happy", "tired", "the", "this", "that", "it", "you", "i", "we", "many"],
        "wait": ["for", "the", "a", "your", "my", "this", "that", "it", "now", "here", "there", "and", "on"],
        "want": ["to", "you", "go", "know", "see", "say", "take", "be", "it", "this", "that", "one", "help"],
        "we": ["are", "can", "have", "need", "will", "would", "should", "could", "like", "love", "want", "go", "get", "see", "make", "take", "say", "know", "were", "had", "did", "do", "just", "really"],
        "what": ["is", "are", "do", "the", "your", "my", "this", "that", "it", "about", "you", "i", "we", "they", "he", "she", "can", "would", "should", "will", "have", "now", "next", "else", "time", "day", "name"],
        "when": ["is", "are", "do", "the", "your", "my", "this", "that", "it", "you", "we", "they", "he", "she", "can", "would", "should", "will", "have", "now", "next", "else", "did", "does", "was", "were"],
        "where": ["is", "are", "do", "the", "your", "my", "this", "that", "it", "you", "we", "they", "he", "she", "can", "would", "should", "will", "have", "now", "next", "else", "from", "to", "at", "in", "on"],
        "why": ["is", "are", "do", "the", "your", "my", "this", "that", "it", "you", "we", "they", "he", "she", "can", "would", "should", "will", "have", "not", "now", "then", "else", "did", "does", "was", "were"],
        "will": ["be", "have", "you", "the", "my", "your", "we", "they", "it", "not", "come", "go", "take", "make", "get", "see", "know"],
        "with": ["you", "me", "the", "your", "my", "us", "them", "her", "him", "this", "that", "it"],
        "work": ["and", "the", "my", "your", "for", "at", "in", "on", "from", "to", "with", "hard", "today", "now", "this", "week", "well", "best", "home", "out", "more", "together"],
        "would": ["be", "like", "have", "you", "the", "a", "it", "not", "go", "come", "want", "need", "see", "say"],
        "yes": ["i", "you", "we", "it", "this", "that", "and", "please", "of", "to", "for", "sure"],
        "you": ["are", "can", "have", "know", "will", "would", "should", "need", "like", "love", "want", "go", "get", "see", "make", "take", "say", "tell", "ask", "were", "had", "did", "do", "please", "just", "really", "could"],
        "your": ["name", "email", "phone", "number", "time", "day", "home", "work", "family", "friend"],
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
