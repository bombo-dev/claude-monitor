enum SessionFileError: Error, Sendable {
    case noJsonlFile
    case noAssistantMessage
    case encodingError
    case pathViolation
}
