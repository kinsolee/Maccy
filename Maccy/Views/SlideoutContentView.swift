import SwiftUI

struct SlideoutContentView: View {
  @Environment(AppState.self) var appState

  var body: some View {
    VStack {
      if let result = appState.presetResults.first(where: { appState.navigator.target == .preset($0.id) }),
         appState.scope != .history {
        HStack {
          Spacer()
          Button("Edit") { appState.beginEditPreset(result.id) }
          Button("Delete", role: .destructive) { appState.requestDelete(.preset(result.id)) }
        }
        PresetPreviewView(draft: result.draft)
      } else {
        ToolbarView()
      }

      if let item = appState.navigator.leadHistoryItem {
        PreviewItemView(item: item)
      } else if let pasteStack = appState.history.pasteStack,
        appState.navigator.pasteStackSelected {
        PasteStackPreviewView(pasteStack: pasteStack)
      } else {
        EmptyView()
      }
    }
    .padding(.horizontal)
    .padding(.bottom)
    .padding(.top, Popup.verticalPadding)
  }

}
