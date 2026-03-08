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
                            childNode(agent: agent, session: session)
                        }
                    }

                    if index < sessions.count - 1 {
                        Divider().padding(.leading, 10)
                    }
                }
            }
        }
        .frame(width: 220)
    }

    // MARK: - Root Node

    private func rootNode(session: SessionInfo) -> some View {
        let isSelected = selection == .session(id: session.id)

        return HStack(alignment: .top, spacing: 8) {
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

            // SF Symbol status icon
            Image(systemName: statusSymbol(for: rootStatus(session: session)))
                .font(.system(size: 14))
                .foregroundStyle(rootStatusColor(session: session))
                .frame(width: 16, height: 16)

            // Text + relative time
            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack {
                    Text(session.tty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(relativeTime(from: session.lastUpdated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
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

    private func childNode(agent: SubagentInfo, session: SessionInfo) -> some View {
        let isSelected = selection == .subagent(sessionId: session.id, agentId: agent.id)

        return HStack(spacing: 8) {
            // SF Symbol status icon
            Image(systemName: statusSymbol(for: agent.status))
                .font(.system(size: 12))
                .foregroundStyle(statusColor(for: agent.status))
                .frame(width: 14, height: 14)

            Text(displayName(for: agent.agentType))
                .font(.caption)
                .lineLimit(1)

            Spacer()
        }
        .padding(.leading, 32)
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
        .overlay(alignment: .leading) {
            // Guide line
            Rectangle()
                .fill(rootStatusColor(session: session).opacity(0.45))
                .frame(width: 1.5)
                .padding(.leading, 19)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .subagent(sessionId: session.id, agentId: agent.id)
        }
    }

    // MARK: - Helpers

    private func rootStatus(session: SessionInfo) -> SessionStatus {
        if session.subagents.contains(where: { $0.status == .error }) {
            return .error
        }
        return session.status
    }

    private func rootStatusColor(session: SessionInfo) -> Color {
        statusColor(for: rootStatus(session: session))
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .running: .green
        case .idle: .yellow
        case .completed: .gray
        case .error: .red
        case .fileReadError: .orange
        }
    }

    private func statusSymbol(for status: SessionStatus) -> String {
        switch status {
        case .running: "circle.fill"
        case .idle: "pause.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .error: "exclamationmark.circle.fill"
        case .fileReadError: "exclamationmark.triangle.fill"
        }
    }

    private func displayName(for agentType: String) -> String {
        if agentType == "unknown" { return "Agent" }
        if let colonIndex = agentType.lastIndex(of: ":") {
            return String(agentType[agentType.index(after: colonIndex)...])
        }
        return agentType
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
