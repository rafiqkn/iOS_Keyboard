import XCTest
import UIKit

final class BundledDictionaryTests: XCTestCase {
    func testBundledLexiconIsPresentAndSubstantial() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "english_swipe_words", withExtension: "txt"))
        let contents = try String(contentsOf: url, encoding: .utf8)
        let words = contents.split(whereSeparator: \.isNewline).map(String.init)

        XCTAssertGreaterThan(words.count, 1_000)
        XCTAssertTrue(words.contains("hello"))
        XCTAssertTrue(words.contains("keyboard"))
        XCTAssertTrue(words.contains("world"))
    }

    func testLocalSwipeDictionaryUsesFirstAndLastLetterIndex() {
        let dictionary = LocalSwipeDictionary(bundle: Bundle(for: Self.self))
        let words = dictionary.words(startingWith: "h", endingWith: "o").map(\.word)

        XCTAssertTrue(words.contains("hello"))
        XCTAssertTrue(words.allSatisfy { $0.first == "h" && $0.last == "o" })
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
}
