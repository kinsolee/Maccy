import AppKit
import Defaults
import Sauce
import SwiftUI

enum PresetScope: Equatable {
  case history
  case ungrouped
  case group(UUID)

  var groupID: UUID? { if case .group(let id) = self { id } else { nil } }
  var storedValue: String {
    switch self {
    case .history: "history"
    case .ungrouped: "ungrouped"
    case .group(let id): id.uuidString
    }
  }

  static func restored(_ value: String, groups: [UUID]) -> Self {
    if value == "ungrouped" { return .ungrouped }
    if let id = UUID(uuidString: value), groups.contains(id) { return .group(id) }
    return .history
  }
}

struct PresetEditor {
  let id: UUID?
  let original: PresetDraft
  var draft: PresetDraft
  var isDirty: Bool { draft != original }
}

struct PresetResult: Identifiable {
  let id: UUID
  let draft: PresetDraft
  let match: Search.Match
  // Set only while searching across all groups.
  var groupName: String?
}

enum PresetDeletion {
  case preset(UUID)
  case group(UUID)
}

struct PresetDrag {
  let token: UUID
  let sourceID: UUID
  let draft: PresetDraft
  // Non-nil when the dragged row is an existing preset (move between groups).
  var presetID: UUID?
  var consumed = false
}

struct PopupSendRequest {
  let generation: UInt64
  let target: PopupTarget?
  let flags: NSEvent.ModifierFlags
}

struct PopupSendProblem {
  let request: PopupSendRequest
  let message: String
  let needsPermission: Bool
}

// App Sandbox permits checking the foreground app, but not reading its AX windows.
struct PasteTarget {
  let application: NSRunningApplication

  static func capture() -> PasteTarget? {
    guard let app = NSWorkspace.shared.frontmostApplication,
          app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
    return PasteTarget(application: app)
  }

  func isCurrent(frontmostPID: pid_t? = NSWorkspace.shared.frontmostApplication?.processIdentifier) -> Bool {
    !application.isTerminated && frontmostPID == application.processIdentifier
  }
}

extension AppState {
  func invalidatePendingSend() {
    sendGeneration &+= 1
  }

  func suspendSending() {
    invalidatePendingSend()
    popup.cancelCycle()
    navigator.hoverSelectionWhileKeyboardNavigating = nil
    preview.cancelAutoOpen()
    if preview.state.isOpen { preview.togglePreview() }
  }

  @MainActor
  func beginPopupSession(captureTarget: Bool = true) {
    invalidatePendingSend()
    sessionOpen = true
    if captureTarget { pasteTarget = PasteTarget.capture() }
    do {
      if presetLibrary == nil { presetLibrary = try PresetLibrary(container: Storage.shared.container) }
      if !interactionLocked {
        applyScope(.restored(Defaults[.lastPresetScope], groups: presetLibrary?.groups.map(\.id) ?? []), remember: false)
      }
    } catch { errorMessage = error.localizedDescription }
  }

  func endPopupSession() {
    sessionOpen = false
    invalidatePendingSend()
    pasteTarget = nil
    navigator.hoverSelectionWhileKeyboardNavigating = nil
  }

  @MainActor
  func chooseScope(_ scope: PresetScope) {
    requestChange { self.applyScope(scope, remember: true) }
  }

  @MainActor
  func applyScope(_ requested: PresetScope, remember: Bool) {
    suspendSending()
    var next = requested
    if let id = requested.groupID, presetLibrary?.groups.contains(where: { $0.id == id }) != true {
      next = .history
    }
    scope = next
    if remember { Defaults[.lastPresetScope] = next.storedValue }
    history.searchQuery = ""
    presetQuery = ""
    popup.extraTopHeight = 0
    popup.extraBottomHeight = 0
    popup.footerHeight = 0
    navigator.enterScope(history: next == .history)
    if next == .history { navigator.highlightFirst() } else { refreshPresetResults() }
    popup.needsResize = true
  }

  @MainActor
  func refreshPresetResults(select id: UUID? = nil, autoselect: Bool = true) {
    guard scope != .history else { return }
    let search = Search()
    // Empty query lists the current group; a non-empty query searches every group.
    let globalSearch = !presetQuery.isEmpty
    presetResults = (presetLibrary?.presets ?? []).compactMap { preset in
      if !globalSearch, preset.group?.id != scope.groupID { return nil }
      let draft = PresetDraft(preset: preset)
      guard let match = search.match(presetQuery, in: draft.searchableText) else { return nil }
      return PresetResult(id: preset.id, draft: draft, match: match,
                          groupName: globalSearch ? preset.group?.name : nil)
    }
    navigator.presetIDs = presetResults.map(\.id)
    let preferred = id ?? navigator.leadSelection
    if let valid = preferred.flatMap({ navigator.presetIDs.contains($0) ? $0 : nil }) {
      navigator.selectPreset(valid)
    } else if autoselect {
      navigator.selectPreset(navigator.presetIDs.first)
    } else {
      navigator.selectPreset(nil)
    }
    popup.needsResize = true
  }

  @MainActor
  func requestChange(_ action: @escaping () -> Void) {
    guard !importInProgress, activeDrag == nil else { return }
    suspendSending()
    if editor?.isDirty == true || newGroupName?.isEmpty == false {
      pendingChange = action
      showUnsavedPrompt = true
    } else {
      clearManagement()
      popup.extraTopHeight = 0
      popup.extraBottomHeight = 0
      popup.footerHeight = 0
      action()
    }
  }

  func clearManagement() {
    editor = nil
    newGroupName = nil
    showUnsavedPrompt = false
    sendProblem = nil
    errorMessage = nil
    popup.needsResize = true
  }

  func cancelPendingChange() {
    showUnsavedPrompt = false
    pendingChange = nil
  }

  func discardManagement() {
    let next = pendingChange
    pendingChange = nil
    clearManagement()
    next?()
  }

  @MainActor
  func beginNewPreset() {
    requestChange {
      let draft = PresetDraft(text: "", groupID: self.scope.groupID)
      self.editor = PresetEditor(id: nil, original: draft, draft: draft)
    }
  }

  @MainActor
  func beginEditPreset(_ id: UUID) {
    requestChange {
      guard let preset = self.presetLibrary?.presets.first(where: { $0.id == id }) else { return }
      let draft = PresetDraft(preset: preset)
      self.editor = PresetEditor(id: id, original: draft, draft: draft)
    }
  }

  @MainActor
  func beginNewGroup() {
    requestChange { self.newGroupName = "" }
  }

  @MainActor
  func saveManagement() {
    guard let library = presetLibrary else { return }
    do {
      var savedID: UUID?
      var createdGroup: UUID?
      if let editor { savedID = try library.save(editor.draft, editing: editor.id) }
      if let name = newGroupName { createdGroup = try library.createGroup(name: name) }
      let next = pendingChange
      pendingChange = nil
      clearManagement()
      if let createdGroup { applyScope(.group(createdGroup), remember: true) }
      refreshPresetResults(select: savedID)
      next?()
    } catch { errorMessage = error.localizedDescription }
  }

  // Deletes are immediate: a preset is re-draggable from history and group deletion
  // keeps its contents in Ungrouped, so nothing is ever destroyed irreversibly.
  @MainActor
  func requestDelete(_ target: PresetDeletion) {
    requestChange {
      guard let library = self.presetLibrary else { return }
      do {
        switch target {
        case .preset(let id): try library.deletePreset(id: id)
        case .group(let id): try library.deleteGroup(id: id)
        }
        self.clearManagement()
        if let id = self.scope.groupID, !library.groups.contains(where: { $0.id == id }) {
          self.applyScope(.history, remember: true)
        } else { self.refreshPresetResults(autoselect: false) }
      } catch { self.errorMessage = error.localizedDescription }
    }
  }

  @MainActor
  func chooseFiles() {
    requestChange {
      guard let window = self.appDelegate?.panel else { return }
      self.importInProgress = true
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.allowsMultipleSelection = true
      panel.treatsFilePackagesAsDirectories = true
      panel.resolvesAliases = false
      panel.beginSheetModal(for: window) { response in
        self.importInProgress = false
        guard response == .OK else { self.invalidatePendingSend(); return }
        self.startImport(PresetDraft(files: panel.urls, groupID: self.scope.groupID))
      }
    }
  }

  @MainActor
  func startImport(_ draft: PresetDraft, sourceID: UUID? = nil) {
    guard let library = presetLibrary else { return }
    suspendSending()
    importInProgress = true
    errorMessage = nil
    importTask = Task { @MainActor in
      defer {
        importInProgress = false
        importTask = nil
        invalidatePendingSend()
        popup.needsResize = true
      }
      do {
        let id = try await library.saveImported(draft) {
          if let sourceID, !self.history.all.contains(where: { $0.id == sourceID }) {
            throw PresetLibrary.LibraryError.missingPreset
          }
        }
        refreshPresetResults(select: id)
      } catch is CancellationError {
        // Cancellation is an explicit management action; no record has become visible.
      } catch { errorMessage = error.localizedDescription }
    }
  }

  @MainActor
  func beginHistoryDrag(id: UUID) -> UUID? {
    guard scope == .history, !interactionLocked,
          let item = history.all.first(where: { $0.id == id }) else { return nil }
    suspendSending()
    let drag = PresetDrag(token: UUID(), sourceID: id, draft: PresetDraft(historyItem: item.item))
    activeDrag = drag
    return drag.token
  }

  /// Dragging a preset row re-parents it onto the dropped group. Rows found by
  /// a global search stay draggable even though they belong to another group.
  @MainActor
  func beginPresetDrag(id: UUID) -> UUID? {
    guard scope != .history, !interactionLocked,
          let preset = presetLibrary?.presets.first(where: { $0.id == id }) else { return nil }
    suspendSending()
    let drag = PresetDrag(token: UUID(), sourceID: id, draft: PresetDraft(preset: preset), presetID: id)
    activeDrag = drag
    return drag.token
  }

  func endHistoryDrag(token: UUID) {
    guard activeDrag?.token == token else { return }
    activeDrag = nil
    suspendSending()
  }

  @MainActor
  func canDrop(token: UUID, groupID: UUID?) -> Bool {
    guard let drag = activeDrag, drag.token == token, !drag.consumed, !importInProgress else { return false }
    if drag.presetID != nil {
      guard presetLibrary?.presets.contains(where: { $0.id == drag.presetID }) == true else { return false }
    } else {
      guard history.all.contains(where: { $0.id == drag.sourceID }) else { return false }
    }
    return groupID == nil || presetLibrary?.groups.contains(where: { $0.id == groupID }) == true
  }

  @MainActor
  @discardableResult
  func drop(token: UUID, groupID: UUID?) -> Bool {
    guard canDrop(token: token, groupID: groupID), var drag = activeDrag else { return false }
    drag.consumed = true
    activeDrag = drag
    if let presetID = drag.presetID {
      do {
        try presetLibrary?.movePreset(id: presetID, to: groupID)
        // Clear the finished drag before refreshing: the selection update must
        // not be blocked by the drag's own interaction lock.
        activeDrag = nil
        refreshPresetResults(autoselect: false)
      } catch {
        errorMessage = error.localizedDescription
        return false
      }
      return true
    }
    var draft = drag.draft
    draft.groupID = groupID
    startImport(draft, sourceID: drag.sourceID)
    return true
  }

  func captureSend(flags: NSEvent.ModifierFlags) -> PopupSendRequest? {
    guard sessionOpen, !interactionLocked else { return nil }
    return PopupSendRequest(generation: sendGeneration, target: navigator.target, flags: flags)
  }

  func accepts(_ request: PopupSendRequest) -> Bool {
    sessionOpen && !interactionLocked && request.generation == sendGeneration && request.target == navigator.target
  }

  @MainActor
  func send(_ request: PopupSendRequest, onlyCopy: Bool = false) {
    guard accepts(request) else { return }
    let flags = onlyCopy ? HistoryItemAction.copy.modifierFlags : request.flags
    let action = flags.isEmpty
      ? (Defaults[.pasteByDefault] ? (Defaults[.removeFormattingByDefault] ? HistoryItemAction.pasteWithoutFormatting : .paste) : .copy)
      : HistoryItemAction(flags)
    guard action != .unknown else { return }
    let shouldPaste = action == .paste || action == .pasteWithoutFormatting
    if case .preset = request.target { history.interruptPasteStack() }

    let sendsContent: Bool
    switch request.target {
    case .history, .preset: sendsContent = true
    default: sendsContent = false
    }
    if shouldPaste, sendsContent {
      guard Accessibility.allowed else {
        showSendProblem(request, message: String(localized: "Allow Accessibility access to paste. You can still copy."), permission: true)
        return
      }
      guard pasteTarget?.isCurrent() == true else {
        showSendProblem(request, message: String(localized: "The target application changed or is unavailable. Reopen Maccy from the intended application, or only copy."))
        return
      }
    }

    switch request.target {
    case .history(let id):
      guard scope == .history, let item = history.items.first(where: { $0.id == id }) else { return }
      if navigator.isMultiSelectInProgress {
        navigator.isManualMultiSelect = false
        history.startPasteStack(selection: &navigator.selection, flags: flags, pasteTarget: pasteTarget)
      } else {
        let target = pasteTarget
        if !history.select(item, flags: flags, pasteTarget: shouldPaste ? target : nil) {
          popup.open(height: popup.height)
          errorMessage = String(localized: "The target application changed or is unavailable. Nothing was pasted.")
        }
      }
    case .preset(let id):
      guard scope != .history, let library = presetLibrary,
            let preset = library.presets.first(where: { $0.id == id }) else { return }
      do {
        let contents = try preset.orderedContents.map { content -> Clipboard.Content in
          if let path = content.relativeFilePath {
            return Clipboard.Content(type: NSPasteboard.PasteboardType.fileURL.rawValue,
                                     value: try library.attachmentURL(for: path).dataRepresentation)
          }
          return Clipboard.Content(type: content.type, value: content.value)
        }
        let target = pasteTarget
        invalidatePendingSend()
        if shouldPaste { popup.close() }
        let copied = Clipboard.shared.copy(contents: contents,
          removeFormatting: action == .pasteWithoutFormatting || (request.flags.isEmpty && Defaults[.removeFormattingByDefault]))
        guard copied else { throw CocoaError(.fileWriteUnknown) }
        if shouldPaste {
          if !Clipboard.shared.paste(onlyIf: { target?.isCurrent() == true }) {
            popup.open(height: popup.height)
            errorMessage = String(localized: "The target application changed or is unavailable. Nothing was pasted.")
          }
        } else { popup.close() }
      } catch { errorMessage = error.localizedDescription }
    case .footer(let id):
      guard scope == .history, let item = footer.items.first(where: { $0.id == id }) else { return }
      invalidatePendingSend()
      if item.confirmation != nil, !Defaults[.suppressClearAlert] { item.showConfirmation = true } else { item.action() }
    case .stack:
      break
    case nil:
      guard scope == .history else { return }
      invalidatePendingSend()
      Clipboard.shared.copyInMaccy(history.searchQuery)
      history.searchQuery = ""
    }
  }

  func showSendProblem(_ request: PopupSendRequest, message: String, permission: Bool = false) {
    suspendSending()
    sendProblem = PopupSendProblem(request: PopupSendRequest(generation: sendGeneration, target: request.target,
                                                            flags: request.flags),
                                   message: message, needsPermission: permission)
  }

  @MainActor
  func onlyCopyPendingSend() {
    guard let problem = sendProblem else { return }
    sendProblem = nil
    send(problem.request, onlyCopy: true)
  }

  @MainActor
  func selectShortcut(_ event: NSEvent) -> Bool {
    guard sessionOpen, !interactionLocked else { return false }
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
    guard HistoryItemAction(flags) != .unknown else { return false }
    if scope == .history {
      guard let item = history.pressedShortcutItem else { return false }
      navigator.select(item: item)
    } else {
      let key = Sauce.shared.key(for: Int(event.keyCode))
      guard let index = (1...9).first(where: { number in KeyShortcut.create(character: String(number)).contains { $0.key == key } }),
            presetResults.indices.contains(index - 1) else { return false }
      navigator.selectPreset(presetResults[index - 1].id)
    }
    guard let request = captureSend(flags: flags) else { return false }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(50))
      guard !Task.isCancelled else { return }
      send(request)
    }
    return true
  }
}
