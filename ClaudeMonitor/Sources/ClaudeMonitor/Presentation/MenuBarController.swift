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
            button.sendAction(on: [.leftMouseUp, .rightMouseDown])
            button.action = #selector(handleClick(_:))
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

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseDown {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openWindowItem = NSMenuItem(
            title: "윈도우로 열기",
            action: #selector(openWindow),
            keyEquivalent: ""
        )
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "종료",
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }
        mainWindowController.openOrFocus()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
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
