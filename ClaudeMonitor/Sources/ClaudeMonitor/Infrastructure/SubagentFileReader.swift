import Foundation

actor SubagentFileReader {
    private let claudeProjectsBase: URL

    init(homeDirectory: URL = .homeDirectory) {
        self.claudeProjectsBase = homeDirectory
            .appending(path: ".claude/projects", directoryHint: .isDirectory)
    }

    func readSubagents(sessionDirectory: URL) -> [SubagentInfo] {
        let basePath = claudeProjectsBase.standardizedFileURL.path()
        let basePathWithSlash = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard sessionDirectory.standardizedFileURL.path()
            .hasPrefix(basePathWithSlash)
        else {
            return []
        }

        let subagentsDir = sessionDirectory
            .appending(path: "subagents", directoryHint: .isDirectory)

        let fm = FileManager.default
        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: subagentsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
        } catch {
            return []
        }

        let jsonlFiles = contents.filter {
            $0.pathExtension == "jsonl" && $0.lastPathComponent.hasPrefix("agent-")
        }

        var results: [SubagentInfo] = []

        for jsonlFile in jsonlFiles {
            let agentId = extractAgentId(from: jsonlFile)
            let metaFile = sessionDirectory
                .appending(path: "subagents/\(agentId).meta.json")
            let agentType = readAgentType(from: metaFile)

            guard let parsed = parseSubagentJsonl(file: jsonlFile, agentId: agentId, agentType: agentType) else {
                continue
            }
            results.append(parsed)
        }

        return results.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    // MARK: - Private

    private func extractAgentId(from jsonlFile: URL) -> String {
        let name = jsonlFile.deletingPathExtension().lastPathComponent
        return name
    }

    private func readAgentType(from metaFile: URL) -> String {
        guard let data = try? Data(contentsOf: metaFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawType = json["agentType"] as? String
        else {
            return "unknown"
        }
        return String(rawType.prefix(100))
    }

    private func parseSubagentJsonl(file: URL, agentId: String, agentType: String) -> SubagentInfo? {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: file)
        } catch {
            return nil
        }
        defer { try? handle.close() }

        let fileSize: UInt64
        do {
            fileSize = try handle.seekToEnd()
        } catch {
            return nil
        }

        guard fileSize > 0 else { return nil }

        let readSize = min(fileSize, 16 * 1024)
        try? handle.seek(toOffset: fileSize - readSize)

        let data = handle.readData(ofLength: Int(readSize))
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        let lines = text.split(separator: "\n").reversed()

        var parentSessionId: String?
        var lastAssistantText: String = ""
        var isTextTruncated = false
        var lastUpdated: Date?
        var foundAssistant = false
        var hasError = false

        for line in lines {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            if parentSessionId == nil, let sid = json["sessionId"] as? String {
                parentSessionId = sid
            }

            if lastUpdated == nil, let ts = json["timestamp"] as? String {
                lastUpdated = parseTimestamp(ts)
            }

            let stopReason = json["stop_reason"] as? String
            if stopReason != nil && stopReason != "end_turn" {
                hasError = true
            }

            guard !foundAssistant else { continue }

            guard json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  message["role"] as? String == "assistant"
            else { continue }

            if let content = message["content"] as? [[String: Any]] {
                let texts = content
                    .filter { $0["type"] as? String == "text" }
                    .compactMap { $0["text"] as? String }
                let joined = texts.joined(separator: " ")
                isTextTruncated = joined.count > 2000
                lastAssistantText = String(joined.prefix(2000))
            }
            foundAssistant = true
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: file.path())
        let fileDate = (attrs?[.modificationDate] as? Date) ?? Date()

        let status: SessionStatus
        if hasError {
            status = .error
        } else if let updated = lastUpdated, Date().timeIntervalSince(updated) > 300 {
            status = .idle
        } else {
            status = .running
        }

        return SubagentInfo(
            id: agentId,
            agentType: agentType,
            parentSessionId: parentSessionId ?? "unknown",
            lastAssistantText: lastAssistantText,
            isTextTruncated: isTextTruncated,
            lastUpdated: lastUpdated ?? fileDate,
            status: status
        )
    }

    private func parseTimestamp(_ ts: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: ts) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: ts)
    }
}
