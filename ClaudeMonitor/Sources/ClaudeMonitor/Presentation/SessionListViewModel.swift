import AppKit

@MainActor
@Observable
final class SessionListViewModel {
    private let store: SessionStore

    enum Selection: Hashable {
        case session(id: String)
        case subagent(sessionId: String, agentId: String)
    }

    var selection: Selection?

    init(store: SessionStore) {
        self.store = store
    }

    var sessions: [SessionInfo] {
        store.sessions
    }

    var activeCount: Int {
        store.sessions.filter { $0.status == .running || $0.status == .idle }.count
    }

    // AC-17: hasError includes subagent error rollup
    var hasError: Bool {
        store.sessions.contains { session in
            session.status == .error
                || session.status == .fileReadError
                || session.subagents.contains { $0.status == .error }
        }
    }

    // AC-20: auto-select most recently updated session
    func selectInitialIfNeeded() {
        guard selection == nil, let first = store.sessions.first else { return }
        selection = .session(id: first.id)
    }

    func openInFinder(session: SessionInfo) {
        let path = session.projectPath.standardizedFileURL.path()
        guard path.hasPrefix(NSHomeDirectory()) else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
