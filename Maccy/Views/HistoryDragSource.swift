import AppKit
import SwiftUI

// AppKit supplies an authoritative end callback even when Escape or an outside drop cancels a drag.
struct HistoryDragSource: NSViewRepresentable {
  enum Item {
    // History rows save a copy on drop; preset rows move to the dropped group.
    case history(id: UUID, title: String)
    case preset(id: UUID, title: String)
  }
  let item: Item
  let onClick: () -> Void
  static let pasteboardType = NSPasteboard.PasteboardType("org.kinsolee.Maccy.history-drag")

  func makeNSView(context: Context) -> DragView { DragView() }

  func updateNSView(_ view: DragView, context: Context) {
    switch item {
    case .history(let id, let title):
      view.historyID = id
      view.presetID = nil
      view.label = title
    case .preset(let id, let title):
      view.presetID = id
      view.historyID = nil
      view.label = title
    }
    view.onClick = onClick
  }

  final class DragView: NSView, NSDraggingSource {
    var historyID: UUID?
    var presetID: UUID?
    var label = ""
    var onClick: (() -> Void)?
    private(set) var token: UUID?
    private var downEvent: NSEvent?

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) { downEvent = event }

    override func mouseUp(with event: NSEvent) {
      if downEvent != nil, token == nil { onClick?() }
      downEvent = nil
    }

    override func mouseDragged(with event: NSEvent) {
      guard token == nil, let downEvent,
            hypot(event.locationInWindow.x - downEvent.locationInWindow.x,
                  event.locationInWindow.y - downEvent.locationInWindow.y) >= 4 else { return }
      let newToken: UUID?
      if let historyID {
        newToken = AppState.shared.beginHistoryDrag(id: historyID)
      } else if let presetID {
        newToken = AppState.shared.beginPresetDrag(id: presetID)
      } else {
        newToken = nil
      }
      guard let token = newToken else { return }
      self.token = token
      self.downEvent = nil
      let item = NSPasteboardItem()
      item.setString(token.uuidString, forType: HistoryDragSource.pasteboardType)
      let draggingItem = NSDraggingItem(pasteboardWriter: item)
      let size = NSSize(width: min(max(bounds.width, 120), 400), height: 32)
      let image = NSImage(size: size, flipped: false) { rect in
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
        let text = self.label.isEmpty ? String(localized: "Saved content") : self.label.shortened(to: 80)
        (text as NSString).draw(in: rect.insetBy(dx: 10, dy: 7), withAttributes: [.font: NSFont.systemFont(ofSize: 13)])
        return true
      }
      draggingItem.setDraggingFrame(NSRect(origin: convert(event.locationInWindow, from: nil), size: size), contents: image)
      beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
      context == .withinApplication ? .copy : []
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
      if let token { AppState.shared.endHistoryDrag(token: token) }
      token = nil
      downEvent = nil
    }
  }
}

struct PresetGroupDropTarget: NSViewRepresentable {
  let groupID: UUID?
  let onClick: () -> Void
  @Binding var targeted: Bool

  func makeNSView(context: Context) -> DropView {
    let view = DropView()
    view.registerForDraggedTypes([HistoryDragSource.pasteboardType])
    return view
  }

  func updateNSView(_ view: DropView, context: Context) {
    view.groupID = groupID
    view.onClick = onClick
    view.setTargeted = { targeted = $0 }
  }

  final class DropView: NSView {
    var groupID: UUID?
    var onClick: (() -> Void)?
    var setTargeted: ((Bool) -> Void)?

    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
      if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }

    fileprivate func validatedToken(_ sender: NSDraggingInfo) -> UUID? {
      guard let source = sender.draggingSource as? HistoryDragSource.DragView,
            let value = sender.draggingPasteboard.string(forType: HistoryDragSource.pasteboardType),
            let token = UUID(uuidString: value), token == source.token,
            AppState.shared.canDrop(token: token, groupID: groupID) else { return nil }
      return token
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
      let valid = validatedToken(sender) != nil
      setTargeted?(valid)
      return valid ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { setTargeted?(false) }
    override func draggingEnded(_ sender: NSDraggingInfo) { setTargeted?(false) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
      setTargeted?(false)
      guard let token = validatedToken(sender) else { return false }
      return AppState.shared.drop(token: token, groupID: groupID)
    }
  }
}

// SwiftUI's host owns drag dispatch; forward our private type to the group under the cursor.
final class PresetDropHostingView<Content: View>: NSHostingView<Content> {
  private weak var highlightedTarget: PresetGroupDropTarget.DropView?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { registerForDraggedTypes([HistoryDragSource.pasteboardType]) }
  }

  private func isHistoryDrag(_ sender: NSDraggingInfo) -> Bool {
    sender.draggingPasteboard.types?.contains(HistoryDragSource.pasteboardType) == true
  }

  private func dropTarget(_ sender: NSDraggingInfo) -> PresetGroupDropTarget.DropView? {
    guard let window, sender.draggingDestinationWindow === window,
          sender.draggingSourceOperationMask.contains(.copy),
          let source = sender.draggingSource as? HistoryDragSource.DragView,
          source.window === window else { return nil }
    let point = superview?.convert(sender.draggingLocation, from: nil) ?? sender.draggingLocation
    guard let target = hitTest(point) as? PresetGroupDropTarget.DropView,
          target.isDescendant(of: self), target.window === window,
          !target.isHiddenOrHasHiddenAncestor,
          target.visibleRect.contains(target.convert(sender.draggingLocation, from: nil)) else { return nil }
    return target
  }

  private func clearHighlight() {
    highlightedTarget?.setTargeted?(false)
    highlightedTarget = nil
  }

  private func updateTarget(_ sender: NSDraggingInfo) -> NSDragOperation {
    let target = dropTarget(sender)
    if highlightedTarget !== target { clearHighlight() }
    highlightedTarget = target
    return target?.draggingEntered(sender) ?? []
  }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
      guard isHistoryDrag(sender) else { return super.draggingEntered(sender) }
    return updateTarget(sender)
    }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard isHistoryDrag(sender) else { return super.draggingUpdated(sender) }
    return updateTarget(sender)
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
      guard isHistoryDrag(sender) else { return super.prepareForDragOperation(sender) }
      let valid = dropTarget(sender)?.validatedToken(sender) != nil
      if !valid { clearHighlight() }
    return valid
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    defer { clearHighlight() }
    guard isHistoryDrag(sender) else { return super.performDragOperation(sender) }
    return dropTarget(sender)?.performDragOperation(sender) ?? false
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    clearHighlight()
    if sender.map(isHistoryDrag) != true { super.draggingExited(sender) }
  }

  override func draggingEnded(_ sender: NSDraggingInfo) {
    clearHighlight()
    if !isHistoryDrag(sender) { super.draggingEnded(sender) }
  }
}
