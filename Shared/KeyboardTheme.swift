import Foundation

struct ThemeColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

enum ThemeSelection: String, Codable, CaseIterable, Identifiable {
    case automatic
    case light
    case dark
    case custom

    var id: String { rawValue }

    var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

struct KeyboardTheme: Codable, Equatable {
    var keyboardBackground: ThemeColor
    var keyBackground: ThemeColor
    var functionKeyBackground: ThemeColor
    var accentKeyBackground: ThemeColor
    var textColor: ThemeColor
    var suggestionBarColor: ThemeColor
    var keyCornerRadius: Double
    var keyHeight: Double
    var fontSize: Double

    static let light = KeyboardTheme(
        keyboardBackground: ThemeColor(red: 0.82, green: 0.84, blue: 0.87),
        keyBackground: ThemeColor(red: 1, green: 1, blue: 1),
        functionKeyBackground: ThemeColor(red: 0.68, green: 0.70, blue: 0.73),
        accentKeyBackground: ThemeColor(red: 0.72, green: 0.74, blue: 0.77),
        textColor: ThemeColor(red: 0.04, green: 0.04, blue: 0.05),
        suggestionBarColor: ThemeColor(red: 0.76, green: 0.78, blue: 0.81),
        keyCornerRadius: 5,
        keyHeight: 44,
        fontSize: 22
    )

    static let dark = KeyboardTheme(
        keyboardBackground: ThemeColor(red: 0.13, green: 0.13, blue: 0.14),
        keyBackground: ThemeColor(red: 0.35, green: 0.35, blue: 0.37),
        functionKeyBackground: ThemeColor(red: 0.22, green: 0.22, blue: 0.24),
        accentKeyBackground: ThemeColor(red: 0.42, green: 0.42, blue: 0.45),
        textColor: ThemeColor(red: 1, green: 1, blue: 1),
        suggestionBarColor: ThemeColor(red: 0.18, green: 0.18, blue: 0.20),
        keyCornerRadius: 5,
        keyHeight: 44,
        fontSize: 22
    )
}

enum KeyboardThemeValidator {
    static func validated(_ theme: KeyboardTheme) -> KeyboardTheme {
        var result = theme
        result.keyboardBackground = validated(theme.keyboardBackground)
        result.keyBackground = validated(theme.keyBackground)
        result.functionKeyBackground = validated(theme.functionKeyBackground)
        result.accentKeyBackground = validated(theme.accentKeyBackground)
        result.textColor = validated(theme.textColor)
        result.suggestionBarColor = validated(theme.suggestionBarColor)
        result.keyCornerRadius = min(max(theme.keyCornerRadius, 0), 12)
        result.keyHeight = min(max(theme.keyHeight, 34), 56)
        result.fontSize = min(max(theme.fontSize, 16), 28)
        result.textColor = readableTextColor(
            preferred: result.textColor,
            backgrounds: [
                result.keyBackground,
                result.functionKeyBackground,
                result.accentKeyBackground
            ]
        )
        return result
    }

    private static func readableTextColor(
        preferred: ThemeColor,
        backgrounds: [ThemeColor]
    ) -> ThemeColor {
        let preferredContrast = backgrounds.map { contrastRatio(preferred, $0) }.min() ?? 1
        guard preferredContrast < 4.5 else { return preferred }

        let black = ThemeColor(red: 0.04, green: 0.04, blue: 0.05)
        let white = ThemeColor(red: 1, green: 1, blue: 1)
        let blackContrast = backgrounds.map { contrastRatio(black, $0) }.min() ?? 1
        let whiteContrast = backgrounds.map { contrastRatio(white, $0) }.min() ?? 1
        return blackContrast >= whiteContrast ? black : white
    }

    private static func contrastRatio(_ first: ThemeColor, _ second: ThemeColor) -> Double {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ color: ThemeColor) -> Double {
        func component(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * component(color.red) +
            0.7152 * component(color.green) +
            0.0722 * component(color.blue)
    }

    private static func validated(_ color: ThemeColor) -> ThemeColor {
        ThemeColor(
            red: min(max(color.red, 0), 1),
            green: min(max(color.green, 0), 1),
            blue: min(max(color.blue, 0), 1),
            alpha: min(max(color.alpha, 0.65), 1)
        )
    }
}

enum ThemeStoreKeys {
    static let appGroup = "group.com.rafiqkn.KnKeys"
    static let selection = "theme.selection"
    static let customTheme = "theme.custom"
    static let revision = "theme.revision"
    static let deletionFeedbackAnimation = "interaction.deletionFeedbackAnimation"
    static let interactionSettings = "interaction.settings"
}

final class ThemeStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = UserDefaults(suiteName: ThemeStoreKeys.appGroup)) {
        self.defaults = defaults ?? .standard
    }

    var revision: Int { defaults.integer(forKey: ThemeStoreKeys.revision) }

    func loadSelection() -> ThemeSelection {
        guard let rawValue = defaults.string(forKey: ThemeStoreKeys.selection),
              let selection = ThemeSelection(rawValue: rawValue) else {
            return .automatic
        }
        return selection
    }

    func loadDeletionFeedbackAnimation() -> Bool {
        defaults.bool(forKey: ThemeStoreKeys.deletionFeedbackAnimation)
    }

    func loadInteractionSettings() -> KeyboardInteractionSettings {
        guard let data = defaults.data(forKey: ThemeStoreKeys.interactionSettings),
              let settings = try? decoder.decode(KeyboardInteractionSettings.self, from: data) else {
            var settings = KeyboardInteractionSettings.defaults
            settings.deletionFeedbackAnimation = loadDeletionFeedbackAnimation()
            return settings
        }
        return settings
    }

    func loadCustomTheme() -> KeyboardTheme {
        guard let data = defaults.data(forKey: ThemeStoreKeys.customTheme),
              let theme = try? decoder.decode(KeyboardTheme.self, from: data) else {
            return .light
        }
        return KeyboardThemeValidator.validated(theme)
    }

    func save(
        selection: ThemeSelection,
        customTheme: KeyboardTheme,
        deletionFeedbackAnimation: Bool,
        keyPopupEnabled: Bool,
        keystrokeSoundMode: KeystrokeSoundMode
    ) {
        let interactionSettings = KeyboardInteractionSettings(
            deletionFeedbackAnimation: deletionFeedbackAnimation,
            keyPopupEnabled: keyPopupEnabled,
            keystrokeSoundMode: keystrokeSoundMode
        )
        defaults.set(selection.rawValue, forKey: ThemeStoreKeys.selection)
        defaults.set(deletionFeedbackAnimation, forKey: ThemeStoreKeys.deletionFeedbackAnimation)
        if let data = try? encoder.encode(interactionSettings) {
            defaults.set(data, forKey: ThemeStoreKeys.interactionSettings)
        }
        if let data = try? encoder.encode(KeyboardThemeValidator.validated(customTheme)) {
            defaults.set(data, forKey: ThemeStoreKeys.customTheme)
        }
        defaults.set(revision + 1, forKey: ThemeStoreKeys.revision)
    }
}
