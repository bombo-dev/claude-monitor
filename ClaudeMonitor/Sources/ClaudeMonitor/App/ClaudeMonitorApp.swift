import SwiftUI

@main
struct ClaudeMonitorApp: App {
    @State private var sessionStore: SessionStore
    @State private var manager: SessionStateManager

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }

    init() {
        let store = SessionStore()
        let mgr = SessionStateManager(store: store)
        _sessionStore = State(initialValue: store)
        _manager = State(initialValue: mgr)

        Task {
            await NotificationService.shared.requestPermission()
            await mgr.start()
        }
    }
}
