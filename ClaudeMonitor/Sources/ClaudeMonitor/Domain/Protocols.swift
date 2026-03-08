import Foundation

protocol ProcessScannerProtocol: Actor {
    func scan() async -> [ClaudeProcessInfo]
}

protocol SessionFileReaderProtocol: Actor {
    func readLatestSession(projectDirectory: URL) throws -> SessionSnapshot
}

protocol NotificationServiceProtocol: Sendable {
    func notify(title: String, body: String)
}
