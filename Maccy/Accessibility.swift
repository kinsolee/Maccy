import AppKit

struct Accessibility {
  static var allowed: Bool { AXIsProcessTrustedWithOptions(nil) }

  static func check() {
    guard !allowed else {
      return
    }
  }
}
