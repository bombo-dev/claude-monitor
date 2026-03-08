import Foundation

actor SessionFileReader: SessionFileReaderProtocol {
    private let claudeProjectsBase: URL

    init(homeDirectory: URL = .homeDirectory) {
        self.claudeProjectsBase = homeDirectory
            .appending(path: ".claude/projects", directoryHint: .isDirectory)
    }

    func readLatestSession(projectDirectory: URL) throws -> SessionSnapshot {
        let basePath = claudeProjectsBase.standardizedFileURL.path()
        let basePathWithSlash = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard projectDirectory.standardizedFileURL.path()
            .hasPrefix(basePathWithSlash)
        else {
            throw SessionFileError.pathViolation
        }

        let jsonlFile = try findLatestJsonl(in: projectDirectory)
        let tailText = try tailRead(file: jsonlFile)
        return try parseLastAssistantMessage(from: tailText, fileURL: jsonlFile)
    }

    func findLatestJsonl(in directory: URL) throws -> URL {
        let fm = FileManager.default
        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
        } catch {
            throw SessionFileError.noJsonlFile
        }

        let jsonlFiles = contents
            .filter { $0.pathExtension == "jsonl" }
            .filter { !$0.path().contains("/subagents/") }

        guard !jsonlFiles.isEmpty else {
            throw SessionFileError.noJsonlFile
        }

        let sorted = jsonlFiles.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return dateA > dateB
        }

        return sorted[0]
    }

    private func tailRead(file: URL) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: file)
        } catch {
            throw SessionFileError.noJsonlFile
        }
        defer { try? handle.close() }

        let fileSize: UInt64
        do {
            fileSize = try handle.seekToEnd()
        } catch {
            throw SessionFileError.noJsonlFile
        }

        guard fileSize > 0 else {
            throw SessionFileError.noAssistantMessage
        }

        let readSize = min(fileSize, 16 * 1024)
        try handle.seek(toOffset: fileSize - readSize)

        let data = handle.readData(ofLength: Int(readSize))
        guard let text = String(data: data, encoding: .utf8) else {
            throw SessionFileError.encodingError
        }
        return text
    }

    private func parseLastAssistantMessage(from text: String, fileURL: URL) throws -> SessionSnapshot {
        let lines = text.split(separator: "\n").reversed()

        var sessionId: String?
        var gitBranch: String?

        for line in lines {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            if sessionId == nil, let sid = json["sessionId"] as? String {
                sessionId = sid
            }
            if gitBranch == nil, let branch = json["gitBranch"] as? String {
                gitBranch = branch
            }

            guard json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  message["role"] as? String == "assistant"
            else { continue }

            let lastAssistantText: String
            let isTextTruncated: Bool
            if let content = message["content"] as? [[String: Any]] {
                let texts = content
                    .filter { $0["type"] as? String == "text" }
                    .compactMap { $0["text"] as? String }
                let joined = texts.joined(separator: " ")
                isTextTruncated = joined.count > 2000
                lastAssistantText = String(joined.prefix(2000))
            } else {
                lastAssistantText = ""
                isTextTruncated = false
            }

            let stopReason = json["stop_reason"] as? String
                ?? (message["stop_reason"] as? String)
            let hasError = (stopReason != nil) && (stopReason != "end_turn")

            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path())
            let lastModified = (attrs?[.modificationDate] as? Date) ?? Date()

            return SessionSnapshot(
                sessionId: sessionId ?? "unknown",
                gitBranch: gitBranch ?? "unknown",
                lastAssistantText: lastAssistantText,
                isTextTruncated: isTextTruncated,
                lastModified: lastModified,
                hasError: hasError
            )
        }

        throw SessionFileError.noAssistantMessage
    }
}
