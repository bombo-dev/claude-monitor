import SwiftUI

struct DetailPanelView: View {
    let sessions: [SessionInfo]
    let selection: SessionListViewModel.Selection?
    var onOpenInFinder: ((SessionInfo) -> Void)?
    var onDismissSession: ((SessionInfo) -> Void)?

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

                statusBadge(status: session.status)

                Spacer()

                Button("Finder에서 보기") {
                    onOpenInFinder?(session)
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

            // Last assistant text or error detail
            if case .fileReadError(let reason) = session.status {
                Divider().padding(.vertical, 4)
                fileReadErrorSection(reason: reason, session: session)
            } else if !session.lastAssistantText.isEmpty {
                Divider().padding(.vertical, 4)
                lastAssistantTextSection(text: session.lastAssistantText, isTruncated: session.isTextTruncated)
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
                lastAssistantTextSection(text: agent.lastAssistantText, isTruncated: agent.isTextTruncated)
            }
        }
    }

    // MARK: - Last Assistant Text

    private func lastAssistantTextSection(text: String, isTruncated: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("마지막 응답")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isTruncated {
                        Divider().padding(.vertical, 6)
                        Text("내용이 너무 길어 일부만 표시됩니다.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.05))
            )
        }
    }

    // MARK: - Empty Selection

    private var emptySelection: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("항목을 선택하세요")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("세션을 선택하면 상세 정보가 표시됩니다.")
                .font(.caption)
                .foregroundStyle(.tertiary)
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

    private func fileReadErrorSection(reason: FileReadErrorReason, session: SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("데이터 읽기 실패", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)

            Text(errorDescription(for: reason))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                onDismissSession?(session)
            } label: {
                Label("세션 제거", systemImage: "trash")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.red)
        }
    }

    private func errorDescription(for reason: FileReadErrorReason) -> String {
        switch reason {
        case .noJsonlFile: "세션 데이터 파일을 찾을 수 없습니다"
        case .noAssistantMessage: "응답 메시지가 없습니다"
        case .encodingError: "파일 인코딩 오류"
        case .pathViolation: "경로 접근이 차단되었습니다"
        case .unknown: "알 수 없는 오류"
        }
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

    private func statusLabel(_ status: SessionStatus) -> String {
        switch status {
        case .running: "running"
        case .idle: "idle"
        case .completed: "completed"
        case .error: "error"
        case .fileReadError: "file error"
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
