# V2EX 首发帖草稿（「分享创造」节点）

## 标题（最终版，≤ 30 字）
> 说人话就能让 iOS 模拟器自己干活：AI 驾驶 + YAML 脚本（开源）

## 正文

写 UI 测试、录演示、或者要在模拟器里反复点同一套流程的 V 友，应该都懂这种别扭：

现有的自动化要么重（服务 + 驱动 + SDK 全家桶，配置半小时起步），要么脆（录好固定坐标，换个机型全废）。

我做了一个 macOS 原生小工具 **千手 (Qianshou)** —— 约 4,000 行（能全部读完）、零第三方依赖。两条路驱动模拟器：

**1. AI 驾驶 —— 说人话**
```
「打开设置，开启深色模式」
```
它自己看屏幕（视觉 + 元素树）→ 决策 → 操作 → 做完，或停下来问你。

**2. flow 脚本 —— YAML 就是自动化本身**
```yaml
appId: com.apple.Preferences
---
- launchApp
- tapOn: "通用"
- assertVisible: "关于本机"   # 找不到就失败，能进 CI
- swipe:
    start: 50%, 50%
    end: 50%, 10%
```

上面这段，就是完整的一段自动化。没有框架，没有配置文件，没有「入门教程」。

![flow 演示：7 条命令自动完成 设置→通用→关于本机](https://raw.githubusercontent.com/tianhaishun/qianshou/main/docs/flow-demo.gif)

### 为什么它有点不一样
- **你的鼠标从未被碰过**：所有点击/滑动走模拟器内部的 XCTest 注入（WebDriverAgent），不控制你的光标 —— 跑自动化的时候你可以继续干别的
- **元素定位，不是坐标**：`tapOn: "通用"` 找的是屏幕上真的叫「通用」的那个按钮；换机型、换分辨率，脚本不用改
- **AI 零配置**：自动读本机已有的 Claude Code 配置（`~/.claude/settings.json`）或 `ANTHROPIC_API_KEY`，装上就能用
- **原生 macOS + 纸页设计**：ScreenCaptureKit 实时镜像 60fps，界面是按纸页排版做的（不是常见的工具风）

### 30 秒跑起来
```bash
./Scripts/setup.sh                      # 一键：构建 + 启动注入服务（不需要签名）
build/Debug/qianshou run examples/settings-browse.yaml
```

### 目前的边界（诚实说）
- 只支持 iOS 模拟器（真机 / Android 暂不支持）
- AI 决策质量取决于你配的模型：Claude 官方模型最稳，DeepSeek 等兼容端点也能跑

### 接下来会做
- flow 进 CI（跑完给退出码，对接 GitHub Actions）
- AI 干完活自动导出 flow 脚本（口头描述 → 可复现测试，存下来复用）
- 更多命令：条件等待 / 断言增强 / 跨步骤变量

GitHub: https://github.com/tianhaishun/qianshou

欢迎 star —— 投的不是现在的千手，是上面这些「接下来」能成真。也欢迎 issue：提需求、提 bug、骂 UI 都行。

—— 做这个工具，是因为我想要一个不被重工具绑架的模拟器自动化。被折磨过的，来握个手。

## 发布计划
- 节点：分享创造
- 时间：建议周五/六晚（中文社区活跃时段）
- 配套：帖子正文直接贴 GIF（用 raw.githubusercontent 直链）；回复区备 2 条 FAQ（① 不碰鼠标的技术原理 ② AI 配置方式）
- 发布后：把帖子链接补进 README（「在 V2EX 讨论」），一周内跟进 issue 与回复
