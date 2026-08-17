import UIKit

protocol ClipboardKeyboardViewDelegate: AnyObject {
    func clipboardKeyboardView(_ view: ClipboardKeyboardView, didTrigger action: KeyboardKeyAction)
    func clipboardKeyboardViewRequestedTextKeyboard(_ view: ClipboardKeyboardView)
}

/// Full keyboard-replacement clipboard panel. Shows a scrollable history of
/// the most recent copied texts; tapping an item inserts it into the active
/// text field. The bottom bar mirrors the emoji view's control bar, with the
/// ⌨️ button in place of the emoji toggle so one tap returns to the existing
/// QWERTY keyboard.
final class ClipboardKeyboardView: UIView {
    weak var delegate: ClipboardKeyboardViewDelegate?

    private let store = ClipboardHistoryStore()
    private var items: [ClipboardItem] = []
    private var controlButtons: [UIButton] = []
    private var theme = KeyboardTheme.light

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 6
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ClipboardCell.self, forCellWithReuseIdentifier: ClipboardCell.reuseIdentifier)
        return collectionView
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "No copied text yet"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15)
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboard()
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Refreshes from shared storage. Called when the panel opens so the user
    /// always sees the latest history (including anything captured by the host
    /// app while it was active).
    func reloadHistory() {
        items = store.load()
        emptyLabel.isHidden = !items.isEmpty
        collectionView.reloadData()
    }

    func updateAppearance(theme: KeyboardTheme) {
        self.theme = theme
        backgroundColor = theme.keyboardBackground.uiColor
        emptyLabel.textColor = theme.textColor.uiColor
        controlButtons.forEach { button in
            button.tintColor = theme.textColor.uiColor
            button.setTitleColor(theme.textColor.uiColor, for: .normal)
            button.backgroundColor = theme.keyBackground.uiColor
            button.layer.cornerRadius = CGFloat(theme.keyCornerRadius)
            button.titleLabel?.font = .systemFont(ofSize: min(CGFloat(theme.fontSize), 20))
        }
        collectionView.reloadData()
    }

    private func setupKeyboard() {
        let controls = makeControlBar()
        addSubview(collectionView)
        addSubview(emptyLabel)
        addSubview(controls)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            collectionView.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -4),
            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: collectionView.leadingAnchor, constant: 12),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: collectionView.trailingAnchor, constant: -12),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            controls.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -5),
            controls.heightAnchor.constraint(equalToConstant: 42)
        ])
        updateAppearance(theme: .light)
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

    @objc private func insertSpace() { delegate?.clipboardKeyboardView(self, didTrigger: .space) }
    @objc private func deleteBackward() { delegate?.clipboardKeyboardView(self, didTrigger: .backspace) }
    @objc private func insertReturn() { delegate?.clipboardKeyboardView(self, didTrigger: .returnKey) }

    @objc private func keyboardButtonTapped() {
        delegate?.clipboardKeyboardViewRequestedTextKeyboard(self)
    }
}

extension ClipboardKeyboardView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ClipboardCell.reuseIdentifier, for: indexPath) as? ClipboardCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: items[indexPath.item].text, theme: theme)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let text = items[indexPath.item].text
        delegate?.clipboardKeyboardView(self, didTrigger: .character(text))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text = items[indexPath.item].text
        let horizontalInset: CGFloat = 12
        let width = collectionView.bounds.width - horizontalInset * 2
        let height = ClipboardCell.height(for: text, width: width)
        return CGSize(width: width, height: height)
    }
}

/// Single clipboard entry: multiline text with the theme's key background.
final class ClipboardCell: UICollectionViewCell {
    static let reuseIdentifier = "ClipboardCell"

    private let label = UILabel()
    private let backgroundBox = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundBox.translatesAutoresizingMaskIntoConstraints = false
        backgroundBox.layer.cornerRadius = 6
        backgroundBox.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15)
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingTail
        contentView.addSubview(backgroundBox)
        backgroundBox.addSubview(label)
        NSLayoutConstraint.activate([
            backgroundBox.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundBox.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            label.topAnchor.constraint(equalTo: backgroundBox.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: backgroundBox.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: backgroundBox.trailingAnchor, constant: -10),
            label.bottomAnchor.constraint(equalTo: backgroundBox.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(with text: String, theme: KeyboardTheme) {
        label.text = text
        label.textColor = theme.textColor.uiColor
        backgroundBox.backgroundColor = theme.keyBackground.uiColor
    }

    static func height(for text: String, width: CGFloat) -> CGFloat {
        let labelWidth = max(width - 20, 40)
        let font = UIFont.systemFont(ofSize: 15)
        let bounding = text.boundingRect(
            with: CGSize(width: labelWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return max(ceil(bounding.height) + 16, 40)
    }
}