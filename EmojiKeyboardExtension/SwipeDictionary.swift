import Foundation

final class LocalSwipeDictionary: SwipeDictionaryProviding {
    private let index: [String: [DictionaryWord]]

    init(bundle: Bundle = .main, resourceName: String = "english_swipe_words") {
        guard let url = bundle.url(forResource: resourceName, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            index = [:]
            return
        }

        var builtIndex: [String: [DictionaryWord]] = [:]
        var seenWords = Set<String>()
        let lines = contents.split(whereSeparator: \.isNewline)
        for (rank, line) in lines.enumerated() {
            let word = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard word.count >= 2,
                  word.allSatisfy({ $0.isLetter }),
                  seenWords.insert(word).inserted,
                  let first = word.first,
                  let last = word.last else { continue }
            let dictionaryWord = DictionaryWord(word: word, frequencyRank: rank)
            builtIndex[Self.indexKey(first: first, last: last), default: []].append(dictionaryWord)
        }
        index = builtIndex
    }

    func words(startingWith first: Character, endingWith last: Character) -> [DictionaryWord] {
        index[Self.indexKey(first: first, last: last)] ?? []
    }

    private static func indexKey(first: Character, last: Character) -> String {
        "\(String(first).lowercased()):\(String(last).lowercased())"
    }
}
