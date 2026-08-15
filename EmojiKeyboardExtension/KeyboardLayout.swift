import Foundation

enum KeyboardLayout {
    static func rows(for mode: KeyboardMode, uppercase: Bool) -> [KeyboardRowDescriptor] {
        switch mode {
        case .letters:
            return letterRows(uppercase: uppercase)
        case .numbers:
            return numberRows
        case .symbols:
            return symbolRows
        case .emoji:
            return []
        }
    }

    private static func characterRow(_ characters: [String]) -> KeyboardRowDescriptor {
        KeyboardRowDescriptor(keys: characters.map {
            KeyboardKeyDescriptor(.character($0), title: $0)
        })
    }

    private static func letterRows(uppercase: Bool) -> [KeyboardRowDescriptor] {
        func letters(_ value: String) -> [String] {
            value.map { uppercase ? String($0).uppercased() : String($0) }
        }

        let shiftSymbol = uppercase ? "shift.fill" : "shift"
        return [
            characterRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
            characterRow(letters("qwertyuiop")),
            KeyboardRowDescriptor(keys: [
                KeyboardKeyDescriptor(.spacer, width: 0.35, style: .spacer)
            ] + characterRow(letters("asdfghjkl")).keys + [
                KeyboardKeyDescriptor(.spacer, width: 0.35, style: .spacer)
            ]),
            KeyboardRowDescriptor(keys: [
                KeyboardKeyDescriptor(.shift, symbolName: shiftSymbol, width: 1.35, style: .function)
            ] + characterRow(letters("zxcvbnm")).keys + [
                KeyboardKeyDescriptor(.backspace, symbolName: "delete.left", width: 1.35, style: .function)
            ]),
            bottomRow(leftMode: .numbers)
        ]
    }

    private static let numberRows: [KeyboardRowDescriptor] = [
        characterRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
        characterRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]),
        characterRow([".", ",", "?", "!", "'", "#", "%", "_"]),
        KeyboardRowDescriptor(keys: [
            KeyboardKeyDescriptor(.mode(.symbols), title: "#+=", width: 1.35, style: .function),
            KeyboardKeyDescriptor(.character("+"), title: "+"),
            KeyboardKeyDescriptor(.character("="), title: "="),
            KeyboardKeyDescriptor(.character("*"), title: "*"),
            KeyboardKeyDescriptor(.character("%"), title: "%"),
            KeyboardKeyDescriptor(.character("#"), title: "#"),
            KeyboardKeyDescriptor(.character("_"), title: "_"),
            KeyboardKeyDescriptor(.backspace, symbolName: "delete.left", width: 1.35, style: .function)
        ]),
        bottomRow(leftMode: .letters)
    ]

    private static let symbolRows: [KeyboardRowDescriptor] = [
        characterRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]),
        characterRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]),
        characterRow([".", ",", "?", "!", "'", "`", "§", "©"]),
        KeyboardRowDescriptor(keys: [
            KeyboardKeyDescriptor(.mode(.numbers), title: "123", width: 1.35, style: .function),
            KeyboardKeyDescriptor(.character("…"), title: "…"),
            KeyboardKeyDescriptor(.character("®"), title: "®"),
            KeyboardKeyDescriptor(.character("™"), title: "™"),
            KeyboardKeyDescriptor(.character("✓"), title: "✓"),
            KeyboardKeyDescriptor(.character("°"), title: "°"),
            KeyboardKeyDescriptor(.character("÷"), title: "÷"),
            KeyboardKeyDescriptor(.backspace, symbolName: "delete.left", width: 1.35, style: .function)
        ]),
        bottomRow(leftMode: .letters)
    ]

    private static func bottomRow(leftMode: KeyboardMode) -> KeyboardRowDescriptor {
        let modeTitle = leftMode == .letters ? "ABC" : "123"
        return KeyboardRowDescriptor(keys: [
            KeyboardKeyDescriptor(.nextKeyboard, symbolName: "globe", width: 1.2, style: .function),
            KeyboardKeyDescriptor(.mode(leftMode), title: modeTitle, width: 1.25, style: .function),
            KeyboardKeyDescriptor(.emoji, symbolName: "face.smiling", width: 1.2, style: .function),
            KeyboardKeyDescriptor(.space, title: "space", width: 4.6, style: .space),
            KeyboardKeyDescriptor(.returnKey, title: "return", width: 1.8, style: .accent)
        ])
    }
}
