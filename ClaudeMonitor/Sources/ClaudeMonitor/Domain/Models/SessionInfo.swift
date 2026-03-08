import Foundation

struct ClaudeProcessInfo: Sendable, Hashable {
    let pid: Int
    let tty: String
    let cwd: String?
}

struct SessionSnapshot: Sendable, Hashable {
    let sessionId: String
    let gitBranch: String
    let lastAssistantText: String
    let lastModified: Date
    let hasError: Bool
}

struct SessionInfo: Identifiable, Sendable, Hashable {
    let id: String
    let pid: Int
    let tty: String
    let projectName: String
    let projectPath: URL
    let gitBranch: String
    let lastAssistantText: String
    let status: SessionStatus
    let lastUpdated: Date
    let subagents: [SubagentInfo]
}
