import AppKit
import SwiftData

@Model
class PresetGroup {
  var id: UUID = UUID()
  var name: String = ""
  var createdAt: Date = Date.now

  @Relationship(deleteRule: .nullify, inverse: \Preset.group)
  var presets: [Preset] = []

  init(name: String) {
    self.name = name
  }
}

@Model
class Preset {
  var id: UUID = UUID()
  var savedAt: Date = Date.now
  var group: PresetGroup?

  @Relationship(deleteRule: .cascade, inverse: \PresetContent.preset)
  var contents: [PresetContent] = []

  init(contents: [PresetContent], group: PresetGroup? = nil) {
    self.contents = contents
    self.group = group
  }

  var orderedContents: [PresetContent] { contents.sorted { $0.position < $1.position } }

  var text: String? {
    orderedContents.first { $0.type == NSPasteboard.PasteboardType.string.rawValue }
      .flatMap { $0.value }
      .flatMap { String(data: $0, encoding: .utf8) }
  }
}

@Model
class PresetContent {
  var position: Int = 0
  var type: String = ""
  var value: Data?
  var relativeFilePath: String?
  var originalFilename: String?
  var preset: Preset?

  init(position: Int, type: String, value: Data? = nil, relativeFilePath: String? = nil,
       originalFilename: String? = nil) {
    self.position = position
    self.type = type
    self.value = value
    self.relativeFilePath = relativeFilePath
    self.originalFilename = originalFilename
  }
}

struct PresetDraft: Equatable, Sendable {
  struct Content: Hashable, Sendable {
    var type: String
    var value: Data?
    var relativeFilePath: String?
    var originalFilename: String?
    // Only a value draft can reference an import source; never stored in the database.
    var sourceFileURL: URL?
  }

  var contents: [Content]
  var groupID: UUID?

  init(text: String, groupID: UUID? = nil) {
    contents = [Content(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(text.utf8))]
    self.groupID = groupID
  }

  init(preset: Preset) {
    contents = preset.orderedContents.map {
      Content(type: $0.type, value: $0.value, relativeFilePath: $0.relativeFilePath,
              originalFilename: $0.originalFilename)
    }
    groupID = preset.group?.id
  }
}


extension PresetDraft {
  var text: String {
    get {
      contents.first { $0.type == NSPasteboard.PasteboardType.string.rawValue }
        .flatMap { $0.value }.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
    set { contents = [Content(type: NSPasteboard.PasteboardType.string.rawValue, value: Data(newValue.utf8))] }
  }

  var isPlainText: Bool {
    contents.count == 1 && contents.first?.type == NSPasteboard.PasteboardType.string.rawValue
  }

  init(files: [URL], groupID: UUID?) {
    self.groupID = groupID
    contents = files.map {
      Content(type: NSPasteboard.PasteboardType.fileURL.rawValue,
              originalFilename: $0.lastPathComponent, sourceFileURL: $0)
    }
  }

  // Capture values while the history objects still exist. No shared relationships or clipboard reads.
  init(historyItem: HistoryItem) {
    groupID = nil
    if historyItem.universalClipboard,
       let url = historyItem.fileURLs.first, url.pathExtension.lowercased() == "jpeg" {
      contents = [Content(type: NSPasteboard.PasteboardType.jpeg.rawValue, sourceFileURL: url)]
    } else if !historyItem.fileURLs.isEmpty {
      contents = historyItem.fileURLs.map {
        Content(type: NSPasteboard.PasteboardType.fileURL.rawValue,
                originalFilename: $0.lastPathComponent, sourceFileURL: $0)
      }
    } else {
      let types = Set(StorageType.all.types.map(\.rawValue))
      contents = historyItem.contents.filter { types.contains($0.type) }.map {
        Content(type: $0.type, value: $0.value)
      }
    }
  }

  var imageData: Data? {
    let types = Set(StorageType.images.types.map(\.rawValue))
    return contents.first { types.contains($0.type) }?.value
  }

  var searchableText: String {
    let filenames = contents.compactMap(\.originalFilename)
    if !filenames.isEmpty { return filenames.joined(separator: "\n") }
    if !text.isEmpty { return text }
    if let data = contents.first(where: { $0.type == NSPasteboard.PasteboardType.rtf.rawValue })?.value,
       let rich = NSAttributedString(rtf: data, documentAttributes: nil) { return rich.string }
    if let data = contents.first(where: { $0.type == NSPasteboard.PasteboardType.html.rawValue })?.value,
       let rich = NSAttributedString(html: data, documentAttributes: nil) { return rich.string }
    return ""
  }
}
