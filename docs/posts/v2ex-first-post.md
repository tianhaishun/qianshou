# V2EX 首发帖草稿（「分享创造」节点）

## 标题候选
- 千手：用一句话让 iOS 模拟器自己干活，你的鼠标从头到尾没被碰过
- 分享一个 macOS 原生工具：给 iOS 模拟器装上「AI 方向盘 + 脚本引擎」

## 正文

做 iOS 开发/测试的 V 友们，模拟器的自动化是不是一直很别扭？

现有方案要么重（一套服务 + 驱动 + SDK 配置半小时起步），要么只能点固定坐标（屏幕一换就废）。

我做了一个 macOS 原生的小工具 **千手 (Qianshou)** —— 4,000 行、零第三方依赖，两条路驱动模拟器：

**1. AI 驾驶**：直接说人话
```
「打开设置，开启深色模式」
```
它自己看屏幕（视觉 + 元素树）→ 决策 → 操作 → 直到做完或停下来问你。

**2. flow 脚本**：可复现的 YAML，带断言
```yaml
appId: com.apple.Preferences
---
- launchApp
- tapOn: "通用"
- assertVisible: "关于本机"   # 找不到就失败，适合进 CI
- swipe:
    start: 50%, 50%
    end: 50%, 10%
```

### 为什么它有点不一样
- **你的鼠标从未被碰过**：所有点击/滑动都通过模拟器内部的 XCTest 注入（WDA），不是控制你的光标 —— 你可以一边跑自动化一边干别的
- **元素定位不是坐标**：`tapOn: "通用"` 找的是屏幕上真的叫「通用」的按钮，换机型换分辨率不用改脚本
- **AI 零配置**：自动读你本机的 Claude Code 配置（`~/.claude/settings.json`）或 `ANTHROPIC_API_KEY`，不用单独填
- **原生 macOS + 纸页设计**：ScreenCaptureKit 实时镜像 60fps，界面是纸页排版风格（不是工具风）

### 30 秒跑起来
```bash
./Scripts/setup.sh   # 一键：构建 + 启动 WDA（不需要签名）
build/Debug/qianshou run examples/settings-browse.yaml
```

（演示 GIF）

### 目前的边界（诚实说）
- 只支持 iOS 模拟器（不支持真机/Android）
- AI 决策质量取决于你配的模型：Claude 官方模型最稳，DeepSeek 等兼容端点也能跑

GitHub: https://github.com/tianhaishun/qianshou （欢迎 star / issue / 提需求）

—— 做这个工具是因为我想要一个「跑模拟器自动化」时不被重工具绑架的选项。如果你也被重型自动化工具折磨过，欢迎来试试。

## 发布计划
- 节点：分享创造
- 时间：README 与 GitHub 全部就绪后（建议本周五/六晚上发，中文社区活跃时段）
- 配套：帖子附 flow-demo.gif；回复中准备 1-2 条 FAQ（不碰鼠标原理 / AI 配置方式）
