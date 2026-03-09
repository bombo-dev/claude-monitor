import SwiftUI

struct SessionTreeView: View {
    let sessions: [SessionInfo]
    @Binding var selection: SessionListViewModel.Selection?
    let aliasResolver: (String) -> String?
    let aliasSaver: (String, String) -> Void
    @State private var expandedSessions: Set<String> = []
    @State private var editingSessionId: String?
    @State private var editingText: String = ""

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
                    if isSessionDataLoading(session) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("데이터를 가져오는 중...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if case .fileReadError(let reason) = session.status {
                        Text(errorReasonText(reason))
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    } else if editingSessionId == session.id {
                        AliasEditField(
                            text: $editingText,
                            onCommit: { commitEdit(for: session.id) },
                            onCancel: { cancelEdit() }
                        )
                    } else {
                        Text(aliasResolver(session.id) ?? session.tty)
                            .font(.caption)
                            .foregroundStyle(aliasResolver(session.id) != nil ? .primary : .secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if !isSessionDataLoading(session) {
                        Text(relativeTime(from: session.lastUpdated))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
        .onTapGesture(count: 2) {
            guard !isSessionDataLoading(session) else { return }
            if case .fileReadError = session.status { return }
            startEdit(for: session)
        }
        .onTapGesture(count: 1) {
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

    private func errorReasonText(_ reason: FileReadErrorReason) -> String {
        switch reason {
        case .noJsonlFile: "JSONL 파일 없음"
        case .noAssistantMessage: "응답 메시지 없음"
        case .encodingError: "인코딩 오류"
        case .pathViolation: "경로 접근 차단"
        case .unknown: "알 수 없는 오류"
        }
    }

    private func isSessionDataLoading(_ session: SessionInfo) -> Bool {
        session.gitBranch == "unknown" && session.lastAssistantText.isEmpty
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Alias Editing

    private func startEdit(for session: SessionInfo) {
        editingText = aliasResolver(session.id) ?? session.tty
        editingSessionId = session.id
    }

    private func commitEdit(for sessionId: String) {
        aliasSaver(sessionId, editingText)
        editingSessionId = nil
        editingText = ""
    }

    private func cancelEdit() {
        editingSessionId = nil
        editingText = ""
    }
}

// MARK: - AliasEditField

private struct AliasEditField: View {
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("별칭 입력", text: $text)
            .font(.caption)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit { onCommit() }
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
            .onChange(of: isFocused) { _, newValue in
                if !newValue { onCommit() }
            }
            .onAppear { isFocused = true }
    }
}
