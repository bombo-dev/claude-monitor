import SwiftUI

struct PopoverView: View {
    let viewModel: SessionListViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }

            Divider()
            footer
        }
        .frame(width: 320, height: 400)
    }

    private var header: some View {
        HStack {
            Text("Claude Monitor")
                .font(.headline)
            Spacer()
            Text("\(viewModel.activeCount) active")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("실행 중인 세션 없음")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.sessions) { session in
                    SessionCardView(session: session) {
                        viewModel.openInFinder(session: session)
                    }

                    if session.id != viewModel.sessions.last?.id {
                        Divider().padding(.leading, 30)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Claude Monitor 종료") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(8)
        }
        .padding(.horizontal, 4)
    }
}
