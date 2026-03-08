import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: SessionListViewModel

    init(viewModel: SessionListViewModel) {
        self.viewModel = viewModel
    }

    func openOrFocus() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = makeWindow()
        newWindow.delegate = self
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let contentView = MainWindowView(viewModel: viewModel)
        let hostingView = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Claude Monitor"
        window.contentViewController = hostingView
        window.minSize = NSSize(width: 720, height: 480)
        window.setFrameAutosaveName("ClaudeMonitorMainWindow")
        if !window.setFrameUsingName("ClaudeMonitorMainWindow") {
            window.center()
        }

        return window
    }
}
