import AppKit
import Defaults
import SwiftData
import SwiftUI
import XCTest
@testable import Maccy

@MainActor
final class PresetPickerTests: XCTestCase {
  override func setUpWithError() throws {
    try XCTSkipUnless(AppDelegate.isUnitTesting, "Requires the isolated unit-test host.")
  }

  private func library(save: @escaping (ModelContext) throws -> Void = { try $0.save() }) throws -> PresetLibrary {
    let container = try ModelContainer(for: HistoryItem.self, PresetGroup.self, Preset.self, PresetContent.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return try PresetLibrary(container: container, attachmentRoot: FileManager.default.temporaryDirectory
      .appendingPathComponent("MaccyPresetTests-\(ProcessInfo.processInfo.processIdentifier)/\(UUID())"), save: save)
  }


  func testHistoryDragSourceKeepsMouseEventsInsteadOfMovingWindow() {
    XCTAssertFalse(HistoryDragSource.DragView().mouseDownCanMoveWindow)
  }

  func testNativeHostRoutesOnlyLocalCopyDragsAndRejectsInvalidTokens() {
    let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                         styleMask: .borderless, backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    defer { panel.close() }
    let host = PresetDropHostingView(rootView: EmptyView())
    host.frame = NSRect(x: 30, y: 20, width: 300, height: 200)
    panel.contentView?.addSubview(host)
    XCTAssertTrue(host.registeredDraggedTypes.contains(HistoryDragSource.pasteboardType))
    let source = HistoryDragSource.DragView(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
    let target = PresetGroupDropTarget.DropView(frame: NSRect(x: 100, y: 80, width: 120, height: 30))
    host.addSubview(source)
    host.addSubview(target)
    var targetUpdates = [Bool]()
    target.setTargeted = { targetUpdates.append($0) }
    let info = SyntheticPresetDragInfo()
    info.draggingDestinationWindow = panel
    info.draggingLocation = target.convert(NSPoint(x: 60, y: 15), to: nil)
    // Synthetic payload on a unique pasteboard; never the system clipboard or a real drag.
    info.draggingPasteboard.setString(UUID().uuidString, forType: HistoryDragSource.pasteboardType)
    defer { info.draggingPasteboard.releaseGlobally() }
    info.draggingSource = NSObject()
    XCTAssertEqual(host.draggingEntered(info), [])
    XCTAssertTrue(targetUpdates.isEmpty)
    info.draggingSource = source
    info.draggingSourceOperationMask = .move
    XCTAssertEqual(host.draggingUpdated(info), [])
    XCTAssertTrue(targetUpdates.isEmpty)
    info.draggingSourceOperationMask = .copy
    XCTAssertEqual(host.draggingUpdated(info), [])
    XCTAssertEqual(targetUpdates, [false]) // Reached the native target; its original token check rejected it.
    XCTAssertFalse(host.prepareForDragOperation(info))
    XCTAssertFalse(host.performDragOperation(info))
    XCTAssertFalse(targetUpdates.contains(true))
    XCTAssertFalse(panel.isVisible)
  }

  func testPreviewAnimationAndHeightChangesKeepOneWindowFrame() async throws {
    let state = AppState.shared
    let saved = (state.appDelegate, state.popup, state.preview, state.navigator, Defaults[.windowSize])
    let delegate = AppDelegate()
    let popup = Popup()
    let preview = SlideoutController(onContentResize: { _ in }, onSlideoutResize: { _ in })
    state.appDelegate = delegate
    state.popup = popup
    state.preview = preview
    state.navigator = NavigationManager(history: History(), footer: Footer())
    let id = UUID()
    state.navigator.enterScope(history: false, presetIDs: [id])
    state.navigator.selectPreset(id)
    preview.contentWidth = 450
    preview.slideoutWidth = 400
    let panel = FloatingPanel(contentRect: NSRect(x: 100, y: 300, width: 450, height: 216),
                              onClose: {}, view: { ContentView() })
    // Exercise real NSPanel frame animations without showing a window or mounting app views.
    panel.contentView = nil
    panel.isReleasedWhenClosed = false
    delegate.panel = panel
    Defaults[.windowSize] = NSSize(width: 450, height: 800)
    defer {
      preview.cancelAutoOpen()
      panel.close()
      state.appDelegate = saved.0
      state.popup = saved.1
      state.preview = saved.2
      state.navigator = saved.3
      Defaults[.windowSize] = saved.4
    }
    XCTAssertFalse(panel.isVisible)
    for placement in [SlideoutPlacement.left, .right] {
      // Start with an open preview: changing editor height must not keep the old 850 width.
      preview.state = .open
      preview.placement = placement
      panel.setFrame(NSRect(x: 100, y: 300, width: 850, height: 216), display: false)
      popup.height = 216
      preview.togglePreview()
      popup.resize(height: 300)
      popup.resize(height: 379)
      try await Task.sleep(for: .milliseconds(600))
      XCTAssertEqual(preview.state, .closed)
      XCTAssertEqual(panel.frame.width, 450, accuracy: 1)
      XCTAssertEqual(panel.frame.height, 379, accuracy: 1)
      XCTAssertEqual(panel.frame.maxY, 516, accuracy: 1)
      XCTAssertEqual(panel.frame.minX, placement == .left ? 500 : 100, accuracy: 1)

      // Reverse the ordering: a height update immediately followed by a preview animation.
      popup.resize(height: 240)
      preview.togglePreview()
      popup.resize(height: 330)
      try await Task.sleep(for: .milliseconds(600))
      XCTAssertEqual(preview.state, .open)
      XCTAssertEqual(panel.frame.width, 850, accuracy: 1)
      XCTAssertEqual(panel.frame.height, 330, accuracy: 1)
      XCTAssertEqual(panel.frame.maxY, 516, accuracy: 1)

      // Rapid close/open/close also has a late height update, like switching into the editor.
      preview.togglePreview()
      try await Task.sleep(for: .milliseconds(50))
      popup.resize(height: 310)
      preview.togglePreview()
      try await Task.sleep(for: .milliseconds(50))
      preview.togglePreview()
      popup.resize(height: 390)
      try await Task.sleep(for: .milliseconds(600))
      XCTAssertEqual(preview.state, .closed)
      // Window-server frame application can lag the synchronous setFrame calls on a
      // loaded host; settle on the final frame instead of a racing snapshot.
      var settledWidth = panel.frame.width
      for _ in 0..<25 where abs(settledWidth - 450) > 1 {
        try await Task.sleep(for: .milliseconds(20))
        settledWidth = panel.frame.width
      }
      XCTAssertEqual(panel.frame.width, 450, accuracy: 1)
      XCTAssertEqual(panel.frame.height, 390, accuracy: 1)
      XCTAssertEqual(panel.frame.maxY, 516, accuracy: 1)
      XCTAssertFalse(panel.isVisible)
    }
  }

  func testPasteTargetChecksApplicationWithoutWindowAccess() {
    let target = PasteTarget(application: .current)
    let pid = ProcessInfo.processInfo.processIdentifier
    // Synthetic foreground IDs: no Accessibility window query or real paste event is needed.
    XCTAssertTrue(target.isCurrent(frontmostPID: pid))
    XCTAssertFalse(target.isCurrent(frontmostPID: nil))
    XCTAssertFalse(target.isCurrent(frontmostPID: pid + 1))
  }

  func testDirectHistorySelectionHonorsManagementLockEvenWithoutPopupSession() throws {
    let state = AppState.shared
    XCTAssertFalse(state.interactionLocked)
    XCTAssertFalse(state.sessionOpen)
    let draft = PresetDraft(text: "direct history copy")
    let item = HistoryItemDecorator(HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(draft.text.utf8))
    ]))
    let board = Clipboard.shared.pasteboard
    XCTAssertNotEqual(board.name, NSPasteboard.general.name)
    let before = board.changeCount
    defer { state.editor = nil; state.importInProgress = false; state.activeDrag = nil }
    state.editor = PresetEditor(id: nil, original: PresetDraft(text: ""), draft: draft)
    XCTAssertFalse(state.history.select(item, flags: .command))
    state.editor = nil
    state.importInProgress = true
    XCTAssertFalse(state.history.select(item, flags: .command))
    state.importInProgress = false
    state.activeDrag = PresetDrag(token: UUID(), sourceID: item.id, draft: draft)
    XCTAssertFalse(state.history.select(item, flags: .command))
    XCTAssertEqual(board.changeCount, before)
    state.activeDrag = nil
    XCTAssertTrue(state.history.select(item, flags: .command))
    XCTAssertEqual(board.string(forType: .string), draft.text)
  }

  func testScopeRestoresStableIDAndResetsEverySelectionSurface() throws {
    let library = try library()
    let group = try library.createGroup(name: "客服")
    let preset = try library.save(PresetDraft(text: "Olá", groupID: group))
    XCTAssertEqual(PresetScope.restored("history", groups: [group]), .history)
    XCTAssertEqual(PresetScope.restored(group.uuidString, groups: [group]), .group(group))
    XCTAssertEqual(PresetScope.restored(UUID().uuidString, groups: [group]), .history)
    XCTAssertEqual(PresetScope.restored("ungrouped", groups: []), .ungrouped)
    let state = AppState(history: History(), footer: Footer(), presetLibrary: library)
    state.sessionOpen = true
    state.navigator.isManualMultiSelect = true
    state.navigator.hoverSelectionWhileKeyboardNavigating = UUID()
    state.navigator.scrollTarget = UUID()
    state.chooseScope(.group(group))
    XCTAssertEqual(state.navigator.target, .preset(preset))
    XCTAssertTrue(state.navigator.selection.isEmpty)
    XCTAssertFalse(state.navigator.isManualMultiSelect)
    XCTAssertNil(state.navigator.hoverSelectionWhileKeyboardNavigating)
    XCTAssertNil(state.footer.selectedItem)
    state.searchQuery = "no match"
    XCTAssertNil(state.navigator.target)
    let before = Clipboard.shared.pasteboard.changeCount
    state.select(flags: .command)
    XCTAssertEqual(Clipboard.shared.pasteboard.changeCount, before)
    state.requestDelete(.group(group))
    XCTAssertEqual(state.scope, .history)
    XCTAssertNil(library.presets.first?.group)
    state.chooseScope(.ungrouped)
    XCTAssertEqual(state.presetResults.map(\.id), [preset])
  }

  func testDirtyDraftSaveDiscardCancelAndFailure() throws {
    var failSave = false
    let library = try library { context in
      if failSave { throw CocoaError(.fileWriteOutOfSpace) }
      try context.save()
    }
    let group = try library.createGroup(name: "group")
    let id = try library.save(PresetDraft(text: "original", groupID: group))
    let state = AppState(history: History(), footer: Footer(), presetLibrary: library)
    state.sessionOpen = true
    state.chooseScope(.group(group))
    let before = Clipboard.shared.pasteboard.changeCount
    state.beginEditPreset(id)
    state.editor?.draft.text = "changed 👩🏽‍💻 e\u{301}\n"
    state.chooseScope(.history)
    XCTAssertTrue(state.showUnsavedPrompt)
    XCTAssertEqual(state.scope, .group(group))
    state.cancelPendingChange()
    XCTAssertNotNil(state.editor)
    failSave = true
    state.saveManagement()
    XCTAssertNotNil(state.errorMessage)
    XCTAssertEqual(state.editor?.draft.text, "changed 👩🏽‍💻 e\u{301}\n")
    XCTAssertEqual(library.presets.first?.text, "original")
    failSave = false
    state.chooseScope(.history)
    state.saveManagement()
    XCTAssertNil(state.editor)
    XCTAssertEqual(state.scope, .history)
    XCTAssertEqual(library.presets.first?.text, "changed 👩🏽‍💻 e\u{301}\n")
    state.beginNewPreset()
    state.editor?.draft.text = "discard me"
    state.chooseScope(.ungrouped)
    state.discardManagement()
    XCTAssertEqual(library.presets.count, 1)
    XCTAssertEqual(state.scope, .ungrouped)
    XCTAssertEqual(Clipboard.shared.pasteboard.changeCount, before)
  }

  func testQueuedSendsExpireOnManagementNavigationAndDragCancellation() throws {
    let library = try library()
    let group = try library.createGroup(name: "group")
    try library.save(PresetDraft(text: "preset", groupID: group))
    let state = AppState(history: History(), footer: Footer(), presetLibrary: library)
    state.sessionOpen = true
    state.chooseScope(.group(group))
    let request = try XCTUnwrap(state.captureSend(flags: .command))
    state.beginNewPreset()
    XCTAssertFalse(state.accepts(request))
    state.discardManagement()
    XCTAssertFalse(state.accepts(request))
    state.chooseScope(.history)
    let historyItem = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("original".utf8))])
    let item = HistoryItemDecorator(historyItem)
    state.history.all = [item]
    state.history.items = [item]
    state.navigator.select(item: item)
    let queued = try XCTUnwrap(state.captureSend(flags: .command))
    let before = Clipboard.shared.pasteboard.changeCount
    let token = try XCTUnwrap(state.beginHistoryDrag(id: item.id))
    XCTAssertNil(state.captureSend(flags: .command))
    state.navigator.hoverSelectionWhileKeyboardNavigating = UUID()
    state.endHistoryDrag(token: token)
    XCTAssertNil(state.navigator.hoverSelectionWhileKeyboardNavigating)
    XCTAssertFalse(state.canDrop(token: token, groupID: group))
    state.send(queued)
    XCTAssertEqual(Clipboard.shared.pasteboard.changeCount, before)
    XCTAssertTrue(library.presets.count == 1)
    state.endPopupSession()
    XCTAssertNil(state.captureSend(flags: .command))
  }

  func testDropUsesValuesSavesOnceAndKeepsHistoryScope() async throws {
    let library = try library()
    let group = try library.createGroup(name: "group")
    let state = AppState(history: History(), footer: Footer(), presetLibrary: library)
    state.sessionOpen = true
    let model = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("captured".utf8))])
    let item = HistoryItemDecorator(model)
    state.history.all = [item]
    state.history.items = [item]
    state.navigator.select(item: item)
    let before = Clipboard.shared.pasteboard.changeCount
    let token = try XCTUnwrap(state.beginHistoryDrag(id: item.id))
    model.contents.first?.value = Data("edited after capture".utf8)
    XCTAssertFalse(state.drop(token: UUID(), groupID: group))
    XCTAssertFalse(state.drop(token: token, groupID: UUID()))
    XCTAssertTrue(state.drop(token: token, groupID: group))
    XCTAssertFalse(state.drop(token: token, groupID: group))
    state.endHistoryDrag(token: token)
    await state.importTask?.value
    XCTAssertEqual(library.presets.count, 1)
    XCTAssertEqual(library.presets.first?.text, "captured")
    XCTAssertEqual(state.scope, .history)
    XCTAssertEqual(state.history.all.count, 1)
    XCTAssertEqual(Clipboard.shared.pasteboard.changeCount, before)

    let expired = try XCTUnwrap(state.beginHistoryDrag(id: item.id))
    state.history.all = []
    XCTAssertFalse(state.drop(token: expired, groupID: group))
    state.endHistoryDrag(token: expired)
    XCTAssertEqual(library.presets.count, 1)
  }

  func testDeletingPresetDoesNotForceSelectAnotherRow() throws {
    let library = try library()
    let group = try library.createGroup(name: "G")
    let first = try library.save(PresetDraft(text: "one", groupID: group))
    let second = try library.save(PresetDraft(text: "two", groupID: group))
    let state = AppState(history: History(), footer: Footer(), presetLibrary: library)
    state.sessionOpen = true
    state.chooseScope(.group(group))
    XCTAssertEqual(state.navigator.target, .preset(first))
    let before = Clipboard.shared.pasteboard.changeCount
    state.requestDelete(.preset(first))
    XCTAssertEqual(state.presetResults.map(\.id), [second])
    XCTAssertNil(state.navigator.target)
    XCTAssertEqual(Clipboard.shared.pasteboard.changeCount, before)
  }

  func testPresetDragMovesGroupsAndSearchReachesAllGroups() throws {
    let library = try library()
    let groupA = try library.createGroup(name: "A")
    let groupB = try library.createGroup(name: "B")
    let alpha = try library.save(PresetDraft(text: "alpha", groupID: groupA))
    let beta = try library.save(PresetDraft(text: "beta", groupID: groupB))
    let state = AppState(history: History(), footer: Footer(), presetLibrary: library)
    state.sessionOpen = true
    state.chooseScope(.group(groupA))
    XCTAssertEqual(state.presetResults.map(\.id), [alpha])

    // A non-empty query searches every group and tags results with their group.
    state.searchQuery = "beta"
    XCTAssertEqual(state.presetResults.map(\.id), [beta])
    XCTAssertEqual(state.presetResults.first?.groupName, "B")
    state.searchQuery = ""
    XCTAssertEqual(state.presetResults.map(\.id), [alpha])

    // Dragging a preset grip re-parents it onto the dropped group; the clipboard is untouched.
    let before = Clipboard.shared.pasteboard.changeCount
    let token = try XCTUnwrap(state.beginPresetDrag(id: alpha))
    XCTAssertTrue(state.drop(token: token, groupID: groupB))
    XCTAssertFalse(state.drop(token: token, groupID: groupA))
    XCTAssertEqual(library.presets.first(where: { $0.id == alpha })?.group?.id, groupB)
    XCTAssertEqual(state.scope, .group(groupA))
    XCTAssertNil(state.navigator.target)
    XCTAssertEqual(Clipboard.shared.pasteboard.changeCount, before)
    // The moved preset no longer belongs to the active group, so it cannot be dragged from here.
    XCTAssertNil(state.beginPresetDrag(id: alpha))
    state.endPopupSession()
    XCTAssertNil(state.beginPresetDrag(id: alpha))
  }
}

// Protocol stand-in for the host's boundary check, not evidence of an OS dragging session.
@MainActor
private final class SyntheticPresetDragInfo: NSObject, @preconcurrency NSDraggingInfo {
  var draggingDestinationWindow: NSWindow?
  var draggingSourceOperationMask: NSDragOperation = .copy
  var draggingLocation: NSPoint = .zero
  var draggedImageLocation: NSPoint = .zero
  var draggedImage: NSImage?
  let draggingPasteboard = NSPasteboard.withUniqueName()
  var draggingSource: Any?
  var draggingSequenceNumber = 1
  var draggingFormation: NSDraggingFormation = .none
  var animatesToDestination = false
  var numberOfValidItemsForDrop = 1
  var springLoadingHighlight: NSSpringLoadingHighlight = .none

  func slideDraggedImage(to screenPoint: NSPoint) {}
  override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
  func resetSpringLoading() {}
  func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?,
                              classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any],
                              using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}
