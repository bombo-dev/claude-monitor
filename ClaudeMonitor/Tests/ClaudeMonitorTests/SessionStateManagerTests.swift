import Testing
import Foundation
@testable import ClaudeMonitor

// MARK: - Mock Actors

actor MockProcessScanner: ProcessScannerProtocol {
    var scanResults: [[ClaudeProcessInfo]] = []
    private var callIndex = 0

    func setScanResults(_ results: [[ClaudeProcessInfo]]) {
        self.scanResults = results
        self.callIndex = 0
    }

    func scan() async -> [ClaudeProcessInfo] {
        guard callIndex < scanResults.count else { return [] }
        let result = scanResults[callIndex]
        callIndex += 1
        return result
    }
}

actor MockSessionFileReader: SessionFileReaderProtocol {
    var results: [String: Result<SessionSnapshot, Error>] = [:]
    var defaultSnapshot: SessionSnapshot?

    func setResult(for directory: URL, result: Result<SessionSnapshot, Error>) {
        results[directory.path()] = result
    }

    func setDefaultSnapshot(_ snapshot: SessionSnapshot) {
        defaultSnapshot = snapshot
    }

    func readLatestSession(projectDirectory: URL) throws -> SessionSnapshot {
        if let result = results[projectDirectory.path()] {
            return try result.get()
        }
        if let snapshot = defaultSnapshot {
            return snapshot
        }
        throw SessionFileError.noJsonlFile
    }
}

final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _notifications: [(title: String, body: String)] = []

    func notify(title: String, body: String) {
        lock.lock()
        _notifications.append((title: title, body: body))
        lock.unlock()
    }

    func getNotifications() -> [(title: String, body: String)] {
        lock.lock()
        defer { lock.unlock() }
        return _notifications
    }
}

// Thread-safe mutable clock for tests
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    init(_ date: Date = Date()) {
        self._now = date
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return _now
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        _now = _now.addingTimeInterval(interval)
        lock.unlock()
    }
}

// MARK: - Tests

@Suite("SessionStateManager Tests")
struct SessionStateManagerTests {

    private func makePathEncoder() -> PathEncoder {
        PathEncoder(homeDirectory: URL(fileURLWithPath: "/tmp/test-home"))
    }

    private func makeSut(
        scanner: MockProcessScanner = MockProcessScanner(),
        fileReader: MockSessionFileReader = MockSessionFileReader(),
        notificationService: MockNotificationService = MockNotificationService(),
        testClock: TestClock = TestClock(),
        idleThreshold: TimeInterval = 5 * 60
    ) async -> (SessionStateManager, SessionStore, MockProcessScanner, MockSessionFileReader, MockNotificationService) {
        let store = await SessionStore()
        let clock = testClock
        let manager = SessionStateManager(
            store: store,
            processScanner: scanner,
            fileReader: fileReader,
            notificationService: notificationService,
            pathEncoder: makePathEncoder(),
            clock: { clock.now },
            idleThreshold: idleThreshold
        )
        return (manager, store, scanner, fileReader, notificationService)
    }

    private func makeProc(pid: Int = 1234, tty: String = "s004", cwd: String? = "/Users/test/project") -> ClaudeProcessInfo {
        ClaudeProcessInfo(pid: pid, tty: tty, cwd: cwd)
    }

    private func makeSnapshot(
        sessionId: String = "test-session",
        gitBranch: String = "main",
        lastAssistantText: String = "Working on task",
        lastModified: Date = Date(),
        hasError: Bool = false
    ) -> SessionSnapshot {
        SessionSnapshot(
            sessionId: sessionId,
            gitBranch: gitBranch,
            lastAssistantText: lastAssistantText,
            lastModified: lastModified,
            hasError: hasError
        )
    }

    // TC-SSM-01: New PID detected → session added
    @Test("New PID detected adds session")
    func newPidAddsSession() async {
        let scanner = MockProcessScanner()
        let (manager, store, _, _, _) = await makeSut(scanner: scanner)

        await scanner.setScanResults([[makeProc()]])
        await manager.pollProcessesOnce()

        let sessions = await store.sessions
        #expect(sessions.count == 1)
        #expect(sessions[0].pid == 1234)
        #expect(sessions[0].projectName == "project")
        #expect(sessions[0].status == .running)
    }

    // TC-SSM-03: PID terminated + no error → completed + notification
    @Test("PID terminated without error marks completed and notifies")
    func pidTerminatedNoError() async {
        let scanner = MockProcessScanner()
        let notifService = MockNotificationService()
        let (manager, store, _, _, _) = await makeSut(scanner: scanner, notificationService: notifService)

        await scanner.setScanResults([
            [makeProc()],
            []
        ])

        await manager.pollProcessesOnce()
        await manager.pollProcessesOnce()

        let sessions = await store.sessions
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .completed)

        let notifications = notifService.getNotifications()
        #expect(notifications.count == 1)
        #expect(notifications[0].body == "Session completed")
    }

    // TC-SSM-04: PID terminated + hasError → error + notification
    @Test("PID terminated with error marks error and notifies")
    func pidTerminatedWithError() async {
        let scanner = MockProcessScanner()
        let fileReader = MockSessionFileReader()
        let notifService = MockNotificationService()
        let (manager, store, _, _, _) = await makeSut(
            scanner: scanner, fileReader: fileReader, notificationService: notifService
        )

        let proc = makeProc()
        await scanner.setScanResults([[proc], []])

        let pathEncoder = makePathEncoder()
        if let projectDir = pathEncoder.projectDirectory(for: proc.cwd!) {
            await fileReader.setResult(
                for: projectDir,
                result: .success(makeSnapshot(hasError: true))
            )
        }

        await manager.pollProcessesOnce()
        await manager.pollFilesOnce()
        await manager.pollProcessesOnce()

        let sessions = await store.sessions
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .error)

        let notifications = notifService.getNotifications()
        #expect(notifications.count == 1)
        #expect(notifications[0].body == "Session error")
    }

    // TC-SSM-05: Completed session removed after 30 seconds
    @Test("Completed session removed after 30 seconds")
    func completedSessionRemovedAfter30s() async {
        let scanner = MockProcessScanner()
        let testClock = TestClock()
        let (manager, store, _, _, _) = await makeSut(scanner: scanner, testClock: testClock)

        await scanner.setScanResults([
            [makeProc()],
            [],
            []
        ])

        await manager.pollProcessesOnce()
        await manager.pollProcessesOnce()

        var sessions = await store.sessions
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .completed)

        testClock.advance(by: 31)
        await manager.pollProcessesOnce()

        sessions = await store.sessions
        #expect(sessions.isEmpty)
    }

    // TC-SSM-06: Error session removed after 60 seconds
    @Test("Error session removed after 60 seconds")
    func errorSessionRemovedAfter60s() async {
        let scanner = MockProcessScanner()
        let fileReader = MockSessionFileReader()
        let testClock = TestClock()
        let (manager, store, _, _, _) = await makeSut(
            scanner: scanner, fileReader: fileReader, testClock: testClock
        )

        let proc = makeProc()
        await scanner.setScanResults([[proc], [], [], []])

        let pathEncoder = makePathEncoder()
        if let projectDir = pathEncoder.projectDirectory(for: proc.cwd!) {
            await fileReader.setResult(
                for: projectDir,
                result: .success(makeSnapshot(hasError: true))
            )
        }

        await manager.pollProcessesOnce()
        await manager.pollFilesOnce()
        await manager.pollProcessesOnce()  // → error

        var sessions = await store.sessions
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .error)

        // 31 seconds — should still be there
        testClock.advance(by: 31)
        await manager.pollProcessesOnce()
        sessions = await store.sessions
        #expect(sessions.count == 1)

        // 61 seconds total — should be removed
        testClock.advance(by: 30)
        await manager.pollProcessesOnce()
        sessions = await store.sessions
        #expect(sessions.isEmpty)
    }

    // TC-SSM-07: JSONL read failure → fileReadError
    @Test("JSONL read failure sets fileReadError status")
    func jsonlReadFailureSetsFileReadError() async {
        let scanner = MockProcessScanner()
        let fileReader = MockSessionFileReader()
        let (manager, store, _, _, _) = await makeSut(scanner: scanner, fileReader: fileReader)

        let proc = makeProc()
        await scanner.setScanResults([[proc]])

        let pathEncoder = makePathEncoder()
        if let projectDir = pathEncoder.projectDirectory(for: proc.cwd!) {
            await fileReader.setResult(
                for: projectDir,
                result: .failure(SessionFileError.noJsonlFile)
            )
        }

        await manager.pollProcessesOnce()
        await manager.pollFilesOnce()

        let sessions = await store.sessions
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .fileReadError(reason: .noJsonlFile))
    }

    // TC-SSM-08: fileReadError → running on successful read
    @Test("fileReadError recovers to running on successful read")
    func fileReadErrorRecoversToRunning() async {
        let scanner = MockProcessScanner()
        let fileReader = MockSessionFileReader()
        let (manager, store, _, _, _) = await makeSut(scanner: scanner, fileReader: fileReader)

        let proc = makeProc()
        await scanner.setScanResults([[proc]])

        let pathEncoder = makePathEncoder()
        guard let projectDir = pathEncoder.projectDirectory(for: proc.cwd!) else {
            Issue.record("Failed to create project directory")
            return
        }

        // First: fail
        await fileReader.setResult(for: projectDir, result: .failure(SessionFileError.noJsonlFile))
        await manager.pollProcessesOnce()
        await manager.pollFilesOnce()

        var sessions = await store.sessions
        #expect(sessions[0].status == .fileReadError(reason: .noJsonlFile))

        // Second: succeed
        await fileReader.setResult(for: projectDir, result: .success(makeSnapshot()))
        await manager.pollFilesOnce()

        sessions = await store.sessions
        #expect(sessions[0].status == .running)
    }

    // TC-SSM-09: running → idle after 5 minutes
    @Test("Running session becomes idle after idle threshold")
    func runningBecomesIdleAfterThreshold() async {
        let scanner = MockProcessScanner()
        let testClock = TestClock()
        let (manager, store, _, _, _) = await makeSut(
            scanner: scanner, testClock: testClock, idleThreshold: 300
        )

        let proc = makeProc()
        await scanner.setScanResults([
            [proc],
            [proc]
        ])

        await manager.pollProcessesOnce()

        testClock.advance(by: 360)
        await manager.pollProcessesOnce()

        let sessions = await store.sessions
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .idle)
    }

    // TC-SSM-10: idle → running when file is updated
    @Test("Idle session becomes running when file is updated")
    func idleBecomesRunningOnFileUpdate() async {
        let scanner = MockProcessScanner()
        let fileReader = MockSessionFileReader()
        let testClock = TestClock()
        let (manager, store, _, _, _) = await makeSut(
            scanner: scanner, fileReader: fileReader, testClock: testClock, idleThreshold: 300
        )

        let proc = makeProc()
        await scanner.setScanResults([
            [proc],
            [proc]
        ])

        let pathEncoder = makePathEncoder()
        guard let projectDir = pathEncoder.projectDirectory(for: proc.cwd!) else {
            Issue.record("Failed to create project directory")
            return
        }

        await manager.pollProcessesOnce()

        // Go idle
        testClock.advance(by: 360)
        await manager.pollProcessesOnce()

        var sessions = await store.sessions
        #expect(sessions[0].status == .idle)

        // File updated after idle → should become running
        let futureModified = testClock.now.addingTimeInterval(10)
        await fileReader.setResult(
            for: projectDir,
            result: .success(makeSnapshot(lastModified: futureModified))
        )
        await manager.pollFilesOnce()

        sessions = await store.sessions
        #expect(sessions[0].status == .running)
    }

    // TC-SSM-11: CWD nil → not added
    @Test("Process with nil CWD is not added")
    func nilCwdNotAdded() async {
        let scanner = MockProcessScanner()
        let (manager, store, _, _, _) = await makeSut(scanner: scanner)

        let proc = ClaudeProcessInfo(pid: 9999, tty: "s001", cwd: nil)
        await scanner.setScanResults([[proc]])
        await manager.pollProcessesOnce()

        let sessions = await store.sessions
        #expect(sessions.isEmpty)
    }

    // TC-SSM-12: Multiple sessions tracked simultaneously
    @Test("Multiple sessions tracked correctly")
    func multipleSessionsTracked() async {
        let scanner = MockProcessScanner()
        let (manager, store, _, _, _) = await makeSut(scanner: scanner)

        await scanner.setScanResults([[
            makeProc(pid: 1001, tty: "s001", cwd: "/Users/test/projectA"),
            makeProc(pid: 1002, tty: "s002", cwd: "/Users/test/projectB"),
            makeProc(pid: 1003, tty: "s003", cwd: "/Users/test/projectC")
        ]])
        await manager.pollProcessesOnce()

        let sessions = await store.sessions
        #expect(sessions.count == 3)
    }
}
