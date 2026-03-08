import Foundation

struct PendingRemoval: Sendable {
    let sessionId: String
    let removeAfter: Date
}
