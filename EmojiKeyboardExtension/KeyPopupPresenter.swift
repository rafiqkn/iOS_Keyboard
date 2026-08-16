import UIKit

final class KeyPopupView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 2

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(text: String, theme: KeyboardTheme) {
        label.text = text
        label.font = .systemFont(ofSize: min(CGFloat(theme.fontSize) * 1.35, 34), weight: .medium)
        label.textColor = theme.textColor.uiColor
        backgroundColor = theme.keyBackground.uiColor
        layer.cornerRadius = max(6, CGFloat(theme.keyCornerRadius))
    }
}

final class KeyPopupPresenter {
    private weak var container: UIView?
    let popup = KeyPopupView()
    var isEnabled = true

    init(container: UIView) {
        self.container = container
        popup.isHidden = true
        container.addSubview(popup)
    }

    func show(text: String, above key: UIView, theme: KeyboardTheme) {
        guard isEnabled, let container else { return }
        popup.configure(text: text, theme: theme)
        let keyFrame = key.convert(key.bounds, to: container)
        let width = max(46, keyFrame.width * 1.22)
        let height = max(52, keyFrame.height * 1.32)
        popup.frame = CGRect(
            x: keyFrame.midX - width / 2,
            y: max(0, keyFrame.minY - height + 5),
            width: width,
            height: height
        )
        popup.isHidden = false
        container.bringSubviewToFront(popup)
        popup.layer.shadowPath = UIBezierPath(
            roundedRect: popup.bounds,
            cornerRadius: popup.layer.cornerRadius
        ).cgPath

        if UIAccessibility.isReduceMotionEnabled {
            popup.alpha = 1
            popup.transform = .identity
        } else {
            popup.alpha = 0
            popup.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            UIView.animate(
                withDuration: 0.08,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.popup.alpha = 1
                self.popup.transform = .identity
            }
        }
    }

    func hide() {
        popup.layer.removeAllAnimations()
        popup.isHidden = true
        popup.alpha = 1
        popup.transform = .identity
    }
}
