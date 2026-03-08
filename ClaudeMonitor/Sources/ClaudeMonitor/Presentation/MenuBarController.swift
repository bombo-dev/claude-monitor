import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let viewModel: SessionListViewModel

    init(viewModel: SessionListViewModel) {
        self.viewModel = viewModel
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "terminal",
                accessibilityDescription: "Claude Monitor"
            )
            button.image = image
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
        }

        statusItem = item

        let hostingView = NSHostingController(rootView: PopoverView(viewModel: viewModel))
        popover.contentViewController = hostingView
        popover.contentSize = NSSize(width: 680, height: 460)
        popover.behavior = .transient

        updateIcon()
        startObserving()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }

        let count = viewModel.activeCount
        button.title = count > 0 ? "\(count)" : ""

        let color: NSColor
        if viewModel.hasError {
            color = .systemRed
        } else if count > 0 {
            color = .labelColor
        } else {
            color = .systemGray
        }

        button.contentTintColor = color
    }

    private func startObserving() {
        withObservationTracking {
            _ = viewModel.sessions
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateIcon()
                self?.startObserving()
            }
        }
    }
}
