import AppKit
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
class PresetLibrary {
  enum LibraryError: LocalizedError {
    case emptyGroupName
    case emptyContent
    case missingGroup
    case missingPreset
    case invalidFile
    case invalidPath

    var errorDescription: String? {
      switch self {
      case .emptyGroupName: String(localized: "Enter a group name.")
      case .emptyContent: String(localized: "Add content before saving.")
      case .missingGroup: String(localized: "This group no longer exists.")
      case .missingPreset: String(localized: "This preset no longer exists.")
      case .invalidFile: String(localized: "Choose regular files, not folders, packages or symbolic links.")
      case .invalidPath: String(localized: "The saved attachment is unavailable.")
      }
    }
  }

  private(set) var groups: [PresetGroup] = []
  private(set) var presets: [Preset] = []

  @ObservationIgnored private var context: ModelContext
  @ObservationIgnored private let saveContext: (ModelContext) throws -> Void

  let attachmentRoot: URL

  init(container: ModelContainer, attachmentRoot: URL? = nil, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) throws {
    self.attachmentRoot = attachmentRoot ?? URL.applicationSupportDirectory
      .appendingPathComponent(Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy")
      .appendingPathComponent("PresetAttachments", isDirectory: true)
    context = ModelContext(container)
    context.autosaveEnabled = false
    saveContext = save
    // Newest groups lead the tab bar, right after the fixed History tab.
    groups = try context.fetch(FetchDescriptor<PresetGroup>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    presets = try context.fetch(FetchDescriptor<Preset>(sortBy: [SortDescriptor(\.savedAt)]))
  }

  @discardableResult
  func createGroup(name: String) throws -> UUID {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw LibraryError.emptyGroupName }
    let group = PresetGroup(name: name)
    context.insert(group)
    try persistChanges()
    return group.id
  }

  func deleteGroup(id: UUID) throws {
    guard let group = groups.first(where: { $0.id == id }) else { throw LibraryError.missingGroup }
    context.delete(group)
    try persistChanges()
  }

  @discardableResult
  func save(_ draft: PresetDraft, editing id: UUID? = nil) throws -> UUID {
    guard !draft.contents.isEmpty,
          draft.contents.contains(where: { $0.value?.isEmpty == false || $0.relativeFilePath != nil }) else {
      throw LibraryError.emptyContent
    }
    for content in draft.contents {
      guard content.sourceFileURL == nil else { throw LibraryError.invalidFile }
      if content.type == NSPasteboard.PasteboardType.fileURL.rawValue, content.relativeFilePath == nil {
        throw LibraryError.invalidPath
      }
      if let path = content.relativeFilePath {
        guard content.type == NSPasteboard.PasteboardType.fileURL.rawValue else { throw LibraryError.invalidPath }
        _ = try attachmentURL(for: path)
      }
    }
    let group = groups.first { $0.id == draft.groupID }
    guard draft.groupID == nil || group != nil else { throw LibraryError.missingGroup }

    let preset: Preset
    if let id {
      guard let existing = presets.first(where: { $0.id == id }) else { throw LibraryError.missingPreset }
      preset = existing
      for content in preset.contents { context.delete(content) }
    } else {
      preset = Preset(contents: [])
      context.insert(preset)
    }
    preset.group = group
    preset.contents = draft.contents.enumerated().map { position, content in
      PresetContent(position: position, type: content.type, value: content.value,
                    relativeFilePath: content.relativeFilePath, originalFilename: content.originalFilename)
    }
    try persistChanges()
    return preset.id
  }

  func deletePreset(id: UUID) throws {
    guard let preset = presets.first(where: { $0.id == id }) else { throw LibraryError.missingPreset }
    context.delete(preset)
    try persistChanges()
  }

  /// Moving between groups re-parents the record; `nil` makes it ungrouped.
  func movePreset(id: UUID, to groupID: UUID?) throws {
    guard let preset = presets.first(where: { $0.id == id }) else { throw LibraryError.missingPreset }
    let group = groupID.flatMap { id in groups.first(where: { $0.id == id }) }
    guard groupID == nil || group != nil else { throw LibraryError.missingGroup }
    preset.group = group
    try persistChanges()
  }

  func attachmentURL(for relativePath: String) throws -> URL {
    let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
    guard !relativePath.hasPrefix("/"), !components.isEmpty,
          components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
      throw LibraryError.invalidPath
    }
    let root = attachmentRoot.resolvingSymlinksInPath().standardizedFileURL
    let file = root.appendingPathComponent(relativePath).standardizedFileURL
    guard file.resolvingSymlinksInPath().path == file.path,
          file.path.hasPrefix(root.path + "/") else { throw LibraryError.invalidPath }
    try Self.validateRegularFile(file)
    return file
  }

  /// Own each import directory exclusively. Only a completed copy and successful DB save become visible.
  @discardableResult
  func saveImported(_ draft: PresetDraft, editing id: UUID? = nil,
                    validate: () throws -> Void = {}) async throws -> UUID {
    let root = attachmentRoot
    let work = Task.detached(priority: .userInitiated) {
      try Self.importContents(draft, root: root)
    }
    let imported = try await withTaskCancellationHandler {
      try await work.value
    } onCancel: {
      work.cancel()
    }
    do {
      try Task.checkCancellation()
      try validate()
      return try save(imported.draft, editing: id)
    } catch {
      if let directory = imported.directory { try? FileManager.default.removeItem(at: directory) }
      throw error
    }
  }

  private nonisolated static func validateRegularFile(_ url: URL) throws {
    guard url.isFileURL else { throw LibraryError.invalidFile }
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isPackageKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true, values.isPackage != true else {
      throw LibraryError.invalidFile
    }
  }

  private nonisolated static func importContents(_ source: PresetDraft, root: URL) throws
    -> (draft: PresetDraft, directory: URL?) {
    var draft = source
    let manager = FileManager.default
    let identifier = UUID().uuidString
    let staging = root.appendingPathComponent(".staging-" + identifier, isDirectory: true)
    let final = root.appendingPathComponent(identifier, isDirectory: true)
    var ownsStaging = false
    var ownsFinal = false
    do {
      for index in draft.contents.indices {
        try Task.checkCancellation()
        guard let url = draft.contents[index].sourceFileURL else { continue }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        try validateRegularFile(url)
        if draft.contents[index].type == NSPasteboard.PasteboardType.fileURL.rawValue {
          if !ownsStaging {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            try manager.createDirectory(at: staging, withIntermediateDirectories: false)
            ownsStaging = true
          }
          let folder = staging.appendingPathComponent(String(index), isDirectory: true)
          try manager.createDirectory(at: folder, withIntermediateDirectories: false)
          let destination = folder.appendingPathComponent(url.lastPathComponent)
          // FileManager streams the copy; even a video is never loaded into Data.
          try manager.copyItem(at: url, to: destination)
          try validateRegularFile(destination)
          draft.contents[index].relativeFilePath = identifier + "/" + String(index) + "/" + url.lastPathComponent
          draft.contents[index].originalFilename = url.lastPathComponent
          draft.contents[index].value = nil
        } else {
          // Universal Clipboard's JPEG URL represents an image, not a file preset.
          let data = try Data(contentsOf: url)
          guard NSImage(data: data) != nil else { throw LibraryError.invalidFile }
          draft.contents[index].value = data
        }
        draft.contents[index].sourceFileURL = nil
      }
      try Task.checkCancellation()
      if ownsStaging {
        try manager.moveItem(at: staging, to: final)
        ownsStaging = false
        ownsFinal = true
      }
      try Task.checkCancellation()
      return (draft, ownsFinal ? final : nil)
    } catch {
      if ownsStaging { try? manager.removeItem(at: staging) }
      if ownsFinal { try? manager.removeItem(at: final) }
      throw error
    }
  }

  private func persistChanges() throws {
    do {
      context.processPendingChanges()
      let nextGroups = try context.fetch(FetchDescriptor<PresetGroup>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
      let nextPresets = try context.fetch(FetchDescriptor<Preset>(sortBy: [SortDescriptor(\.savedAt)]))
      try saveContext(context)
      groups = nextGroups
      presets = nextPresets
    } catch {
      context.rollback()
      // Rollback can leave replaced relationship objects in the published arrays.
      // Read the committed models through a fresh context owned only by this library.
      groups = []
      presets = []
      let restored = try PresetLibrary(container: context.container, attachmentRoot: attachmentRoot, save: saveContext)
      context = restored.context
      groups = restored.groups
      presets = restored.presets
      throw error
    }
  }
}
