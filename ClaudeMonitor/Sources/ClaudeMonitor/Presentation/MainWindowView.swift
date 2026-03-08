import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: SessionListViewModel
    @State private var selection: SessionListViewModel.Selection?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.isInitialLoading {
                loadingState
            } else if viewModel.sessions.isEmpty {
                emptyState
            } else {
                contentArea
            }

            Divider()
            footer
        }
        .onAppear {
            selectInitialIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Claude Monitor")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            if viewModel.activeCount > 0 {
                Text("\(viewModel.activeCount) active")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.bar)
    }

    private var loadingState: some View {
        VStack(spacing: 0) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
                .padding(.bottom, 12)
            Text("세션 확인 중...")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "desktopcomputer.and.arrow.down")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            Text("실행 중인 세션 없음")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            Text("Claude Code CLI를 실행하면\n여기에 세션이 표시됩니다.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var contentArea: some View {
        HStack(spacing: 0) {
            SessionTreeView(
                sessions: viewModel.sessions,
                selection: $selection
            )

            Divider()

            DetailPanelView(
                sessions: viewModel.sessions,
                selection: selection,
                onOpenInFinder: { session in
                    viewModel.openInFinder(session: session)
                },
                onDismissSession: { session in
                    viewModel.dismissSession(session)
                }
            )
        }
    }

    private var footer: some View {
        HStack {
            StatusDotView(status: viewModel.statusSummary)

            Spacer()

            Text("Claude Monitor v3")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
    }

    private func selectInitialIfNeeded() {
        guard selection == nil, let first = viewModel.sessions.first else { return }
        selection = .session(id: first.id)
    }
}
