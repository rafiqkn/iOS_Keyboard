import UIKit

protocol QwertyKeyboardViewDelegate: AnyObject {
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTrigger action: KeyboardKeyAction)
}

final class QwertyKeyboardView: UIView {
    weak var delegate: QwertyKeyboardViewDelegate?

    private let rowsStack = UIStackView()
    private let suggestionStack = UIStackView()
    private var state = KeyboardState()
    private var keyControls: [KeyboardKeyControl] = []
    private var metrics: KeyboardMetrics?
    private var theme = KeyboardTheme.light
    private var returnKeyTitle = "return"
    private var swipeGesture: SwipeTypingGestureRecognizer?
    private var homeRowGesture: HorizontalDeletionGestureRecognizer?
    private weak var homeRowView: UIView?
    private var deletionFeedbackAnimationEnabled = false
    private var deleteDelayWorkItem: DispatchWorkItem?
    private var deleteRepeatTimer: Timer?
    private var topConstraint: NSLayoutConstraint!
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        suggestionStack.translatesAutoresizingMaskIntoConstraints = false
        suggestionStack.axis = .horizontal
        suggestionStack.distribution = .fillEqually
        suggestionStack.spacing = 1
        suggestionStack.isHidden = true
        suggestionStack.layer.cornerRadius = 6
        suggestionStack.clipsToBounds = true
        rowsStack.axis = .vertical
        rowsStack.distribution = .fillEqually
        addSubview(rowsStack)
        addSubview(suggestionStack)
        topConstraint = rowsStack.topAnchor.constraint(equalTo: topAnchor)
        leadingConstraint = rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor)
        trailingConstraint = rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor)
        bottomConstraint = rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            topConstraint,
            leadingConstraint,
            trailingConstraint,
            bottomConstraint,
            suggestionStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            suggestionStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            suggestionStack.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.72),
            suggestionStack.heightAnchor.constraint(equalToConstant: 34)
        ])
        rebuildRows()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        cancelActiveInteractions()
    }

    func cancelActiveInteractions() {
        stopDeleteRepeat()
        swipeGesture?.cancel()
        homeRowGesture?.cancel()
    }

    func update(state: KeyboardState, theme: KeyboardTheme, size: CGSize, returnKeyTitle: String) {
        let modeChanged = self.state.mode != state.mode
        let shiftChanged = self.state.shift != state.shift
        let themeChanged = self.theme != theme
        self.state = state
        self.theme = theme
        self.returnKeyTitle = returnKeyTitle
        let nextMetrics = KeyboardMetrics.resolve(
            for: size,
            idiom: traitCollection.userInterfaceIdiom,
            theme: theme
        )

        if modeChanged {
            rebuildRows()
        } else if shiftChanged {
            updateLetterCase()
        }
        if metrics != nextMetrics || themeChanged {
            metrics = nextMetrics
            rowsStack.spacing = nextMetrics.rowSpacing
            topConstraint.constant = nextMetrics.verticalPadding
            leadingConstraint.constant = nextMetrics.horizontalPadding
            trailingConstraint.constant = -nextMetrics.horizontalPadding
            bottomConstraint.constant = -nextMetrics.verticalPadding
        }
        updateKeyAppearance()
    }

    private func rebuildRows() {
        stopDeleteRepeat()
        if let swipeGesture {
            swipeGesture.cancel()
            removeGestureRecognizer(swipeGesture)
            self.swipeGesture = nil
        }
        homeRowGesture?.cancel()
        homeRowGesture = nil
        homeRowView = nil
        keyControls.removeAll(keepingCapacity: true)
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let uppercase = state.shift != .off
        for row in KeyboardLayout.rows(for: state.mode, uppercase: uppercase) {
            let rowView = UIStackView()
            rowView.axis = .horizontal
            rowView.distribution = .fill
            rowView.alignment = .fill
            rowView.spacing = metrics?.keySpacing ?? 5

            if row.role == .homeLetters {
                let deletionGesture = HorizontalDeletionGestureRecognizer(
                    target: self,
                    action: #selector(homeRowGestureChanged(_:))
                )
                rowView.addGestureRecognizer(deletionGesture)
                homeRowGesture = deletionGesture
                homeRowView = rowView
            }

            var previousKey: KeyboardKeyControl?
            for descriptor in row.keys {
                let key = KeyboardKeyControl(descriptor: descriptor)
                configureInteraction(for: key)
                rowView.addArrangedSubview(key)
                keyControls.append(key)

                if let previousKey {
                    key.widthAnchor.constraint(
                        equalTo: previousKey.widthAnchor,
                        multiplier: descriptor.width / previousKey.widthUnit
                    ).isActive = true
                }
                previousKey = key
            }
            rowsStack.addArrangedSubview(rowView)
        }
        configureSwipeGestureIfNeeded()
        updateKeyAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSwipeKeyGeometries()
    }

    private func configureSwipeGestureIfNeeded() {
        guard state.mode == .letters else { return }
        let recognizer = SwipeTypingGestureRecognizer(
            target: self,
            action: #selector(swipeGestureChanged(_:))
        )
        if let homeRowGesture {
            recognizer.require(toFail: homeRowGesture)
        }
        addGestureRecognizer(recognizer)
        swipeGesture = recognizer
        setNeedsLayout()
    }

    private func updateSwipeKeyGeometries() {
        guard let swipeGesture, state.mode == .letters else { return }
        var geometries: [Character: SwipeKeyGeometry] = [:]
        for key in keyControls {
            guard case .character(let value) = key.action,
                  value.count == 1,
                  let character = value.lowercased().first,
                  character.isLetter else { continue }
            geometries[character] = SwipeKeyGeometry(
                letter: character,
                frame: key.convert(key.bounds, to: self)
            )
        }
        swipeGesture.keyGeometries = geometries
    }

    private func updateLetterCase() {
        guard state.mode == .letters else { return }
        let uppercase = state.shift != .off
        for key in keyControls {
            switch key.action {
            case .character(let value) where value.count == 1 && value.first?.isLetter == true:
                key.setCharacter(uppercase ? value.uppercased() : value.lowercased())
            case .shift:
                key.setSymbol(uppercase ? "shift.fill" : "shift")
            default:
                break
            }
        }
    }

    private func configureInteraction(for key: KeyboardKeyControl) {
        switch key.action {
        case .backspace:
            key.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
            key.addTarget(self, action: #selector(backspaceTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        case .spacer:
            break
        default:
            key.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        }
    }

    private func updateKeyAppearance() {
        guard let metrics else { return }
        suggestionStack.backgroundColor = theme.suggestionBarColor.uiColor
        for case let button as UIButton in suggestionStack.arrangedSubviews {
            button.setTitleColor(theme.textColor.uiColor, for: .normal)
            button.backgroundColor = theme.suggestionBarColor.uiColor
        }
        rowsStack.arrangedSubviews.compactMap { $0 as? UIStackView }.forEach {
            $0.spacing = metrics.keySpacing
        }
        for key in keyControls {
            let selected = key.action == .shift && state.shift == .capsLock
            if key.action == .returnKey {
                key.setTitle(returnKeyTitle)
            }
            key.update(metrics: metrics, theme: theme, selected: selected)
        }
    }

    func showSwipeCandidates(_ candidates: [String]) {
        suggestionStack.arrangedSubviews.forEach {
            suggestionStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for candidate in candidates.prefix(3) {
            let button = UIButton(type: .system)
            button.setTitle(candidate, for: .normal)
            button.setTitleColor(theme.textColor.uiColor, for: .normal)
            button.titleLabel?.font = .systemFont(
                ofSize: min(CGFloat(theme.fontSize) * 0.72, 17),
                weight: .medium
            )
            button.backgroundColor = theme.suggestionBarColor.uiColor
            button.addTarget(self, action: #selector(swipeCandidateTapped(_:)), for: .touchUpInside)
            suggestionStack.addArrangedSubview(button)
        }
        suggestionStack.isHidden = candidates.isEmpty
    }

    @objc private func swipeCandidateTapped(_ sender: UIButton) {
        guard let candidate = sender.title(for: .normal) else { return }
        delegate?.qwertyKeyboardView(self, didTrigger: .swipeAlternative(candidate))
    }

    func updateDeletionFeedbackAnimation(enabled: Bool) {
        deletionFeedbackAnimationEnabled = enabled && !UIAccessibility.isReduceMotionEnabled
    }

    @objc private func homeRowGestureChanged(_ recognizer: HorizontalDeletionGestureRecognizer) {
        guard recognizer.state == .ended, let level = recognizer.deletionLevel else { return }
        animateDeletionFeedbackIfNeeded()
        delegate?.qwertyKeyboardView(self, didTrigger: .gestureDelete(level))
    }

    private func animateDeletionFeedbackIfNeeded() {
        guard deletionFeedbackAnimationEnabled, let homeRowView else { return }
        UIView.animate(
            withDuration: 0.08,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            homeRowView.transform = CGAffineTransform(translationX: -8, y: 0)
            homeRowView.alpha = 0.78
        } completion: { _ in
            UIView.animate(withDuration: 0.10, delay: 0, options: [.allowUserInteraction]) {
                homeRowView.transform = .identity
                homeRowView.alpha = 1
            }
        }
    }

    @objc private func swipeGestureChanged(_ recognizer: SwipeTypingGestureRecognizer) {
        guard recognizer.state == .ended, let result = recognizer.result else { return }
        if case .typing(let path) = result {
            delegate?.qwertyKeyboardView(self, didTrigger: .swipePath(path))
        }
    }

    @objc private func keyTapped(_ sender: KeyboardKeyControl) {
        delegate?.qwertyKeyboardView(self, didTrigger: sender.action)
    }

    @objc private func backspaceTouchDown(_ sender: KeyboardKeyControl) {
        delegate?.qwertyKeyboardView(self, didTrigger: .backspace)
        stopDeleteRepeat()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.deleteRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.075, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.delegate?.qwertyKeyboardView(self, didTrigger: .backspace)
            }
        }
        deleteDelayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: workItem)
    }

    @objc private func backspaceTouchEnded(_ sender: KeyboardKeyControl) {
        stopDeleteRepeat()
    }

    private func stopDeleteRepeat() {
        deleteDelayWorkItem?.cancel()
        deleteDelayWorkItem = nil
        deleteRepeatTimer?.invalidate()
        deleteRepeatTimer = nil
    }
}
