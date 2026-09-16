import SwiftUI

struct SearchFieldView: View {
  var placeholder: LocalizedStringKey
  @Binding var query: String

  @Environment(AppState.self) private var appState

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous)
        .fill(BUI.field)

      RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous)
        .stroke(BUI.lineStrong, lineWidth: 1)

      HStack(spacing: 0) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(BUI.ink3)
          .frame(width: 11, height: 11)
          .padding(.leading, 8)
          .accessibilityHidden(true)

        TextField(placeholder, text: $query)
          .font(BUI.rowFont)
          .disableAutocorrection(true)
          .lineLimit(1)
          .textFieldStyle(.plain)
          .padding(.leading, 6)
          .onSubmit {
            appState.select(flags: .currentModifierFlags)
          }

        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 12))
              .frame(width: 11, height: 11)
              .padding(.trailing, 8)
          }
          .buttonStyle(.plain)
          .foregroundStyle(BUI.ink3)
          .accessibilityLabel(Text("search_clear_accessibility_label"))
        }
      }
    }
    .frame(height: 26)
  }
}

#Preview {
  return List {
    SearchFieldView(placeholder: "search_placeholder", query: .constant(""))
    SearchFieldView(placeholder: "search_placeholder", query: .constant("search"))
  }
  .frame(width: 300)
  .environment(\.locale, .init(identifier: "en"))
}
