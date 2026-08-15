import UIKit

final class BasicSwipeCandidateGenerator: SwipeCandidateGenerating {
    private let dictionary: SwipeDictionaryProviding
    private let maximumCandidates: Int

    init(dictionary: SwipeDictionaryProviding, maximumCandidates: Int = 300) {
        self.dictionary = dictionary
        self.maximumCandidates = maximumCandidates
    }

    func candidates(for path: SwipePath) -> [DictionaryWord] {
        let sequence = path.keySequence
        guard let first = sequence.first, let last = sequence.last else { return [] }
        return dictionary.words(startingWith: first, endingWith: last)
            .filter { word in
                let minimumLength = max(2, sequence.count - 2)
                let maximumLength = sequence.count + 5
                return word.word.count >= minimumLength &&
                    word.word.count <= maximumLength &&
                    orderedMatch(word.signature, in: sequence)
            }
            .prefix(maximumCandidates)
            .map { $0 }
    }

    private func orderedMatch(_ signature: [Character], in sequence: [Character]) -> Bool {
        guard let first = signature.first,
              let last = signature.last,
              first == sequence.first,
              last == sequence.last else { return false }

        var sequenceIndex = 0
        var matched = 0
        for character in signature {
            while sequenceIndex < sequence.count && sequence[sequenceIndex] != character {
                sequenceIndex += 1
            }
            if sequenceIndex < sequence.count {
                matched += 1
                sequenceIndex += 1
            }
        }
        let required = max(2, Int(ceil(Double(signature.count) * 0.65)))
        return matched >= required
    }
}

final class BasicSwipeCandidateRanker: SwipeCandidateRanking {
    private let maximumRankedCandidates: Int

    init(maximumRankedCandidates: Int = 50) {
        self.maximumRankedCandidates = maximumRankedCandidates
    }

    func rank(_ candidates: [DictionaryWord], for path: SwipePath) -> [SwipeCandidate] {
        let sequence = path.keySequence
        guard !sequence.isEmpty else { return [] }
        return candidates
            .map { word in
                let sequenceScore = alignmentScore(word.signature, sequence)
                let geometryScore = geometricScore(word: word.word, path: path)
                let frequencyScore = 1 / (1 + log10(Double(word.frequencyRank + 2)))
                let score = geometryScore * 0.50 + sequenceScore * 0.35 + frequencyScore * 0.15
                return SwipeCandidate(
                    word: word.word,
                    score: score,
                    frequencyRank: word.frequencyRank
                )
            }
            .sorted {
                if $0.score == $1.score { return $0.frequencyRank < $1.frequencyRank }
                return $0.score > $1.score
            }
            .prefix(maximumRankedCandidates)
            .map { $0 }
    }

    private func alignmentScore(_ target: [Character], _ observed: [Character]) -> Double {
        guard !target.isEmpty, !observed.isEmpty else { return 0 }
        var previous = Array(0...observed.count)
        for (targetIndex, targetCharacter) in target.enumerated() {
            var current = [targetIndex + 1] + Array(repeating: 0, count: observed.count)
            for (observedIndex, observedCharacter) in observed.enumerated() {
                let substitution = targetCharacter == observedCharacter ? 0 : 1
                current[observedIndex + 1] = min(
                    previous[observedIndex + 1] + 1,
                    current[observedIndex] + 1,
                    previous[observedIndex] + substitution
                )
            }
            previous = current
        }
        let distance = previous[observed.count]
        let normalizer = max(target.count, observed.count)
        return max(0, 1 - Double(distance) / Double(normalizer))
    }

    private func geometricScore(word: String, path: SwipePath) -> Double {
        guard !path.points.isEmpty else { return 0 }
        let characters = Array(word.lowercased())
        var total = 0.0
        var measured = 0

        for (index, character) in characters.enumerated() {
            guard let geometry = path.keyGeometries[character] else { continue }
            let progress = characters.count == 1 ? 0 : Double(index) / Double(characters.count - 1)
            let sampleIndex = min(
                path.points.count - 1,
                Int((Double(path.points.count - 1) * progress).rounded())
            )
            let sample = path.points[sampleIndex].position
            let distance = hypot(sample.x - geometry.center.x, sample.y - geometry.center.y)
            let scale = max(geometry.frame.width, geometry.frame.height, 1)
            total += min(Double(distance / scale), 2)
            measured += 1
        }
        guard measured > 0 else { return 0 }
        return max(0, 1 - total / Double(measured * 2))
    }
}

final class SwipeTypingEngine {
    private let generator: SwipeCandidateGenerating
    private let ranker: SwipeCandidateRanking
    private let minimumConfidence: Double

    init(
        generator: SwipeCandidateGenerating = BasicSwipeCandidateGenerator(dictionary: LocalSwipeDictionary()),
        ranker: SwipeCandidateRanking = BasicSwipeCandidateRanker(),
        minimumConfidence: Double = 0.46
    ) {
        self.generator = generator
        self.ranker = ranker
        self.minimumConfidence = minimumConfidence
    }

    func recognize(path: SwipePath) -> SwipeTypingResult? {
        let candidates = generator.candidates(for: path)
        let ranked = ranker.rank(candidates, for: path)
        guard let best = ranked.first, best.score >= minimumConfidence else { return nil }
        let runnerUpScore = ranked.dropFirst().first?.score ?? 0
        let confidence = best.score - runnerUpScore * 0.25
        guard confidence >= minimumConfidence * 0.75 else { return nil }
        return SwipeTypingResult(
            word: best.word,
            alternatives: ranked.prefix(5).map(\.word),
            confidence: confidence
        )
    }
}
