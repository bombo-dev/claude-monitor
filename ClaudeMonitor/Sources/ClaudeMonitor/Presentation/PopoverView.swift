import SwiftUI

struct PopoverView: View {
    @Bindable var viewModel: SessionListViewModel
    var onOpenWindow: (() -> Void)?

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
        .onAppear {
            viewModel.selectInitialIfNeeded()
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
                selection: $viewModel.selection
            )

            Divider()

            DetailPanelView(
                sessions: viewModel.sessions,
                selection: viewModel.selection,
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
        HStack(spacing: 12) {
            Button {
                onOpenWindow?()
            } label: {
                Label("윈도우로 열기", systemImage: "macwindow")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            StatusDotView(status: viewModel.statusSummary)

            Spacer()

            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
    }
}
