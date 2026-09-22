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
        HStack(spacing: 4) {
          ForEach(appState.presetLibrary?.groups ?? []) { group in
            PresetGroupTab(name: group.name, scope: .group(group.id))
          }
          if appState.scope == .ungrouped || appState.presetLibrary?.presets.contains(where: { $0.group == nil }) == true {
            PresetGroupTab(name: String(localized: "Ungrouped"), scope: .ungrouped)
          }
        }
      }
      .scrollIndicators(.hidden)
      Button(action: appState.beginNewGroup) {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .medium))
          .frame(width: 26, height: 24)
      }
      .buttonStyle(BUIQuietButtonStyle(color: BUI.ink3))
      .overlay(RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous).stroke(BUI.line, lineWidth: 1))
      .accessibilityLabel(Text("New group"))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
  }

  private func groupButton(_ name: String, scope: PresetScope) -> some View {
    Button { appState.chooseScope(scope) } label: {
      Text(name)
        .font(BUI.controlFont)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
    .buttonStyle(BUIQuietButtonStyle(isActive: appState.scope == scope))
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
      Text(name)
        .font(BUI.controlFont)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
    .buttonStyle(BUIQuietButtonStyle(isActive: appState.scope == scope))
    .overlay(
      RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous)
        .stroke(targeted ? BUI.accent : .clear, lineWidth: 2)
    )
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
            BUIEmptyState(
              icon: appState.searchQuery.isEmpty ? "tray" : "magnifyingglass",
              title: appState.searchQuery.isEmpty ? "Add text or files to this group." : "No matching content."
            )
          }
          ForEach(Array(appState.presetResults.enumerated()), id: \.element.id) { index, result in
            PresetRowView(result: result, index: index)
              .id(result.id)
            BUIHairline(color: BUI.lineSoft).padding(.horizontal, 8)
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

  // A plain click only selects for previewing; sending requires a modifier key.
  private func performSelect() {
    guard !appState.interactionLocked else { return }
    appState.navigator.selectPreset(result.id)
    let flags = NSEvent.ModifierFlags.currentModifierFlags
    if HistoryItemAction(flags) == .unknown {
      appState.preview.startAutoOpen()
    } else {
      appState.select(flags: flags)
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      Button(action: performSelect) {
        HStack(spacing: 12) {
          PresetContentLabel(draft: result.draft, match: result.match)
          if let groupName = result.groupName {
            Text(groupName)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(BUI.ink2)
              .lineLimit(1)
              .padding(.horizontal, 7)
              .padding(.vertical, 2)
              .background(BUI.inset, in: RoundedRectangle(cornerRadius: BUI.radiusChip, style: .continuous))
          }
          Spacer(minLength: 8)
          if index < 9 {
            let shortcuts = KeyShortcut.create(character: String(index + 1))
            ZStack {
              ForEach(shortcuts) { shortcut in
                if shortcut.isVisible(shortcuts, modifierFlags.flags) { KeyboardShortcutView(shortcut: shortcut) }
              }
            }
            .foregroundStyle(selected ? BUI.accentInk : BUI.ink3)
          }
        }
        // Same row metrics as history items (ListItemView).
        .frame(maxWidth: .infinity, minHeight: Popup.itemHeight, alignment: .leading)
        .padding(.leading, 10)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      // The whole row drags, matching history rows; dropping on a group moves the preset.
      .overlay { HistoryDragSource(item: .preset(id: result.id, title: result.draft.searchableText), onClick: performSelect) }
      .accessibilityLabel(result.draft.searchableText.isEmpty ? String(localized: "Image preset") : result.draft.searchableText)
      .accessibilityAddTraits(selected ? .isSelected : [])

      // Sibling controls: management clicks cannot bubble into the content's send button.
      Menu {
        Button("Edit") { appState.beginEditPreset(result.id) }
        Button("Delete", role: .destructive) { appState.requestDelete(.preset(result.id)) }
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 12, weight: .medium))
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .buttonStyle(.plain)
      .foregroundStyle(BUI.ink3)
      .background(hovered || selected ? BUI.hover : .clear, in: RoundedRectangle(cornerRadius: BUI.radiusChip, style: .continuous))
      .opacity(hovered || selected ? 1 : 0)
      .accessibilityLabel(Text("Manage preset"))
      .padding(.horizontal, 6)
    }
    // Match the history row's selection appearance.
    .foregroundStyle(selected ? BUI.ink : .primary)
    .background(selected ? BUI.selectionFill : .white.opacity(0.001))
    .clipShape(RoundedRectangle(cornerRadius: Popup.cornerRadius))
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
        Text(editor.id == nil ? "Add content" : "Edit content")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(BUI.ink)
        if editor.draft.isPlainText {
          TextEditor(text: draftText).font(BUI.rowFont).focused($textFocused)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(BUI.surface, in: RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous).stroke(BUI.line, lineWidth: 1))
            .frame(height: 170)
        } else { PresetPreviewView(draft: editor.draft).frame(height: 170) }
        Picker("Group", selection: Binding(get: { appState.editor?.draft.groupID }, set: { appState.editor?.draft.groupID = $0 })) {
          Text("Ungrouped").tag(Optional<UUID>.none)
          ForEach(appState.presetLibrary?.groups ?? []) { group in Text(group.name).tag(Optional(group.id)) }
        }
        .font(BUI.controlFont)
      } else if appState.newGroupName != nil {
        Text("New group")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(BUI.ink)
        TextField("Group name", text: Binding(get: { appState.newGroupName ?? "" }, set: { appState.newGroupName = $0 }))
          .focused($textFocused)
          .textFieldStyle(.roundedBorder)
          .onSubmit { appState.saveManagement() }
      } else if appState.importInProgress {
        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Importing files…").font(BUI.controlFont).foregroundStyle(BUI.ink2) }
        Button("Cancel import") { appState.importTask?.cancel() }
          .buttonStyle(BUISecondaryButtonStyle())
          .disabled(appState.importTask == nil)
      }

      if let error = appState.errorMessage {
        Text(error)
          .font(BUI.rowFont)
          .foregroundStyle(BUI.red)
          .textSelection(.enabled)
      }

      if appState.showUnsavedPrompt {
        Text("Save changes before leaving?").font(BUI.rowFont).foregroundStyle(BUI.ink)
        HStack(spacing: 8) {
          Button("Save") { appState.saveManagement() }.buttonStyle(BUIPrimaryButtonStyle())
          Button("Discard changes", role: .destructive) { appState.discardManagement() }.buttonStyle(BUISecondaryButtonStyle())
          Button("Cancel") { appState.cancelPendingChange() }.buttonStyle(BUISecondaryButtonStyle())
        }
      } else if !appState.importInProgress {
        HStack(spacing: 8) {
          Spacer()
          Button("Cancel") { appState.requestChange {} }.buttonStyle(BUISecondaryButtonStyle())
          Button("Save") { appState.saveManagement() }.buttonStyle(BUIPrimaryButtonStyle())
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
        Label {
          Text(problem.message).font(BUI.rowFont).foregroundStyle(BUI.ink)
        } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(BUI.orange)
        }
        HStack(spacing: 8) {
          Button("Only Copy") { appState.onlyCopyPendingSend() }.buttonStyle(BUISecondaryButtonStyle())
          if problem.needsPermission {
            Button("Open Settings") {
              if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
              }
            }
            .buttonStyle(BUISecondaryButtonStyle())
          }
          Button("Cancel") { appState.sendProblem = nil; appState.invalidatePendingSend() }
            .buttonStyle(BUISecondaryButtonStyle())
        }
      }
      .padding(14)
      .background(RoundedRectangle(cornerRadius: BUI.radiusCard, style: .continuous).fill(BUI.orangeTint))
      .overlay(RoundedRectangle(cornerRadius: BUI.radiusCard, style: .continuous).stroke(BUI.orange.opacity(0.35), lineWidth: 1))
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background { GeometryReader { geo in Color.clear.task { appState.popup.resize(height: geo.size.height) } } }
    }
  }
}

struct PresetFooterView: View {
  @Environment(AppState.self) private var appState

  private func hint(_ label: LocalizedStringKey) -> some View {
    Text(label)
      .font(.system(size: 10.5, weight: .medium).monospaced())
      .foregroundStyle(BUI.ink2)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(BUI.inset, in: RoundedRectangle(cornerRadius: BUI.radiusChip, style: .continuous))
  }

  var body: some View {
    VStack(spacing: 10) {
      BUIHairline(color: BUI.line)
      HStack(spacing: 6) {
        Text("preset_drag_to_save_hint")
          .foregroundStyle(BUI.ink3)
          .font(.system(size: 11))
        Spacer(minLength: 0)
      }
      HStack(spacing: 6) {
        hint("preset_hint_select")
        hint("preset_hint_preview")
        if Defaults[.pasteByDefault] {
          hint("preset_hint_cmd_click_paste")
          hint("preset_hint_return_paste")
          hint("preset_hint_alt_return_copy")
        } else {
          hint("preset_hint_alt_click_paste")
          hint("preset_hint_return_copy")
          hint("preset_hint_alt_return_paste")
        }
        hint("preset_hint_esc_close")
        Spacer(minLength: 0)
      }
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
    .readHeight(appState, into: \.popup.footerHeight)
  }
}
