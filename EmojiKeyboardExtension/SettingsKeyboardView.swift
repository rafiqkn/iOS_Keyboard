import UIKit

protocol SettingsKeyboardViewDelegate: AnyObject {
    func settingsKeyboardView(_ view: SettingsKeyboardView, didTrigger action: KeyboardKeyAction)
    func settingsKeyboardViewRequestedTextKeyboard(_ view: SettingsKeyboardView)
    func settingsKeyboardView(_ view: SettingsKeyboardView, didChange settings: KeyboardInteractionSettings)
}

/// Full keyboard-replacement settings panel. Mirrors the interaction toggles
/// from the host app (Word Prediction, Key Popups, Keystroke Sound, Deletion
/// Feedback) and persists them through the same App Group store, so changes
/// apply live in the keyboard and stay in sync with the host app.
final class SettingsKeyboardView: UIView {
    weak var delegate: SettingsKeyboardViewDelegate?

    private var settings = KeyboardInteractionSettings.defaults
    private var controlButtons: [UIButton] = []
    private var theme = KeyboardTheme.light
    private var rowViews: [SettingsRowView] = []

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboard()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(settings: KeyboardInteractionSettings) {
        self.settings = settings
        for (index, row) in rowViews.enumerated() {
            row.isOn = switchValue(at: index)
        }
    }

    func updateAppearance(theme: KeyboardTheme) {
        self.theme = theme
        backgroundColor = theme.keyboardBackground.uiColor
        rowViews.forEach { $0.updateAppearance(theme: theme) }
        controlButtons.forEach { button in
            button.tintColor = theme.textColor.uiColor
            button.setTitleColor(theme.textColor.uiColor, for: .normal)
            button.backgroundColor = theme.keyBackground.uiColor
            button.layer.cornerRadius = CGFloat(theme.keyCornerRadius)
            button.titleLabel?.font = .systemFont(ofSize: min(CGFloat(theme.fontSize), 20))
        }
    }

    private func setupKeyboard() {
        let rows: [(title: String, subtitle: String)] = [
            ("Word Prediction", "Suggest words while typing"),
            ("Key Popups", "Show a popup above pressed keys"),
            ("Keystroke Sound", "Play the system key click"),
            ("Deletion Feedback", "Animate the home row on swipe delete")
        ]
        rowViews = rows.enumerated().map { index, item in
            let row = SettingsRowView(title: item.title, subtitle: item.subtitle)
            row.tag = index
            row.onValueChanged = { [weak self] isOn in
                self?.toggleValue(at: index, isOn: isOn)
            }
            return row
        }

        let controls = makeControlBar()
        addSubview(scrollView)
        scrollView.addSubview(rowsStack)
        addSubview(controls)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            scrollView.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -4),
            rowsStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 4),
            rowsStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 4),
            rowsStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -4),
            rowsStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -4),
            rowsStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -8),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            controls.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -5),
            controls.heightAnchor.constraint(equalToConstant: 42)
        ])
        rowViews.forEach { rowsStack.addArrangedSubview($0) }
        updateAppearance(theme: .light)
    }

    private func switchValue(at index: Int) -> Bool {
        switch index {
        case 0: return settings.predictionEnabled
        case 1: return settings.keyPopupEnabled
        case 2: return settings.keystrokeSoundMode == .system
        case 3: return settings.deletionFeedbackAnimation
        default: return false
        }
    }

    private func toggleValue(at index: Int, isOn: Bool) {
        var updated = settings
        switch index {
        case 0:
            updated.predictionEnabled = isOn
        case 1:
            updated.keyPopupEnabled = isOn
        case 2:
            updated.keystrokeSoundMode = isOn ? .system : .off
        case 3:
            updated.deletionFeedbackAnimation = isOn
        default:
            return
        }
        settings = updated
        delegate?.settingsKeyboardView(self, didChange: updated)
    }

    private func makeControlBar() -> UIView {
        let keyboardButton = makeKeyButton(symbol: "keyboard", accessibilityLabel: "Keyboard")
        keyboardButton.addTarget(self, action: #selector(keyboardButtonTapped), for: .touchUpInside)
        let spaceButton = makeKeyButton(title: "space", accessibilityLabel: "Space")
        spaceButton.addTarget(self, action: #selector(insertSpace), for: .touchUpInside)
        let deleteButton = makeKeyButton(symbol: "delete.left", accessibilityLabel: "Delete")
        deleteButton.addTarget(self, action: #selector(deleteBackward), for: .touchUpInside)
        let returnButton = makeKeyButton(symbol: "return", accessibilityLabel: "Return")
        returnButton.addTarget(self, action: #selector(insertReturn), for: .touchUpInside)

        controlButtons = [keyboardButton, spaceButton, deleteButton, returnButton]
        let stack = UIStackView(arrangedSubviews: controlButtons)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fill
        keyboardButton.widthAnchor.constraint(equalToConstant: 46).isActive = true
        deleteButton.widthAnchor.constraint(equalToConstant: 54).isActive = true
        returnButton.widthAnchor.constraint(equalToConstant: 54).isActive = true
        return stack
    }

    private func makeKeyButton(title: String? = nil, symbol: String? = nil, accessibilityLabel: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        if let symbol { button.setImage(UIImage(systemName: symbol), for: .normal) }
        button.accessibilityLabel = accessibilityLabel
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.18
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0.5
        return button
    }

    @objc private func insertSpace() { delegate?.settingsKeyboardView(self, didTrigger: .space) }
    @objc private func deleteBackward() { delegate?.settingsKeyboardView(self, didTrigger: .backspace) }
    @objc private func insertReturn() { delegate?.settingsKeyboardView(self, didTrigger: .returnKey) }

    @objc private func keyboardButtonTapped() {
        delegate?.settingsKeyboardViewRequestedTextKeyboard(self)
    }
}

/// A single labeled row with a toggle switch, themed like a keyboard key.
final class SettingsRowView: UIView {
    var onValueChanged: ((Bool) -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let toggle = UISwitch()
    private let box = UIView()

    var isOn: Bool {
        get { toggle.isOn }
        set { toggle.setOn(newValue, animated: false) }
    }

    init(title: String, subtitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        box.translatesAutoresizingMaskIntoConstraints = false
        box.layer.cornerRadius = 6
        box.clipsToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.8

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2

        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)

        titleLabel.text = title
        subtitleLabel.text = subtitle
        addSubview(box)
        box.addSubview(textStack)
        box.addSubview(toggle)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 54),
            box.topAnchor.constraint(equalTo: topAnchor),
            box.leadingAnchor.constraint(equalTo: leadingAnchor),
            box.trailingAnchor.constraint(equalTo: trailingAnchor),
            box.bottomAnchor.constraint(equalTo: bottomAnchor),
            textStack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -8),
            toggle.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            toggle.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func toggleChanged() {
        onValueChanged?(toggle.isOn)
    }

    func updateAppearance(theme: KeyboardTheme) {
        box.backgroundColor = theme.keyBackground.uiColor
        titleLabel.textColor = theme.textColor.uiColor
        subtitleLabel.textColor = theme.textColor.uiColor.withAlphaComponent(0.65)
    }
}