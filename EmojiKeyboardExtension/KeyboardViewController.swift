import UIKit

private struct PredictionDisplayRecord {
    let replacementCount: Int
    let expectedSuffix: String
    let generation: Int
}

private struct SwipeInsertionRecord {
    let insertedCount: Int
    let leadingSpace: Bool
    let capitalized: Bool
}

final class KeyboardViewController: UIInputViewController {
    private let qwertyView = QwertyKeyboardView()
    private let themeManager = ThemeManager()
    private let feedbackManager = KeyboardFeedbackManager()
    private lazy var swipeTypingEngine = SwipeTypingEngine()
    private lazy var wordPredictionEngine = BasicWordPredictionEngine()
    private let swipeRecognitionQueue = DispatchQueue(
        label: "com.rafiqkn.KnKeys.swipe-recognition",
        qos: .userInitiated
    )
    private let predictionQueue = DispatchQueue(
        label: "com.rafiqkn.KnKeys.word-prediction",
        qos: .userInitiated
    )
    private lazy var emojiView: EmojiKeyboardView = {
        let view = EmojiKeyboardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()

    private var state = KeyboardState()
    private var heightConstraint: NSLayoutConstraint?
    private var appliedKeyboardHeight: CGFloat = 0
    private var lastShiftTapTime: TimeInterval = 0
    private var lastSpaceTapTime: TimeInterval = 0
    private var didSetInitialShiftState = false
    private var swipeGeneration = 0
    private var predictionGeneration = 0
    private var latestPrediction: PredictionDisplayRecord?
    private var swipeInsertedTrailingSpace = false
    private var lastSwipeInsertion: SwipeInsertionRecord?

    override func viewDidLoad() {
        super.viewDidLoad()
        themeManager.reloadIfNeeded(for: textDocumentProxy.keyboardAppearance ?? .default, force: true)
        qwertyView.delegate = self
        installKeyboardView(qwertyView)
        updateHeight()
        updateAppearanceAndLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAppearanceAndLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateHeight()
        updateAppearanceAndLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass else { return }
        updateHeight()
        updateAppearanceAndLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        qwertyView.cancelActiveInteractions()
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            self.updateHeight()
            self.updateAppearanceAndLayout(size: size)
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        let themeChanged = themeManager.reloadIfNeeded(for: textDocumentProxy.keyboardAppearance ?? .default)
        if themeChanged {
            updateHeight()
        }
        updateAutomaticShiftIfNeeded()
        schedulePredictions()
        updateAppearanceAndLayout()
    }

    private func installKeyboardView(_ keyboardView: UIView) {
        for subview in view.subviews where subview === qwertyView || subview === emojiView {
            subview.removeFromSuperview()
        }
        view.addSubview(keyboardView)
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setMode(_ mode: KeyboardMode) {
        guard state.mode != mode else { return }
        swipeGeneration += 1
        predictionGeneration += 1
        latestPrediction = nil
        qwertyView.showCandidates(.hidden)
        qwertyView.cancelActiveInteractions()
        if state.mode != .emoji {
            state.previousTextMode = state.mode
        }
        state.mode = mode
        updateHeight()
        if mode == .emoji {
            installKeyboardView(emojiView)
        } else {
            installKeyboardView(qwertyView)
            if mode == .letters {
                updateAutomaticShiftIfNeeded(force: true)
            }
        }
        updateAppearanceAndLayout()
    }

    private func updateHeight() {
        let height = KeyboardHeightPolicy.outerHeight(
            keyHeight: CGFloat(themeManager.currentTheme.keyHeight),
            idiom: traitCollection.userInterfaceIdiom,
            verticalSizeClass: traitCollection.verticalSizeClass
        )
        guard abs(height - appliedKeyboardHeight) > 0.5 else { return }
        appliedKeyboardHeight = height
        if heightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: height)
            constraint.priority = .defaultHigh
            constraint.isActive = true
            heightConstraint = constraint
        } else {
            heightConstraint?.constant = height
        }
    }

    private func updateAppearanceAndLayout(size: CGSize? = nil) {
        let theme = themeManager.currentTheme
        view.backgroundColor = theme.keyboardBackground.uiColor
        qwertyView.updateDeletionFeedbackAnimation(
            enabled: themeManager.deletionFeedbackAnimationEnabled
        )
        qwertyView.updateKeyPopup(
            enabled: themeManager.interactionSettings.keyPopupEnabled
        )
        feedbackManager.soundMode = themeManager.interactionSettings.keystrokeSoundMode
        qwertyView.update(
            state: state,
            theme: theme,
            size: size ?? view.bounds.size,
            returnKeyTitle: returnKeyTitle
        )
        if state.mode == .emoji {
            emojiView.updateAppearance(theme: theme)
        }
    }

    private func handle(_ action: KeyboardKeyAction) {
        switch action {
        case .swipePath, .swipeAlternative, .predictionSelected:
            break
        default:
            swipeGeneration += 1
            lastSwipeInsertion = nil
            latestPrediction = nil
            qwertyView.showCandidates(.hidden)
        }
        switch action {
        case .character(let text):
            if swipeInsertedTrailingSpace, isPunctuation(text) {
                textDocumentProxy.deleteBackward()
            }
            swipeInsertedTrailingSpace = false
            insertText(text)
            schedulePredictions()
            if state.mode == .letters && state.shift == .on {
                state.shift = .off
                updateAppearanceAndLayout()
            }
        case .shift:
            updateShiftState()
        case .backspace:
            swipeInsertedTrailingSpace = false
            textDocumentProxy.deleteBackward()
            playInputClick()
            updateAutomaticShiftIfNeeded()
            schedulePredictions()
        case .space:
            swipeInsertedTrailingSpace = false
            insertSpace()
            schedulePredictions()
        case .returnKey:
            swipeInsertedTrailingSpace = false
            insertText("\n")
            schedulePredictions()
            if state.mode == .letters && state.shift != .capsLock {
                state.shift = .on
                updateAppearanceAndLayout()
            }
        case .emoji:
            setMode(.emoji)
        case .mode(let mode):
            setMode(mode)
        case .gestureDelete(let level):
            delete(using: level)
        case .swipePath(let path):
            recognizeSwipe(path)
        case .swipeAlternative(let word):
            replaceLastSwipeWord(with: word)
        case .predictionSelected(let word):
            applyPrediction(word)
        case .spacer:
            break
        }
    }

    private func schedulePredictions() {
        guard lastSwipeInsertion == nil else { return }
        guard state.mode == .letters,
              let context = TextContextParser.parse(
                before: textDocumentProxy.documentContextBeforeInput,
                after: textDocumentProxy.documentContextAfterInput
              ) else {
            predictionGeneration += 1
            latestPrediction = nil
            qwertyView.showCandidates(.hidden)
            return
        }

        predictionGeneration += 1
        let generation = predictionGeneration
        let engine = wordPredictionEngine
        predictionQueue.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self, generation == self.predictionGeneration else { return }
            let predictions = engine.predict(for: context)
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      generation == self.predictionGeneration,
                      self.state.mode == .letters else { return }
                guard !predictions.isEmpty else {
                    self.latestPrediction = nil
                    self.qwertyView.showCandidates(.hidden)
                    return
                }
                self.latestPrediction = PredictionDisplayRecord(
                    replacementCount: context.replacementCount,
                    expectedSuffix: context.currentWord,
                    generation: generation
                )
                self.qwertyView.showCandidates(.predictions(predictions.map(\.word)))
            }
        }
    }

    private func applyPrediction(_ word: String) {
        guard let record = latestPrediction,
              record.generation == predictionGeneration else { return }
        let currentContext = textDocumentProxy.documentContextBeforeInput ?? ""
        guard currentContext.lowercased().hasSuffix(record.expectedSuffix.lowercased()) else {
            latestPrediction = nil
            qwertyView.showCandidates(.hidden)
            return
        }
        for _ in 0..<record.replacementCount {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(word + " ")
        latestPrediction = nil
        qwertyView.showCandidates(.hidden)
        playInputClick()
        schedulePredictions()
    }

    private func recognizeSwipe(_ path: SwipePath) {
        predictionGeneration += 1
        latestPrediction = nil
        qwertyView.showCandidates(.hidden)
        swipeGeneration += 1
        let generation = swipeGeneration
        swipeRecognitionQueue.async { [weak self] in
            guard let self else { return }
            let result = self.swipeTypingEngine.recognize(path: path)
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      generation == self.swipeGeneration,
                      self.state.mode == .letters,
                      let result else { return }
                self.insertSwipeWord(result.word)
                self.qwertyView.showCandidates(.swipeAlternatives(result.alternatives))
            }
        }
    }

    private func insertSwipeWord(_ word: String) {
        let output: String
        if state.shift != .off {
            output = word.prefix(1).uppercased() + word.dropFirst()
        } else {
            output = word
        }

        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        let needsLeadingSpace = context.last.map { $0.isLetter || $0.isNumber } ?? false
        let insertedText = (needsLeadingSpace ? " " : "") + output + " "
        textDocumentProxy.insertText(insertedText)
        lastSwipeInsertion = SwipeInsertionRecord(
            insertedCount: insertedText.count,
            leadingSpace: needsLeadingSpace,
            capitalized: state.shift != .off
        )
        swipeInsertedTrailingSpace = true
        playInputClick()

        if state.shift == .on {
            state.shift = .off
            updateAppearanceAndLayout()
        }
    }

    private func replaceLastSwipeWord(with word: String) {
        guard let record = lastSwipeInsertion else { return }
        for _ in 0..<record.insertedCount {
            textDocumentProxy.deleteBackward()
        }
        let output = record.capitalized
            ? word.prefix(1).uppercased() + word.dropFirst()
            : word
        let replacement = (record.leadingSpace ? " " : "") + output + " "
        textDocumentProxy.insertText(replacement)
        lastSwipeInsertion = SwipeInsertionRecord(
            insertedCount: replacement.count,
            leadingSpace: record.leadingSpace,
            capitalized: record.capitalized
        )
        swipeInsertedTrailingSpace = true
        playInputClick()
    }

    private func isPunctuation(_ text: String) -> Bool {
        guard text.count == 1, let scalar = text.unicodeScalars.first else { return false }
        return CharacterSet.punctuationCharacters.contains(scalar)
    }

    private func delete(using level: GestureDeletionLevel) {
        let count = TextDeletionPlanner.deletionCount(
            for: level,
            context: textDocumentProxy.documentContextBeforeInput,
            configuration: GestureDeletionConfiguration.standard
        )
        for _ in 0..<count {
            textDocumentProxy.deleteBackward()
        }
        if count > 0 {
            playInputClick()
            updateAutomaticShiftIfNeeded()
            schedulePredictions()
        }
    }

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
        playInputClick()
    }

    private func insertSpace() {
        let now = ProcessInfo.processInfo.systemUptime
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        if now - lastSpaceTapTime < 0.42, context.hasSuffix(" "), shouldInsertPeriod(after: context) {
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(". ")
        } else {
            textDocumentProxy.insertText(" ")
        }
        lastSpaceTapTime = now
        playInputClick()
    }

    private func shouldInsertPeriod(after context: String) -> Bool {
        guard context.count >= 2 else { return false }
        let textBeforeSpace = context.dropLast()
        guard let last = textBeforeSpace.last else { return false }
        return last.isLetter || last.isNumber || last == ")" || last == "]"
    }

    private func updateShiftState() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastShiftTapTime < 0.35 {
            state.shift = .capsLock
        } else {
            switch state.shift {
            case .off:
                state.shift = .on
            case .on, .capsLock:
                state.shift = .off
            }
        }
        lastShiftTapTime = now
        didSetInitialShiftState = true
        updateAppearanceAndLayout()
    }

    private func updateAutomaticShiftIfNeeded(force: Bool = false) {
        guard state.mode == .letters, state.shift != .capsLock else { return }
        let shouldShift = shouldAutomaticallyCapitalize()
        if force || !didSetInitialShiftState || state.shift != (shouldShift ? .on : .off) {
            state.shift = shouldShift ? .on : .off
            didSetInitialShiftState = true
            updateAppearanceAndLayout()
        }
    }

    private func shouldAutomaticallyCapitalize() -> Bool {
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            guard let context = textDocumentProxy.documentContextBeforeInput else { return true }
            return context.isEmpty || context.last?.isWhitespace == true
        case .sentences:
            guard let context = textDocumentProxy.documentContextBeforeInput else { return true }
            let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let last = trimmed.last else { return true }
            return ".!?".contains(last)
        @unknown default:
            return false
        }
    }

    private var returnKeyTitle: String {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: return "go"
        case .google: return "Google"
        case .join: return "join"
        case .next: return "next"
        case .route: return "route"
        case .search: return "search"
        case .send: return "send"
        case .yahoo: return "Yahoo"
        case .done: return "done"
        case .emergencyCall: return "emergency"
        case .continue: return "continue"
        case .default: return "return"
        @unknown default: return "return"
        }
    }

    private func playInputClick() {
        feedbackManager.playKeyClick()
    }
}

extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

extension KeyboardViewController: QwertyKeyboardViewDelegate {
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTrigger action: KeyboardKeyAction) {
        handle(action)
    }

}

extension KeyboardViewController: EmojiKeyboardViewDelegate {
    func emojiKeyboardView(_ view: EmojiKeyboardView, didTrigger action: KeyboardKeyAction) {
        handle(action)
    }


    func emojiKeyboardViewRequestedTextKeyboard(_ view: EmojiKeyboardView) {
        setMode(state.previousTextMode == .emoji ? .letters : state.previousTextMode)
    }
}
