import AppKit
import Defaults
import Logging
import Observation

enum SlideoutState {
  case opening
  case closing
  case open
  case closed

  var isAnimating: Bool {
    switch self {
    case .closed, .open:
      return false
    case .opening, .closing:
      return true
    }
  }

  var isOpen: Bool {
    switch self {
    case .open, .opening:
      return true
    case .closed, .closing:
      return false
    }
  }
}

enum SlideoutPlacement {
  case left
  case right
}

enum SlideoutToggleTrigger {
  case autoOpen
  case manual
}

enum ResizingMode {
  case none
  case content
  case slideout
}

@Observable
class SlideoutController {
  let logger = Logger(label: "org.p0deje.Maccy")

  let onContentResize: (CGFloat) -> Void
  let onSlideoutResize: (CGFloat) -> Void

  let minimumContentWidth: CGFloat = 200
  var contentResizeWidth: CGFloat = 0

  let minimumSlideoutWidth: CGFloat = 200
  var slideoutResizeWidth: CGFloat = 0

  private var _contentWidth: CGFloat = 0
  var contentWidth: CGFloat {
    get { return _contentWidth }
    set {
      _contentWidth = max(minimumContentWidth, newValue).rounded()
      onContentResize(_contentWidth)
    }
  }
  private var _slideoutWidth: CGFloat = 400
  var slideoutWidth: CGFloat {
    get { return _slideoutWidth }
    set {
      _slideoutWidth = max(minimumSlideoutWidth, newValue).rounded()
      onSlideoutResize(_slideoutWidth)
    }
  }

  var placement: SlideoutPlacement = .right
  var state: SlideoutState = .closed
  var resizingMode: ResizingMode = .none

  var nswindow: NSWindow? {
    return AppState.shared.appDelegate?.panel
  }

  private var autoOpenTask: Task<Void, Never>?
  private var autoOpenSuppressed = false
  private var autoOpenEnabled = true

  init(onContentResize: @escaping (CGFloat) -> Void, onSlideoutResize: @escaping (CGFloat) -> Void) {
    self.onContentResize = onContentResize
    self.onSlideoutResize = onSlideoutResize
  }

  func computePlacement(window: NSWindow, for size: NSSize) -> SlideoutPlacement {
    guard let screen = window.screen?.frame else { return placement }
    let windowFrame = window.frame
    if windowFrame.minX + size.width > screen.maxX {
      return .left
    } else {
      return .right
    }
  }

  func computeSizeWithPreview(_ size: NSSize, state newState: SlideoutState) -> NSSize {
    var newSize = size
    if newState.isOpen {
      newSize.width += slideoutWidth
    }
    let popup = AppState.shared.popup
    newSize.height = popup.preferredHeight(for: popup.height)
    return newSize
  }

  func togglePreview(trigger: SlideoutToggleTrigger = .manual) {
    let wasOpen = state.isOpen
    if !wasOpen {
      guard !AppState.shared.interactionLocked else { return }
      let navigator = AppState.shared.navigator
      let presetSelected: Bool
      if case .preset = navigator.target { presetSelected = true } else { presetSelected = false }
      guard navigator.leadHistoryItem != nil || navigator.pasteStackSelected || presetSelected else { return }
    }

    if trigger == .manual {
      autoOpenSuppressed = wasOpen
    }

    cancelAutoOpen()

    // The frame changes in a single synchronous setFrame: window.animator()
    // completions interrupted by rapid toggles or concurrent height updates
    // leave the panel at stale intermediate sizes, and animating the frame
    // concurrently with a drag session breaks the drag event loop.
    let target: SlideoutState = wasOpen ? .closed : .open
    // The transient animating state keeps windowWillResize from persisting the intermediate frame.
    state = wasOpen ? .closing : .opening
    if let window = nswindow {
      var newSize = window.frame.size
      newSize.width = contentWidth
      newSize = computeSizeWithPreview(newSize, state: target)
      if target == .open {
        placement = computePlacement(window: window, for: newSize)
      }
      var newOrigin = window.frame.origin
      newOrigin.y = window.frame.maxY - newSize.height
      if placement == .left {
        newOrigin.x += target == .open ? -slideoutWidth : slideoutWidth
      }
      window.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }
    state = target
    // Restore the last manual preview state on the next popup session.
    Defaults[.previewOpen] = target == .open
  }

  func startResize(mode: ResizingMode) {
    logger.info("Starting resize with mode \(mode)")
    resizingMode = mode
    contentWidth = contentResizeWidth
    slideoutWidth = slideoutResizeWidth
  }

  func endResize() {
    logger.info("Ended resize. Mode was \(resizingMode)")
    switch resizingMode {
    case .none:
      return
    case .content:
      contentWidth = contentResizeWidth
    case .slideout:
      slideoutWidth = slideoutResizeWidth
    }
    resizingMode = .none
  }

  func startAutoOpen() {
    cancelAutoOpen()

    guard Defaults[.openPreviewAutomatically] else { return }
    guard !AppState.shared.interactionLocked else { return }
    guard autoOpenEnabled else { return }
    guard !autoOpenSuppressed else { return }
    guard !state.isOpen else { return }

    autoOpenTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(Defaults[.previewDelay]))
      guard !Task.isCancelled else { return }
      guard Defaults[.openPreviewAutomatically] else { return }
      guard !AppState.shared.interactionLocked else { return }

      if !state.isOpen {
        togglePreview(trigger: .autoOpen)
      }
    }
  }

  func cancelAutoOpen() {
    autoOpenTask?.cancel()
    autoOpenTask = nil
  }

  func enableAutoOpen() {
    autoOpenEnabled = true
  }

  func disableAutoOpen() {
    autoOpenEnabled = false
    cancelAutoOpen()
  }

  func resetAutoOpenSuppression() {
    autoOpenSuppressed = false
  }
}
