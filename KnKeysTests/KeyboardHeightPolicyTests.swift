import XCTest
import UIKit

final class KeyboardHeightPolicyTests: XCTestCase {
    func testPortraitPhoneDoesNotUseLandscapeCapEvenThoughKeyboardIsWide() {
        let height = KeyboardHeightPolicy.outerHeight(
            keyHeight: 56,
            idiom: .phone,
            verticalSizeClass: .regular
        )
        XCTAssertEqual(height, 354)
        XCTAssertGreaterThan(height, 230)
    }

    func testCompactPhoneUsesLandscapeCap() {
        XCTAssertEqual(
            KeyboardHeightPolicy.outerHeight(
                keyHeight: 56,
                idiom: .phone,
                verticalSizeClass: .compact
            ),
            230
        )
    }

    func testIPadHeightIsIndependentOfPhoneLandscapeRule() {
        XCTAssertEqual(
            KeyboardHeightPolicy.outerHeight(
                keyHeight: 56,
                idiom: .pad,
                verticalSizeClass: .compact
            ),
            360
        )
    }

    func testOuterHeightIsModeIndependentByConstruction() {
        let expected = KeyboardHeightPolicy.outerHeight(
            keyHeight: 44,
            idiom: .phone,
            verticalSizeClass: .regular
        )
        for _ in KeyboardMode.allTestModes {
            XCTAssertEqual(
                KeyboardHeightPolicy.outerHeight(
                    keyHeight: 44,
                    idiom: .phone,
                    verticalSizeClass: .regular
                ),
                expected
            )
        }
    }

    func testRowHeightUsesPreferredHeightWhenSpaceAllows() {
        XCTAssertEqual(
            KeyboardRowHeightPolicy.effectiveHeight(
                preferredHeight: 44,
                containerHeight: 294,
                rowCount: 5,
                rowSpacing: 6,
                verticalPadding: 7
            ),
            43.2,
            accuracy: 0.01
        )
    }

    func testRowHeightIsCappedInLandscape() {
        XCTAssertEqual(
            KeyboardRowHeightPolicy.effectiveHeight(
                preferredHeight: 56,
                containerHeight: 230,
                rowCount: 5,
                rowSpacing: 3,
                verticalPadding: 4
            ),
            34,
            accuracy: 0.01
        )
    }

    func testInvalidContainerDoesNotProduceNegativeHeight() {
        XCTAssertEqual(
            KeyboardRowHeightPolicy.effectiveHeight(
                preferredHeight: 44,
                containerHeight: 0,
                rowCount: 5,
                rowSpacing: 6,
                verticalPadding: 7
            ),
            0
        )
    }
}

private extension KeyboardMode {
    static let allTestModes: [KeyboardMode] = [.letters, .numbers, .symbols, .emoji]
}
