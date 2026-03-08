import Foundation

struct SubagentInfo: Identifiable, Sendable, Hashable {
    let id: String
    let agentType: String
    let parentSessionId: String
    let lastAssistantText: String
    let lastUpdated: Date
    let status: SessionStatus
}
