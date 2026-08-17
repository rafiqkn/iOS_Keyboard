import XCTest

final class ClipboardHistoryTests: XCTestCase {
    private var store: ClipboardHistoryStore!

    override func setUp() {
        super.setUp()
        store = ClipboardHistoryStore(defaults: UserDefaults(suiteName: "clipboard.test.store"))
        store.clear()
    }

    override func tearDown() {
        store.clear()
        store = nil
        super.tearDown()
    }

    func testNewestRecordsAppearFirst() {
        store.add("first")
        store.add("second")

        XCTAssertEqual(store.load().map(\.text), ["second", "first"])
    }

    func testEmptyTextIsIgnored() {
        store.add("   ")
        store.add("")
        store.add("hello")

        XCTAssertEqual(store.load().map(\.text), ["hello"])
    }

    func testFifoEvictionKeepsMaximumTwentyFive() {
        for index in 1...30 {
            store.add("record-\(index)")
        }

        let items = store.load()
        XCTAssertEqual(items.count, 25)
        XCTAssertEqual(items.first?.text, "record-30", "newest stays at the front")
        XCTAssertEqual(items.last?.text, "record-6", "oldest record-5 and older evicted")
        XCTAssertTrue(store.load().contains { $0.text == "record-6" })
        XCTAssertFalse(store.load().contains { $0.text == "record-5" })
    }

    func testRecopyingSameTextMovesItToFrontWithoutDuplicate() {
        store.add("a")
        store.add("b")
        store.add("a")

        let items = store.load()
        XCTAssertEqual(items.map(\.text), ["a", "b"])
        XCTAssertEqual(items.count, 2)
    }

    func testPersistenceSurvivesNewStoreInstance() {
        store.add("persisted")

        let reloaded = ClipboardHistoryStore(defaults: UserDefaults(suiteName: "clipboard.test.store"))
        XCTAssertEqual(reloaded.load().map(\.text), ["persisted"])
    }

    func testRemoveById() {
        store.add("a")
        store.add("b")
        let target = store.load().first { $0.text == "b" }!

        store.remove(id: target.id)

        XCTAssertEqual(store.load().map(\.text), ["a"])
    }

    func testClearEmptiesHistory() {
        store.add("a")
        store.clear()

        XCTAssertTrue(store.load().isEmpty)
    }
}