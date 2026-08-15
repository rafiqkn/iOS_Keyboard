import UIKit

final class KeyboardKeyControl: UIControl {
    private(set) var action: KeyboardKeyAction
    let widthUnit: CGFloat

    private let titleLabel = UILabel()
    private let imageView = UIImageView()
    private let keyStyle: KeyboardKeyStyle
    private var darkMode = false

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

    func update(metrics: KeyboardMetrics, darkMode: Bool, selected: Bool = false) {
        self.darkMode = darkMode
        layer.cornerRadius = metrics.cornerRadius
        titleLabel.font = .systemFont(
            ofSize: keyStyle == .character ? metrics.characterFontSize : metrics.functionFontSize,
            weight: keyStyle == .character ? .regular : .medium
        )
        accessibilityTraits = selected ? [.keyboardKey, .selected] : .keyboardKey
        applyColors(selected: selected)
    }

    private func applyColors(selected: Bool? = nil) {
        let isSelected = selected ?? accessibilityTraits.contains(.selected)
        let foreground: UIColor = darkMode ? .white : .black
        titleLabel.textColor = foreground
        imageView.tintColor = foreground

        if keyStyle == .spacer {
            backgroundColor = .clear
        } else if isHighlighted {
            backgroundColor = darkMode ? .systemGray : .systemGray3
        } else if isSelected || keyStyle == .accent {
            backgroundColor = isSelected
                ? UIColor.systemBlue.withAlphaComponent(darkMode ? 0.75 : 0.9)
                : (darkMode ? .systemGray2 : .systemGray4)
        } else if keyStyle == .character || keyStyle == .space {
            backgroundColor = darkMode ? UIColor(white: 0.35, alpha: 1) : .white
        } else {
            backgroundColor = darkMode ? UIColor(white: 0.22, alpha: 1) : UIColor(white: 0.68, alpha: 1)
        }
    }
}
