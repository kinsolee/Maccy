import Foundation
import SwiftUI

enum PopupTarget: Equatable {
  case history(UUID)
  case preset(UUID)
  case footer(UUID)
  case stack(UUID)

  var id: UUID {
    switch self {
    case .history(let id), .preset(let id), .footer(let id), .stack(let id): id
    }
  }
}

@Observable
class NavigationManager { // swiftlint:disable:this type_body_length
  private var history: History
  private var footer: Footer

  init(history: History, footer: Footer) {
    self.history = history
    self.footer = footer
  }

  var selection: Selection<HistoryItemDecorator> = Selection() {
    willSet {
      selection.forEach { _, item in item.selectionIndex = -1 }
      newValue.forEach { index, item in item.selectionIndex = index }
    }
  }

  @ObservationIgnored var selectionDidChange: (() -> Void)?
  @ObservationIgnored var interactionLocked: () -> Bool = { false }
  private(set) var target: PopupTarget? {
    didSet { if target != oldValue { selectionDidChange?() } }
  }
  private(set) var isHistoryScope = true
  var presetIDs: [UUID] = []
  var scrollTarget: UUID?
  var leadSelection: UUID? { target?.id }

  func enterScope(history: Bool, presetIDs: [UUID] = []) {
    selection = .init()
    leadHistoryItem = nil
    footer.selectedItem = nil
    target = nil
    scrollTarget = nil
    hoverSelectionWhileKeyboardNavigating = nil
    isManualMultiSelect = false
    isKeyboardNavigating = true
    isHistoryScope = history
    self.presetIDs = presetIDs
  }

  func selectPreset(_ id: UUID?) {
    guard !interactionLocked(), !isHistoryScope else { return }
    target = id.flatMap { presetIDs.contains($0) ? .preset($0) : nil }
    scrollTarget = target?.id
  }

  private func movePreset(_ offset: Int, cycle: Bool = false) {
    guard !interactionLocked(), !presetIDs.isEmpty else { return }
    let current = leadSelection.flatMap { presetIDs.firstIndex(of: $0) } ?? -1
    let next = current + offset
    let index = cycle ? (next + presetIDs.count) % presetIDs.count : min(max(next, 0), presetIDs.count - 1)
    selectPreset(presetIDs[index])
  }

  private(set) var leadHistoryItem: HistoryItemDecorator? {
    didSet {
      guard oldValue?.id != leadHistoryItem?.id else { return }

      // Announce the visual selection change, keeping repeated navigation updates concise.
      if let item = leadHistoryItem {
        announceForAccessibility {
          var parts = [item.hasImage ? NSLocalizedString("history_item_image_accessibility_generic", comment: "") : item.title]
          if let application = item.application {
            parts.append(application)
          }
          if item.isPinned {
            parts.append(NSLocalizedString("history_item_pinned_accessibility_value", comment: ""))
          }
          return parts.joined(separator: ", ")
        }
      }

      let preview = AppState.shared.preview
      if leadHistoryItem != nil {
        preview.resetAutoOpenSuppression()
        preview.startAutoOpen()
      } else {
        preview.cancelAutoOpen()
      }
    }
  }

  var pasteStackSelected: Bool {
    return leadSelection != nil && leadSelection == history.pasteStack?.id
  }

  var isManualMultiSelect: Bool = false
  var isMultiSelectInProgress: Bool {
    return isManualMultiSelect || selection.count > 1
  }

  var hoverSelectionWhileKeyboardNavigating: UUID?
  var isKeyboardNavigating: Bool = true {
    didSet {
      if !interactionLocked() && !isKeyboardNavigating && !isMultiSelectInProgress,
         let hoverSelection = hoverSelectionWhileKeyboardNavigating {
        hoverSelectionWhileKeyboardNavigating = nil
        select(id: hoverSelection)
      }
    }
  }

  var isFirstItemHighlighted: Bool { history.firstVisibleItem == leadHistoryItem }

  private func scroll(to id: UUID?, item: HistoryItemDecorator? = nil) {
    scrollTarget = id
  }

  func select(id: UUID) {
    guard !interactionLocked() else { return }
    if !isHistoryScope { selectPreset(id); return }
    if let item = history.items.first(where: { $0.id == id }) {
      select(item: item, footerItem: nil)
    } else if let item = footer.items.first(where: { $0.id == id }) {
      select(item: nil, footerItem: item)
    } else {
      select(item: nil, footerItem: nil)
    }
  }

  func select(item: HistoryItemDecorator? = nil, footerItem: FooterItem? = nil) {
    withTransaction(Transaction()) {
      selectWithoutScrolling(item: item, footerItem: footerItem)
      scroll(to: item?.id, item: item)
    }
  }

  func addToSelection(item: HistoryItemDecorator) {
    guard isHistoryScope, !interactionLocked() else { return }
    var newSelectionState = selection

    if item.isSelected {
      if newSelectionState.count <= 1 {
        isManualMultiSelect = !isManualMultiSelect
      } else {
        newSelectionState.remove(item)
      }
    } else {
      newSelectionState.add(item)
    }

    withTransaction(Transaction()) {
      selection = newSelectionState
      leadHistoryItem = item
      target = .history(item.id)
      scrollTarget = leadSelection
    }
  }

  func extendSelection(
    from fromItem: HistoryItemDecorator,
    to toItem: HistoryItemDecorator,
    isRange: Bool
  ) {
    guard isHistoryScope, !interactionLocked() else { return }
    var newSelectionState = selection

    if isRange {
      if let itemRange = history.visibleItems.between(
        from: fromItem,
        to: toItem,
        inOrder: false
      ) {
        newSelectionState = Selection(items: itemRange)
      }
    } else {
      if toItem.isSelected {
        newSelectionState.remove(fromItem)
      } else {
        newSelectionState.add(toItem)
      }
    }

    withTransaction(Transaction()) {
      selection = newSelectionState
      leadHistoryItem = toItem
      target = .history(toItem.id)
      scrollTarget = leadSelection
    }
  }

  func selectWithoutScrolling(id: UUID) {
    guard !interactionLocked() else { return }
    if !isHistoryScope { selectPreset(id); return }
    if let stack = history.pasteStack,
       stack.id == id {
      selectWithoutScrolling(item: nil, footerItem: nil)
      target = .stack(stack.id)
    } else if let item = history.items.first(where: { $0.id == id }) {
      if !isMultiSelectInProgress {
        selectWithoutScrolling(item: item, footerItem: nil)
      }
    } else if let item = footer.items.first(where: { $0.id == id }) {
      selectWithoutScrolling(item: nil, footerItem: item)
    } else {
      selectWithoutScrolling(item: nil, footerItem: nil)
    }
  }

  func selectWithoutScrolling(
    item: HistoryItemDecorator? = nil,
    footerItem: FooterItem? = nil
  ) {
    guard isHistoryScope, !interactionLocked() else { return }
    if let item = item {
      selectInHistory(item)
    } else if let footerItem = footerItem {
      selectInFooter(footerItem)
    } else {
      leadHistoryItem = nil
      selection = .init()
      footer.selectedItem = nil
      target = nil
    }
  }

  private func selectInHistory(_ item: HistoryItemDecorator) {
    target = .history(item.id)
    leadHistoryItem = item
    selection = .init(items: [item])
    footer.selectedItem = nil
  }

  private func selectInFooter(_ item: FooterItem) {
    target = .footer(item.id)
    leadHistoryItem = nil
    if !isMultiSelectInProgress {
      selection = .init()
    }
    footer.selectedItem = item
  }

  private func selectFromKeyboardNavigation(
    item: HistoryItemDecorator? = nil,
    footerItem: FooterItem? = nil
  ) {
    isKeyboardNavigating = true
    isManualMultiSelect = false
    select(item: item, footerItem: footerItem)
  }

  private func extendHistorySelectionFromKeyboardNavigation(
    from fromItem: HistoryItemDecorator,
    to toItem: HistoryItemDecorator,
    isRange: Bool
  ) {
    isKeyboardNavigating = true
    extendSelection(from: fromItem, to: toItem, isRange: isRange)
  }

  func highlightFirst() {
    guard !interactionLocked() else { return }
    if !isHistoryScope { selectPreset(presetIDs.first); return }
    if let item = history.firstVisibleItem {
      selectFromKeyboardNavigation(item: item)
    } else {
      selectFromKeyboardNavigation(item: nil)
    }
  }

  func highlightPrevious() {
    guard !interactionLocked() else { return }
    if !isHistoryScope { movePreset(-1); return }
    guard let lead = leadSelection else { return }

    if let historyItem = history.firstVisibleItem(where: { $0.id == lead }) {
      if let nextItem = history.visibleItem(before: historyItem) {
        selectFromKeyboardNavigation(item: nextItem)
      } else if let stack = history.pasteStack {
        selectWithoutScrolling(id: stack.id)
      } else {
        highlightFirst()
      }
    } else if let footerItem = footer.firstVisibleItem(where: { $0.id == lead }) {
      if let nextItem = footer.visibleItem(before: footerItem) {
        selectFromKeyboardNavigation(footerItem: nextItem)
      } else if let nextItem = history.lastVisibleItem {
        selectFromKeyboardNavigation(item: nextItem)
      }
    }
  }

  func highlightNext(allowCycle: Bool = false) {
    guard !interactionLocked() else { return }
    if !isHistoryScope { movePreset(1, cycle: allowCycle); return }
    guard let lead = leadSelection else { return }

    if leadSelection == history.pasteStack?.id {
      highlightFirst()
      return
    }

    if let historyItem = history.firstVisibleItem(where: { $0.id == lead }) {
      if let nextItem = history.visibleItem(after: historyItem) {
        selectFromKeyboardNavigation(item: nextItem)
      } else if let nextItem = footer.firstVisibleItem {
        selectFromKeyboardNavigation(footerItem: nextItem)
      } else if allowCycle {
        highlightFirst()
      }
    } else if let footerItem = footer.firstVisibleItem(where: { $0.id == lead }) {
      if let nextItem = footer.visibleItem(after: footerItem) {
        selectFromKeyboardNavigation(footerItem: nextItem)
      } else if let nextItem = footer.firstVisibleItem {
        selectFromKeyboardNavigation(footerItem: nextItem)
      } else if allowCycle {
        // End of footer; cycle to the beginning
        highlightFirst()
      }
    }
  }

  func highlightLast() {
    guard !interactionLocked() else { return }
    if !isHistoryScope { selectPreset(presetIDs.last); return }
    guard let lead = leadSelection else { return }

    if let historyItem = history.firstVisibleItem(where: { $0.id == lead }) {
      if historyItem == history.lastVisibleItem,
         let nextItem = footer.firstVisibleItem {
        selectFromKeyboardNavigation(footerItem: nextItem)
      } else {
        selectFromKeyboardNavigation(item: history.lastVisibleItem)
      }
    } else if footer.selectedItem != nil {
      selectFromKeyboardNavigation(footerItem: footer.lastVisibleItem)
    } else {
      selectFromKeyboardNavigation(footerItem: footer.firstVisibleItem)
    }
  }

  func extendHighlightToNext() {
    if let leadSelection,
       let leadItem = history.firstVisibleItem(where: {$0.id == leadSelection}) {
      guard let nextItem = history.visibleItem(after: leadItem) else { return }
      extendHistorySelectionFromKeyboardNavigation(from: leadItem, to: nextItem, isRange: false)
    } else {
      highlightNext()
    }
  }

  func extendHighlightToPrevious() {
    if let leadSelection,
       let leadItem = history.firstVisibleItem(where: {$0.id == leadSelection}) {
      guard let nextItem = history.visibleItem(before: leadItem) else { return }
      extendHistorySelectionFromKeyboardNavigation(from: leadItem, to: nextItem, isRange: false)
    } else {
      highlightPrevious()
    }
  }

  func extendHighlightToFirst() {
    if let leadSelection,
       let leadItem = history.firstVisibleItem(where: {$0.id == leadSelection}) {
      guard let nextItem = history.firstVisibleItem else { return }
      extendHistorySelectionFromKeyboardNavigation(from: leadItem, to: nextItem, isRange: true)
    } else {
      highlightFirst()
    }
  }

  func extendHighlightToLast() {
    if let leadSelection,
       let leadItem = history.firstVisibleItem(where: {$0.id == leadSelection}) {
      guard let nextItem = history.lastVisibleItem else { return }
      extendHistorySelectionFromKeyboardNavigation(from: leadItem, to: nextItem, isRange: true)
    } else {
      highlightFirst()
    }
  }

}
