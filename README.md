<div align="center">

# 千手 · Qianshou

**Drive your iOS Simulator from a live mirror — auto-click, record, and replay operations on your Mac, with zero setup.**

<img src="docs/demo.gif" alt="Qianshou demo" width="720">

![CI](https://github.com/tianhaishun/qianshou/actions/workflows/ci.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## Why Qianshou?

The iOS Simulator turns macOS mouse events into touch events. Qianshou exploits this: **click injection is just a `CGEvent`** — no USB pairing, no code signing, no WebDriverAgent, no remote protocols. A native macOS app, zero third-party dependencies, ~1,700 lines of Swift.

- **Live mirror** — ScreenCaptureKit window capture at 60fps, zoom 1–4×, drag to pan
- **AI driving** — describe a goal in plain language ("open Settings and enable dark mode"); the agent looks at the screen, decides, and operates the simulator with Claude (vision + element tree). Interrupt it anytime with a manual instruction mid-run
- **Auto-click** — click on the mirrored screen to place points, configure interval/loops, inject touches via XCTest
- **Record & replay** — a global event tap records your clicks *and drags* with precise timing; sequences persist as JSON and replay exactly as recorded
- **Touch injection without touching your mouse** — replay drives the simulator through WebDriverAgent running inside the simulator (XCTest-level touch synthesis), so your cursor never moves
- **Simulator management** — list, boot, shutdown, install `.app`/`.ipa` from the toolbar menu, 2s auto-refresh

## Quick start

Requires macOS 14+, Xcode 15+ (for building), and an iOS Simulator.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -configuration Debug build
open build/Debug/Qianshou.app   # or the DerivedData product
```

**Or download the latest release** from [Releases](https://github.com/tianhaishun/qianshou/releases) (coming soon).

### First-run setup

1. **Start the touch-injection service** (once per simulator boot):
   ```bash
   ./Scripts/start_wda.sh
   ```
   Builds WebDriverAgent for the simulator (no code signing needed) and keeps it running on `localhost:8100`. The toolbar shows its status — tap to re-check.
2. **Screen Recording permission** (system prompt) for the live mirror.

No Accessibility permission needed: touch injection goes through XCTest inside the simulator, not macOS mouse events.

## Usage

1. **Boot a simulator** (toolbar device menu, or `xcrun simctl boot <udid>`) and keep its window visible
2. **AI driving** — hit the ✨ AI 驾驶 button, enter your goal, and let the agent operate the simulator. It pauses to ask when it needs input (e.g. credentials); you can also insert manual instructions mid-run
3. **Place points** — click on the mirrored screen; numbered markers appear
4. **Auto-click** — set per-point interval, per-round interval, and round count, then hit **开始连点**
5. **Record & replay** — switch to 录制 mode, record clicks/drags on the simulator window, stop, then hit **回放**. Sequences are auto-saved to `~/Library/Application Support/QianShou/sequences/`
6. **Install apps** — toolbar device menu → 安装 App… (`.app` or `.ipa`), auto-launched after install

### AI driving setup

Add your Anthropic API key in ⚙ → AI 驾驶 (model: Opus 4.8 / Sonnet 5 / Fable 5). Keys are stored in UserDefaults on your machine only.

### Global hotkey

Toggle **F8** in the toolbar to start/stop auto-clicking from any app.

## Design notes

- **Coordinates are content-area-relative (0–1)**, so points stay accurate when you move or resize the simulator window; the window rect is re-fetched every second while mirroring and re-calibrated per frame (Retina scale auto-detected)
- The coordinate pipeline (view → frame → content → screen) is pure functions in `CoordinateMapper` with unit tests, including zoom/pan
- Mirroring, injection, and recording each stop gracefully when the simulator window leaves the screen — no blind clicks into other apps

## Development

```bash
xcodegen generate        # required after adding/removing files
xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -destination 'platform=macOS' test
```

Debug log: `/tmp/qianshou_debug.log`

## Roadmap

- [x] Auto-click engine
- [x] Record & replay (clicks + drags, JSON persistence)
- [x] Zoom / pan mirror
- [x] Global hotkey (F8)
- [ ] Sequence editor (drag points, edit timing)
- [ ] Command-line mode (`qianshou run sequence.json`)
- [ ] Recording screen recording of sessions

## FAQ

**Does this work with a physical iPhone?** Not yet — the current focus is the Simulator. A real-device path (WebDriverAgent-based) was prototyped and intentionally shelved; see `git log` for the story.

**Why not Appium / WebDriverAgent / idb?** Those are powerful but heavyweight: install agents, code signing, test runners. Qianshou is the opposite end: install, run, click. It's for the 90% of cases where you just need repeatable taps.

**Is the window occlusion a problem?** During auto-click the simulator window must stay visible (keep it frontmost). If the window leaves the screen, clicking stops automatically.

## Contributing

PRs welcome. Small codebase (~1,700 lines), pure functions for the hard parts, and a debug log that writes to `/tmp/qianshou_debug.log`. Please keep the zero-dependency rule.

## License

[MIT](LICENSE)
