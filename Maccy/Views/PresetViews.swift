import AppKit
import Defaults
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct PresetGroupBar: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    HStack(spacing: 6) {
      groupButton(String(localized: "History"), scope: .history)
      ScrollView(.horizontal) {
        HStack(spacing: 6) {
          ForEach(appState.presetLibrary?.groups ?? []) { group in
            PresetGroupTab(name: group.name, scope: .group(group.id))
          }
          if appState.scope == .ungrouped || appState.presetLibrary?.presets.contains(where: { $0.group == nil }) == true {
            PresetGroupTab(name: String(localized: "Ungrouped"), scope: .ungrouped)
          }
        }
      }
      .scrollIndicators(.hidden)
      Button(action: appState.beginNewGroup) { Image(systemName: "plus").frame(width: 24, height: 23) }
        .buttonStyle(.plain)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(Text("New group"))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
  }

  private func groupButton(_ name: String, scope: PresetScope) -> some View {
    Button { appState.chooseScope(scope) } label: {
      Text(name).lineLimit(1).padding(.horizontal, 12).padding(.vertical, 6)
        .background(appState.scope == scope ? Color(nsColor: .controlBackgroundColor) : .secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(appState.scope == scope ? Color.secondary.opacity(0.4) : Color.clear))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(appState.scope == scope ? .isSelected : [])
  }
}

private struct PresetGroupTab: View {
  let name: String
  let scope: PresetScope
  @Environment(AppState.self) private var appState
  @State private var targeted = false

  var body: some View {
    Button { appState.chooseScope(scope) } label: {
      Text(name).lineLimit(1).padding(.horizontal, 14).padding(.vertical, 6)
        .background(appState.scope == scope ? Color(nsColor: .controlBackgroundColor) : .secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(targeted ? Color.accentColor : .clear, lineWidth: 2))
    }
    .buttonStyle(.plain)
    .overlay { PresetGroupDropTarget(groupID: scope.groupID, onClick: { appState.chooseScope(scope) }, targeted: $targeted) }
    .accessibilityLabel(name)
    .accessibilityAddTraits(appState.scope == scope ? .isSelected : [])
    .contextMenu {
      if let id = scope.groupID {
        Button("Delete group", role: .destructive) { appState.requestDelete(.group(id)) }
      }
    }
  }
}

struct PresetListView: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          if appState.presetResults.isEmpty {
            Text(appState.searchQuery.isEmpty ? "Add text or files to this group." : "No matching content.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, minHeight: 100)
          }
          ForEach(Array(appState.presetResults.enumerated()), id: \.element.id) { index, result in
            PresetRowView(result: result, index: index)
              .id(result.id)
            Divider().padding(.horizontal, 8)
          }
        }
        .padding(.vertical, 6)
        .background {
          GeometryReader { geo in
            Color.clear
              .task(id: appState.popup.needsResize) {
                if appState.popup.needsResize, !appState.interactionLocked {
                  appState.popup.resize(height: geo.size.height)
                }
              }
          }
        }
      }
      .onChange(of: appState.navigator.scrollTarget) {
        guard let id = appState.navigator.scrollTarget else { return }
        proxy.scrollTo(id)
        appState.navigator.scrollTarget = nil
      }
    }
    .onAppear {
      appState.popup.extraTopHeight = 0
      appState.popup.extraBottomHeight = 0
      appState.popup.needsResize = true
    }
  }
}

private struct PresetRowView: View {
  let result: PresetResult
  let index: Int
  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @State private var hovered = false

  private var selected: Bool { appState.navigator.target == .preset(result.id) }

  var body: some View {
    HStack(spacing: 0) {
      Button {
        guard !appState.interactionLocked else { return }
        appState.navigator.selectPreset(result.id)
        // A plain click only selects for previewing; sending requires a modifier key.
        let flags = NSEvent.ModifierFlags.currentModifierFlags
        if HistoryItemAction(flags) == .unknown {
          appState.preview.startAutoOpen()
        } else {
          appState.select(flags: flags)
        }
      } label: {
        HStack(spacing: 12) {
          PresetContentLabel(draft: result.draft, match: result.match)
          if let groupName = result.groupName {
            Text(groupName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
          }
          Spacer(minLength: 8)
          if index < 9 {
            let shortcuts = KeyShortcut.create(character: String(index + 1))
            ZStack {
              ForEach(shortcuts) { shortcut in
                if shortcut.isVisible(shortcuts, modifierFlags.flags) { KeyboardShortcutView(shortcut: shortcut) }
              }
            }
            .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .padding(.leading, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(result.draft.searchableText.isEmpty ? String(localized: "Image preset") : result.draft.searchableText)
      .accessibilityAddTraits(selected ? .isSelected : [])

      // Dedicated grip: dragging from here moves the preset to another group.
      Image(systemName: "line.3.horizontal")
        .foregroundStyle(.secondary)
        .frame(width: 20, height: 26)
        .opacity(hovered || selected ? 1 : 0)
        .overlay { HistoryDragSource(item: .preset(id: result.id, title: result.draft.searchableText), onClick: {}) }
        .accessibilityLabel(Text("Drag to move to another group"))
        .padding(.leading, 2)

      // Sibling controls: management clicks cannot bubble into the content's send button.
      Menu {
        Button("Edit") { appState.beginEditPreset(result.id) }
        Button("Delete", role: .destructive) { appState.requestDelete(.preset(result.id)) }
      } label: { Image(systemName: "ellipsis").frame(width: 24, height: 26) }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .opacity(hovered || selected ? 1 : 0)
      .accessibilityLabel(Text("Manage preset"))
      .padding(.horizontal, 6)
    }
    .background(selected ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.accentColor : .clear))
    .padding(.horizontal, 4)
    .onHover { hovered = $0 }
    .hoverSelectionId(result.id)
  }
}

struct PresetContentLabel: View {
  let draft: PresetDraft
  var match: Search.Match?

  var body: some View {
    if let data = draft.imageData, let image = NSImage(data: data) {
      Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
        .frame(maxWidth: 140, maxHeight: 78).clipShape(RoundedRectangle(cornerRadius: 6))
    } else if let filename = draft.contents.compactMap(\.originalFilename).first {
      Image(nsImage: NSWorkspace.shared.icon(for: .init(filenameExtension: (filename as NSString).pathExtension) ?? .data))
        .resizable().frame(width: 28, height: 32)
      Text(match?.summary ?? Search.Match(text: draft.searchableText).summary)
        .lineLimit(2).truncationMode(.tail)
    } else {
      Text(match?.summary ?? Search.Match(text: draft.searchableText).summary)
        .lineLimit(1).truncationMode(.tail)
    }
  }
}

struct PresetPreviewView: View {
  let draft: PresetDraft
  @Environment(AppState.self) private var appState
  @State private var thumbnails: [String: NSImage] = [:]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if let data = draft.imageData, let image = NSImage(data: data) {
          Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
        } else if draft.contents.contains(where: { $0.relativeFilePath != nil }) {
          ForEach(Array(draft.contents.enumerated()), id: \.offset) { _, content in
            if let path = content.relativeFilePath {
              HStack {
                if let thumbnail = thumbnails[path] {
                  Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit).frame(width: 100, height: 80)
                } else { Image(systemName: "doc").font(.largeTitle) }
                Text(content.originalFilename ?? "").textSelection(.enabled)
              }
            }
          }
        } else {
          Text(draft.searchableText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .task(id: draft.contents) {
      thumbnails = [:]
      for content in draft.contents {
        guard let path = content.relativeFilePath, let url = try? appState.presetLibrary?.attachmentURL(for: path) else { continue }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 200, height: 160), scale: 2, representationTypes: .thumbnail)
        if let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request), !Task.isCancelled {
          thumbnails[path] = thumbnail.nsImage
        }
      }
    }
  }
}

struct PresetManagementView: View {
  @Environment(AppState.self) private var appState
  @FocusState private var textFocused: Bool

  private var draftText: Binding<String> {
    Binding(get: { appState.editor?.draft.text ?? "" }, set: { appState.editor?.draft.text = $0 })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let editor = appState.editor {
        Text(editor.id == nil ? "Add content" : "Edit content").font(.headline)
        if editor.draft.isPlainText {
          TextEditor(text: draftText).font(.body).focused($textFocused)
            .scrollContentBackground(.hidden)
            .padding(6).background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            .frame(height: 170)
        } else { PresetPreviewView(draft: editor.draft).frame(height: 170) }
        Picker("Group", selection: Binding(get: { appState.editor?.draft.groupID }, set: { appState.editor?.draft.groupID = $0 })) {
          Text("Ungrouped").tag(Optional<UUID>.none)
          ForEach(appState.presetLibrary?.groups ?? []) { group in Text(group.name).tag(Optional(group.id)) }
        }
      } else if appState.newGroupName != nil {
        Text("New group").font(.headline)
        TextField("Group name", text: Binding(get: { appState.newGroupName ?? "" }, set: { appState.newGroupName = $0 }))
          .focused($textFocused)
          .textFieldStyle(.roundedBorder)
          .onSubmit { appState.saveManagement() }
      } else if appState.importInProgress {
        HStack { ProgressView().controlSize(.small); Text("Importing files…") }
        Button("Cancel import") { appState.importTask?.cancel() }
          .disabled(appState.importTask == nil)
      }

      if let error = appState.errorMessage { Text(error).foregroundStyle(.red).textSelection(.enabled) }

      if appState.showUnsavedPrompt {
        Text("Save changes before leaving?")
        HStack {
          Button("Save") { appState.saveManagement() }
          Button("Discard changes", role: .destructive) { appState.discardManagement() }
          Button("Cancel") { appState.cancelPendingChange() }
        }
      } else if !appState.importInProgress {
        HStack {
          Spacer()
          Button("Cancel") { appState.requestChange {} }
          Button("Save") { appState.saveManagement() }.buttonStyle(.borderedProminent)
        }
      }
    }
    .padding(16)
    .onAppear { textFocused = true }
    .background {
      GeometryReader { geo in
        Color.clear.task(id: geo.size.height) { appState.popup.resize(height: geo.size.height) }
      }
    }
  }
}

struct PresetSendProblemView: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    if let problem = appState.sendProblem {
      VStack(alignment: .leading, spacing: 12) {
        Text(problem.message)
        HStack {
          Button("Only Copy") { appState.onlyCopyPendingSend() }
          if problem.needsPermission {
            Button("Open Settings") {
              if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
              }
            }
          }
          Button("Cancel") { appState.sendProblem = nil; appState.invalidatePendingSend() }
        }
      }
      .padding(16)
      .background { GeometryReader { geo in Color.clear.task { appState.popup.resize(height: geo.size.height) } } }
    }
  }
}

struct PresetFooterView: View {
  @Environment(AppState.self) private var appState
  var body: some View {
    VStack(spacing: 10) {
      Text("Drag history items onto a group to save.").foregroundStyle(.secondary).font(.caption)
      Divider()
      HStack(spacing: 18) {
        Text("↑↓ Select")
        Text("Click Preview")
        Text(Defaults[.pasteByDefault] ? "⌘Click Paste" : "⌥Click Paste")
        Text(Defaults[.pasteByDefault] ? "↩ Paste" : "↩ Copy")
        Text(Defaults[.pasteByDefault] ? "⌥↩ Copy" : "⌥↩ Paste")
        Text("Esc Close")
        Spacer(minLength: 0)
      }.font(.caption)
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
    .readHeight(appState, into: \.popup.footerHeight)
  }
}
