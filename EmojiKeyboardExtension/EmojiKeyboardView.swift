import UIKit

protocol EmojiKeyboardViewDelegate: AnyObject {
    func emojiKeyboardView(_ view: EmojiKeyboardView, didTrigger action: KeyboardKeyAction)
    func emojiKeyboardView(_ view: EmojiKeyboardView, handleInputModeListFrom control: UIControl, event: UIEvent)
    func emojiKeyboardViewRequestedTextKeyboard(_ view: EmojiKeyboardView)
}

final class EmojiKeyboardView: UIView {
    weak var delegate: EmojiKeyboardViewDelegate?

    private let categories = EmojiCatalog.categories
    private var selectedCategoryIndex = 0
    private var categoryButtons: [UIButton] = []
    private var darkMode = false

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseIdentifier)
        return collectionView
    }()

    private let categoryStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboard()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    func updateAppearance(darkMode: Bool) {
        self.darkMode = darkMode
        backgroundColor = darkMode
            ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)

        categoryButtons.forEach { button in
            let selected = button.tag == selectedCategoryIndex
            button.tintColor = selected ? .systemBlue : (darkMode ? .lightGray : .darkGray)
            button.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.14) : .clear
        }
        for case let stack as UIStackView in subviews {
            for case let button as UIButton in stack.arrangedSubviews where stack !== categoryStack {
                button.tintColor = darkMode ? .white : .black
                button.setTitleColor(darkMode ? .white : .black, for: .normal)
                button.backgroundColor = darkMode ? .systemGray3 : .white
            }
        }
    }

    private func setupKeyboard() {
        for (index, category) in categories.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setImage(UIImage(systemName: category.iconName), for: .normal)
            button.accessibilityLabel = category.title
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryButtons.append(button)
            categoryStack.addArrangedSubview(button)
        }

        let controls = makeControlBar()
        addSubview(categoryStack)
        addSubview(collectionView)
        addSubview(controls)
        NSLayoutConstraint.activate([
            categoryStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            categoryStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            categoryStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            categoryStack.heightAnchor.constraint(equalToConstant: 38),
            collectionView.topAnchor.constraint(equalTo: categoryStack.bottomAnchor, constant: 2),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            collectionView.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -4),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            controls.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -5),
            controls.heightAnchor.constraint(equalToConstant: 42)
        ])
        selectCategory(at: 0)
        updateAppearance(darkMode: false)
    }

    private func makeControlBar() -> UIView {
        let globeButton = makeKeyButton(symbol: "globe", accessibilityLabel: "Next keyboard")
        globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let keyboardButton = makeKeyButton(symbol: "keyboard", accessibilityLabel: "Letters")
        keyboardButton.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        let spaceButton = makeKeyButton(title: "space", accessibilityLabel: "Space")
        spaceButton.addTarget(self, action: #selector(insertSpace), for: .touchUpInside)
        let deleteButton = makeKeyButton(symbol: "delete.left", accessibilityLabel: "Delete")
        deleteButton.addTarget(self, action: #selector(deleteBackward), for: .touchUpInside)
        let returnButton = makeKeyButton(symbol: "return", accessibilityLabel: "Return")
        returnButton.addTarget(self, action: #selector(insertReturn), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [globeButton, keyboardButton, spaceButton, deleteButton, returnButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fill
        globeButton.widthAnchor.constraint(equalToConstant: 46).isActive = true
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

    @objc private func categoryTapped(_ sender: UIButton) {
        selectCategory(at: sender.tag)
    }

    private func selectCategory(at index: Int) {
        guard categories.indices.contains(index) else { return }
        selectedCategoryIndex = index
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
        updateAppearance(darkMode: darkMode)
        UIAccessibility.post(notification: .announcement, argument: categories[index].title)
    }

    @objc private func handleInputModeList(from sender: UIControl, with event: UIEvent) {
        delegate?.emojiKeyboardView(self, handleInputModeListFrom: sender, event: event)
    }

    @objc private func insertSpace() { delegate?.emojiKeyboardView(self, didTrigger: .space) }
    @objc private func deleteBackward() { delegate?.emojiKeyboardView(self, didTrigger: .backspace) }
    @objc private func insertReturn() { delegate?.emojiKeyboardView(self, didTrigger: .returnKey) }

    @objc private func emojiButtonTapped() {
        delegate?.emojiKeyboardViewRequestedTextKeyboard(self)
    }
}

extension EmojiKeyboardView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        categories[selectedCategoryIndex].emojis.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseIdentifier, for: indexPath) as? EmojiCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: categories[selectedCategoryIndex].emojis[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.emojiKeyboardView(self, didTrigger: .character(categories[selectedCategoryIndex].emojis[indexPath.item]))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = traitCollection.horizontalSizeClass == .regular ? 10 : 8
        return CGSize(width: floor(collectionView.bounds.width / columns), height: 44)
    }
}
