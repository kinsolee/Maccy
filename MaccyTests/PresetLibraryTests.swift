import Defaults
import SwiftData
import XCTest
@testable import Maccy

@MainActor
final class PresetLibraryTests: XCTestCase {
  private var directory: URL!
  private var storeURL: URL { directory.appendingPathComponent("Storage.sqlite") }

  override func setUpWithError() throws {
    try XCTSkipUnless(AppDelegate.isUnitTesting, "Run with the isolated unit-test configuration.")
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MaccyPresetTests-\(ProcessInfo.processInfo.processIdentifier)")
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    // SwiftData can keep SQLite descriptors alive until the test host exits.
    // Remove MaccyPresetTests-<pid> only after that process has stopped.
    directory = nil
  }

  func testHostIsIsolated() {
    XCTAssertTrue(AppDelegate.isTesting)
    XCTAssertTrue(AppDelegate.isUnitTesting)
    XCTAssertNil(AppState.shared.appDelegate)
    XCTAssertEqual(Clipboard.shared.pasteboard.name.rawValue, Defaults.Keys.testingSuiteName)
    XCTAssertTrue(Defaults.Keys.testingSuiteName.hasPrefix(Bundle.main.bundleIdentifier! + ".uitests."))
  }

  func testLegacyStoreAndGroupDeletionSurviveReopening() throws {
    // Synthetic old-schema disk store: no real user history or clipboard is read.
    try autoreleasepool {
      let legacy = try ModelContainer(for: HistoryItem.self, configurations: ModelConfiguration(url: storeURL))
      let history = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("history".utf8))])
      history.title = "existing alias"
      history.pin = "b"
      legacy.mainContext.insert(history)
      try legacy.mainContext.save()
    }
    let original = "  订单\nOlá 👩🏽‍💻 e\u{301}\n\t"
    try autoreleasepool {
      let container = try makeContainer()
      let history = try container.mainContext.fetch(FetchDescriptor<HistoryItem>())
      XCTAssertEqual(history.count, 1)
      XCTAssertEqual(history.first?.title, "existing alias")
      XCTAssertEqual(history.first?.pin, "b")
      let library = try PresetLibrary(container: container)
      let groupID = try library.createGroup(name: "客服")
      try library.save(PresetDraft(text: original, groupID: groupID))
      try library.deleteGroup(id: groupID)
    }
    try autoreleasepool {
      let container = try makeContainer()
      let library = try PresetLibrary(container: container)
      XCTAssertTrue(library.groups.isEmpty)
      XCTAssertEqual(library.presets.count, 1)
      XCTAssertNil(library.presets.first?.group)
      XCTAssertEqual(library.presets.first?.text, original)
      XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<HistoryItemContent>()), 1)
    }
  }

  func testNewGroupsLeadTheTabBar() throws {
    let container = try makeContainer()
    let library = try PresetLibrary(container: container)
    let first = try library.createGroup(name: "first")
    let second = try library.createGroup(name: "second")
    XCTAssertEqual(library.groups.map(\.id), [second, first])
  }

  func testFailedDraftCannotLeakThroughAnotherSave() throws {
    try autoreleasepool {
      let container = try makeContainer()
      var failSave = false
      let library = try PresetLibrary(container: container) { context in
        XCTAssertFalse(context === container.mainContext)
        XCTAssertFalse(context.autosaveEnabled)
        if failSave { throw CocoaError(.fileWriteOutOfSpace) }
        try context.save()
      }
      let group = try library.createGroup(name: "original group")
      let id = try library.save(PresetDraft(text: "original", groupID: group))
      let draft = PresetDraft(text: "abandoned draft", groupID: group)
      failSave = true
      XCTAssertThrowsError(try library.save(draft, editing: id))
      XCTAssertEqual(library.presets.first?.text, "original")
      XCTAssertEqual(draft.contents.first?.value, Data("abandoned draft".utf8))
      XCTAssertThrowsError(try library.deleteGroup(id: group))
      XCTAssertEqual(library.presets.first?.group?.id, group)
      XCTAssertThrowsError(try library.createGroup(name: "failed group"))
      XCTAssertThrowsError(try library.save(PresetDraft(text: "failed insert")))
      XCTAssertThrowsError(try library.deletePreset(id: id))
      XCTAssertEqual(library.groups.count, 1)
      XCTAssertEqual(library.presets.count, 1)
      XCTAssertEqual(library.presets.first?.text, "original")

      // Saving the history context, then the preset context, must not revive the failed edit.
      container.mainContext.insert(HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text",
                                                                           value: Data("new history".utf8))]))
      try container.mainContext.save()
      XCTAssertEqual(library.presets.first?.text, "original")
      failSave = false
      try library.createGroup(name: "later successful save")
      XCTAssertEqual(library.presets.first?.text, "original")
    }
    try autoreleasepool {
      let container = try makeContainer()
      let library = try PresetLibrary(container: container)
      XCTAssertEqual(library.presets.first?.text, "original")
      XCTAssertEqual(library.presets.first?.group?.name, "original group")
      XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PresetContent>()), 1)
      XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<HistoryItem>()), 1)
    }
  }

  func testHistoryCommandsDoNotDeletePresets() throws {
    let context = Storage.shared.context
    let pinned = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("pinned".utf8))])
    pinned.pin = "b"
    context.insert(pinned)
    context.insert(HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("history".utf8))]))
    try context.save()
    let library = try PresetLibrary(container: Storage.shared.container)
    let id = try library.save(PresetDraft(text: "saved independently"))
    defer { try? library.deletePreset(id: id) }
    History.shared.clear()
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryItem>()), 1)
    History.shared.clearAll()
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryItem>()), 0)
    let reread = try PresetLibrary(container: Storage.shared.container)
    XCTAssertEqual(reread.presets.first(where: { $0.id == id })?.text, "saved independently")
  }

  func testMissingTargetAndEmptyInputDoNotCreateRecords() throws {
    let library = try PresetLibrary(container: makeContainer())
    XCTAssertThrowsError(try library.createGroup(name: " \n"))
    XCTAssertThrowsError(try library.save(PresetDraft(text: "")))
    XCTAssertThrowsError(try library.save(PresetDraft(text: "body", groupID: UUID())))
    XCTAssertTrue(library.groups.isEmpty)
    XCTAssertTrue(library.presets.isEmpty)
    let id = try library.save(PresetDraft(text: " \n\t"))
    XCTAssertEqual(library.presets.first?.text, " \n\t")
    try library.deletePreset(id: id)
    let reread = try PresetLibrary(container: makeContainer())
    XCTAssertTrue(reread.presets.isEmpty)
  }

  private func makeContainer() throws -> ModelContainer {
    try ModelContainer(for: HistoryItem.self, PresetGroup.self, Preset.self, PresetContent.self,
                       configurations: ModelConfiguration(url: storeURL))
  }
}
