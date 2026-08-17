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
    private lazy var emojiView: EmojiKeyboardView = {
        let view = EmojiKeyboardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    private lazy var clipboardView: ClipboardKeyboardView = {
        let view = ClipboardKeyboardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    private lazy var settingsView: SettingsKeyboardView = {
        let view = SettingsKeyboardView()
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
        ClipboardPasteboardSync.sweep()
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
        // Cheap changeCount probe: folds in a fresh copy even when the
        // keyboard stayed up (e.g. switching fields). No timers/background use.
        ClipboardPasteboardSync.sweep()
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
        for subview in view.subviews where subview === qwertyView || subview === emojiView || subview === clipboardView || subview === settingsView {
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
        lastPredictionContextBefore = nil
        latestPrediction = nil
        qwertyView.showCandidates(.hidden, animated: false)
        qwertyView.cancelActiveInteractions()
        if state.mode != .emoji && state.mode != .clipboard {
            state.previousTextMode = state.mode
        }
        state.mode = mode
        updateHeight()
        switch mode {
        case .emoji:
            installKeyboardView(emojiView)
        case .clipboard:
            installKeyboardView(clipboardView)
            ClipboardPasteboardSync.sweep()
            clipboardView.reloadHistory()
        case .settings:
            installKeyboardView(settingsView)
            settingsView.configure(settings: themeManager.interactionSettings)
        default:
            installKeyboardView(qwertyView)
            if mode == .letters {
                updateAutomaticShiftIfNeeded(
                    force: true,
                    contextBefore: textDocumentProxy.documentContextBeforeInput
                )
                schedulePredictions(before: textDocumentProxy.documentContextBeforeInput)
            }
        }
        updateAppearanceAndLayout()
    }

    /// One-tap paste from the suggestion bar: refreshes from the system
    /// pasteboard (a no-op when unreadable), then inserts the newest stored
    /// record. With nothing stored yet the clipboard panel is opened instead so
    /// the user sees the current state rather than a silent no-op.
    private func pasteMostRecentClipboardItem() {
        ClipboardPasteboardSync.sweep()
        guard let newest = ClipboardHistoryStore().load().first else {
            setMode(.clipboard)
            return
        }
        playInputClick()
        cancelPredictionForTextMutation()
        textDocumentProxy.insertText(newest.text)
        pendingInsertionText = nil
        pendingInsertionRestoreText = nil
        refreshPredictionsAfterMutation()
    }

    /// Applies interaction-setting changes made in the in-keyboard panel so
    /// they take effect immediately instead of waiting for the next reload.
    private func applyInteractionSettings(_ settings: KeyboardInteractionSettings) {
        let old = themeManager.interactionSettings
        themeManager.updateInteractionSettings(settings)
        qwertyView.updateDeletionFeedbackAnimation(
            enabled: themeManager.deletionFeedbackAnimationEnabled
        )
        qwertyView.updateKeyPopup(enabled: settings.keyPopupEnabled)
        feedbackManager.soundMode = settings.keystrokeSoundMode
        if old.predictionEnabled == settings.predictionEnabled {
            return
        }
        if settings.predictionEnabled {
            schedulePredictions(before: textDocumentProxy.documentContextBeforeInput)
        } else {
            disablePredictionsIfNeeded()
        }
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
        } else if state.mode == .clipboard {
            clipboardView.updateAppearance(theme: theme)
        } else if state.mode == .settings {
            settingsView.updateAppearance(theme: theme)
        }
    }

    private func handle(_ action: KeyboardKeyAction) {
        switch action {
        case .character(let text):
            // Invalidate stale suggestions BEFORE the mutation: the refresh
            // below re-schedules predictions for the new context directly,
            // without depending on host textDidChange delivery timing.
            cancelPredictionForTextMutation()
            insertText(text)
            pendingInsertionText = text
            pendingInsertionRestoreText = nil
            refreshPredictionsAfterMutation()
            if state.mode == .letters && state.shift == .on {
                state.shift = .off
                qwertyView.updateShift(state.shift)
            }
        case .shift:
            updateShiftState()
        case .backspace:
            cancelPredictionForTextMutation()
            textDocumentProxy.deleteBackward()
            refreshPredictionsAfterMutation()
            playInputClick()
        case .space:
            cancelPredictionForTextMutation()
            pendingInsertionText = insertSpace()
            refreshPredictionsAfterMutation()
        case .retractLastInsert:
            retractPendingInsertion()
        case .returnKey:
            cancelPredictionForTextMutation()
            insertText("\n")
            refreshPredictionsAfterMutation()
            if state.mode == .letters && state.shift != .capsLock {
                state.shift = .on
                qwertyView.updateShift(state.shift)
            }
        case .emoji:
            setMode(.emoji)
        case .mode(let mode):
            setMode(mode)
        case .settings:
            setMode(.settings)
        case .clipboard:
            setMode(.clipboard)
        case .pasteFromClipboard:
            pasteMostRecentClipboardItem()
        case .gestureDelete(let level):
            cancelPredictionForTextMutation()
            delete(using: level)
            refreshPredictionsAfterMutation()
        case .predictionSelected(let word):
            applyPrediction(word)
        case .spacer:
            break
        }
    }

    /// Recomputes suggestions from the document proxy right after this
    /// keyboard mutated the text. The proxy reflects inserts/deletes
    /// synchronously, so the bar is always correct the moment a finger
    /// lifts — no reliance on the host's textDidChange callback. The
    /// textDidChange path remains as a backup for edits made outside this
    /// keyboard; the lastPredictionContextBefore guard deduplicates.
    private func refreshPredictionsAfterMutation() {
        guard themeManager.interactionSettings.predictionEnabled else { return }
        schedulePredictions(before: textDocumentProxy.documentContextBeforeInput)
    }

    private func cancelPredictionForTextMutation() {
        predictionGeneration += 1
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
        cancelPredictionForTextMutation()
        for _ in 0..<inserted.count {
            textDocumentProxy.deleteBackward()
        }
        if let restore, !restore.isEmpty {
            textDocumentProxy.insertText(restore)
        }
        refreshPredictionsAfterMutation()
    }

    private func disablePredictionsIfNeeded() {
        guard lastPredictionContextBefore != nil ||
                latestPrediction != nil ||
                qwertyView.hasVisibleCandidates else { return }
        cancelPredictionForTextMutation()
        qwertyView.showCandidates(.hidden, animated: false)
    }

    private func schedulePredictions(before: String?) {
        guard state.mode == .letters else {
            disablePredictionsIfNeeded()
            return
        }
        guard before != lastPredictionContextBefore else { return }
        lastPredictionContextBefore = before

        predictionGeneration += 1
        let generation = predictionGeneration
        guard let context = TextContextParser.parse(before: before, after: nil) else {
            latestPrediction = nil
            qwertyView.showCandidates(.hidden)
            return
        }
        let predictions = wordPredictionEngine.predict(for: context)
        guard !predictions.isEmpty else {
            latestPrediction = nil
            qwertyView.showCandidates(.hidden)
            return
        }
        latestPrediction = PredictionDisplayRecord(
            replacementCount: context.replacementCount,
            expectedSuffix: context.currentWord,
            generation: generation
        )
        qwertyView.showCandidates(.predictions(predictions.map(\.word)))
    }

    private func applyPrediction(_ word: String) {
        guard let record = latestPrediction,
              record.generation == predictionGeneration else { return }
        let currentContext = textDocumentProxy.documentContextBeforeInput ?? ""
        // The tapped suggestion is only valid if the word under the cursor is
        // still exactly the word it was built from. A plain hasSuffix check
        // would wrongly accept "help".hasSuffix("hel") and then delete the
        // wrong number of characters.
        let currentWord = TextContextParser.parse(before: currentContext, after: nil)?.currentWord ?? ""
        guard currentWord == record.expectedSuffix else {
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
        refreshPredictionsAfterMutation()
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

extension KeyboardViewController: ClipboardKeyboardViewDelegate {
    func clipboardKeyboardView(_ view: ClipboardKeyboardView, didTrigger action: KeyboardKeyAction) {
        handle(action)
    }

    func clipboardKeyboardViewRequestedTextKeyboard(_ view: ClipboardKeyboardView) {
        setMode(state.previousTextMode == .clipboard ? .letters : state.previousTextMode)
    }
}

extension KeyboardViewController: SettingsKeyboardViewDelegate {
    func settingsKeyboardView(_ view: SettingsKeyboardView, didTrigger action: KeyboardKeyAction) {
        handle(action)
    }

    func settingsKeyboardViewRequestedTextKeyboard(_ view: SettingsKeyboardView) {
        setMode(state.previousTextMode == .settings ? .letters : state.previousTextMode)
    }

    func settingsKeyboardView(_ view: SettingsKeyboardView, didChange settings: KeyboardInteractionSettings) {
        applyInteractionSettings(settings)
    }
}
