import XCTest
import UIKit

final class KeyboardLayoutTests: XCTestCase {
    func testLetterLayoutContainsFiveRowsAndPermanentNumberRow() {
        let rows = KeyboardLayout.rows(for: .letters, uppercase: false)

        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(characterTitles(in: rows[0]), Array("1234567890").map(String.init))
        XCTAssertEqual(characterTitles(in: rows[1]), Array("qwertyuiop").map(String.init))
        XCTAssertEqual(rows[2].role, .homeLetters)
    }

    func testUppercaseLayoutTransformsLettersOnly() {
        let rows = KeyboardLayout.rows(for: .letters, uppercase: true)

        XCTAssertEqual(characterTitles(in: rows[1]), Array("QWERTYUIOP").map(String.init))
        XCTAssertEqual(characterTitles(in: rows[0]), Array("1234567890").map(String.init))
        XCTAssertTrue(rows[3].keys.contains { $0.action == .shift && $0.symbolName == "shift.fill" })
    }

    func testAllTextModesHaveFiveRowsAndRequiredControls() {
        for mode in [KeyboardMode.letters, .numbers, .symbols] {
            let rows = KeyboardLayout.rows(for: mode, uppercase: false)
            XCTAssertEqual(rows.count, 5, "Unexpected row count for \(mode)")
            let actions = rows.flatMap(\.keys).map(\.action)
            XCTAssertTrue(actions.contains(.space))
            XCTAssertTrue(actions.contains(.returnKey))
            XCTAssertTrue(actions.contains(.emoji))
        }
    }

    func testEmojiModeHasNoQwertyRows() {
        XCTAssertTrue(KeyboardLayout.rows(for: .emoji, uppercase: false).isEmpty)
    }

    func testMetricsUseThemeDimensionsAndDeviceProfile() {
        var theme = KeyboardTheme.light
        theme.keyCornerRadius = 9
        theme.fontSize = 26

        let phone = KeyboardMetrics.resolve(
            for: CGSize(width: 390, height: 320),
            idiom: .phone,
            theme: theme
        )
        let pad = KeyboardMetrics.resolve(
            for: CGSize(width: 1024, height: 350),
            idiom: .pad,
            theme: theme
        )

        XCTAssertEqual(phone.cornerRadius, 9)
        XCTAssertEqual(phone.characterFontSize, 26)
        XCTAssertEqual(pad.characterFontSize, 26)
        XCTAssertGreaterThan(pad.horizontalPadding, phone.horizontalPadding)
    }

    func testKeyboardStateDefaultsToLetters() {
        let state = KeyboardState()
        XCTAssertEqual(state.mode, .letters)
        XCTAssertEqual(state.previousTextMode, .letters)
        XCTAssertEqual(state.shift, .off)
    }

    private func characterTitles(in row: KeyboardRowDescriptor) -> [String] {
        row.keys.compactMap { descriptor in
            guard case .character = descriptor.action else { return nil }
            return descriptor.title
        }
    }
}

final class EmojiCatalogTests: XCTestCase {
    func testCatalogHasUniqueNonEmptyCategories() {
        XCTAssertEqual(EmojiCatalog.categories.count, 9)
        XCTAssertEqual(Set(EmojiCatalog.categories.map(\.title)).count, EmojiCatalog.categories.count)

        for category in EmojiCatalog.categories {
            XCTAssertFalse(category.title.isEmpty)
            XCTAssertFalse(category.iconName.isEmpty)
            XCTAssertFalse(category.emojis.isEmpty)
            XCTAssertFalse(category.emojis.contains(where: \.isEmpty))
        }
    }

    func testCategoryParserSplitsEmojiTokens() {
        let category = EmojiCategory(iconName: "star", title: "Test", emojis: "😀 🚀 ❤️")
        XCTAssertEqual(category.emojis, ["😀", "🚀", "❤️"])
    }
}

final class TextDeletionPlannerTests: XCTestCase {
    private let configuration = GestureDeletionConfiguration.standard

    func testCharacterDeletionIsClamped() {
        XCTAssertEqual(
            TextDeletionPlanner.deletionCount(for: .characters(99), context: "hello", configuration: configuration),
            configuration.maximumCharacterCount
        )
        XCTAssertEqual(
            TextDeletionPlanner.deletionCount(for: .characters(0), context: "hello", configuration: configuration),
            1
        )
    }

    func testPreviousWordIncludesTrailingWhitespaceAndPunctuation() {
        let context = "hello world  "
        let count = TextDeletionPlanner.deletionCount(
            for: .previousWord,
            context: context,
            configuration: configuration
        )

        XCTAssertEqual(String(context.suffix(count)), "world  ")
    }

    func testPreviousWordFallsBackWithoutContext() {
        XCTAssertEqual(
            TextDeletionPlanner.deletionCount(for: .previousWord, context: nil, configuration: configuration),
            1
        )
    }

    func testSentenceDeletionHonorsMaximum() {
        var configuration = configuration
        configuration.maximumSentenceCharacterCount = 10
        let count = TextDeletionPlanner.deletionCount(
            for: .previousSentence,
            context: "This is a very long sentence.",
            configuration: configuration
        )
        XCTAssertEqual(count, 10)
    }
}
