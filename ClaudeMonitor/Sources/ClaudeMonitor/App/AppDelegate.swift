import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let sessionStore = SessionStore()
    private var manager: SessionStateManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = SessionListViewModel(store: sessionStore)
        menuBarController = MenuBarController(viewModel: viewModel)
        menuBarController?.setup()

        let mgr = SessionStateManager(store: sessionStore)
        manager = mgr

        Task {
            await NotificationService.shared.requestPermission()
            await mgr.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        let mgr = manager
        Task { await mgr?.stop() }
    }
}
