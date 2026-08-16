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
    private var letterKeyControls: [KeyboardKeyControl] = []
    private weak var shiftKeyControl: KeyboardKeyControl?
    private var rowHeightConstraints: [NSLayoutConstraint] = []
    private var lastLayoutSize = CGSize.zero
    private var metrics: KeyboardMetrics?
    private var theme = KeyboardTheme.light
    private var returnKeyTitle = "return"
    private var homeRowGesture: HorizontalDeletionGestureRecognizer?
    private weak var homeRowView: UIView?
    private var deletionFeedbackAnimationEnabled = false
    private lazy var keyPopupPresenter = KeyPopupPresenter(container: self)
    private var candidateBarContent = CandidateBarContent.hidden
    private var candidateButtons: [UIButton] = []
    private var candidateHeightConstraint: NSLayoutConstraint!
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
        candidateButtons = (0..<3).map { _ in
            let button = UIButton(type: .system)
            button.isHidden = true
            button.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)
            suggestionStack.addArrangedSubview(button)
            return button
        }
        rowsStack.axis = .vertical
        rowsStack.distribution = .fill
        addSubview(rowsStack)
        addSubview(suggestionStack)
        candidateHeightConstraint = suggestionStack.heightAnchor.constraint(equalToConstant: 34)
        topConstraint = rowsStack.topAnchor.constraint(equalTo: suggestionStack.bottomAnchor, constant: 2)
        leadingConstraint = rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor)
        trailingConstraint = rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor)
        bottomConstraint = rowsStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        NSLayoutConstraint.activate([
            topConstraint,
            leadingConstraint,
            trailingConstraint,
            bottomConstraint,
            suggestionStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            suggestionStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            suggestionStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            candidateHeightConstraint
        ])
        rebuildRows()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        stopDeleteRepeat()
    }

    func cancelActiveInteractions() {
        stopDeleteRepeat()
        homeRowGesture?.cancel()
        keyPopupPresenter.hide()
    }

    func update(state: KeyboardState, theme: KeyboardTheme, size: CGSize, returnKeyTitle: String) {
        let modeChanged = self.state.mode != state.mode
        let shiftChanged = self.state.shift != state.shift
        let themeChanged = self.theme != theme
        let sizeChanged = lastLayoutSize != size
        let returnKeyChanged = self.returnKeyTitle != returnKeyTitle
        self.state = state
        self.theme = theme
        self.returnKeyTitle = returnKeyTitle
        lastLayoutSize = size
        let nextMetrics = KeyboardMetrics.resolve(
            for: size,
            idiom: traitCollection.userInterfaceIdiom,
            verticalSizeClass: traitCollection.verticalSizeClass,
            theme: theme
        )

        if modeChanged {
            candidateHeightConstraint.constant = 34
            suggestionStack.isHidden = state.mode != .letters
            if state.mode != .letters {
                candidateBarContent = .hidden
            }
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
            updateRowHeights(for: size, metrics: nextMetrics)
        } else if sizeChanged {
            updateRowHeights(for: size, metrics: nextMetrics)
        }
        if modeChanged || themeChanged || returnKeyChanged {
            updateKeyAppearance()
        }
    }

    private func rebuildRows() {
        stopDeleteRepeat()
        homeRowGesture?.cancel()
        homeRowGesture = nil
        homeRowView = nil
        keyControls.removeAll(keepingCapacity: true)
        letterKeyControls.removeAll(keepingCapacity: true)
        shiftKeyControl = nil
        NSLayoutConstraint.deactivate(rowHeightConstraints)
        rowHeightConstraints.removeAll(keepingCapacity: true)
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
                configurePopup(for: key)
                rowView.addArrangedSubview(key)
                keyControls.append(key)
                switch key.action {
                case .character(let value) where value.count == 1 && value.first?.isLetter == true:
                    letterKeyControls.append(key)
                case .shift:
                    shiftKeyControl = key
                default:
                    break
                }

                if let previousKey {
                    key.widthAnchor.constraint(
                        equalTo: previousKey.widthAnchor,
                        multiplier: descriptor.width / previousKey.widthUnit
                    ).isActive = true
                }
                previousKey = key
            }
            rowsStack.addArrangedSubview(rowView)
            let rowHeight = rowView.heightAnchor.constraint(equalToConstant: CGFloat(theme.keyHeight))
            rowHeight.isActive = true
            rowHeightConstraints.append(rowHeight)
        }
        if let metrics {
            updateRowHeights(for: lastLayoutSize, metrics: metrics)
        }
        updateKeyAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let metrics, bounds.size != lastLayoutSize {
            lastLayoutSize = bounds.size
            updateRowHeights(for: bounds.size, metrics: metrics)
        }
    }

    private func updateRowHeights(for size: CGSize, metrics: KeyboardMetrics) {
        guard !rowHeightConstraints.isEmpty, size.height > 0 else { return }
        let effectiveHeight = KeyboardRowHeightPolicy.effectiveHeight(
            preferredHeight: CGFloat(theme.keyHeight),
            containerHeight: size.height,
            rowCount: rowHeightConstraints.count,
            rowSpacing: metrics.rowSpacing,
            verticalPadding: metrics.verticalPadding,
            candidateBandHeight: candidateHeightConstraint.constant + 6
        )
        rowHeightConstraints.forEach { $0.constant = effectiveHeight }
    }

    func updateShift(_ shift: ShiftState) {
        guard state.shift != shift else { return }
        state.shift = shift
        updateLetterCase()
    }

    private func updateLetterCase() {
        guard state.mode == .letters else { return }
        let uppercase = state.shift != .off
        for key in letterKeyControls {
            guard case .character(let value) = key.action else { continue }
            key.setCharacter(uppercase ? value.uppercased() : value.lowercased())
        }
        shiftKeyControl?.setSymbol(uppercase ? "shift.fill" : "shift")
    }

    private func configurePopup(for key: KeyboardKeyControl) {
        guard key.popupText != nil else { return }
        key.onTouchDown = { [weak self] key in
            guard let self, let text = key.popupText else { return }
            self.keyPopupPresenter.show(text: text, above: key, theme: self.theme)
        }
        key.onTouchEnded = { [weak self] in
            self?.keyPopupPresenter.hide()
        }
    }

    func updateKeyPopup(enabled: Bool) {
        keyPopupPresenter.isEnabled = enabled
        if !enabled { keyPopupPresenter.hide() }
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

    var hasVisibleCandidates: Bool {
        candidateBarContent != .hidden
    }

    func showCandidates(_ content: CandidateBarContent) {
        guard candidateBarContent != content else { return }
        let candidates: [String]
        switch content {
        case .hidden:
            candidates = []
        case .predictions(let values):
            candidates = values
        }
        candidateBarContent = content
        let font = UIFont.systemFont(
            ofSize: min(CGFloat(theme.fontSize) * 0.72, 17),
            weight: .medium
        )
        for (index, button) in candidateButtons.enumerated() {
            let candidate = index < candidates.count ? candidates[index] : nil
            let shouldHide = candidate == nil
            if button.isHidden != shouldHide { button.isHidden = shouldHide }
            if button.title(for: .normal) != candidate { button.setTitle(candidate, for: .normal) }
            if button.titleLabel?.font != font { button.titleLabel?.font = font }
            let textColor = theme.textColor.uiColor
            if button.titleColor(for: .normal) != textColor {
                button.setTitleColor(textColor, for: .normal)
            }
            let backgroundColor = theme.suggestionBarColor.uiColor
            if button.backgroundColor != backgroundColor { button.backgroundColor = backgroundColor }
        }
        let shouldHideStack = candidates.isEmpty
        if suggestionStack.isHidden != shouldHideStack { suggestionStack.isHidden = shouldHideStack }
    }

    @objc private func candidateTapped(_ sender: UIButton) {
        guard let candidate = sender.title(for: .normal) else { return }
        switch candidateBarContent {
        case .predictions:
            delegate?.qwertyKeyboardView(self, didTrigger: .predictionSelected(candidate))
        case .hidden:
            break
        }
    }

    func updateDeletionFeedbackAnimation(enabled: Bool) {
        deletionFeedbackAnimationEnabled = enabled && !UIAccessibility.isReduceMotionEnabled
    }

    @objc private func homeRowGestureChanged(_ recognizer: HorizontalDeletionGestureRecognizer) {
        if recognizer.state == .began { keyPopupPresenter.hide() }
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
