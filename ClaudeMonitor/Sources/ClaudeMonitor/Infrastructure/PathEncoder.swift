import Foundation

struct PathEncoder: Sendable {
    private let claudeProjectsBase: URL

    init(homeDirectory: URL = .homeDirectory) {
        self.claudeProjectsBase = homeDirectory
            .appending(path: ".claude/projects", directoryHint: .isDirectory)
    }

    func encode(path: String) -> String {
        let normalized = URL(fileURLWithPath: path).standardized.path
        let collapsed = normalized.split(separator: "/").joined(separator: "/")
        let withLeadingSlash = normalized.hasPrefix("/") ? "/" + collapsed : collapsed
        return withLeadingSlash
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "_", with: "-")
    }

    func projectDirectory(for path: String) -> URL? {
        let encoded = encode(path: path)
        let result = claudeProjectsBase
            .appending(path: encoded, directoryHint: .isDirectory)
        guard result.path().hasPrefix(claudeProjectsBase.path()) else { return nil }
        return result
    }
}
