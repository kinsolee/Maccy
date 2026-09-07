import AppKit
import SwiftData
import XCTest
@testable import Maccy

@MainActor
final class PresetMediaTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    try XCTSkipUnless(AppDelegate.isUnitTesting, "Requires isolated defaults, storage and pasteboards.")
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("MaccyPresetTests-\(ProcessInfo.processInfo.processIdentifier)/\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  private func library(save: @escaping (ModelContext) throws -> Void = { try $0.save() }) throws -> PresetLibrary {
    let container = try ModelContainer(for: HistoryItem.self, PresetGroup.self, Preset.self, PresetContent.self,
                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return try PresetLibrary(container: container, attachmentRoot: root.appendingPathComponent("attachments"), save: save)
  }

  func testIndependentCopiesPreserveOrderNamesBytesAndTypedClipboard() async throws {
    let library = try library()
    var sources: [URL] = []
    for index in 0..<2 {
      let directory = root.appendingPathComponent("source-\(index)")
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let file = directory.appendingPathComponent("尺码 表.mp4")
      try Data("synthetic video file \(index)".utf8).write(to: file)
      sources.append(file)
    }
    let id = try await library.saveImported(PresetDraft(files: sources, groupID: nil))
    let preset = try XCTUnwrap(library.presets.first(where: { $0.id == id }))
    let contents = preset.orderedContents
    XCTAssertEqual(contents.map(\.originalFilename), ["尺码 表.mp4", "尺码 表.mp4"])
    XCTAssertTrue(contents.allSatisfy { $0.value == nil && $0.relativeFilePath?.hasPrefix("/") == false })
    for source in sources { try FileManager.default.removeItem(at: source) }
    let urls = try contents.map { try library.attachmentURL(for: XCTUnwrap($0.relativeFilePath)) }
    for (index, url) in urls.enumerated() {
      XCTAssertEqual(try Data(contentsOf: url), Data("synthetic video file \(index)".utf8))
    }
    let board = NSPasteboard(name: .init("MaccyPresetMediaTests-\(UUID())"))
    defer { board.releaseGlobally() }
    let clipboard = Clipboard(pasteboard: board)
    XCTAssertTrue(clipboard.copy(contents: urls.map { Clipboard.Content(type: NSPasteboard.PasteboardType.fileURL.rawValue, value: $0.dataRepresentation) }))
    XCTAssertEqual(board.pasteboardItems?.compactMap { $0.string(forType: .fileURL) }, urls.map(\.absoluteString))
    XCTAssertEqual(clipboard.changeCount, board.changeCount)
    XCTAssertNotNil(board.string(forType: .fromMaccy))
    try library.deletePreset(id: id)
    XCTAssertTrue(library.presets.isEmpty)
    XCTAssertTrue(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    // These are named-pasteboard checks, not cross-application paste acceptance.
  }

  func testFailureCancellationAndPathValidationLeaveNoVisiblePartialImport() async throws {
    var failSave = false
    let library = try library { context in
      if failSave { throw CocoaError(.fileWriteOutOfSpace) }
      try context.save()
    }
    let source = root.appendingPathComponent("file.txt")
    try Data("synthetic".utf8).write(to: source)
    let draft = PresetDraft(files: [source], groupID: nil)
    let keptID = try await library.saveImported(draft)
    let keptPath = try XCTUnwrap(library.presets.first?.orderedContents.first?.relativeFilePath)
    failSave = true
    do { _ = try await library.saveImported(draft); XCTFail("Expected failed DB save") } catch {}
    failSave = false
    let cancelled = Task { try await library.saveImported(draft) }
    cancelled.cancel()
    do { _ = try await cancelled.value; XCTFail("Expected cancellation") } catch is CancellationError {} catch { XCTFail("\(error)") }
    do {
      _ = try await library.saveImported(draft) { throw PresetLibrary.LibraryError.missingGroup }
      XCTFail("Expected invalidated destination")
    } catch {}
    XCTAssertEqual(library.presets.map(\.id), [keptID])
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: library.attachmentRoot.path).count, 1)
    XCTAssertEqual(try Data(contentsOf: library.attachmentURL(for: keptPath)), Data("synthetic".utf8))
    for path in ["../file.txt", "/file.txt", "a/../../file.txt", "a//file.txt"] {
      XCTAssertThrowsError(try library.attachmentURL(for: path))
    }
    let symlink = root.appendingPathComponent("link.txt")
    try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: source)
    for invalid in [root!, symlink] {
      do { _ = try await library.saveImported(PresetDraft(files: [invalid], groupID: nil)); XCTFail("Expected non-regular file rejection") } catch {}
    }
    XCTAssertEqual(library.presets.count, 1)
  }

  func testUniversalClipboardJPEGIsCapturedAsActualImageData() async throws {
    let library = try library()
    let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let jpeg = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [:]))
    let source = root.appendingPathComponent("clipboard.jpeg")
    try jpeg.write(to: source)
    let history = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.fileURL.rawValue, value: source.dataRepresentation),
      HistoryItemContent(type: NSPasteboard.PasteboardType.universalClipboard.rawValue, value: Data())
    ])
    let draft = PresetDraft(historyItem: history)
    XCTAssertEqual(draft.contents.first?.type, NSPasteboard.PasteboardType.jpeg.rawValue)
    try await library.saveImported(draft)
    try FileManager.default.removeItem(at: source)
    let saved = try XCTUnwrap(library.presets.first)
    XCTAssertEqual(saved.orderedContents.first?.value, jpeg)
    XCTAssertNil(saved.orderedContents.first?.relativeFilePath)
    XCTAssertNotNil(NSImage(data: try XCTUnwrap(saved.orderedContents.first?.value)))
  }
}
