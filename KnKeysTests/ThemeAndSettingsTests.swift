import XCTest

final class ThemeAndSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "KnKeysTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testThemeValidatorClampsDimensionsAndColors() {
        var theme = KeyboardTheme.light
        theme.keyCornerRadius = 99
        theme.keyHeight = 10
        theme.fontSize = 50
        theme.keyBackground = ThemeColor(red: -1, green: 2, blue: 0.5, alpha: 0.1)

        let result = KeyboardThemeValidator.validated(theme)

        XCTAssertEqual(result.keyCornerRadius, 12)
        XCTAssertEqual(result.keyHeight, 34)
        XCTAssertEqual(result.fontSize, 28)
        XCTAssertEqual(result.keyBackground.red, 0)
        XCTAssertEqual(result.keyBackground.green, 1)
        XCTAssertEqual(result.keyBackground.blue, 0.5)
        XCTAssertEqual(result.keyBackground.alpha, 0.65)
    }

    func testThemeValidatorCorrectsUnreadableTextColor() {
        var theme = KeyboardTheme.light
        theme.textColor = theme.keyBackground

        let result = KeyboardThemeValidator.validated(theme)

        XCTAssertNotEqual(result.textColor, result.keyBackground)
        XCTAssertEqual(result.textColor, ThemeColor(red: 0.04, green: 0.04, blue: 0.05))
    }

    func testStoreRoundTripsThemeAndInteractionSettings() {
        let store = ThemeStore(defaults: defaults)
        var custom = KeyboardTheme.dark
        custom.keyHeight = 50

        store.save(
            selection: .custom,
            customTheme: custom,
            deletionFeedbackAnimation: true,
            keyPopupEnabled: false,
            keystrokeSoundMode: .off
        )

        XCTAssertEqual(store.loadSelection(), .custom)
        XCTAssertEqual(store.loadCustomTheme().keyHeight, 50)
        XCTAssertEqual(
            store.loadInteractionSettings(),
            KeyboardInteractionSettings(
                deletionFeedbackAnimation: true,
                keyPopupEnabled: false,
                keystrokeSoundMode: .off
            )
        )
        XCTAssertEqual(store.revision, 1)
    }

    func testStoreMigratesLegacyDeletionAnimationSetting() {
        defaults.set(true, forKey: ThemeStoreKeys.deletionFeedbackAnimation)
        let settings = ThemeStore(defaults: defaults).loadInteractionSettings()

        XCTAssertTrue(settings.deletionFeedbackAnimation)
        XCTAssertTrue(settings.keyPopupEnabled)
        XCTAssertEqual(settings.keystrokeSoundMode, .system)
    }

    func testThemeManagerResolvesExplicitDarkAndReloadsRevision() {
        let store = ThemeStore(defaults: defaults)
        let manager = ThemeManager(store: store)

        store.save(
            selection: .dark,
            customTheme: .light,
            deletionFeedbackAnimation: false,
            keyPopupEnabled: true,
            keystrokeSoundMode: .system
        )

        XCTAssertTrue(manager.reloadIfNeeded(for: .light, force: true))
        XCTAssertEqual(manager.currentTheme, .dark)
        XCTAssertTrue(manager.interactionSettings.keyPopupEnabled)
        XCTAssertFalse(manager.reloadIfNeeded(for: .light))
    }

    func testInteractionSettingsCodableRoundTrip() throws {
        let settings = KeyboardInteractionSettings(
            deletionFeedbackAnimation: true,
            keyPopupEnabled: false,
            keystrokeSoundMode: .off
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(KeyboardInteractionSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }
}
