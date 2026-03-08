import Foundation
import Darwin

actor ProcessScanner {
    private var cwdCache: [Int: String] = [:]

    func scan() async -> [ProcessInfo] {
        let output = runPs()
        let entries = parsePs(output: output)
        var results: [ProcessInfo] = []
        var alivePids: Set<Int> = []

        for entry in entries {
            alivePids.insert(entry.pid)
            let cwd = getCwd(pid: entry.pid)
            results.append(ProcessInfo(pid: entry.pid, tty: entry.tty, cwd: cwd))
        }

        invalidateCache(alivePids: alivePids)
        return results
    }

    struct PsEntry: Sendable {
        let pid: Int
        let tty: String
        let comm: String
    }

    func parsePs(output: String) -> [PsEntry] {
        var entries: [PsEntry] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let tokens = trimmed.split(separator: " ", maxSplits: 2)
            guard tokens.count >= 3 else { continue }

            guard let pid = Int(tokens[0]) else { continue }
            let tty = String(tokens[1])
            let comm = String(tokens[2])

            guard tty != "??" else { continue }
            guard comm.contains("claude") else { continue }

            entries.append(PsEntry(pid: pid, tty: tty, comm: comm))
        }
        return entries
    }

    private func runPs() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-ax", "-o", "pid=,tty=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func getCwd(pid: Int) -> String? {
        if let cached = cwdCache[pid] { return cached }

        let cwd = procPidCwd(pid: pid) ?? lsofFallback(pid: pid)
        if let cwd { cwdCache[pid] = cwd }
        return cwd
    }

    private func procPidCwd(pid: Int) -> String? {
        let pathInfoSize = MemoryLayout<proc_vnodepathinfo>.size
        let pathInfo = UnsafeMutablePointer<proc_vnodepathinfo>.allocate(capacity: 1)
        defer { pathInfo.deallocate() }

        let result = proc_pidinfo(
            Int32(pid),
            PROC_PIDVNODEPATHINFO,
            0,
            pathInfo,
            Int32(pathInfoSize)
        )
        guard result == Int32(pathInfoSize) else { return nil }

        return withUnsafePointer(to: &pathInfo.pointee.pvi_cdir.vip_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cstr in
                let path = String(cString: cstr)
                return path.isEmpty ? nil : path
            }
        }
    }

    private func lsofFallback(pid: Int) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-p", "\(pid)", "-a", "-d", "cwd", "-F", "n"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.split(separator: "\n") {
            if line.hasPrefix("n/") {
                return String(line.dropFirst(1))
            }
        }
        return nil
    }

    private func invalidateCache(alivePids: Set<Int>) {
        cwdCache = cwdCache.filter { alivePids.contains($0.key) }
    }
}
