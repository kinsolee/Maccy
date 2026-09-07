import AppKit
import Defaults
import Foundation
import Settings
import SwiftUI

@Observable
class AppState: Sendable {
  static let shared = AppState(history: History.shared, footer: Footer())

  let multiSelectionEnabled = false

  var appDelegate: AppDelegate?
  var popup: Popup
  var history: History
  var footer: Footer
  var navigator: NavigationManager
  var preview: SlideoutController

  var presetLibrary: PresetLibrary?
  var scope: PresetScope = .history
  var presetQuery = ""
  var presetResults: [PresetResult] = []
  var editor: PresetEditor?
  var newGroupName: String?
  var errorMessage: String?
  var showUnsavedPrompt = false
  var importInProgress = false
  var activeDrag: PresetDrag?
  var sendProblem: PopupSendProblem?
  var sendGeneration: UInt64 = 0
  var sessionOpen = false
  @ObservationIgnored var pendingChange: (() -> Void)?
  @ObservationIgnored var importTask: Task<Void, Never>?
  @ObservationIgnored var pasteTarget: PasteTarget?

  var interactionLocked: Bool {
    editor != nil || newGroupName != nil || showUnsavedPrompt
      || importInProgress || activeDrag != nil || sendProblem != nil
  }

  @MainActor
  var searchQuery: String {
    get { scope == .history ? history.searchQuery : presetQuery }
    set {
      invalidatePendingSend()
      if scope == .history { history.searchQuery = newValue } else {
        presetQuery = newValue
        refreshPresetResults()
      }
    }
  }

  @MainActor
  var searchVisible: Bool {
    if !Defaults[.showSearch] { return false }
    switch Defaults[.searchVisibility] {
    case .always: return true
    case .duringSearch: return !searchQuery.isEmpty
    }
  }

  var menuIconText: String {
    var title = history.unpinnedItems.first?.text.shortened(to: 100)
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    title.unicodeScalars.removeAll(where: CharacterSet.newlines.contains)
    return title.shortened(to: 20)
  }

  private let about = About()
  private var settingsWindowController: SettingsWindowController?

  init(history: History, footer: Footer, presetLibrary: PresetLibrary? = nil) {
    self.presetLibrary = presetLibrary
    self.history = history
    self.footer = footer
    popup = Popup()
    navigator = NavigationManager(history: history, footer: footer)
    preview = SlideoutController(
      onContentResize: { contentWidth in
        Defaults[.windowSize].width = contentWidth
      },
      onSlideoutResize: { previewWidth in
        Defaults[.previewWidth] = previewWidth
      })
    preview.contentWidth = Defaults[.windowSize].width
    preview.slideoutWidth = Defaults[.previewWidth]
    navigator.selectionDidChange = { [weak self] in self?.invalidatePendingSend() }
    navigator.interactionLocked = { [weak self] in self?.interactionLocked ?? true }
  }

  @MainActor
  func select(flags modifierFlags: NSEvent.ModifierFlags) {
    guard let request = captureSend(flags: modifierFlags) else { return }
    send(request)
  }

  @MainActor
  func togglePin() {
    guard scope == .history, !interactionLocked else { return }
    invalidatePendingSend()
    withTransaction(Transaction()) {
      navigator.selection.forEach { _, item in
        history.togglePin(item)
      }
    }
  }

  @MainActor
  func removePasteStack() {
    history.interruptPasteStack()
    navigator.highlightFirst()
  }

  @MainActor
  func deleteSelection() {
    guard !interactionLocked else { return }
    if case .preset(let id) = navigator.target { requestDelete(.preset(id)); return }
    guard scope == .history else { return }
    invalidatePendingSend()
    guard let leadItem = navigator.leadHistoryItem else { return }
    let nextUnselectedItem = history.visibleItems.nearest(to: leadItem) { !$0.isSelected }

    withTransaction(Transaction()) {
      navigator.selection.forEach { _, item in
        history.delete(item)
      }
      navigator.select(item: nextUnselectedItem)
    }
  }

  func openAbout() {
    about.openAbout(nil)
  }

  @MainActor
  func openPreferences() { // swiftlint:disable:this function_body_length
    if settingsWindowController == nil {
      let generalTitle = NSLocalizedString("Title", tableName: "GeneralSettings", comment: "")
      let storageTitle = NSLocalizedString("Title", tableName: "StorageSettings", comment: "")
      let appearanceTitle = NSLocalizedString("Title", tableName: "AppearanceSettings", comment: "")
      let pinsTitle = NSLocalizedString("Title", tableName: "PinsSettings", comment: "")
      let ignoreTitle = NSLocalizedString("Title", tableName: "IgnoreSettings", comment: "")
      let advancedTitle = NSLocalizedString("Title", tableName: "AdvancedSettings", comment: "")
      let toolbarTitles = [generalTitle, storageTitle, appearanceTitle, pinsTitle, ignoreTitle, advancedTitle]
      let titleAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
      let titleWidth = toolbarTitles.reduce(CGFloat.zero) {
        $0 + ($1 as NSString).size(withAttributes: titleAttributes).width
      }
      let toolbarItemSpacing: CGFloat = 24
      let toolbarEdgeSpacing: CGFloat = 40
      let toolbarWidth = titleWidth + CGFloat(toolbarTitles.count) * toolbarItemSpacing + toolbarEdgeSpacing
      let minimumWidth = max(500, ceil(toolbarWidth))
      settingsWindowController = SettingsWindowController(
        panes: [
          Settings.Pane(
            identifier: Settings.PaneIdentifier.general,
            title: generalTitle,
            toolbarIcon: NSImage.gearshape!
          ) {
            GeneralSettingsPane()
              .frame(minWidth: minimumWidth)
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.storage,
            title: storageTitle,
            toolbarIcon: NSImage.externaldrive!
          ) {
            StorageSettingsPane()
              .frame(minWidth: minimumWidth)
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.appearance,
            title: appearanceTitle,
            toolbarIcon: NSImage.paintpalette!
          ) {
            AppearanceSettingsPane()
              .frame(minWidth: minimumWidth)
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.pins,
            title: pinsTitle,
            toolbarIcon: NSImage.pincircle!
          ) {
            PinsSettingsPane()
              .environment(self)
              .modelContainer(Storage.shared.container)
              .frame(minWidth: minimumWidth)
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.ignore,
            title: ignoreTitle,
            toolbarIcon: NSImage.nosign!
          ) {
            IgnoreSettingsPane()
              .frame(minWidth: minimumWidth)
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.advanced,
            title: advancedTitle,
            toolbarIcon: NSImage.gearshape2!
          ) {
            AdvancedSettingsPane()
              .frame(minWidth: minimumWidth)
          }
        ]
      )
    }
    settingsWindowController?.show()
    settingsWindowController?.window?.orderFrontRegardless()
  }

  func quit() {
    NSApp.terminate(self)
  }
}
