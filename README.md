# 千手 (Qianshou)

macOS 原生工具：**iOS 模拟器连点 / 录制回放 / 实时镜像**。

在 MacBook 上通过镜像画面操作 iOS 模拟器 —— 点击镜像添加连点点位、录制点击序列、按时间偏移精确回放。模拟器把 macOS 鼠标事件转换为触摸事件，因此全程本地实现，无需 USB 连接、签名或任何远程协议。

## 功能

- **实时镜像**：ScreenCaptureKit 窗口捕获，60fps，支持缩放（1x-4x）与拖拽平移
- **连点**：点击镜像画面添加点位（相对坐标），配置点间隔/轮间隔/循环轮数，注入到模拟器
- **录制回放**：CGEventTap 全局监听模拟器窗口内的点击，记录坐标 + 时间偏移；序列自动保存为 JSON，可回放
- **模拟器管理**：列表/启动/关机，2s 自动刷新

## 技术要点

| 模块 | 实现 |
|---|---|
| 镜像 | `ScreenCaptureKit` SCStream 窗口捕获 → CGImage 帧 |
| 点击注入 | `CGEvent`（leftMouseDown/Up）→ 模拟器窗口内容区坐标 |
| 录制 | `CGEvent.tapCreate`(.cghidEventTap) 监听 + 内容区过滤 |
| 坐标换算 | 视图 → 帧 → 内容区相对（0-1）→ 屏幕；纯函数 `CoordinateMapper`，含缩放/平移 |
| 序列存储 | JSON → `~/Library/Application Support/QianShou/sequences/` |

关键设计：点位用**内容区相对坐标**（0-1），模拟器窗口移动/缩放后依然准确；每次注入前取最新窗口 rect。

## 构建与运行

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -configuration Debug build
open build/Debug/Qianshou.app   # 或 DerivedData 产物
```

首次运行需授权：
1. **屏幕录制**（镜像画面）
2. **辅助功能**（点击注入与录制监听）

## 使用

1. 启动模拟器（`xcrun simctl boot <udid>` 或 App 侧栏右键启动），保持窗口不被遮挡
2. 镜像区显示模拟器画面后，**点击画面添加点位**（蓝色编号圆点）
3. 配置间隔与轮数，点「开始连点」
4. 「录制」模式：开始录制 → 在模拟器窗口上操作 → 停止录制（自动保存）→ 点「回放上次录制」

## 开发

```bash
xcodegen generate          # 新增/删除文件后必须重新生成
xcodebuild ... test        # 单元测试（CoordinateMapper、序列 JSON）
```

调试日志：`/tmp/qianshou_debug.log`

## 目录结构

```
Qianshou/
├── App/          QianShouApp, AppState（全局状态）
├── Models/       SimulatorDevice, ClickPoint, ClickSequence
├── Services/     SimulatorManager, WindowLocator, MirrorCapture,
│                 CoordinateMapper, Injector, ClickEngine, Recorder, Player, SequenceStore
├── ViewModels/
├── Views/        Sidebar, Mirror（手势层+点位标记）, ControlPanel（连点/录制）
└── Support/      entitlements
Tests/            CoordinateMapperTests, ClickSequenceTests
Scripts/          bootstrap.sh（venv+pymobiledevice3，真机方案遗留）
vendor/           WebDriverAgent（真机方案遗留，当前不使用）
```

> 注：`Scripts/`、`vendor/`、pymobiledevice3 是早期「真机 + WebDriverAgent」方案的遗留物，当前模拟器方案不依赖它们，可随时清理。
