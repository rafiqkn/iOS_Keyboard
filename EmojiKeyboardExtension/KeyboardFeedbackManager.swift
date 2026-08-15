import UIKit

final class KeyboardFeedbackManager {
    var soundMode: KeystrokeSoundMode = .system

    func playKeyClick() {
        guard soundMode == .system else { return }
        UIDevice.current.playInputClick()
    }
}
