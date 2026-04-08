# Bob Usage

A lightweight macOS menubar app that displays your Bob-Shell usage statistics at a glance.

## Features

- 🔄 **Auto-refresh** every 2 minutes
- 🚦 **Color-coded status** - Green (<50 msgs), Yellow (50-100), Red (>100)
- 📊 **Today, Week, and All-Time stats** displayed together
- 📝 **Recent sessions** with message counts
- 🪶 **Lightweight** - Native Swift, minimal resources
- 🔒 **Privacy-first** - Reads local files only, no network calls

## Installation

### Build from Source

#### Option 1: Xcode GUI
```bash
cd /Users/cdunlap/git/claudecodeusage
open BobUsage.xcodeproj
```
Then build with ⌘B and run with ⌘R.

#### Option 2: Command Line

Build with ad-hoc signing (no developer certificate needed):

```bash
cd /Users/cdunlap/git/claudecodeusage

xcodebuild \
  -project BobUsage.xcodeproj \
  -scheme BobUsage \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Then launch the built app:
```bash
open ~/Library/Developer/Xcode/DerivedData/BobUsage-*/Build/Products/Debug/BobUsage.app
```

#### Troubleshooting xcodebuild

If you see `xcodebuild failed to load a required plug-in`, run this once:
```bash
xcodebuild -runFirstLaunch
```

## Requirements

- macOS 13.0 (Ventura) or later
- Bob-Shell installed and configured

## How It Works

Bob Usage reads session logs from `~/.bob/tmp/*/logs.json` files to calculate usage statistics:

- **Today's Activity**: Messages and sessions from today
- **This Week**: Messages and sessions from the last 7 days
- **All Time**: Total messages and sessions across all history
- **Recent Sessions**: Shows the 5 most recent sessions with message counts

### Data Structure

Bob-Shell stores session data in JSON format:
```json
[
  {
    "sessionId": "uuid",
    "messageId": 0,
    "type": "user",
    "message": "your message",
    "timestamp": "2026-03-18T16:58:38.861Z"
  }
]
```

The app aggregates this data to provide meaningful statistics without any network calls or external dependencies.

## Status Colors

| Normal | Warning | Critical |
|--------|---------|----------|
| 🟢 <50 msgs | 🟡 50-100 msgs | 🔴 >100 msgs |

## Privacy

- Your data never leaves your machine
- No analytics or telemetry
- No network calls whatsoever
- Reads only from `~/.bob/tmp/` directory
- Open source - verify the code yourself

## Troubleshooting

### App doesn't appear in menubar

Check if the app is running in Activity Monitor. Try quitting and reopening.

### No data showing

Ensure Bob-Shell has been used and has created session logs in `~/.bob/tmp/`. The app needs at least one session with logs to display statistics.

### Stats seem incorrect

Click the refresh button (↻) in the dropdown to reload data from disk.

## Project Structure

```
BobUsage/
├── BobUsageApp.swift       # Main app and menubar setup
├── BobUsageManager.swift   # Data loading and statistics
├── BobUsageView.swift      # SwiftUI interface
├── BobUsage.entitlements   # Sandbox permissions
└── Assets.xcassets/        # App icon
```

## Comparison with Claude Usage

| Feature | Claude Usage | Bob Usage |
|---------|-------------|-----------|
| Data Source | Anthropic API | Local logs |
| Authentication | OAuth/Keychain | None needed |
| Network | Required | Not required |
| Metrics | API limits | Message counts |
| Refresh | 5 minutes | 2 minutes |

## Contributing

PRs welcome! This is a companion tool to the existing ClaudeUsage app.

## License

MIT License - do whatever you want with it.

## Disclaimer

This is an unofficial tool for monitoring Bob-Shell usage. It reads local session logs and does not interact with any IBM services.

---

Built as a companion to [ClaudeUsage](https://github.com/richhickson/claude-usage) by [@richhickson](https://x.com/richhickson)
