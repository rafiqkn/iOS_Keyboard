import Foundation
import UIKit

/// Folds the system pasteboard into the shared clipboard history at natural,
/// user-initiated moments (keyboard presentation, clipboard panel open, host
/// app activation, field changes). It never runs on a timer and never watches
/// the pasteboard in the background.
///
/// The pasteboard is only touched when `changeCount` advanced since the last
/// observed value. Non-Full-Access keyboards that cannot read the pasteboard
/// simply see `nil` and skip; the host-app path still seeds the history.
enum ClipboardPasteboardSync {
    private static var lastObservedChangeCount: Int = -1

    static func sweep() {
        let pasteboard = UIPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastObservedChangeCount else { return }
        lastObservedChangeCount = changeCount

        guard let raw = pasteboard.string else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let store = ClipboardHistoryStore()
        guard store.load().first?.text != trimmed else { return }
        store.add(trimmed)
    }

    /// Test seam that lets a fresh process start from a known change count.
    static func resetObservation() {
        lastObservedChangeCount = -1
    }
}