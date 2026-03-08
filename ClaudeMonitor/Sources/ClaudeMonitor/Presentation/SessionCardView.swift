import SwiftUI

struct SessionCardView: View {
    let session: SessionInfo
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectName)
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text("\(session.tty) · \(session.gitBranch)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if session.status == .fileReadError {
                    Text("데이터 읽기 실패")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !session.lastAssistantText.isEmpty {
                    Text(String(session.lastAssistantText.prefix(100)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var statusColor: Color {
        switch session.status {
        case .running: .green
        case .idle: .yellow
        case .completed: .gray
        case .error, .fileReadError: .red
        }
    }
}
