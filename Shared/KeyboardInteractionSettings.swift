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
    var predictionEnabled: Bool

    static let defaults = KeyboardInteractionSettings(
        deletionFeedbackAnimation: false,
        keyPopupEnabled: true,
        keystrokeSoundMode: .system,
        predictionEnabled: true
    )

    private enum CodingKeys: String, CodingKey {
        case deletionFeedbackAnimation
        case keyPopupEnabled
        case keystrokeSoundMode
        case predictionEnabled
    }

    init(
        deletionFeedbackAnimation: Bool,
        keyPopupEnabled: Bool,
        keystrokeSoundMode: KeystrokeSoundMode,
        predictionEnabled: Bool = true
    ) {
        self.deletionFeedbackAnimation = deletionFeedbackAnimation
        self.keyPopupEnabled = keyPopupEnabled
        self.keystrokeSoundMode = keystrokeSoundMode
        self.predictionEnabled = predictionEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deletionFeedbackAnimation = try container.decode(Bool.self, forKey: .deletionFeedbackAnimation)
        keyPopupEnabled = try container.decode(Bool.self, forKey: .keyPopupEnabled)
        keystrokeSoundMode = try container.decode(KeystrokeSoundMode.self, forKey: .keystrokeSoundMode)
        predictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .predictionEnabled) ?? true
    }
}
