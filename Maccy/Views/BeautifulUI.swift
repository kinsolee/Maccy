import SwiftUI

// Design tokens ported from the Beautiful UI design system
// (github.com/slev12397/beautiful-ui): cool blue-tinted neutrals, solid
// hairline borders, a single blue accent used sparingly, and tight radii
// (chips 6, controls 8, cards 10, windows 14).
enum BUI {
  // MARK: Radii

  static let radiusChip: CGFloat = 6
  static let radiusControl: CGFloat = 8
  static let radiusCard: CGFloat = 10
  static let radiusWindow: CGFloat = 14

  // MARK: Colors (light / dark, resolved per appearance)

  private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double), darkAlpha: Double = 1) -> Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      let isDark = appearance.bestMatch(from: [
        .aqua, .darkAqua, .vibrantLight, .vibrantDark,
        .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
        .accessibilityHighContrastVibrantLight, .accessibilityHighContrastVibrantDark,
      ]).map { $0 == .darkAqua || $0 == .vibrantDark || $0 == .accessibilityHighContrastDarkAqua || $0 == .accessibilityHighContrastVibrantDark } ?? false
      let (r, g, b) = isDark ? dark : light
      return NSColor(srgbRed: r, green: g, blue: b, alpha: isDark ? darkAlpha : 1)
    }))
  }

  // surfaces
  static let surface = dynamic(light: (1, 1, 1), dark: (0.1373, 0.1412, 0.1529))
  static let inset = dynamic(light: (0.9686, 0.9725, 0.9765), dark: (0.1216, 0.1255, 0.1333))
  static let hover = dynamic(light: (0.9569, 0.9608, 0.9647), dark: (0.1647, 0.1686, 0.1804))
  static let hover2 = dynamic(light: (0.9059, 0.9137, 0.9216), dark: (0.1922, 0.1961, 0.2118))
  static let field = dynamic(light: (0.9490, 0.9490, 0.9529), dark: (0.1686, 0.1725, 0.1843))

  // ink ramp
  static let ink = dynamic(light: (0.1216, 0.1294, 0.1412), dark: (0.9490, 0.9529, 0.9569))
  static let ink2 = dynamic(light: (0.3843, 0.3961, 0.4196), dark: (0.6471, 0.6588, 0.6784))
  static let ink3 = dynamic(light: (0.6039, 0.6157, 0.6392), dark: (0.4235, 0.4353, 0.4588))

  // borders — solid and crisp, not alpha
  static let line = dynamic(light: (0.9255, 0.9294, 0.9373), dark: (0.1804, 0.1882, 0.2000))
  static let lineStrong = dynamic(light: (0.8784, 0.8863, 0.8980), dark: (0.2275, 0.2353, 0.2510))
  static let lineSoft = dynamic(light: (0.9529, 0.9569, 0.9608), dark: (0.1529, 0.1569, 0.1686))

  // accent — the single blue, used as a condiment
  static let accent = dynamic(light: (0.0078, 0.5216, 1.0000), dark: (0.2392, 0.6039, 1.0000))
  static let accentInk = dynamic(light: (0.0000, 0.4392, 0.8667), dark: (0.4941, 0.7529, 1.0000))
  static let accentTint = dynamic(light: (0.9137, 0.9529, 1.0000), dark: (0.2392, 0.6039, 1.0000), darkAlpha: 0.16)

  // Opaque selection fill: accent tint premixed over the surface so rows keep
  // a readable blue pill even on the translucent panel material.
  static let selectionFill = dynamic(light: (0.9137, 0.9529, 1.0000), dark: (0.1537, 0.2153, 0.2886))

  // semantic
  static let green = dynamic(light: (0.0980, 0.6039, 0.3020), dark: (0.2353, 0.7333, 0.4471))
  static let greenTint = dynamic(light: (0.9098, 0.9608, 0.9294), dark: (0.2353, 0.7333, 0.4471), darkAlpha: 0.14)
  static let orange = dynamic(light: (0.9373, 0.4471, 0.0510), dark: (0.9647, 0.5608, 0.2353))
  static let orangeTint = dynamic(light: (0.9922, 0.9451, 0.8980), dark: (0.9647, 0.5608, 0.2353), darkAlpha: 0.14)
  static let red = dynamic(light: (0.8902, 0.2784, 0.2980), dark: (0.9333, 0.3608, 0.3804))
  static let redTint = dynamic(light: (0.9882, 0.9255, 0.9255), dark: (0.9333, 0.3608, 0.3804), darkAlpha: 0.14)

  // MARK: Typography

  // 12px medium is the canonical UI-control size; 13px for row content.
  static let controlFont = Font.system(size: 12, weight: .medium)
  static let rowFont = Font.system(size: 13, weight: .regular)
  static let captionFont = Font.system(size: 11, weight: .medium)
}

// A 1px solid rule in the token line color, replacing system Divider so the
// popup reads as one continuous surface.
struct BUIHairline: View {
  var color: Color = BUI.line

  var body: some View {
    Rectangle()
      .fill(color)
      .frame(height: 1)
  }
}

// MARK: Button styles

// Transparent until hovered — for dense toolbars, tabs, and action rows.
// Pass isActive to render the selected-tab look: accent tint fill + accent ink.
struct BUIQuietButtonStyle: ButtonStyle {
  var cornerRadius: CGFloat = BUI.radiusControl
  var color: Color = BUI.ink2
  var activeColor: Color = BUI.ink
  var isActive = false
  var activeBackground: Color = BUI.accentTint
  var activeForeground: Color = BUI.accentInk

  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(labelColor(pressed: configuration.isPressed))
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(backgroundColor(pressed: configuration.isPressed))
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .onHover { hovering = $0 }
      .animation(.easeOut(duration: 0.12), value: hovering)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }

  private func labelColor(pressed: Bool) -> Color {
    if isActive { return activeForeground }
    if pressed || hovering { return activeColor }
    return color
  }

  private func backgroundColor(pressed: Bool) -> Color {
    if isActive { return activeBackground }
    if pressed { return BUI.hover2 }
    if hovering { return BUI.hover }
    return .clear
  }
}

// Bordered surface pill — secondary actions.
struct BUISecondaryButtonStyle: ButtonStyle {
  var cornerRadius: CGFloat = BUI.radiusControl

  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(BUI.controlFont)
      .foregroundStyle(BUI.ink)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(configuration.isPressed ? BUI.hover2 : hovering ? BUI.inset : BUI.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(BUI.line, lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .onHover { hovering = $0 }
      .animation(.easeOut(duration: 0.12), value: hovering)
  }
}

// Filled accent pill — the one primary action.
struct BUIPrimaryButtonStyle: ButtonStyle {
  var cornerRadius: CGFloat = BUI.radiusControl

  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(BUI.controlFont)
      .foregroundStyle(Color.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(hovering ? BUI.accentInk : BUI.accent)
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .onHover { hovering = $0 }
      .animation(.easeOut(duration: 0.12), value: hovering)
  }
}

// MARK: Shared fragments

// Empty-state block from Beautiful UI's SearchList: an icon in a hairline
// inset box, a medium title, and a quiet hint.
struct BUIEmptyState: View {
  let icon: String
  let title: LocalizedStringKey
  var hint: LocalizedStringKey?

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(BUI.ink3)
        .frame(width: 30, height: 30)
        .background(RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous).fill(BUI.inset))
        .overlay(RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous).stroke(BUI.line, lineWidth: 1))
        .padding(.bottom, 2)
      Text(title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(BUI.ink)
      if let hint {
        Text(hint)
          .font(.system(size: 12))
          .foregroundStyle(BUI.ink3)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
  }
}
