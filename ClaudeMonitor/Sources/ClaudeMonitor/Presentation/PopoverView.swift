import SwiftUI

struct PopoverView: View {
    @Bindable var viewModel: SessionListViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                contentArea
            }

            Divider()
            footer
        }
        .frame(width: 680, height: 460)
        .onAppear {
            viewModel.selectInitialIfNeeded()
        }
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

    private var contentArea: some View {
        HStack(spacing: 0) {
            SessionTreeView(
                sessions: viewModel.sessions,
                selection: $viewModel.selection
            )

            Divider()

            DetailPanelView(
                sessions: viewModel.sessions,
                selection: viewModel.selection,
                onOpenInFinder: { session in
                    viewModel.openInFinder(session: session)
                }
            )
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
