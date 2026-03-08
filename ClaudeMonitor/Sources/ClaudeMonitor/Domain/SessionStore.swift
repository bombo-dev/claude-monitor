import Foundation

@MainActor
@Observable
final class SessionStore {
    var sessions: [SessionInfo] = []
}
