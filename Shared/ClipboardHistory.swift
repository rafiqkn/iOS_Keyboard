import Foundation

/// A single clipboard history record. Newest-first ordering is enforced by
/// the store; FIFO eviction drops the oldest entry once the cap is hit.
struct ClipboardItem: Codable, Equatable {
    let id: UUID
    let text: String
    let addedAt: Date

    init(id: UUID = UUID(), text: String, addedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.addedAt = addedAt
    }
}

enum ClipboardHistoryKeys {
    static let history = "clipboard.history"
    static let maxRecords = 25
}

/// App-Group-backed clipboard history shared between the host app and the
/// keyboard extension. Newest record is stored at index 0; adding a record
/// beyond `maxRecords` removes the oldest (FIFO). Re-copying identical text
/// moves it to the front instead of creating a duplicate record.
final class ClipboardHistoryStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = UserDefaults(suiteName: ThemeStoreKeys.appGroup)) {
        self.defaults = defaults ?? .standard
    }

    func load() -> [ClipboardItem] {
        guard let data = defaults.data(forKey: ClipboardHistoryKeys.history),
              let items = try? decoder.decode([ClipboardItem].self, from: data) else {
            return []
        }
        return items
    }

    /// Inserts `text` at the front. Empty text is ignored. Existing copies of
    /// the same text are removed first (most recent wins), and the array is
    /// trimmed to `maxRecords`, evicting the oldest entry (FIFO).
    @discardableResult
    func add(_ text: String) -> [ClipboardItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return load() }
        var items = load()
        items.removeAll { $0.text == trimmed }
        items.insert(ClipboardItem(text: trimmed), at: 0)
        if items.count > ClipboardHistoryKeys.maxRecords {
            items = Array(items.prefix(ClipboardHistoryKeys.maxRecords))
        }
        save(items)
        return items
    }

    func remove(id: UUID) {
        save(load().filter { $0.id != id })
    }

    func clear() {
        defaults.removeObject(forKey: ClipboardHistoryKeys.history)
    }

    private func save(_ items: [ClipboardItem]) {
        if let data = try? encoder.encode(items) {
            defaults.set(data, forKey: ClipboardHistoryKeys.history)
        }
    }
}