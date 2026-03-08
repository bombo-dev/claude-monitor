import UserNotifications

final class NotificationService: NotificationServiceProtocol, Sendable {
    static let shared = NotificationService()

    private var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    func requestPermission() async {
        guard isAvailable else { return }
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func notify(title: String, body: String) {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
