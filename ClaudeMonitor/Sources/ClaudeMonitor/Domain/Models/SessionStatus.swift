enum SessionStatus: Sendable, Hashable {
    case running
    case idle
    case completed
    case error
    case fileReadError
}
