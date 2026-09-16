import Defaults
import SwiftUI

struct HeaderView: View {
  @State private var appState = AppState.shared

  let controller: SlideoutController
  @FocusState.Binding var searchFocused: Bool

  var previewPlacement: SlideoutPlacement {
    return controller.placement
  }

  var body: some View {
    VStack(spacing: 0) {
      // Search sits above the group bar so a query searches every group.
      HStack(spacing: 8) {
        if appState.searchVisible {
          ListHeaderView(searchFocused: $searchFocused, searchQuery: $appState.searchQuery)
            .disabled(appState.interactionLocked)
        }
        Spacer(minLength: 0)
        Menu {
          Button("Add text") { appState.beginNewPreset() }
          Button("Import files…") { appState.chooseFiles() }
          if let id = appState.scope.groupID {
            Divider()
            Button("Delete group", role: .destructive) { appState.requestDelete(.group(id)) }
          }
        } label: {
          HStack(spacing: 4) {
            Text("Add manually")
            Image(systemName: "chevron.down")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(BUI.ink3)
          }
          .font(BUI.controlFont)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(BUI.surface, in: RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: BUI.radiusControl, style: .continuous).stroke(BUI.line, lineWidth: 1))
          .contentShape(Rectangle())
        } primaryAction: { appState.beginNewPreset() }
          .menuStyle(.borderlessButton)
          .menuIndicator(.hidden)
          .fixedSize()
          .disabled(appState.importInProgress || appState.activeDrag != nil)
        ToolbarButton { controller.togglePreview() } label: {
          Image(systemName: previewPlacement == .right ? "sidebar.left" : "sidebar.right")
        }
        .shortcutKeyHelp(name: .togglePreview,
                         key: controller.state.isOpen ? "ClosePreview" : "OpenPreview",
                         tableName: "PreviewItemView", replacementKey: "previewKey")
        .disabled(appState.interactionLocked)
      }
      .padding(.horizontal, 14)
      .padding(.top, 10)
      .padding(.bottom, 8)
      PresetGroupBar()
      BUIHairline(color: BUI.line)
    }
    .readHeight(appState, into: \.popup.headerHeight)
  }
}
