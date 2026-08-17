import Foundation
import UIKit

/// Folds the system pasteboard into the shared clipboard history at natural,
/// user-initiated moments (keyboard presentation, clipboard panel open, host
/// app activation, field changes). It never runs on a timer and never watches
/// the pasteboard in the background.
///
/// The pasteboard is only touched when `changeCount` advanced since the last
/// observed value. Non-Full-Access keyboards cannot read the pasteboard (the
/// system returns no snapshot), so they skip; the host-app path still seeds
/// the history, and enabling Optional Full Access in Settings turns on
/// automatic capture inside the keyboard itself.
enum ClipboardPasteboardSync {
    struct Snapshot {
        let changeCount: Int
        let text: String?
    }

    private static var lastObservedChangeCount: Int = -1

    /// `snapshot` and `store` are injectable for tests; production callers use
    /// the real system pasteboard and the shared App Group store.
    static func sweep(
        _ snapshot: Snapshot? = nil,
        store: ClipboardHistoryStore? = nil
    ) {
        let resolved = snapshot ?? Snapshot(
            changeCount: UIPasteboard.general.changeCount,
            text: UIPasteboard.general.string
        )
        let resolvedStore = store ?? ClipboardHistoryStore()
        guard resolved.changeCount != lastObservedChangeCount else { return }
        lastObservedChangeCount = resolved.changeCount

        guard let raw = resolved.text else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard resolvedStore.load().first?.text != trimmed else { return }
        resolvedStore.add(trimmed)
    }

    /// Test seam that lets a fresh process start from a known change count.
    static func resetObservation() {
        lastObservedChangeCount = -1
    }
}