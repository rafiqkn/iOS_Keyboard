import UIKit

protocol QwertyKeyboardViewDelegate: AnyObject {
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTrigger action: KeyboardKeyAction)
    func qwertyKeyboardView(_ view: QwertyKeyboardView, handleInputModeListFrom control: UIControl, event: UIEvent)
}

final class QwertyKeyboardView: UIView {
    weak var delegate: QwertyKeyboardViewDelegate?

    private let rowsStack = UIStackView()
    private var state = KeyboardState()
    private var keyControls: [KeyboardKeyControl] = []
    private var metrics: KeyboardMetrics?
    private var darkMode = false
    private var returnKeyTitle = "return"
    private let gestureConfiguration = GestureDeletionConfiguration.standard
    private var homeRowGesture: HorizontalDeletionGestureRecognizer?
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
        rowsStack.axis = .vertical
        rowsStack.distribution = .fillEqually
        addSubview(rowsStack)
        topConstraint = rowsStack.topAnchor.constraint(equalTo: topAnchor)
        leadingConstraint = rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor)
        trailingConstraint = rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor)
        bottomConstraint = rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            topConstraint,
            leadingConstraint,
            trailingConstraint,
            bottomConstraint
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
        homeRowGesture?.cancel()
    }

    func update(state: KeyboardState, darkMode: Bool, size: CGSize, returnKeyTitle: String) {
        let modeChanged = self.state.mode != state.mode
        let shiftChanged = self.state.shift != state.shift
        self.state = state
        self.darkMode = darkMode
        self.returnKeyTitle = returnKeyTitle
        let nextMetrics = KeyboardMetrics.resolve(for: size, idiom: traitCollection.userInterfaceIdiom)

        if modeChanged {
            homeRowGesture = nil
            rebuildRows()
        } else if shiftChanged {
            updateLetterCase()
        }
        if metrics != nextMetrics {
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
        homeRowGesture?.cancel()
        homeRowGesture = nil
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
                let recognizer = HorizontalDeletionGestureRecognizer(
                    configuration: gestureConfiguration,
                    target: self,
                    action: #selector(homeRowGestureChanged(_:))
                )
                rowView.addGestureRecognizer(recognizer)
                homeRowGesture = recognizer
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
        updateKeyAppearance()
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
        case .nextKeyboard:
            key.addTarget(self, action: #selector(handleInputModeList(_:event:)), for: .allTouchEvents)
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
        rowsStack.arrangedSubviews.compactMap { $0 as? UIStackView }.forEach {
            $0.spacing = metrics.keySpacing
        }
        for key in keyControls {
            let selected = key.action == .shift && state.shift == .capsLock
            if key.action == .returnKey {
                key.setTitle(returnKeyTitle)
            }
            key.update(metrics: metrics, darkMode: darkMode, selected: selected)
        }
    }

    @objc private func homeRowGestureChanged(_ recognizer: HorizontalDeletionGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            guard let level = recognizer.deletionLevel else { return }
            delegate?.qwertyKeyboardView(self, didTrigger: .gestureDelete(level))
        default:
            break
        }
    }

    @objc private func keyTapped(_ sender: KeyboardKeyControl) {
        delegate?.qwertyKeyboardView(self, didTrigger: sender.action)
    }

    @objc private func handleInputModeList(_ sender: UIControl, event: UIEvent) {
        delegate?.qwertyKeyboardView(self, handleInputModeListFrom: sender, event: event)
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
