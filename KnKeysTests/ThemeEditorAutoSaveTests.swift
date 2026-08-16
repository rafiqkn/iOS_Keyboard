import XCTest

@MainActor
final class ThemeEditorAutoSaveTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: ThemeStore!

    override func setUp() {
        super.setUp()
        suiteName = "KnKeysThemeEditorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = ThemeStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testScheduledAutoSavePersistsAllSettings() async throws {
        let model = ThemeEditorModel(store: store)
        model.selection = .custom
        model.theme.keyHeight = 50
        model.keyPopupEnabled = false
        model.deletionFeedbackAnimation = true
        model.keystrokeSoundMode = .off

        model.scheduleAutoSave()
        XCTAssertEqual(model.saveStatus, .saving)

        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(model.saveStatus, .saved)
        XCTAssertEqual(store.loadSelection(), .custom)
        XCTAssertEqual(store.loadCustomTheme().keyHeight, 50)
        XCTAssertEqual(
            store.loadInteractionSettings(),
            KeyboardInteractionSettings(
                deletionFeedbackAnimation: true,
                keyPopupEnabled: false,
                keystrokeSoundMode: .off
            )
        )
        XCTAssertEqual(store.revision, 1)
    }

    func testRepeatedChangesAreDebouncedIntoOneRevision() async throws {
        let model = ThemeEditorModel(store: store)

        model.theme.fontSize = 20
        model.scheduleAutoSave()
        model.theme.fontSize = 22
        model.scheduleAutoSave()
        model.theme.fontSize = 24
        model.scheduleAutoSave()

        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(store.loadCustomTheme().fontSize, 24)
        XCTAssertEqual(store.revision, 1)
    }

    func testFlushPersistsWithoutWaitingForDebounce() {
        let model = ThemeEditorModel(store: store)
        model.selection = .dark
        model.scheduleAutoSave()

        model.flushPendingChanges()

        XCTAssertEqual(model.saveStatus, .saved)
        XCTAssertEqual(store.loadSelection(), .dark)
        XCTAssertEqual(store.revision, 1)
    }

    func testResetParticipatesInAutoSavePipeline() {
        let model = ThemeEditorModel(store: store)
        model.theme = .dark
        model.reset()
        model.scheduleAutoSave()
        model.flushPendingChanges()

        XCTAssertEqual(store.loadSelection(), .custom)
        XCTAssertEqual(store.loadCustomTheme(), .light)
    }
}
