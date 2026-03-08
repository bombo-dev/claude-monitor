import AppKit

@MainActor
@Observable
final class SessionListViewModel {
    private let store: SessionStore

    init(store: SessionStore) {
        self.store = store
    }

    var sessions: [SessionInfo] {
        store.sessions
    }

    var activeCount: Int {
        store.sessions.filter { $0.status == .running || $0.status == .idle }.count
    }

    var hasError: Bool {
        store.sessions.contains { $0.status == .error || $0.status == .fileReadError }
    }

    func openInFinder(session: SessionInfo) {
        let path = session.projectPath.standardizedFileURL.path()
        guard path.hasPrefix(NSHomeDirectory()) else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
