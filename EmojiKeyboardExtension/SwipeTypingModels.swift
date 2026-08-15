import UIKit

struct SwipeKeyGeometry: Equatable {
    let letter: Character
    let frame: CGRect

    var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

struct SwipePathPoint: Equatable {
    let position: CGPoint
    let timestamp: TimeInterval
    let letter: Character
}

struct SwipePath: Equatable {
    let points: [SwipePathPoint]
    let keyGeometries: [Character: SwipeKeyGeometry]

    var keySequence: [Character] {
        points.reduce(into: []) { result, point in
            if result.last != point.letter {
                result.append(point.letter)
            }
        }
    }
}

struct SwipeCandidate: Equatable {
    let word: String
    let score: Double
    let frequencyRank: Int
}

struct SwipeTypingResult: Equatable {
    let word: String
    let alternatives: [String]
    let confidence: Double
}

enum SwipeGestureResult: Equatable {
    case typing(SwipePath)
    case deletion(GestureDeletionLevel)
}

protocol SwipeDictionaryProviding {
    func words(startingWith first: Character, endingWith last: Character) -> [DictionaryWord]
}

protocol SwipeCandidateGenerating {
    func candidates(for path: SwipePath) -> [DictionaryWord]
}

protocol SwipeCandidateRanking {
    func rank(_ candidates: [DictionaryWord], for path: SwipePath) -> [SwipeCandidate]
}

struct DictionaryWord: Equatable {
    let word: String
    let frequencyRank: Int
    let signature: [Character]

    init(word: String, frequencyRank: Int) {
        self.word = word
        self.frequencyRank = frequencyRank
        signature = word.lowercased().reduce(into: []) { result, character in
            if result.last != character {
                result.append(character)
            }
        }
    }
}
