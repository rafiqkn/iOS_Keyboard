import UIKit

extension ThemeColor {
    var uiColor: UIColor {
        UIColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}

final class ThemeManager {
    private let store: ThemeStore
    private var loadedRevision = -1
    private var selection: ThemeSelection = .automatic
    private var customTheme = KeyboardTheme.light
    private var cachedAppearance: UIKeyboardAppearance?
    private(set) var currentTheme = KeyboardTheme.light
    private(set) var deletionFeedbackAnimationEnabled = false

    init(store: ThemeStore = ThemeStore()) {
        self.store = store
    }

    @discardableResult
    func reloadIfNeeded(for appearance: UIKeyboardAppearance, force: Bool = false) -> Bool {
        let revision = store.revision
        let appearanceChanged = cachedAppearance != appearance
        guard force || revision != loadedRevision || appearanceChanged else { return false }

        if force || revision != loadedRevision {
            selection = store.loadSelection()
            customTheme = store.loadCustomTheme()
            deletionFeedbackAnimationEnabled = store.loadDeletionFeedbackAnimation()
            loadedRevision = revision
        }
        cachedAppearance = appearance
        let resolvedTheme = resolveTheme(for: appearance)
        guard resolvedTheme != currentTheme else { return false }
        currentTheme = resolvedTheme
        return true
    }

    private func resolveTheme(for appearance: UIKeyboardAppearance) -> KeyboardTheme {
        switch selection {
        case .automatic:
            return appearance == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        case .custom:
            return KeyboardThemeValidator.validated(customTheme)
        }
    }
}
