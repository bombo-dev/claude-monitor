import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let viewModel: SessionListViewModel
    private let mainWindowController: MainWindowController

    init(viewModel: SessionListViewModel, mainWindowController: MainWindowController) {
        self.viewModel = viewModel
        self.mainWindowController = mainWindowController
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

        let hostingView = NSHostingController(
            rootView: PopoverView(
                viewModel: viewModel,
                onOpenWindow: { [weak self] in
                    self?.openWindow()
                }
            )
        )
        popover.contentViewController = hostingView
        popover.contentSize = NSSize(width: 680, height: 460)
        popover.behavior = .transient

        updateIcon()
        startObserving()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func openWindow() {
        popover.performClose(nil)
        mainWindowController.openOrFocus()
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
        updateDockBadge()
    }

    private func updateDockBadge() {
        let dockTile = NSApp.dockTile
        if viewModel.hasError {
            dockTile.badgeLabel = "!"
        } else if viewModel.activeCount > 0 {
            dockTile.badgeLabel = "\(viewModel.activeCount)"
        } else {
            dockTile.badgeLabel = nil
        }
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
