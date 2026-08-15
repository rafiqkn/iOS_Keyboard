import UIKit

struct GestureDeletionConfiguration {
    var activationDistance: CGFloat = 24
    var maximumVerticalDrift: CGFloat = 18
    var horizontalDominance: CGFloat = 1.6
    var characterStepDistance: CGFloat = 36
    var wordDistance: CGFloat = 110
    var wordPromotionDistance: CGFloat = 85
    var wordPromotionVelocity: CGFloat = 900
    var sentenceDistance: CGFloat = 190
    var sentencePromotionVelocity: CGFloat = 1_500
    var maximumCharacterCount = 5
    var maximumSentenceCharacterCount = 300
    var enablesSentenceDeletion = false

    static let standard = GestureDeletionConfiguration()
}

enum GestureDeletionLevel: Equatable {
    case characters(Int)
    case previousWord
    case previousSentence
}

enum TextDeletionPlanner {
    static func deletionCount(for level: GestureDeletionLevel, context: String?, configuration: GestureDeletionConfiguration) -> Int {
        switch level {
        case .characters(let count):
            return max(1, min(count, configuration.maximumCharacterCount))
        case .previousWord:
            return previousWordCount(in: context)
        case .previousSentence:
            return min(previousSentenceCount(in: context), configuration.maximumSentenceCharacterCount)
        }
    }

    private static func previousWordCount(in context: String?) -> Int {
        guard let context, !context.isEmpty else { return 1 }
        var range: Range<String.Index>?
        context.enumerateSubstrings(in: context.startIndex..<context.endIndex, options: [.byWords, .reverse]) { _, candidate, _, stop in
            range = candidate
            stop = true
        }
        guard let range else { return 1 }
        return max(1, context[range.lowerBound..<context.endIndex].count)
    }

    private static func previousSentenceCount(in context: String?) -> Int {
        guard let context, !context.isEmpty else { return 1 }
        var range: Range<String.Index>?
        context.enumerateSubstrings(in: context.startIndex..<context.endIndex, options: [.bySentences, .reverse]) { _, candidate, _, stop in
            range = candidate
            stop = true
        }
        guard let range else { return previousWordCount(in: context) }
        return max(1, context[range.lowerBound..<context.endIndex].count)
    }
}

final class HorizontalDeletionGestureRecognizer: UIGestureRecognizer {
    let configuration: GestureDeletionConfiguration
    private(set) var deletionLevel: GestureDeletionLevel?
    private var initialPoint = CGPoint.zero
    private var initialTimestamp: TimeInterval = 0

    init(configuration: GestureDeletionConfiguration = .standard, target: Any?, action: Selector?) {
        self.configuration = configuration
        super.init(target: target, action: action)
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1, let touch = touches.first, let view else {
            state = .failed
            return
        }
        initialPoint = touch.location(in: view)
        initialTimestamp = touch.timestamp
        deletionLevel = nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else {
            state = .failed
            return
        }
        let point = touch.location(in: view)
        let deltaX = point.x - initialPoint.x
        let leftDistance = max(0, -deltaX)
        let verticalDistance = abs(point.y - initialPoint.y)
        guard leftDistance >= configuration.activationDistance,
              verticalDistance <= configuration.maximumVerticalDrift,
              leftDistance >= verticalDistance * configuration.horizontalDominance else {
            if deltaX > configuration.activationDistance * 0.5 || verticalDistance > configuration.maximumVerticalDrift * 2 {
                state = .failed
            }
            return
        }

        state = state == .possible ? .began : .changed
        let duration = max(0.001, touch.timestamp - initialTimestamp)
        deletionLevel = classify(distance: leftDistance, velocity: leftDistance / duration)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = deletionLevel == nil ? .failed : .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }

    override func reset() {
        super.reset()
        deletionLevel = nil
    }

    func cancel() {
        guard isEnabled else { return }
        isEnabled = false
        isEnabled = true
    }

    private func classify(distance: CGFloat, velocity: CGFloat) -> GestureDeletionLevel {
        if configuration.enablesSentenceDeletion,
           distance >= configuration.sentenceDistance,
           velocity >= configuration.sentencePromotionVelocity {
            return .previousSentence
        }
        if distance >= configuration.wordDistance ||
            (distance >= configuration.wordPromotionDistance && velocity >= configuration.wordPromotionVelocity) {
            return .previousWord
        }
        return .characters(max(1, min(Int(distance / configuration.characterStepDistance), configuration.maximumCharacterCount)))
    }
}
