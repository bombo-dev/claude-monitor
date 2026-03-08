import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var mainWindowController: MainWindowController?
    private let sessionStore = SessionStore()
    private var manager: SessionStateManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mgr = SessionStateManager(store: sessionStore)
        manager = mgr

        let viewModel = SessionListViewModel(store: sessionStore, stateManager: mgr)
        let windowController = MainWindowController(viewModel: viewModel)
        mainWindowController = windowController
        menuBarController = MenuBarController(
            viewModel: viewModel,
            mainWindowController: windowController
        )
        menuBarController?.setup()

        Task {
            await NotificationService.shared.requestPermission()
            await mgr.start()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindowController?.openOrFocus()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        let mgr = manager
        Task { await mgr?.stop() }
    }
}
