import SwiftUI

struct ConfirmationView<Content: View>: View {
  @Environment(AppState.self) private var appState
  @Bindable var item: FooterItem
  @ViewBuilder let content: () -> Content

  var body: some View {
    if let confirmation = item.confirmation, let suppressConfirmation = item.suppressConfirmation {
      content()
        .buttonAction {
          guard appState.scope == .history, !appState.interactionLocked else { return }
          appState.suspendSending()
          if suppressConfirmation.wrappedValue {
            item.action()
          } else {
            item.showConfirmation = true
          }
        }
        .confirmationDialog(confirmation.message, isPresented: $item.showConfirmation) {
          Text(confirmation.comment)
          Button(confirmation.confirm, role: .destructive) {
            guard appState.scope == .history, !appState.interactionLocked else { return }
            item.action()
          }
          .accessibilityIdentifier("confirmation-confirm")
          Button(confirmation.cancel, role: .cancel) {}
        }
        .dialogSuppressionToggle(isSuppressed: suppressConfirmation)
    } else {
      content()
        .buttonAction {
          guard appState.scope == .history, !appState.interactionLocked else { return }
          appState.suspendSending()
          item.action()
        }
    }
  }
}
