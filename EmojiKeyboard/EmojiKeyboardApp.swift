import SwiftUI
import UIKit

@main
struct EmojiKeyboardApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { phase in
            // Folds the system clipboard into the shared history only while
            // the app is actively foregrounded. No timers or background
            // monitoring; the changeCount probe is cheap and skipped when
            // nothing was copied since the last observation.
            guard phase == .active else { return }
            ClipboardPasteboardSync.sweep()
        }
    }
}
