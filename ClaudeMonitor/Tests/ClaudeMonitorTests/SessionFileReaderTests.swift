import Testing
import Foundation
@testable import ClaudeMonitor

@Suite("SessionFileReader Tests")
struct SessionFileReaderTests {

    private func createTempDir() throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        return tmpDir
    }

    private func createReaderWithBase(_ baseDir: URL) -> SessionFileReader {
        // baseDir = <home>/.claude/projects/
        // 2단계 역산: projects → .claude → home
        let home = baseDir
            .deletingLastPathComponent() // .claude
            .deletingLastPathComponent() // home
        return SessionFileReader(homeDirectory: home)
    }

    private func setupProjectDir() throws -> (projectDir: URL, reader: SessionFileReader) {
        let tmpDir = try createTempDir()
        let claudeProjects = tmpDir.appending(path: ".claude/projects/test-project", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: claudeProjects, withIntermediateDirectories: true)
        let reader = createReaderWithBase(
            tmpDir.appending(path: ".claude/projects", directoryHint: .isDirectory)
        )
        return (claudeProjects, reader)
    }

    private let normalJsonl = """
    {"type":"system","sessionId":"abc-123","gitBranch":"main","cwd":"/tmp"}
    {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hello, I can help you with that task."}]},"stop_reason":"end_turn","sessionId":"abc-123","gitBranch":"main"}
    """

    // TC-07: Normal JSONL parsing
    @Test("reads latest session from valid JSONL")
    func readNormalJsonl() async throws {
        let (projectDir, reader) = try setupProjectDir()
        let file = projectDir.appending(path: "session1.jsonl")
        try normalJsonl.write(to: file, atomically: true, encoding: .utf8)

        let snapshot = try await reader.readLatestSession(projectDirectory: projectDir)
        #expect(snapshot.sessionId == "abc-123")
        #expect(snapshot.gitBranch == "main")
        #expect(snapshot.lastAssistantText == "Hello, I can help you with that task.")
        #expect(snapshot.hasError == false)
    }

    // TC-08: No assistant message → returns partial snapshot with empty text
    @Test("returns empty text when no assistant lines")
    func noAssistantMessage() async throws {
        let (projectDir, reader) = try setupProjectDir()
        let file = projectDir.appending(path: "session1.jsonl")
        let content = """
        {"type":"system","sessionId":"abc-123","gitBranch":"main"}
        {"type":"user","message":{"role":"user","content":"hello"}}
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let snapshot = try await reader.readLatestSession(projectDirectory: projectDir)
        #expect(snapshot.sessionId == "abc-123")
        #expect(snapshot.gitBranch == "main")
        #expect(snapshot.lastAssistantText == "")
        #expect(snapshot.hasError == false)
    }

    // TC-09: Empty directory
    @Test("throws noJsonlFile for empty directory")
    func emptyDirectory() async throws {
        let (projectDir, reader) = try setupProjectDir()

        await #expect(throws: SessionFileError.noJsonlFile) {
            try await reader.readLatestSession(projectDirectory: projectDir)
        }
    }

    // TC-10: prefix(2000) applied
    @Test("lastAssistantText truncated to 2000 chars")
    func prefixTruncation() async throws {
        let (projectDir, reader) = try setupProjectDir()
        let longText = String(repeating: "a", count: 5000)
        let content = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"\(longText)"}]},"stop_reason":"end_turn","sessionId":"s1","gitBranch":"main"}
        """
        let file = projectDir.appending(path: "session1.jsonl")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let snapshot = try await reader.readLatestSession(projectDirectory: projectDir)
        #expect(snapshot.lastAssistantText.count == 2000)
        #expect(snapshot.isTextTruncated == true)
    }

    // TC-11: stop_reason != end_turn → hasError
    @Test("hasError true when stop_reason is not end_turn")
    func hasErrorOnNonEndTurn() async throws {
        let (projectDir, reader) = try setupProjectDir()
        let content = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"partial"}]},"stop_reason":"max_tokens","sessionId":"s1","gitBranch":"main"}
        """
        let file = projectDir.appending(path: "session1.jsonl")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let snapshot = try await reader.readLatestSession(projectDirectory: projectDir)
        #expect(snapshot.hasError == true)
    }

    // TC: stop_reason nil (streaming/in-progress) → hasError false
    @Test("hasError false when stop_reason is nil")
    func hasErrorFalseWhenStopReasonNil() async throws {
        let (projectDir, reader) = try setupProjectDir()
        let content = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"still working"}]},"sessionId":"s1","gitBranch":"main"}
        """
        let file = projectDir.appending(path: "session1.jsonl")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let snapshot = try await reader.readLatestSession(projectDirectory: projectDir)
        #expect(snapshot.hasError == false)
    }

    // TC-12: thinking content excluded
    @Test("excludes thinking content blocks")
    func excludeThinking() async throws {
        let (projectDir, reader) = try setupProjectDir()
        let content = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"internal thought"},{"type":"text","text":"visible response"}]},"stop_reason":"end_turn","sessionId":"s1","gitBranch":"main"}
        """
        let file = projectDir.appending(path: "session1.jsonl")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let snapshot = try await reader.readLatestSession(projectDirectory: projectDir)
        #expect(snapshot.lastAssistantText == "visible response")
        #expect(!snapshot.lastAssistantText.contains("internal thought"))
    }

    // TC-13: Path violation
    @Test("throws pathViolation for directory outside claudeProjectsBase")
    func pathViolation() async throws {
        let tmpDir = try createTempDir()
        let reader = SessionFileReader(homeDirectory: tmpDir)
        let outsideDir = FileManager.default.temporaryDirectory
            .appending(path: "outside-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)

        await #expect(throws: SessionFileError.pathViolation) {
            try await reader.readLatestSession(projectDirectory: outsideDir)
        }
    }

    // TC-14: subagents/ directory excluded
    @Test("findLatestJsonl excludes subagents directory")
    func excludeSubagents() async throws {
        let (projectDir, reader) = try setupProjectDir()

        // Create a jsonl in subagents/ (should be ignored)
        let subagentsDir = projectDir.appending(path: "subagents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: subagentsDir, withIntermediateDirectories: true)
        try "{}".write(to: subagentsDir.appending(path: "sub.jsonl"), atomically: true, encoding: .utf8)

        // Create a valid jsonl at root level
        let file = projectDir.appending(path: "session1.jsonl")
        try normalJsonl.write(to: file, atomically: true, encoding: .utf8)

        let latest = try await reader.findLatestJsonl(in: projectDir)
        #expect(latest.lastPathComponent == "session1.jsonl")
    }

    // TC-15: findLatestJsonl picks most recent
    @Test("findLatestJsonl returns most recently modified file")
    func latestByModificationDate() async throws {
        let (projectDir, reader) = try setupProjectDir()

        let file1 = projectDir.appending(path: "old.jsonl")
        try "{}".write(to: file1, atomically: true, encoding: .utf8)

        // Small delay to ensure different modification times
        try await Task.sleep(for: .milliseconds(50))

        let file2 = projectDir.appending(path: "new.jsonl")
        try normalJsonl.write(to: file2, atomically: true, encoding: .utf8)

        let latest = try await reader.findLatestJsonl(in: projectDir)
        #expect(latest.lastPathComponent == "new.jsonl")
    }
}
