import Foundation

enum KeystrokeSoundMode: String, Codable, CaseIterable, Identifiable {
    case off
    case system

    var id: String { rawValue }
    var title: String { self == .off ? "Off" : "System Click" }
}

struct KeyboardInteractionSettings: Codable, Equatable {
    var deletionFeedbackAnimation: Bool
    var keyPopupEnabled: Bool
    var keystrokeSoundMode: KeystrokeSoundMode

    static let defaults = KeyboardInteractionSettings(
        deletionFeedbackAnimation: false,
        keyPopupEnabled: true,
        keystrokeSoundMode: .system
    )
}
