import UIKit

private struct PredictionDisplayRecord {
    let replacementCount: Int
    let expectedSuffix: String
    let generation: Int
}

final class KeyboardViewController: UIInputViewController {
    private let qwertyView = QwertyKeyboardView()
    private let themeManager = ThemeManager()
    private let feedbackManager = KeyboardFeedbackManager()
    private lazy var wordPredictionEngine = BasicWordPredictionEngine()
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
    private var predictionGeneration = 0
    private var predictionWorkItem: DispatchWorkItem?
    private var latestPrediction: PredictionDisplayRecord?
    private var lastPredictionContextBefore: String?
    private var pendingInsertionText: String?
    private var pendingInsertionRestoreText: String?

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

        let predictionEnabled = themeManager.interactionSettings.predictionEnabled
        let contextBefore = predictionEnabled || automaticCapitalizationNeedsContext
            ? textDocumentProxy.documentContextBeforeInput
            : nil
        updateAutomaticShiftIfNeeded(contextBefore: contextBefore)

        if predictionEnabled {
            schedulePredictions(before: contextBefore)
        } else {
            disablePredictionsIfNeeded()
        }
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
        predictionGeneration += 1
        predictionWorkItem?.cancel()
        predictionWorkItem = nil
        lastPredictionContextBefore = nil
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
                updateAutomaticShiftIfNeeded(
                    force: true,
                    contextBefore: textDocumentProxy.documentContextBeforeInput
                )
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
        case .character(let text):
            insertText(text)
            pendingInsertionText = text
            pendingInsertionRestoreText = nil
            cancelPredictionForTextMutation()
            if state.mode == .letters && state.shift == .on {
                state.shift = .off
                qwertyView.updateShift(state.shift)
            }
        case .shift:
            updateShiftState()
        case .backspace:
            textDocumentProxy.deleteBackward()
            cancelPredictionForTextMutation()
            playInputClick()
        case .space:
            pendingInsertionText = insertSpace()
            cancelPredictionForTextMutation()
        case .retractLastInsert:
            retractPendingInsertion()
        case .returnKey:
            insertText("\n")
            cancelPredictionForTextMutation()
            if state.mode == .letters && state.shift != .capsLock {
                state.shift = .on
                qwertyView.updateShift(state.shift)
            }
        case .emoji:
            setMode(.emoji)
        case .mode(let mode):
            setMode(mode)
        case .gestureDelete(let level):
            delete(using: level)
            cancelPredictionForTextMutation()
        case .predictionSelected(let word):
            applyPrediction(word)
        case .spacer:
            break
        }
    }

    private func cancelPredictionForTextMutation() {
        predictionGeneration += 1
        predictionWorkItem?.cancel()
        predictionWorkItem = nil
        lastPredictionContextBefore = nil
        latestPrediction = nil
    }

    /// Undoes the most recent touch-down insertion when the finger slid off
    /// the key before release. Stale requests (later edits, multi-touch) fail
    /// the suffix check and do nothing.
    private func retractPendingInsertion() {
        let inserted = pendingInsertionText
        let restore = pendingInsertionRestoreText
        pendingInsertionText = nil
        pendingInsertionRestoreText = nil
        guard let inserted,
              InsertionRetractionPolicy.isRetractable(
                insertedText: inserted,
                contextBefore: textDocumentProxy.documentContextBeforeInput
              ) else { return }
        for _ in 0..<inserted.count {
            textDocumentProxy.deleteBackward()
        }
        if let restore, !restore.isEmpty {
            textDocumentProxy.insertText(restore)
        }
        cancelPredictionForTextMutation()
    }

    private func disablePredictionsIfNeeded() {
        guard predictionWorkItem != nil ||
                lastPredictionContextBefore != nil ||
                latestPrediction != nil ||
                qwertyView.hasVisibleCandidates else { return }
        cancelPredictionForTextMutation()
        qwertyView.showCandidates(.hidden)
    }

    private func schedulePredictions(before: String?) {
        guard state.mode == .letters else {
            disablePredictionsIfNeeded()
            return
        }
        guard before != lastPredictionContextBefore else { return }
        lastPredictionContextBefore = before

        predictionGeneration += 1
        predictionWorkItem?.cancel()
        let generation = predictionGeneration
        let engine = wordPredictionEngine
        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  workItem?.isCancelled == false,
                  let context = TextContextParser.parse(before: before, after: nil) else { return }
            let predictions = engine.predict(for: context)
            guard workItem?.isCancelled == false else { return }
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
        predictionWorkItem = workItem
        if let workItem {
            predictionQueue.async(execute: workItem)
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
        }
    }

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
        playInputClick()
    }

    @discardableResult
    private func insertSpace() -> String {
        let now = ProcessInfo.processInfo.systemUptime
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        let inserted: String
        if now - lastSpaceTapTime < 0.42, context.hasSuffix(" "), shouldInsertPeriod(after: context) {
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(". ")
            inserted = ". "
            pendingInsertionRestoreText = " "
        } else {
            textDocumentProxy.insertText(" ")
            inserted = " "
        }
        lastSpaceTapTime = now
        playInputClick()
        return inserted
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
        qwertyView.updateShift(state.shift)
    }

    private func updateAutomaticShiftIfNeeded(
        force: Bool = false,
        contextBefore: String?
    ) {
        guard state.mode == .letters, state.shift != .capsLock else { return }
        let shouldShift = shouldAutomaticallyCapitalize(contextBefore: contextBefore)
        if force || !didSetInitialShiftState || state.shift != (shouldShift ? .on : .off) {
            state.shift = shouldShift ? .on : .off
            didSetInitialShiftState = true
            qwertyView.updateShift(state.shift)
        }
    }

    private var automaticCapitalizationNeedsContext: Bool {
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .words, .sentences:
            return true
        case .none, .allCharacters:
            return false
        @unknown default:
            return false
        }
    }

    private func shouldAutomaticallyCapitalize(contextBefore context: String?) -> Bool {
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            guard let context else { return true }
            return context.isEmpty || context.last?.isWhitespace == true
        case .sentences:
            guard let context else { return true }
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
