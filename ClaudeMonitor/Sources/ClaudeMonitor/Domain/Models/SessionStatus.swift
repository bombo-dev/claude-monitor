enum FileReadErrorReason: Sendable, Hashable {
    case noJsonlFile
    case noAssistantMessage
    case encodingError
    case pathViolation
    case unknown
}

extension FileReadErrorReason {
    init(from error: Error) {
        if let fileError = error as? SessionFileError {
            switch fileError {
            case .noJsonlFile: self = .noJsonlFile
            case .noAssistantMessage: self = .noAssistantMessage
            case .encodingError: self = .encodingError
            case .pathViolation: self = .pathViolation
            }
        } else {
            self = .unknown
        }
    }
}

enum SessionStatus: Sendable, Hashable {
    case running
    case idle
    case completed
    case error
    case fileReadError(reason: FileReadErrorReason)
}
