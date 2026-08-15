import UIKit

final class KeyboardKeyControl: UIControl {
    private(set) var action: KeyboardKeyAction
    let widthUnit: CGFloat

    var onTouchDown: ((KeyboardKeyControl) -> Void)?
    var onTouchEnded: (() -> Void)?

    private let titleLabel = UILabel()
    private let imageView = UIImageView()
    private let keyStyle: KeyboardKeyStyle
    private var theme = KeyboardTheme.light

    init(descriptor: KeyboardKeyDescriptor) {
        action = descriptor.action
        widthUnit = descriptor.width
        keyStyle = descriptor.style
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = descriptor.style != .spacer
        accessibilityTraits = .keyboardKey
        accessibilityLabel = descriptor.title ?? descriptor.symbolName

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = descriptor.title
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.65

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = descriptor.symbolName.flatMap { UIImage(systemName: $0) }
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)

        addSubview(titleLabel)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.55),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.55)
        ])

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = keyStyle == .spacer ? 0 : 0.25
        isUserInteractionEnabled = keyStyle != .spacer
        addTarget(self, action: #selector(notifyTouchDown), for: .touchDown)
        addTarget(
            self,
            action: #selector(notifyTouchEnded),
            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit]
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet { applyColors() }
    }

    func setTitle(_ title: String) {
        imageView.image = nil
        titleLabel.text = title
        accessibilityLabel = title
    }

    func setCharacter(_ character: String) {
        action = .character(character)
        setTitle(character)
    }

    func setSymbol(_ symbolName: String) {
        titleLabel.text = nil
        imageView.image = UIImage(systemName: symbolName)
    }

    func update(metrics: KeyboardMetrics, theme: KeyboardTheme, selected: Bool = false) {
        self.theme = theme
        layer.cornerRadius = metrics.cornerRadius
        titleLabel.font = .systemFont(
            ofSize: keyStyle == .character ? metrics.characterFontSize : metrics.functionFontSize,
            weight: keyStyle == .character ? .regular : .medium
        )
        accessibilityTraits = selected ? [.keyboardKey, .selected] : .keyboardKey
        applyColors(selected: selected)
    }

    var popupText: String? {
        guard case .character(let value) = action else { return nil }
        return value
    }

    @objc private func notifyTouchDown() {
        onTouchDown?(self)
    }

    @objc private func notifyTouchEnded() {
        onTouchEnded?()
    }

    private func applyColors(selected: Bool? = nil) {
        let isSelected = selected ?? accessibilityTraits.contains(.selected)
        let foreground = theme.textColor.uiColor
        titleLabel.textColor = foreground
        imageView.tintColor = foreground

        if keyStyle == .spacer {
            backgroundColor = .clear
        } else if isHighlighted {
            backgroundColor = theme.keyBackground.uiColor.withAlphaComponent(0.72)
        } else if isSelected {
            backgroundColor = theme.accentKeyBackground.uiColor
        } else {
            switch keyStyle {
            case .character, .space:
                backgroundColor = theme.keyBackground.uiColor
            case .function:
                backgroundColor = theme.functionKeyBackground.uiColor
            case .accent:
                backgroundColor = theme.accentKeyBackground.uiColor
            case .spacer:
                backgroundColor = .clear
            }
        }
    }
}
