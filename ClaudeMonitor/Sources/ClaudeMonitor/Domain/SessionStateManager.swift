import Foundation

actor SessionStateManager {

    private struct ManagedSession: Sendable {
        var info: SessionInfo
        let processInfo: ClaudeProcessInfo
        var enteredCurrentStatusAt: Date
        var hasError: Bool = false
        var consecutiveFileReadFailures: Int = 0
        var hasEverLoadedData: Bool = false
    }

    static let fileReadErrorThreshold = 3

    private let sessionStore: SessionStore
    private let processScanner: any ProcessScannerProtocol
    private let fileReader: any SessionFileReaderProtocol
    private let subagentReader: SubagentFileReader
    private let notificationService: any NotificationServiceProtocol
    private let pathEncoder: PathEncoder
    private let clock: @Sendable () -> Date
    private let processInterval: Duration
    private let fileInterval: Duration
    private let idleThreshold: TimeInterval

    private var managed: [String: ManagedSession] = [:]
    private var pendingRemovals: [PendingRemoval] = []
    private var previousPids: Set<Int> = []
    private var pidToSessionId: [Int: String] = [:]
    private var dismissedSessionIds: Set<String> {
        didSet { Self.saveDismissedIds(dismissedSessionIds) }
    }
    private var processTask: Task<Void, Never>?
    private var fileTask: Task<Void, Never>?

    init(
        store: SessionStore,
        processScanner: any ProcessScannerProtocol = ProcessScanner(),
        fileReader: any SessionFileReaderProtocol = SessionFileReader(),
        subagentReader: SubagentFileReader = SubagentFileReader(),
        notificationService: any NotificationServiceProtocol = NotificationService.shared,
        pathEncoder: PathEncoder = PathEncoder(),
        clock: @escaping @Sendable () -> Date = { Date() },
        processInterval: Duration = .seconds(10),
        fileInterval: Duration = .seconds(5),
        idleThreshold: TimeInterval = 5 * 60
    ) {
        self.sessionStore = store
        self.processScanner = processScanner
        self.fileReader = fileReader
        self.subagentReader = subagentReader
        self.notificationService = notificationService
        self.pathEncoder = pathEncoder
        self.clock = clock
        self.processInterval = processInterval
        self.fileInterval = fileInterval
        self.idleThreshold = idleThreshold
        self.dismissedSessionIds = Self.loadDismissedIds()
    }

    deinit {
        processTask?.cancel()
        fileTask?.cancel()
    }

    func start() {
        guard processTask == nil else { return }

        processTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.pollProcessesOnce()
                try? await Task.sleep(for: self.processInterval)
            }
        }

        fileTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.pollFilesOnce()
                try? await Task.sleep(for: self.fileInterval)
            }
        }
    }

    func stop() {
        processTask?.cancel()
        processTask = nil
        fileTask?.cancel()
        fileTask = nil
    }

    // MARK: - Process Polling

    func pollProcessesOnce() async {
        let processes = await processScanner.scan()
        let currentPids = Set(processes.map(\.pid))

        // Detect new PIDs
        for proc in processes where !previousPids.contains(proc.pid) {
            addSession(from: proc)
        }

        // Detect terminated PIDs
        let terminatedPids = previousPids.subtracting(currentPids)
        for pid in terminatedPids {
            markTerminated(pid: pid)
        }

        // Check idle transitions
        checkIdleTransitions(alivePids: currentPids)

        // Process pending removals
        processPendingRemovals()

        previousPids = currentPids
        await pushToStore()
    }

    // MARK: - File Polling

    func pollFilesOnce() async {
        let now = clock()

        for (sessionId, session) in managed {
            guard let cwd = session.processInfo.cwd,
                  let projectDir = pathEncoder.projectDirectory(for: cwd)
            else { continue }

            // Skip completed/error sessions
            switch session.info.status {
            case .completed, .error:
                continue
            default:
                break
            }

            do {
                let snapshot = try await fileReader.readLatestSession(projectDirectory: projectDir)
                updateFromSnapshot(sessionId: sessionId, snapshot: snapshot, now: now)

                // Read subagents from session directory
                let sessionDir = projectDir.appending(
                    path: snapshot.sessionId, directoryHint: .isDirectory
                )
                let subagents = await subagentReader.readSubagents(
                    sessionDirectory: sessionDir
                )
                updateSubagents(sessionId: sessionId, subagents: subagents)
            } catch {
                let reason = FileReadErrorReason(from: error)
                markFileReadError(sessionId: sessionId, now: now, reason: reason)
            }
        }

        await pushToStore()
    }

    // MARK: - Session Management

    private func addSession(from proc: ClaudeProcessInfo) {
        guard let cwd = proc.cwd else { return }

        // Skip if another session with the same project path already exists
        // (subagent processes share the parent's cwd)
        let projectPath = URL(fileURLWithPath: cwd)
        let alreadyTracked = managed.values.contains { $0.info.projectPath == projectPath }
        guard !alreadyTracked else { return }

        let now = clock()
        let projectName = projectPath.lastPathComponent
        let sessionId = "\(proc.pid)-\(proc.tty)"

        guard !dismissedSessionIds.contains(sessionId) else { return }

        let info = SessionInfo(
            id: sessionId,
            pid: proc.pid,
            tty: proc.tty,
            projectName: projectName,
            projectPath: URL(fileURLWithPath: cwd),
            gitBranch: "unknown",
            lastAssistantText: "",
            isTextTruncated: false,
            status: .running,
            lastUpdated: now,
            subagents: []
        )

        managed[sessionId] = ManagedSession(
            info: info,
            processInfo: proc,
            enteredCurrentStatusAt: now
        )
        pidToSessionId[proc.pid] = sessionId
    }

    private func markTerminated(pid: Int) {
        guard let sessionId = pidToSessionId[pid],
              var session = managed[sessionId]
        else { return }

        let now = clock()

        // Sessions that never loaded data (e.g. subagent processes) — remove silently
        if !session.hasEverLoadedData {
            managed.removeValue(forKey: sessionId)
            pidToSessionId.removeValue(forKey: pid)
            return
        }

        if session.hasError {
            session.info = rebuildInfo(session.info, status: .error, lastUpdated: now)
            pendingRemovals.append(PendingRemoval(sessionId: sessionId, removeAfter: now.addingTimeInterval(60)))
            notificationService.notify(
                title: session.info.projectName,
                body: "Session error"
            )
        } else {
            session.info = rebuildInfo(session.info, status: .completed, lastUpdated: now)
            pendingRemovals.append(PendingRemoval(sessionId: sessionId, removeAfter: now.addingTimeInterval(30)))
            notificationService.notify(
                title: session.info.projectName,
                body: "Session completed"
            )
        }

        session.enteredCurrentStatusAt = now
        managed[sessionId] = session
        pidToSessionId.removeValue(forKey: pid)
    }

    private func updateFromSnapshot(sessionId: String, snapshot: SessionSnapshot, now: Date) {
        guard var session = managed[sessionId] else { return }

        let newStatus: SessionStatus
        if session.info.status == .idle && snapshot.lastModified > session.enteredCurrentStatusAt {
            newStatus = .running
        } else if case .fileReadError = session.info.status {
            newStatus = .running
        } else {
            newStatus = session.info.status
        }

        let statusChanged = newStatus != session.info.status

        session.info = SessionInfo(
            id: session.info.id,
            pid: session.info.pid,
            tty: session.info.tty,
            projectName: session.info.projectName,
            projectPath: session.info.projectPath,
            gitBranch: snapshot.gitBranch,
            lastAssistantText: snapshot.lastAssistantText,
            isTextTruncated: snapshot.isTextTruncated,
            status: newStatus,
            lastUpdated: now,
            subagents: session.info.subagents
        )

        session.hasError = snapshot.hasError
        session.consecutiveFileReadFailures = 0
        session.hasEverLoadedData = true

        if statusChanged {
            session.enteredCurrentStatusAt = now
        }

        managed[sessionId] = session
    }

    private func updateSubagents(sessionId: String, subagents: [SubagentInfo]) {
        guard var session = managed[sessionId] else { return }
        let activeSubagents = subagents.filter { $0.status != .completed }
        session.info = SessionInfo(
            id: session.info.id,
            pid: session.info.pid,
            tty: session.info.tty,
            projectName: session.info.projectName,
            projectPath: session.info.projectPath,
            gitBranch: session.info.gitBranch,
            lastAssistantText: session.info.lastAssistantText,
            isTextTruncated: session.info.isTextTruncated,
            status: session.info.status,
            lastUpdated: session.info.lastUpdated,
            subagents: activeSubagents
        )
        // AC-17: hasError rollup - include subagent errors
        if subagents.contains(where: { $0.status == .error }) {
            session.hasError = true
        }
        managed[sessionId] = session
    }

    private func markFileReadError(sessionId: String, now: Date, reason: FileReadErrorReason) {
        guard var session = managed[sessionId] else { return }

        session.consecutiveFileReadFailures += 1

        // Never show fileReadError for sessions that have never loaded data
        // (likely subagent processes without their own JSONL files)
        guard session.hasEverLoadedData else {
            managed[sessionId] = session
            return
        }

        // Only transition to fileReadError after consecutive failures exceed threshold
        switch session.info.status {
        case .running, .idle:
            guard session.consecutiveFileReadFailures >= Self.fileReadErrorThreshold else {
                managed[sessionId] = session
                return
            }
            session.info = rebuildInfo(session.info, status: .fileReadError(reason: reason), lastUpdated: now)
            session.enteredCurrentStatusAt = now
            managed[sessionId] = session
        default:
            break
        }
    }

    func dismissSession(sessionId: String) async {
        if let session = managed[sessionId] {
            pidToSessionId.removeValue(forKey: session.info.pid)
        }
        dismissedSessionIds.insert(sessionId)
        managed.removeValue(forKey: sessionId)
        await pushToStore()
    }

    private func checkIdleTransitions(alivePids: Set<Int>) {
        let now = clock()

        for (sessionId, var session) in managed {
            guard alivePids.contains(session.info.pid) else { continue }

            if session.info.status == .running {
                let elapsed = now.timeIntervalSince(session.info.lastUpdated)
                if elapsed > idleThreshold {
                    session.info = rebuildInfo(session.info, status: .idle, lastUpdated: now)
                    session.enteredCurrentStatusAt = now
                    managed[sessionId] = session
                }
            }
        }
    }

    private func processPendingRemovals() {
        let now = clock()
        var remainingRemovals: [PendingRemoval] = []

        for removal in pendingRemovals {
            if removal.removeAfter <= now {
                if let session = managed[removal.sessionId] {
                    pidToSessionId.removeValue(forKey: session.info.pid)
                }
                managed.removeValue(forKey: removal.sessionId)
            } else {
                remainingRemovals.append(removal)
            }
        }

        pendingRemovals = remainingRemovals
    }

    // MARK: - SwiftUI Push

    private func pushToStore() async {
        let sortedSessions = managed.values
            .map(\.info)
            .sorted { $0.lastUpdated > $1.lastUpdated }

        await MainActor.run {
            sessionStore.sessions = sortedSessions
        }
    }

    // MARK: - Helpers

    private func rebuildInfo(_ info: SessionInfo, status: SessionStatus, lastUpdated: Date) -> SessionInfo {
        SessionInfo(
            id: info.id,
            pid: info.pid,
            tty: info.tty,
            projectName: info.projectName,
            projectPath: info.projectPath,
            gitBranch: info.gitBranch,
            lastAssistantText: info.lastAssistantText,
            isTextTruncated: info.isTextTruncated,
            status: status,
            lastUpdated: lastUpdated,
            subagents: info.subagents
        )
    }

    // MARK: - Persistence

    private static let dismissedKey = "dismissedSessionIds"

    private nonisolated static func loadDismissedIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []
        return Set(array)
    }

    private nonisolated static func saveDismissedIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: dismissedKey)
    }

    // MARK: - Test Helpers

    var currentSessions: [SessionInfo] {
        managed.values.map(\.info).sorted { $0.lastUpdated > $1.lastUpdated }
    }

    var pendingRemovalCount: Int {
        pendingRemovals.count
    }
}
