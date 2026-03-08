import Testing
@testable import ClaudeMonitor

@Suite("ProcessScanner Tests")
struct ProcessScannerTests {

    // TC-01: scan() returns results (may be empty if no claude running)
    @Test("scan returns ProcessInfo array")
    func scanReturnsArray() async {
        let scanner = ProcessScanner()
        let results = await scanner.scan()
        // Can't guarantee claude is running, just verify it doesn't crash
        #expect(results is [ProcessInfo])
    }

    // TC-02: TTY ?? excluded
    @Test("parsePs excludes TTY ??")
    func parsePsExcludesDaemon() async {
        let output = """
        1234 s004 /usr/local/bin/claude
        5678 ??   /usr/local/bin/claude
        9012 s005 /usr/local/bin/node
        """
        let scanner = ProcessScanner()
        let entries = await scanner.parsePs(output: output)
        #expect(entries.count == 1)
        #expect(entries[0].pid == 1234)
        #expect(entries[0].tty == "s004")
    }

    // TC-03: Only claude processes matched
    @Test("parsePs filters claude only")
    func parsePsFiltersClaude() async {
        let output = """
        1111 s001 /usr/bin/vim
        2222 s002 /usr/local/bin/claude
        3333 s003 /usr/bin/node
        """
        let scanner = ProcessScanner()
        let entries = await scanner.parsePs(output: output)
        #expect(entries.count == 1)
        #expect(entries[0].pid == 2222)
    }

    // TC-05: Normal ps output parsing
    @Test("parsePs parses well-formed output")
    func parsePsNormal() async {
        let output = """
        12345 s004 /opt/homebrew/bin/claude
        67890 s005 /opt/homebrew/bin/claude
        """
        let scanner = ProcessScanner()
        let entries = await scanner.parsePs(output: output)
        #expect(entries.count == 2)
        #expect(entries[0].pid == 12345)
        #expect(entries[0].tty == "s004")
        #expect(entries[1].pid == 67890)
        #expect(entries[1].tty == "s005")
    }

    // TC-06: Empty output
    @Test("parsePs handles empty output")
    func parsePsEmpty() async {
        let scanner = ProcessScanner()
        let entries = await scanner.parsePs(output: "")
        #expect(entries.isEmpty)
    }

    // TC: Malformed lines skipped
    @Test("parsePs skips malformed lines")
    func parsePsMalformed() async {
        let output = """
        notanumber s004 claude
        1234

        5678 s005 /usr/local/bin/claude
        """
        let scanner = ProcessScanner()
        let entries = await scanner.parsePs(output: output)
        #expect(entries.count == 1)
        #expect(entries[0].pid == 5678)
    }
}
