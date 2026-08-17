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
    private var settingsButton: UIButton!
    private var clipboardButton: UIButton!
    private var candidateHeightConstraint: NSLayoutConstraint!
    private var deleteDelayWorkItem: DispatchWorkItem?
    private var deleteRepeatTimer: Timer?
    private weak var activeInsertKey: KeyboardKeyControl?
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
        suggestionStack.alpha = 0
        suggestionStack.layer.cornerRadius = 6
        suggestionStack.clipsToBounds = true
        candidateButtons = (0..<3).map { _ in
            let button = UIButton(type: .system)
            button.isHidden = true
            button.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)
            suggestionStack.addArrangedSubview(button)
            return button
        }
        settingsButton = makeBarButton(systemName: "gearshape", accessibilityLabel: "Settings")
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        clipboardButton = makeBarButton(systemName: "doc.on.clipboard", accessibilityLabel: "Clipboard")
        clipboardButton.addTarget(self, action: #selector(clipboardButtonTapped), for: .touchUpInside)
        rowsStack.axis = .vertical
        rowsStack.distribution = .fill
        addSubview(rowsStack)
        addSubview(suggestionStack)
        addSubview(settingsButton)
        addSubview(clipboardButton)
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
            suggestionStack.leadingAnchor.constraint(equalTo: settingsButton.trailingAnchor, constant: 4),
            suggestionStack.trailingAnchor.constraint(equalTo: clipboardButton.leadingAnchor, constant: -4),
            candidateHeightConstraint,
            settingsButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            settingsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            settingsButton.widthAnchor.constraint(equalToConstant: 36),
            settingsButton.heightAnchor.constraint(equalToConstant: 34),
            clipboardButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            clipboardButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            clipboardButton.widthAnchor.constraint(equalToConstant: 36),
            clipboardButton.heightAnchor.constraint(equalToConstant: 34)
        ])
        updateBarVisibility()
        rebuildRows()
    }

    private func makeBarButton(systemName: String, accessibilityLabel: String) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.accessibilityLabel = accessibilityLabel
        button.tintColor = theme.textColor.uiColor
        button.backgroundColor = theme.functionKeyBackground.uiColor
        button.layer.cornerRadius = CGFloat(theme.keyCornerRadius)
        return button
    }

    /// The ⚙️/📋 bar buttons are part of the suggestion band and only exist in
    /// letters mode. They stay visible even when there are no predictions to
    /// show (unlike the prediction stack, which fades with its content).
    private func updateBarVisibility() {
        let visible = state.mode == .letters
        settingsButton.alpha = visible ? 1 : 0
        clipboardButton.alpha = visible ? 1 : 0
        settingsButton.isUserInteractionEnabled = visible
        clipboardButton.isUserInteractionEnabled = visible
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
        activeInsertKey = nil
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
            if state.mode != .letters {
                candidateBarContent = .hidden
            }
            applyCandidateVisibility(animated: false)
            updateBarVisibility()
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
        case .character, .space:
            key.addTarget(self, action: #selector(insertKeyTouchDown(_:)), for: .touchDown)
            key.addTarget(self, action: #selector(insertKeyLiftedInside(_:)), for: .touchUpInside)
            key.addTarget(self, action: #selector(insertKeyLiftedOutside(_:)), for: [.touchUpOutside, .touchCancel])
        case .spacer:
            break
        default:
            key.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        }
    }

    @objc private func insertKeyTouchDown(_ sender: KeyboardKeyControl) {
        activeInsertKey = sender
        delegate?.qwertyKeyboardView(self, didTrigger: sender.action)
    }

    @objc private func insertKeyLiftedInside(_ sender: KeyboardKeyControl) {
        if activeInsertKey === sender {
            activeInsertKey = nil
        }
    }

    @objc private func insertKeyLiftedOutside(_ sender: KeyboardKeyControl) {
        guard activeInsertKey === sender else { return }
        activeInsertKey = nil
        delegate?.qwertyKeyboardView(self, didTrigger: .retractLastInsert)
    }

    private func updateKeyAppearance() {
        guard let metrics else { return }
        suggestionStack.backgroundColor = theme.suggestionBarColor.uiColor
        for case let button as UIButton in suggestionStack.arrangedSubviews {
            button.setTitleColor(theme.textColor.uiColor, for: .normal)
            button.backgroundColor = theme.suggestionBarColor.uiColor
        }
        settingsButton.tintColor = theme.textColor.uiColor
        settingsButton.backgroundColor = theme.functionKeyBackground.uiColor
        settingsButton.layer.cornerRadius = CGFloat(theme.keyCornerRadius)
        clipboardButton.tintColor = theme.textColor.uiColor
        clipboardButton.backgroundColor = theme.functionKeyBackground.uiColor
        clipboardButton.layer.cornerRadius = CGFloat(theme.keyCornerRadius)
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

    /// The candidate words currently presented in the bar (empty when hidden).
    var visibleCandidateTitles: [String] {
        switch candidateBarContent {
        case .hidden:
            return []
        case .predictions(let values):
            return values
        }
    }

    /// Whether the candidate bar is actually drawn on screen (not just
    /// logically populated). Used to keep mode switches from flashing an
    /// empty bar.
    var suggestionBarIsVisible: Bool {
        !suggestionStack.isHidden && suggestionStack.alpha > 0.5
    }

    func showCandidates(_ content: CandidateBarContent, animated: Bool = true) {
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
        applyCandidateVisibility(animated: animated)
    }

    /// Keeps the candidate bar laid out (it always reserves its band) and
    /// toggles only opacity so show/hide transitions fade instead of popping
    /// and never cause layout jumps.
    private func applyCandidateVisibility(animated: Bool) {
        let shouldHide: Bool
        switch candidateBarContent {
        case .hidden:
            shouldHide = true
        case .predictions(let values):
            shouldHide = values.isEmpty
        }
        suggestionStack.isUserInteractionEnabled = !shouldHide
        let targetAlpha: CGFloat = shouldHide ? 0 : 1
        guard suggestionStack.alpha != targetAlpha else { return }
        if animated {
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) { [weak self] in
                self?.suggestionStack.alpha = targetAlpha
            }
        } else {
            suggestionStack.alpha = targetAlpha
        }
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

    @objc private func settingsButtonTapped() {
        delegate?.qwertyKeyboardView(self, didTrigger: .settings)
    }

    @objc private func clipboardButtonTapped() {
        delegate?.qwertyKeyboardView(self, didTrigger: .clipboard)
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
