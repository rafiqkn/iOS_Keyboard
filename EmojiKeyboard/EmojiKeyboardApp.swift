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
            // Captures the system clipboard only while the app is actively
            // foregrounded. No timers or background monitoring.
            guard phase == .active else { return }
            ClipboardPasteboardSync.captureIfNeeded()
        }
    }
}

/// Seeding helper: folds the current system clipboard into the shared
/// App Group history when the host app is foregrounded. The same store is
/// read by the keyboard extension's clipboard panel.
private enum ClipboardPasteboardSync {
    static func captureIfNeeded() {
        guard let string = UIPasteboard.general.string, !string.isEmpty else { return }
        let store = ClipboardHistoryStore()
        guard store.load().first?.text != string else { return }
        store.add(string)
    }
}
