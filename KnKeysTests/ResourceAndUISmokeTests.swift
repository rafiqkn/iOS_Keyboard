import XCTest
import UIKit

final class BundledDictionaryTests: XCTestCase {
    func testBundledLexiconIsPresentAndSubstantial() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "english_prediction_words", withExtension: "txt"))
        let contents = try String(contentsOf: url, encoding: .utf8)
        let words = contents.split(whereSeparator: \.isNewline).map(String.init)

        XCTAssertGreaterThan(words.count, 1_000)
        XCTAssertTrue(words.contains("hello"))
        XCTAssertTrue(words.contains("keyboard"))
        XCTAssertTrue(words.contains("world"))
    }

    func testLocalPredictionDictionarySupportsPrefixesAndBigrams() {
        let dictionary = LocalWordPredictionDictionary(bundle: Bundle(for: Self.self))

        XCTAssertTrue(dictionary.words(withPrefix: "key", limit: 10).map(\.word).contains("key"))
        XCTAssertEqual(dictionary.nextWords(after: "thank", limit: 3).first?.word, "you")
    }
}

final class UIKitComponentSmokeTests: XCTestCase {
    func testKeyboardKeyControlUpdatesCharacterAndTheme() {
        let descriptor = KeyboardKeyDescriptor(.character("a"), title: "a")
        let control = KeyboardKeyControl(descriptor: descriptor)
        let metrics = KeyboardMetrics.resolve(
            for: CGSize(width: 390, height: 300),
            idiom: .phone,
            verticalSizeClass: .regular,
            theme: .light
        )

        control.setCharacter("A")
        control.update(metrics: metrics, theme: .light)

        XCTAssertEqual(control.action, .character("A"))
        XCTAssertEqual(control.popupText, "A")
        XCTAssertEqual(control.layer.cornerRadius, metrics.cornerRadius)
    }

    func testKeyPopupPresenterCanShowAndHideWithoutChangingContainerLayout() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        let key = UIView(frame: CGRect(x: 100, y: 100, width: 36, height: 44))
        container.addSubview(key)
        let presenter = KeyPopupPresenter(container: container)
        let initialBounds = container.bounds

        presenter.show(text: "A", above: key, theme: .light)
        XCTAssertNotNil(presenter.popup.layer.shadowPath, "Popup should cache its shadow path to avoid per-frame offscreen rendering")
        presenter.hide()

        XCTAssertEqual(container.bounds, initialBounds)
        XCTAssertEqual(container.subviews.count, 2)
    }

    func testEmojiCellCanBeConfiguredAndReused() {
        let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        cell.configure(with: "😀")

        XCTAssertEqual(cell.accessibilityLabel, "😀")
        XCTAssertTrue(cell.accessibilityTraits.contains(.keyboardKey))
    }

    func testEmojiViewAppliesThemesWithoutAmbiguousLayout() {
        let view = EmojiKeyboardView(frame: CGRect(x: 0, y: 0, width: 390, height: 294))
        view.updateAppearance(theme: .dark)
        view.layoutIfNeeded()

        XCTAssertEqual(view.backgroundColor, KeyboardTheme.dark.keyboardBackground.uiColor)
        XCTAssertFalse(view.hasAmbiguousLayout)
    }

    func testClipboardViewAppliesThemeWithoutAmbiguousLayout() {
        let view = ClipboardKeyboardView(frame: CGRect(x: 0, y: 0, width: 390, height: 294))
        view.reloadHistory()
        view.updateAppearance(theme: .dark)
        view.layoutIfNeeded()

        XCTAssertEqual(view.backgroundColor, KeyboardTheme.dark.keyboardBackground.uiColor)
        XCTAssertFalse(view.hasAmbiguousLayout)
    }

    func testSuggestionBarWithSettingsAndClipboardButtonsLaysOut() {
        let view = QwertyKeyboardView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        view.update(
            state: KeyboardState(),
            theme: .light,
            size: view.bounds.size,
            returnKeyTitle: "return"
        )
        view.showCandidates(.predictions(["the", "this", "that"]), animated: false)
        view.layoutIfNeeded()

        XCTAssertFalse(view.hasAmbiguousLayout)
        XCTAssertTrue(view.suggestionBarIsVisible)
    }

    func testSettingsKeyboardViewRendersTogglesWithoutAmbiguousLayout() {
        let view = SettingsKeyboardView(frame: CGRect(x: 0, y: 0, width: 390, height: 294))
        view.configure(settings: .defaults)
        view.updateAppearance(theme: .dark)
        view.layoutIfNeeded()

        XCTAssertEqual(view.backgroundColor, KeyboardTheme.dark.keyboardBackground.uiColor)
        XCTAssertFalse(view.hasAmbiguousLayout)
    }
}
