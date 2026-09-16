import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background

  @FocusState private var searchFocused: Bool

  var body: some View {
    ZStack {
      if #available(macOS 26.0, *) {
        GlassEffectView()
      } else {
        VisualEffectView()
      }

      KeyHandlingView(searchQuery: $appState.searchQuery, searchFocused: $searchFocused) {
        VStack(spacing: 0) {
          SlideoutView(controller: appState.preview) {
            HeaderView(
              controller: appState.preview,
              searchFocused: $searchFocused
            )

            VStack(alignment: .leading, spacing: 0) {
              if appState.sendProblem != nil {
                PresetSendProblemView()
              } else if appState.editor != nil || appState.newGroupName != nil || appState.importInProgress {
                PresetManagementView()
              } else {
                if let error = appState.errorMessage {
                  HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                      .font(.system(size: 12, weight: .medium))
                      .foregroundStyle(BUI.red)
                    Text(error)
                      .font(BUI.rowFont)
                      .foregroundStyle(BUI.ink)
                    Spacer()
                    Button {
                      appState.errorMessage = nil
                    } label: {
                      Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .foregroundStyle(BUI.ink3)
                    }
                    .buttonStyle(BUIQuietButtonStyle(color: BUI.ink3))
                  }
                  .padding(10)
                  .background(RoundedRectangle(cornerRadius: BUI.radiusCard, style: .continuous).fill(BUI.redTint))
                  .overlay(RoundedRectangle(cornerRadius: BUI.radiusCard, style: .continuous).stroke(BUI.red.opacity(0.35), lineWidth: 1))
                  .padding(.horizontal, 8)
                  .padding(.top, 6)
                }
                if appState.scope == .history {
                  HistoryListView(searchQuery: $appState.searchQuery, searchFocused: $searchFocused)
                  FooterView(footer: appState.footer)
                } else {
                  PresetListView()
                  PresetFooterView()
                }
              }

            }
            .animation(.default.speed(3), value: appState.history.items)
            .animation(
              .default.speed(3),
              value: appState.history.pasteStack?.id
            )
            .padding(.horizontal, Popup.horizontalPadding)
            .onAppear {
              searchFocused = true
            }
            .onMouseMove {
              if !appState.interactionLocked { appState.navigator.isKeyboardNavigating = false }
            }
          } slideout: {
            SlideoutContentView()
          }
          .frame(minHeight: 0)
          .layoutPriority(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .task {
        try? await appState.history.load()
      }
    }
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    .environment(appState)
    .environment(modifierFlags)
    .environment(\.scenePhase, scenePhase)
    // FloatingPanel is not a scene, so let's implement custom scenePhase..
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .active
        if !appState.interactionLocked { searchFocused = true }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .background
      }
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
