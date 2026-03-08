import SwiftUI

struct SessionTreeView: View {
    let sessions: [SessionInfo]
    @Binding var selection: SessionListViewModel.Selection?
    @State private var expandedSessions: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    rootNode(session: session)

                    if expandedSessions.contains(session.id) {
                        ForEach(session.subagents) { agent in
                            childNode(agent: agent, sessionId: session.id)
                        }
                    }

                    if index < sessions.count - 1 {
                        Divider().padding(.leading, 10)
                    }
                }
            }
        }
        .frame(width: 220)
        .onAppear {
            // Initially expand all sessions that have subagents
            for session in sessions where !session.subagents.isEmpty {
                expandedSessions.insert(session.id)
            }
        }
    }

    // MARK: - Root Node

    private func rootNode(session: SessionInfo) -> some View {
        let isSelected = selection == .session(id: session.id)

        return HStack(alignment: .top, spacing: 6) {
            // Chevron
            if session.subagents.isEmpty {
                Color.clear.frame(width: 16, height: 16)
            } else {
                Image(systemName: expandedSessions.contains(session.id)
                      ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }

            // Status indicator (AC-17: rollup)
            Circle()
                .fill(rootStatusColor(session: session))
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(session.tty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minHeight: 40)
        .background(
            isSelected
                ? RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
                    .padding(.horizontal, 4)
                : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .session(id: session.id)
            if !session.subagents.isEmpty {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedSessions.contains(session.id) {
                        expandedSessions.remove(session.id)
                    } else {
                        expandedSessions.insert(session.id)
                    }
                }
            }
        }
    }

    // MARK: - Child Node

    private func childNode(agent: SubagentInfo, sessionId: String) -> some View {
        let isSelected = selection == .subagent(sessionId: sessionId, agentId: agent.id)

        return HStack(spacing: 6) {
            Circle()
                .fill(statusColor(for: agent.status))
                .frame(width: 6, height: 6)

            Text(displayName(for: agent.agentType))
                .font(.caption)
                .lineLimit(1)

            Spacer()
        }
        .padding(.leading, 26)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 28)
        .background(
            isSelected
                ? RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
                    .padding(.horizontal, 4)
                : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .subagent(sessionId: sessionId, agentId: agent.id)
        }
    }

    // MARK: - Helpers

    private func rootStatusColor(session: SessionInfo) -> Color {
        // AC-17: subagent error rollup
        if session.subagents.contains(where: { $0.status == .error }) {
            return .red
        }
        return statusColor(for: session.status)
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .running: .green
        case .idle: .yellow
        case .completed: .gray
        case .error, .fileReadError: .red
        }
    }

    private func displayName(for agentType: String) -> String {
        if agentType == "unknown" { return "Agent" }
        if let colonIndex = agentType.lastIndex(of: ":") {
            return String(agentType[agentType.index(after: colonIndex)...])
        }
        return agentType
    }
}
