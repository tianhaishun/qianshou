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
- **Auto-click** — click on the mirrored screen to place points, configure interval/loops, inject clicks into the simulator
- **Record & replay** — a global event tap records your clicks *and drags* with precise timing; sequences persist as JSON and replay exactly as recorded
- **Simulator management** — list, boot, shutdown from the sidebar, 2s auto-refresh

## Quick start

Requires macOS 14+, Xcode 15+ (for building), and an iOS Simulator.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -configuration Debug build
open build/Debug/Qianshou.app   # or the DerivedData product
```

**Or download the latest release** from [Releases](https://github.com/tianhaishun/qianshou/releases) (coming soon).

### First-run permissions

Two system permissions are needed (shown live in the sidebar):

| Permission | Purpose |
|---|---|
| **Screen Recording** | capture the simulator window for the mirror |
| **Accessibility** | inject clicks and listen for recording |

## Usage

1. **Boot a simulator** (right-click a device in the sidebar → 启动, or `xcrun simctl boot <udid>`) and keep its window visible
2. **Place points** — click on the mirrored screen; numbered markers appear (blue circle, red while being clicked)
3. **Auto-click** — set per-point interval, per-round interval, and round count, then hit **开始连点**
4. **Record & replay** — switch to 录制 mode, record your clicks/drags on the simulator window, stop, then hit **回放上次录制**. Sequences are auto-saved to `~/Library/Application Support/QianShou/sequences/` and survive restarts

### Global hotkey

Toggle **F8 启停连点** in the sidebar to start/stop auto-clicking from any app (requires Accessibility).

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
