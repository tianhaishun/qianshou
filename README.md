<div align="center">

# 千手 · Qianshou

**AI driving for the iOS Simulator — describe a goal, watch it operate. On your Mac, zero setup.**

<img src="docs/demo.gif" alt="Qianshou demo" width="720">

![CI](https://github.com/tianhaishun/qianshou/actions/workflows/ci.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![macOS](https://img.shields.io/badge/macOS-14%2B-333333)

</div>

---

## What is it?

Qianshou is a native macOS cockpit for the iOS Simulator:

- **✨ AI driving** — type *"open Settings and enable dark mode"*; the agent looks at the screen (vision + element tree), decides, and operates the simulator with Claude. Pause to ask you when needed, and **insert manual instructions mid-run** anytime.
- **🖱️ Touch injection without touching your mouse** — replay and auto-click drive the simulator through XCTest inside the simulator (WebDriverAgent). Your cursor never moves.
- **🖥️ Live mirror** — ScreenCaptureKit at 60fps, zoom 1–4×, pan, crosshair with live coordinates, draggable points.
- **🎬 Record & replay** — clicks *and drags* with precise timing, persisted as JSON.
- **📦 App install** — drop in `.app` or `.ipa`, auto-launched.

Zero third-party dependencies. ~4,000 lines of Swift.

## The design

Qianshou's UI follows the **paper-typesetting tradition** (the Claude aesthetic): warm paper background, a single terracotta accent, and three type roles — serif for titles, sans for function, mono for data. Every contrast pair is computed and documented (14.7:1 body, 5.3:1 accent text, 4.9:1 buttons). Details live in [`Qianshou/Support/DesignTokens.swift`](Qianshou/Support/DesignTokens.swift).

## Quick start

Requires macOS 14+, Xcode 15+, and an iOS Simulator.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -configuration Debug build
```

**Or download** the latest release from [Releases](https://github.com/tianhaishun/qianshou/releases).

### First-run setup

1. **Start the touch-injection service** (once per simulator boot):
   ```bash
   ./Scripts/start_wda.sh
   ```
   Builds WebDriverAgent for the simulator — **no code signing needed**. The status bar shows its state.
2. **Screen Recording permission** (system prompt) for the live mirror.

No Accessibility permission needed: touch injection goes through XCTest inside the simulator, not macOS mouse events.

### AI driving setup

Add your Anthropic API key in the AI panel's settings (model: Opus 4.8 / Sonnet 5 / Fable 5). Keys stay in your local UserDefaults.

## Usage

1. **Boot a simulator** (toolbar device menu, or `xcrun simctl boot <udid>`)
2. **✨ AI driving** — hit the PILOT activity, describe your goal, let the agent operate. Interrupt anytime with a manual instruction; it pauses to ask when it needs input.
3. **Auto-click** — click on the mirrored canvas to place points (drag to fine-tune), set interval/loops, hit the single CTA.
4. **Record & replay** — switch to RECORDER, record clicks/drags on the simulator window, then replay. Sequences auto-save to `~/Library/Application Support/QianShou/sequences/`.
5. **Install apps** — toolbar device menu → 安装 App… (`.app` or `.ipa`), auto-launched.

**Keyboard-first**: `⌘1/⌘2/⌘3` switch activities, `⌘K` opens the command palette (type to filter, ↑↓ to select, ⏎ to run), `Space` starts/stops auto-click, `F8` works globally from any app.

## Architecture

```
macOS                              iOS Simulator
┌──────────────────────────┐       ┌──────────────────────┐
│  Qianshou (SwiftUI)      │       │  WebDriverAgent       │
│  · Mirror (SCK 60fps)    │  HTTP │  (XCTest runner)      │
│  · AI agent (Claude API) │──────▶│      ↓ testmanagerd   │
│  · Record/Replay         │ :8100 │  iOS touch synthesis  │
│  · Click engine          │       └──────────────────────┘
└──────────────────────────┘
```

- **Coordinates are content-relative (0–1)**, so window moves/resizes never break accuracy
- Recording listens to *your* real input; injection happens *inside the simulator* — the two never mix
- Simulator-side XCTest needs **no code signing** (unlike the real-device story)

## Development

```bash
xcodegen generate        # required after adding/removing files
xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -destination 'platform=macOS' test -only-testing:QianshouTests
```

**22 unit tests** cover coordinate math, sequence JSON, and the HTTP layer (URLProtocol stubs — including catching a missing `type:"base64"` field and a WDA XML format change). UI tests (XCUITest) are run locally — macOS headless CI can't drive SwiftUI reliably.

Debug log: `/tmp/qianshou_debug.log`

## Roadmap

- [x] AI driving (Claude vision + element tree, manual override)
- [x] Record & replay (clicks + drags, JSON persistence)
- [x] Touch injection without mouse (XCTest)
- [x] App install & launch
- [x] Command palette (⌘K)
- [ ] Element-level automation (assertions, loops)
- [ ] CLI mode (`qianshou run script.json`)

## FAQ

**Does this work with a physical iPhone?** Not yet — simulator-focused. A real-device path (WebDriverAgent signing) was prototyped and shelved.

**Why not Appium / WebDriverAgent / idb?** Those are powerful but heavyweight. Qianshou is the opposite end: native app, one script, describe-and-go.

**Why "paper" design?** The simulator cockpit is a *workspace*, not a game — warm paper, quiet borders, and data you can read at a glance.

## Contributing

PRs welcome. Keep the zero-dependency rule, match the paper-typesetting tokens, and run the unit tests. The codebase is small and readable; `DesignTokens.swift` and `Controls.swift` are where the visual language lives.

## License

[MIT](LICENSE)
