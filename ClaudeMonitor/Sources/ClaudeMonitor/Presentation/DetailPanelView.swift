import SwiftUI

struct DetailPanelView: View {
    let sessions: [SessionInfo]
    let selection: SessionListViewModel.Selection?
    let onOpenInFinder: (SessionInfo) -> Void

    var body: some View {
        Group {
            if let selection {
                switch selection {
                case .session(let id):
                    if let session = sessions.first(where: { $0.id == id }) {
                        sessionDetail(session: session)
                    } else {
                        emptySelection
                    }
                case .subagent(let sessionId, let agentId):
                    if let session = sessions.first(where: { $0.id == sessionId }),
                       let agent = session.subagents.first(where: { $0.id == agentId }) {
                        subagentDetail(agent: agent)
                    } else {
                        emptySelection
                    }
                }
            } else {
                emptySelection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Session Detail

    private func sessionDetail(session: SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(session.projectName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Button("Finder에서 보기") {
                    onOpenInFinder(session)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 6)

            // Meta info
            VStack(alignment: .leading, spacing: 6) {
                metaRow(icon: "folder", text: session.projectPath.path())
                metaRow(icon: "arrow.triangle.branch", text: session.gitBranch)
                metaRow(icon: "terminal", text: session.tty)
                metaRow(icon: "clock", text: relativeTime(from: session.lastUpdated))
            }

            // Subagent summary
            if !session.subagents.isEmpty {
                Divider().padding(.vertical, 4)
                subagentSummary(subagents: session.subagents)
            }

            // Last assistant text
            if session.status == .fileReadError {
                Divider().padding(.vertical, 4)
                Text("데이터 읽기 실패")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !session.lastAssistantText.isEmpty {
                Divider().padding(.vertical, 4)
                ScrollView {
                    Text(session.lastAssistantText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Subagent Detail

    private func subagentDetail(agent: SubagentInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(displayName(for: agent.agentType))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                statusBadge(status: agent.status)
            }

            Divider().padding(.vertical, 6)

            // Meta info
            VStack(alignment: .leading, spacing: 6) {
                metaRow(icon: "person.crop.circle", text: agent.id)
                metaRow(icon: "clock", text: relativeTime(from: agent.lastUpdated))
            }

            // Last assistant text
            if !agent.lastAssistantText.isEmpty {
                Divider().padding(.vertical, 4)
                ScrollView {
                    Text(agent.lastAssistantText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Empty Selection

    private var emptySelection: some View {
        VStack {
            Spacer()
            Text("항목을 선택하세요")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    private func subagentSummary(subagents: [SubagentInfo]) -> some View {
        let grouped = Dictionary(grouping: subagents, by: \.status)
        let statuses: [SessionStatus] = [.running, .idle, .completed, .error]

        return HStack(spacing: 12) {
            ForEach(statuses, id: \.self) { status in
                if let agents = grouped[status], !agents.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(for: status))
                            .frame(width: 6, height: 6)
                        Text("\(agents.count) \(statusLabel(status))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func statusBadge(status: SessionStatus) -> some View {
        Text(statusLabel(status))
            .font(.caption2)
            .foregroundStyle(statusColor(for: status).opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(statusColor(for: status).opacity(0.15))
            )
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .running: .green
        case .idle: .yellow
        case .completed: .gray
        case .error, .fileReadError: .red
        }
    }

    private func statusLabel(_ status: SessionStatus) -> String {
        switch status {
        case .running: "running"
        case .idle: "idle"
        case .completed: "completed"
        case .error: "error"
        case .fileReadError: "error"
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
