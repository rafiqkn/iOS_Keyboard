import UIKit

final class KeyboardViewController: UIInputViewController {
    private let qwertyView = QwertyKeyboardView()
    private lazy var emojiView: EmojiKeyboardView = {
        let view = EmojiKeyboardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()

    private var state = KeyboardState()
    private var heightConstraint: NSLayoutConstraint?
    private var lastShiftTapTime: TimeInterval = 0
    private var lastSpaceTapTime: TimeInterval = 0
    private var didSetInitialShiftState = false

    override func viewDidLoad() {
        super.viewDidLoad()
        qwertyView.delegate = self
        installKeyboardView(qwertyView)
        updateHeight(for: view.bounds.size)
        updateAppearanceAndLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeight(for: view.bounds.size)
        updateAppearanceAndLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        qwertyView.cancelActiveInteractions()
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            self.updateHeight(for: size)
            self.updateAppearanceAndLayout(size: size)
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateAutomaticShiftIfNeeded()
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
        qwertyView.cancelActiveInteractions()
        if state.mode != .emoji {
            state.previousTextMode = state.mode
        }
        state.mode = mode
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

    private func updateHeight(for size: CGSize) {
        let landscape = size.width > size.height && size.height > 0
        let height: CGFloat
        if traitCollection.userInterfaceIdiom == .pad {
            height = landscape ? 320 : 350
        } else {
            height = landscape ? 220 : 300
        }
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
        let darkMode = textDocumentProxy.keyboardAppearance == .dark
        view.backgroundColor = darkMode
            ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)
        qwertyView.update(
            state: state,
            darkMode: darkMode,
            size: size ?? view.bounds.size,
            returnKeyTitle: returnKeyTitle
        )
        if state.mode == .emoji {
            emojiView.updateAppearance(darkMode: darkMode)
        }
    }

    private func handle(_ action: KeyboardKeyAction) {
        switch action {
        case .character(let text):
            insertText(text)
            if state.mode == .letters && state.shift == .on {
                state.shift = .off
                updateAppearanceAndLayout()
            }
        case .shift:
            updateShiftState()
        case .backspace:
            textDocumentProxy.deleteBackward()
            playInputClick()
            updateAutomaticShiftIfNeeded()
        case .space:
            insertSpace()
        case .returnKey:
            insertText("\n")
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
        case .nextKeyboard, .spacer:
            break
        }
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
        UIDevice.current.playInputClick()
    }
}

extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

extension KeyboardViewController: QwertyKeyboardViewDelegate {
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTrigger action: KeyboardKeyAction) {
        handle(action)
    }

    func qwertyKeyboardView(_ view: QwertyKeyboardView, handleInputModeListFrom control: UIControl, event: UIEvent) {
        handleInputModeList(from: control, with: event)
    }
}

extension KeyboardViewController: EmojiKeyboardViewDelegate {
    func emojiKeyboardView(_ view: EmojiKeyboardView, didTrigger action: KeyboardKeyAction) {
        handle(action)
    }

    func emojiKeyboardView(_ view: EmojiKeyboardView, handleInputModeListFrom control: UIControl, event: UIEvent) {
        handleInputModeList(from: control, with: event)
    }

    func emojiKeyboardViewRequestedTextKeyboard(_ view: EmojiKeyboardView) {
        setMode(state.previousTextMode == .emoji ? .letters : state.previousTextMode)
    }
}
