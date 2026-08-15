import UIKit

final class KeyboardViewController: UIInputViewController {
    private let categories = EmojiCatalog.categories
    private var selectedCategoryIndex = 0
    private var categoryButtons: [UIButton] = []
    private var heightConstraint: NSLayoutConstraint?

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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboard()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        heightConstraint?.constant = traitCollection.verticalSizeClass == .compact ? 220 : 300
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateAppearance()
    }

    private func setupKeyboard() {
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 300)
        heightConstraint?.priority = .defaultHigh
        heightConstraint?.isActive = true

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
        view.addSubview(categoryStack)
        view.addSubview(collectionView)
        view.addSubview(controls)

        NSLayoutConstraint.activate([
            categoryStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            categoryStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            categoryStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            categoryStack.heightAnchor.constraint(equalToConstant: 38),

            collectionView.topAnchor.constraint(equalTo: categoryStack.bottomAnchor, constant: 2),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            collectionView.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -4),

            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            controls.heightAnchor.constraint(equalToConstant: 42)
        ])

        selectCategory(at: 0)
        updateAppearance()
    }

    private func makeControlBar() -> UIView {
        let globeButton = makeKeyButton(symbol: "globe", accessibilityLabel: "Next keyboard")
        globeButton.addTarget(
            self,
            action: #selector(handleInputModeList(from:with:)),
            for: .allTouchEvents
        )

        let spaceButton = makeKeyButton(title: "space", accessibilityLabel: "Space")
        spaceButton.addTarget(self, action: #selector(insertSpace), for: .touchUpInside)

        let deleteButton = makeKeyButton(symbol: "delete.left", accessibilityLabel: "Delete")
        deleteButton.addTarget(self, action: #selector(deleteBackward), for: .touchUpInside)

        let returnButton = makeKeyButton(symbol: "return", accessibilityLabel: "Return")
        returnButton.addTarget(self, action: #selector(insertReturn), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [globeButton, spaceButton, deleteButton, returnButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fill

        globeButton.widthAnchor.constraint(equalToConstant: 46).isActive = true
        deleteButton.widthAnchor.constraint(equalToConstant: 54).isActive = true
        returnButton.widthAnchor.constraint(equalToConstant: 54).isActive = true
        return stack
    }

    private func makeKeyButton(
        title: String? = nil,
        symbol: String? = nil,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        if let symbol {
            button.setImage(UIImage(systemName: symbol), for: .normal)
        }
        button.accessibilityLabel = accessibilityLabel
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.18
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0.5
        return button
    }

    private func updateAppearance() {
        let darkMode = textDocumentProxy.keyboardAppearance == .dark
        view.backgroundColor = darkMode
            ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)

        categoryButtons.forEach { button in
            let selected = button.tag == selectedCategoryIndex
            button.tintColor = selected ? .systemBlue : (darkMode ? .lightGray : .darkGray)
            button.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.14) : .clear
            button.layer.cornerRadius = 6
        }

        for case let stack as UIStackView in view.subviews {
            for case let button as UIButton in stack.arrangedSubviews where stack !== categoryStack {
                button.tintColor = darkMode ? .white : .black
                button.setTitleColor(darkMode ? .white : .black, for: .normal)
                button.backgroundColor = darkMode ? .systemGray3 : .white
            }
        }
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        selectCategory(at: sender.tag)
    }

    private func selectCategory(at index: Int) {
        guard categories.indices.contains(index) else { return }
        selectedCategoryIndex = index
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
        updateAppearance()
        UIAccessibility.post(notification: .announcement, argument: categories[index].title)
    }

    @objc private func insertSpace() {
        insertText(" ")
    }

    @objc private func deleteBackward() {
        textDocumentProxy.deleteBackward()
        playInputClick()
    }

    @objc private func insertReturn() {
        insertText("\n")
    }

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
        playInputClick()
    }

    private func playInputClick() {
        UIDevice.current.playInputClick()
    }
}

extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

extension KeyboardViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        categories[selectedCategoryIndex].emojis.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: EmojiCell.reuseIdentifier,
            for: indexPath
        ) as? EmojiCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: categories[selectedCategoryIndex].emojis[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        insertText(categories[selectedCategoryIndex].emojis[indexPath.item])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let columns: CGFloat = traitCollection.horizontalSizeClass == .regular ? 10 : 8
        return CGSize(width: floor(collectionView.bounds.width / columns), height: 44)
    }
}
