import UIKit

enum KeyboardMode: Equatable {
    case letters
    case numbers
    case symbols
    case emoji
}

enum ShiftState: Equatable {
    case off
    case on
    case capsLock
}

enum CandidateBarContent: Equatable {
    case hidden
    case predictions([String])
}

enum KeyboardKeyAction: Equatable {
    case character(String)
    case shift
    case backspace
    case space
    case returnKey
    case emoji
    case mode(KeyboardMode)
    case gestureDelete(GestureDeletionLevel)
    case predictionSelected(String)
    case retractLastInsert
    case spacer
}

/// A touch-down insertion is undone only when the document still ends with
/// exactly what was inserted. Stale retractions (multi-touch, later edits)
/// fail the suffix check and become no-ops.
enum InsertionRetractionPolicy {
    static func isRetractable(insertedText: String?, contextBefore: String?) -> Bool {
        guard let insertedText, !insertedText.isEmpty else { return false }
        return (contextBefore ?? "").hasSuffix(insertedText)
    }
}

enum KeyboardKeyStyle {
    case character
    case function
    case accent
    case space
    case spacer
}

struct KeyboardKeyDescriptor {
    let action: KeyboardKeyAction
    let title: String?
    let symbolName: String?
    let width: CGFloat
    let style: KeyboardKeyStyle

    init(
        _ action: KeyboardKeyAction,
        title: String? = nil,
        symbolName: String? = nil,
        width: CGFloat = 1,
        style: KeyboardKeyStyle = .character
    ) {
        self.action = action
        self.title = title
        self.symbolName = symbolName
        self.width = width
        self.style = style
    }
}

enum KeyboardRowRole {
    case standard
    case homeLetters
}

struct KeyboardRowDescriptor {
    let keys: [KeyboardKeyDescriptor]
    let role: KeyboardRowRole

    init(keys: [KeyboardKeyDescriptor], role: KeyboardRowRole = .standard) {
        self.keys = keys
        self.role = role
    }
}

struct KeyboardState {
    var mode: KeyboardMode = .letters
    var previousTextMode: KeyboardMode = .letters
    var shift: ShiftState = .off
}

struct KeyboardHeightPolicy {
    static func outerHeight(
        keyHeight: CGFloat,
        idiom: UIUserInterfaceIdiom,
        verticalSizeClass: UIUserInterfaceSizeClass?
    ) -> CGFloat {
        let compactPhoneLandscape = idiom == .phone && verticalSizeClass == .compact
        let rowSpacing: CGFloat = idiom == .pad ? 7 : (compactPhoneLandscape ? 3 : 6)
        let verticalPadding: CGFloat = idiom == .pad ? 8 : (compactPhoneLandscape ? 4 : 7)
        let themedHeight = keyHeight * 5 + rowSpacing * 4 + verticalPadding * 2 + 36
        let allowedRange: ClosedRange<CGFloat>
        if idiom == .pad {
            allowedRange = 280...370
        } else if compactPhoneLandscape {
            allowedRange = 190...230
        } else {
            allowedRange = 250...360
        }
        return min(max(themedHeight, allowedRange.lowerBound), allowedRange.upperBound)
    }
}

struct KeyboardRowHeightPolicy {
    static func effectiveHeight(
        preferredHeight: CGFloat,
        containerHeight: CGFloat,
        rowCount: Int,
        rowSpacing: CGFloat,
        verticalPadding: CGFloat,
        candidateBandHeight: CGFloat = 40
    ) -> CGFloat {
        guard rowCount > 0, containerHeight > 0 else { return 0 }
        let spacingHeight = rowSpacing * CGFloat(max(0, rowCount - 1))
        let availableHeight = max(
            0,
            containerHeight - candidateBandHeight - verticalPadding * 2 - spacingHeight
        )
        let maximumRowHeight = availableHeight / CGFloat(rowCount)
        return max(28, min(preferredHeight, maximumRowHeight))
    }
}

struct KeyboardMetrics: Equatable {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let rowSpacing: CGFloat
    let keySpacing: CGFloat
    let cornerRadius: CGFloat
    let characterFontSize: CGFloat
    let functionFontSize: CGFloat

    static func resolve(
        for size: CGSize,
        idiom: UIUserInterfaceIdiom,
        verticalSizeClass: UIUserInterfaceSizeClass? = nil,
        theme: KeyboardTheme
    ) -> KeyboardMetrics {
        let landscape = idiom == .phone && verticalSizeClass == .compact
        if idiom == .pad {
            return KeyboardMetrics(
                horizontalPadding: 10,
                verticalPadding: 8,
                rowSpacing: 7,
                keySpacing: 6,
                cornerRadius: CGFloat(theme.keyCornerRadius),
                characterFontSize: CGFloat(theme.fontSize),
                functionFontSize: min(CGFloat(theme.fontSize), 20)
            )
        }
        return KeyboardMetrics(
            horizontalPadding: landscape ? 8 : 4,
            verticalPadding: landscape ? 4 : 7,
            rowSpacing: landscape ? 3 : 6,
            keySpacing: landscape ? 4 : 5,
            cornerRadius: CGFloat(theme.keyCornerRadius),
            characterFontSize: landscape ? min(CGFloat(theme.fontSize), 22) : CGFloat(theme.fontSize),
            functionFontSize: landscape ? min(CGFloat(theme.fontSize) * 0.7, 16) : min(CGFloat(theme.fontSize) * 0.72, 18)
        )
    }
}
