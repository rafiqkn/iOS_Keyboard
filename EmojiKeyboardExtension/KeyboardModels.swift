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

enum KeyboardKeyAction: Equatable {
    case character(String)
    case shift
    case backspace
    case space
    case returnKey
    case nextKeyboard
    case emoji
    case mode(KeyboardMode)
    case gestureDelete(GestureDeletionLevel)
    case spacer
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

struct KeyboardMetrics: Equatable {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let rowSpacing: CGFloat
    let keySpacing: CGFloat
    let cornerRadius: CGFloat
    let characterFontSize: CGFloat
    let functionFontSize: CGFloat

    static func resolve(for size: CGSize, idiom: UIUserInterfaceIdiom) -> KeyboardMetrics {
        let landscape = size.width > size.height
        if idiom == .pad {
            return KeyboardMetrics(
                horizontalPadding: 10,
                verticalPadding: 8,
                rowSpacing: 7,
                keySpacing: 6,
                cornerRadius: 6,
                characterFontSize: 22,
                functionFontSize: 15
            )
        }
        return KeyboardMetrics(
            horizontalPadding: landscape ? 8 : 4,
            verticalPadding: landscape ? 4 : 7,
            rowSpacing: landscape ? 3 : 6,
            keySpacing: landscape ? 4 : 5,
            cornerRadius: 5,
            characterFontSize: landscape ? 18 : 22,
            functionFontSize: landscape ? 13 : 15
        )
    }
}
