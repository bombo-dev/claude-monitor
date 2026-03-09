# Claude Monitor

A lightweight macOS menu bar app that monitors active [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI sessions in real time.

## Features

- **Menu Bar Integration** — Lives in your menu bar with a status indicator; click to see all active sessions
- **Session Tracking** — Automatically detects running Claude Code processes and displays project name, git branch, and last assistant response
- **Subagent Monitoring** — Shows active subagents spawned by Claude Code with their current status
- **Status Notifications** — Sends macOS notifications when sessions complete or encounter errors
- **Idle Detection** — Identifies sessions that haven't been updated for 5+ minutes
- **Multi-Session Support** — Track multiple Claude Code sessions running across different projects simultaneously

## How It Works

Claude Monitor reads data from two sources:

1. **Process Scanner** — Polls running processes every 10 seconds to detect active `claude` CLI instances and their working directories
2. **Session File Reader** — Reads JSONL session files from `~/.claude/projects/` every 30 seconds to extract git branch, assistant responses, and error states

No network requests are made. All data is read locally from the filesystem.

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (arm64)
- Claude Code CLI installed and used at least once (so `~/.claude/projects/` exists)

## Installation

### Download (Recommended)

1. Download `ClaudeMonitor-arm64.zip` from [Releases](https://github.com/bombo-dev/claude-monitor/releases)
2. Unzip the file
3. Move `ClaudeMonitor.app` to your Applications folder
4. On first launch, right-click the app and select **Open** (required because the app is not notarized)

### Build from Source

```bash
cd ClaudeMonitor
swift build -c release
bash scripts/bundle.sh
open .build/ClaudeMonitor.app
```

## Architecture

```
ClaudeMonitor/Sources/ClaudeMonitor/
├── App/                  # App entry point, AppDelegate
├── Domain/
│   ├── Models/           # SessionInfo, SubagentInfo, SessionStatus
│   ├── SessionStateManager.swift  # Core state machine (Actor)
│   └── SessionStore.swift         # Observable store for SwiftUI
├── Infrastructure/
│   ├── ProcessScanner.swift       # Detects running Claude processes
│   ├── SessionFileReader.swift    # Parses JSONL session files
│   ├── SubagentFileReader.swift   # Parses subagent JSONL files
│   ├── PathEncoder.swift          # Encodes paths to match Claude CLI format
│   └── NotificationService.swift  # macOS notification delivery
└── Presentation/
    ├── MenuBarController.swift    # Menu bar icon and popover
    ├── SessionTreeView.swift      # Session list with subagent tree
    ├── DetailPanelView.swift      # Session detail panel
    └── MainWindowView.swift       # Standalone window view
```

## Session Lifecycle

```
[Process Detected] → Running → Idle (after 5 min)
                        ↓            ↓
                   [Process Ends] [Process Ends]
                        ↓            ↓
                   Completed      Completed
                   (removed 30s)  (removed 30s)
```

If the session file contains an error state:
```
[Process Ends] → Error (removed 60s)
```

## Tech Stack

- **Language**: Swift 6
- **UI**: SwiftUI + AppKit (menu bar integration)
- **Concurrency**: Swift Actors for thread-safe state management
- **Testing**: Swift Testing framework
- **Build**: Swift Package Manager

## License

MIT
