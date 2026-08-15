import UIKit

final class SwipeTypingGestureRecognizer: UIGestureRecognizer {
    private enum Intent {
        case undecided
        case typing
    }

    var keyGeometries: [Character: SwipeKeyGeometry] = [:]
    private(set) var result: SwipeGestureResult?

    private let activationDistance: CGFloat
    private let sampleDistance: CGFloat
    private let minimumDistinctKeys: Int

    private var intent: Intent = .undecided
    private var initialPoint = CGPoint.zero
    private var startedOnHomeRow = false
    private var samples: [SwipePathPoint] = []
    private var distinctKeys: [Character] = []

    init(
        activationDistance: CGFloat = 18,
        sampleDistance: CGFloat = 7,
        minimumDistinctKeys: Int = 3,
        target: Any?,
        action: Selector?
    ) {
        self.activationDistance = activationDistance
        self.sampleDistance = sampleDistance
        self.minimumDistinctKeys = minimumDistinctKeys
        super.init(target: target, action: action)
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1,
              let touch = touches.first,
              let view,
              let geometry = geometry(at: touch.location(in: view)) else {
            state = .failed
            return
        }
        initialPoint = touch.location(in: view)
        startedOnHomeRow = "asdfghjkl".contains(geometry.letter)
        appendSample(at: initialPoint, timestamp: touch.timestamp, geometry: geometry, force: true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else {
            state = .failed
            return
        }
        let point = touch.location(in: view)
        if let geometry = nearestGeometry(to: point) {
            appendSample(at: point, timestamp: touch.timestamp, geometry: geometry)
        }

        let deltaX = point.x - initialPoint.x
        let deltaY = point.y - initialPoint.y
        let distance = hypot(deltaX, deltaY)

        if intent == .undecided {
            let remainsOnHomeRow = distinctKeys.allSatisfy { "asdfghjkl".contains($0) }
            if startedOnHomeRow && remainsOnHomeRow && abs(deltaX) > abs(deltaY) * 1.4 {
                return
            }
            if distance >= activationDistance && distinctKeys.count >= minimumDistinctKeys {
                intent = .typing
                state = .began
            } else if abs(deltaY) > 54 && distinctKeys.count < 2 {
                state = .failed
                return
            }
        } else if state == .began || state == .changed {
            state = .changed
        }

        guard state == .began || state == .changed else { return }
        if intent == .typing {
            result = .typing(SwipePath(points: samples, keyGeometries: keyGeometries))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed, result != nil {
            state = .ended
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }

    override func reset() {
        super.reset()
        intent = .undecided
        result = nil
        samples.removeAll(keepingCapacity: true)
        distinctKeys.removeAll(keepingCapacity: true)
        startedOnHomeRow = false
    }

    func cancel() {
        guard isEnabled else { return }
        isEnabled = false
        isEnabled = true
    }

    private func appendSample(
        at point: CGPoint,
        timestamp: TimeInterval,
        geometry: SwipeKeyGeometry,
        force: Bool = false
    ) {
        let movedEnough: Bool
        if let previous = samples.last {
            movedEnough = hypot(point.x - previous.position.x, point.y - previous.position.y) >= sampleDistance
        } else {
            movedEnough = true
        }
        guard force || movedEnough || samples.last?.letter != geometry.letter else { return }
        samples.append(SwipePathPoint(position: point, timestamp: timestamp, letter: geometry.letter))
        if distinctKeys.last != geometry.letter {
            distinctKeys.append(geometry.letter)
        }
    }

    private func geometry(at point: CGPoint) -> SwipeKeyGeometry? {
        keyGeometries.values.first { $0.frame.contains(point) }
    }

    private func nearestGeometry(to point: CGPoint) -> SwipeKeyGeometry? {
        keyGeometries.values.min {
            distance(from: point, to: $0.center) < distance(from: point, to: $1.center)
        }
    }

    private func distance(from point: CGPoint, to center: CGPoint) -> CGFloat {
        hypot(point.x - center.x, point.y - center.y)
    }

}
