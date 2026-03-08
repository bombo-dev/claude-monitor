import SwiftUI

struct StatusDotView: View {
    let status: AppStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var dotColor: Color {
        switch status {
        case .monitoring: .green
        case .idle: .orange
        case .error: .red
        }
    }

    private var label: String {
        switch status {
        case .monitoring(let count): "세션 \(count)개 모니터링 중"
        case .idle: "대기 중"
        case .error: "오류 감지됨"
        }
    }
}
