import Testing
import Foundation
@testable import ClaudeMonitor

@Suite("SubagentFileReader Tests")
struct SubagentFileReaderTests {

    private func createTempDir() throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        return tmpDir
    }

    private func setupSessionDir() throws -> (sessionDir: URL, reader: SubagentFileReader) {
        let tmpDir = try createTempDir()
        let sessionDir = tmpDir.appending(
            path: ".claude/projects/test-project/session-abc",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let reader = SubagentFileReader(
            homeDirectory: tmpDir
        )
        return (sessionDir, reader)
    }

    private func createSubagentsDir(in sessionDir: URL) throws -> URL {
        let subDir = sessionDir.appending(path: "subagents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        return subDir
    }

    private let agentJsonl = """
    {"type":"system","sessionId":"parent-session","timestamp":"2026-03-08T10:00:00Z"}
    {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Implementing the feature now."}]},"stop_reason":"end_turn","sessionId":"parent-session","timestamp":"2026-03-08T10:01:00Z"}
    """

    // AC-13: JSONL 파싱 정상 동작
    @Test("reads subagent from valid JSONL")
    func readValidSubagent() async throws {
        let (sessionDir, reader) = try setupSessionDir()
        let subDir = try createSubagentsDir(in: sessionDir)

        let file = subDir.appending(path: "agent-abc123.jsonl")
        try agentJsonl.write(to: file, atomically: true, encoding: .utf8)

        let results = await reader.readSubagents(sessionDirectory: sessionDir)
        #expect(results.count == 1)
        #expect(results[0].id == "agent-abc123")
        #expect(results[0].parentSessionId == "parent-session")
        #expect(results[0].lastAssistantText == "Implementing the feature now.")
    }

    // AC-13: meta.json 파싱
    @Test("reads agentType from meta.json")
    func readAgentType() async throws {
        let (sessionDir, reader) = try setupSessionDir()
        let subDir = try createSubagentsDir(in: sessionDir)

        let jsonlFile = subDir.appending(path: "agent-reviewer.jsonl")
        try agentJsonl.write(to: jsonlFile, atomically: true, encoding: .utf8)

        let metaFile = subDir.appending(path: "agent-reviewer.meta.json")
        try #"{"agentType":"feature-dev:code-reviewer"}"#
            .write(to: metaFile, atomically: true, encoding: .utf8)

        let results = await reader.readSubagents(sessionDirectory: sessionDir)
        #expect(results.count == 1)
        #expect(results[0].agentType == "feature-dev:code-reviewer")
    }

    // AC-13: meta.json 없는 경우 unknown
    @Test("agentType is unknown when meta.json missing")
    func missingMetaJson() async throws {
        let (sessionDir, reader) = try setupSessionDir()
        let subDir = try createSubagentsDir(in: sessionDir)

        let file = subDir.appending(path: "agent-abc123.jsonl")
        try agentJsonl.write(to: file, atomically: true, encoding: .utf8)

        let results = await reader.readSubagents(sessionDirectory: sessionDir)
        #expect(results.count == 1)
        #expect(results[0].agentType == "unknown")
    }

    // AC-13: subagents/ 디렉토리 없는 경우 빈 배열
    @Test("returns empty array when subagents directory missing")
    func noSubagentsDirectory() async throws {
        let (sessionDir, reader) = try setupSessionDir()

        let results = await reader.readSubagents(sessionDirectory: sessionDir)
        #expect(results.isEmpty)
    }

    // AC-21: 경로 검증 위반 시 빈 배열
    @Test("returns empty array for path outside claudeProjectsBase")
    func pathViolation() async throws {
        let tmpDir = try createTempDir()
        let reader = SubagentFileReader(homeDirectory: tmpDir)

        let outsideDir = FileManager.default.temporaryDirectory
            .appending(path: "outside-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)

        let results = await reader.readSubagents(sessionDirectory: outsideDir)
        #expect(results.isEmpty)
    }

    // RISK-02: agentType prefix(100) 제한
    @Test("agentType truncated to 100 characters")
    func agentTypeTruncation() async throws {
        let (sessionDir, reader) = try setupSessionDir()
        let subDir = try createSubagentsDir(in: sessionDir)

        let jsonlFile = subDir.appending(path: "agent-long.jsonl")
        try agentJsonl.write(to: jsonlFile, atomically: true, encoding: .utf8)

        let longType = String(repeating: "x", count: 200)
        let metaFile = subDir.appending(path: "agent-long.meta.json")
        try "{\"agentType\":\"\(longType)\"}".write(to: metaFile, atomically: true, encoding: .utf8)

        let results = await reader.readSubagents(sessionDirectory: sessionDir)
        #expect(results.count == 1)
        #expect(results[0].agentType.count == 100)
    }

    // AC-22: meta.json 파싱 오류 시 unknown
    @Test("agentType is unknown when meta.json has invalid JSON")
    func invalidMetaJson() async throws {
        let (sessionDir, reader) = try setupSessionDir()
        let subDir = try createSubagentsDir(in: sessionDir)

        let jsonlFile = subDir.appending(path: "agent-bad.jsonl")
        try agentJsonl.write(to: jsonlFile, atomically: true, encoding: .utf8)

        let metaFile = subDir.appending(path: "agent-bad.meta.json")
        try "not valid json".write(to: metaFile, atomically: true, encoding: .utf8)

        let results = await reader.readSubagents(sessionDirectory: sessionDir)
        #expect(results.count == 1)
        #expect(results[0].agentType == "unknown")
    }

    // lastAssistantText prefix(5000) 적용
    @Test("lastAssistantText truncated to 5000 characters")
    func textTruncation() async throws {
        let (sessionDir, reader) = try setupSessionDir()
        let subDir = try createSubagentsDir(in: sessionDir)

        let longText = String(repeating: "a", count: 8000)
        let content = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"\(longText)"}]},"stop_reason":"end_turn","sessionId":"s1","timestamp":"2026-03-08T10:00:00Z"}
        """
        let file = subDir.appending(path: "agent-truncate.jsonl")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let results = await reader.readSubagents(sessionDirectory: sessionDir)
        #expect(results.count == 1)
        #expect(results[0].lastAssistantText.count == 5000)
        #expect(results[0].isTextTruncated == true)
    }

    // 복수 서브에이전트 파싱
    @Test("reads multiple subagents sorted by lastUpdated")
    func multipleSubagents() async throws {
        let (sessionDir, reader) = try setupSessionDir()
        let subDir = try createSubagentsDir(in: sessionDir)

        let older = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"older"}]},"stop_reason":"end_turn","sessionId":"s1","timestamp":"2026-03-08T09:00:00Z"}
        """
        let newer = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"newer"}]},"stop_reason":"end_turn","sessionId":"s1","timestamp":"2026-03-08T11:00:00Z"}
        """

        try older.write(to: subDir.appending(path: "agent-old.jsonl"), atomically: true, encoding: .utf8)
        try newer.write(to: subDir.appending(path: "agent-new.jsonl"), atomically: true, encoding: .utf8)

        let results = await reader.readSubagents(sessionDirectory: sessionDir)
        #expect(results.count == 2)
        #expect(results[0].lastAssistantText == "newer")
        #expect(results[1].lastAssistantText == "older")
    }
}
