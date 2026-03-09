import AppKit

enum AppStatus: Sendable {
    case monitoring(count: Int)
    case idle
    case error
}

@MainActor
@Observable
final class SessionListViewModel {
    private let store: SessionStore
    private let stateManager: SessionStateManager
    let aliasStore: SessionAliasStore
    private var refreshTimer: Timer?

    // Incremented every 10s to force SwiftUI re-render (updates relative timestamps)
    var refreshTick: UInt64 = 0

    enum Selection: Hashable {
        case session(id: String)
        case subagent(sessionId: String, agentId: String)
    }

    var selection: Selection?

    init(store: SessionStore, stateManager: SessionStateManager, aliasStore: SessionAliasStore = SessionAliasStore()) {
        self.store = store
        self.stateManager = stateManager
        self.aliasStore = aliasStore
        startRefreshTimer()
    }

    func alias(for sessionId: String) -> String? {
        aliasStore.alias(for: sessionId)
    }

    func saveAlias(_ alias: String, for sessionId: String) {
        aliasStore.setAlias(alias, for: sessionId)
    }

    var sessions: [SessionInfo] {
        // Reference refreshTick so SwiftUI re-renders when it changes
        _ = refreshTick
        return store.sessions
    }

    var activeCount: Int {
        store.sessions.filter { $0.status == .running || $0.status == .idle }.count
    }

    var statusSummary: AppStatus {
        if hasError { return .error }
        if activeCount > 0 { return .monitoring(count: activeCount) }
        return .idle
    }

    // AC-17: hasError includes subagent error rollup
    var hasError: Bool {
        store.sessions.contains { session in
            session.status == .error
                || isFileReadError(session.status)
                || session.subagents.contains { $0.status == .error }
        }
    }

    private func isFileReadError(_ status: SessionStatus) -> Bool {
        if case .fileReadError = status { return true }
        return false
    }

    func dismissSession(_ session: SessionInfo) {
        Task {
            await stateManager.dismissSession(sessionId: session.id)
        }
    }

    // AC-20: auto-select most recently updated session
    func selectInitialIfNeeded() {
        guard selection == nil, let first = store.sessions.first else { return }
        selection = .session(id: first.id)
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTick &+= 1
            }
        }
    }

    func openInFinder(session: SessionInfo) {
        let path = session.projectPath.standardizedFileURL.path()
        guard path.hasPrefix(NSHomeDirectory()) else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
