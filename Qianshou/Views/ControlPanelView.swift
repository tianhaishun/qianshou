import SwiftUI

/// 控制面板：连点模式（点位/配置/控制三卡）与录制模式（序列/录制控制/回放三卡）
struct ControlPanelView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: PanelMode = .clicker

    enum PanelMode: String, CaseIterable {
        case clicker = "连点"
        case recorder = "录制"
    }

    var body: some View {
        VStack(spacing: 10) {
            modePicker
            HStack(alignment: .top, spacing: 10) {
                switch mode {
                case .clicker:
                    pointCard
                    configCard
                    clickControlCard
                case .recorder:
                    sequenceCard
                    recordControlCard
                    replayCard
                }
            }
        }
        .padding(12)
        .background(DesignTokens.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                .stroke(DesignTokens.borderCard, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
        .onAppear {
            appState.loadSequences()
        }
    }

    // MARK: - 模式切换（matchedGeometryEffect 滑动指示）

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(PanelMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(duration: 0.22, bounce: 0.2)) {
                        mode = m
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m == .clicker ? "cursorarrow.click.2" : "record.circle")
                        Text(m.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(mode == m ? .white : DesignTokens.textSecondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            if mode == m {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(DesignTokens.brandGradient)
                                    .matchedGeometryEffect(id: "mode", in: namespace)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(DesignTokens.bgSunken))
    }

    @Namespace private var namespace

    // MARK: - 卡片容器

    private func cardHeader(_ systemImage: String, _ title: String, count: Int? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.brandBright)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(DesignTokens.brandGradient))
            }
            Spacer()
        }
        .padding(.bottom, 6)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.bgSunken)
        )
    }

    // MARK: - 连点模式：点位卡

    private var pointCard: some View {
        card {
            cardHeader("mappin.circle.fill", "点位", count: appState.clickPoints.count)
            if appState.clickPoints.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text("点击右侧画面放置点位")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.textSecondary)
                    Text("F8 开始连点")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(Array(appState.clickPoints.enumerated()), id: \.element.id) { index, point in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(DesignTokens.brandGradient))
                            Text("\(String(format: "%.2f", point.x)) · \(String(format: "%.2f", point.y))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DesignTokens.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .background(appState.clickEngine.currentPointIndex == index
                                    ? DesignTokens.brandTint : .clear)
                    }
                    .onDelete { offsets in
                        appState.removeClickPoint(at: offsets)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90)
            }
            Button("清空点位") {
                appState.clearClickPoints()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(appState.clickPoints.isEmpty || appState.clickEngine.isRunning)
        }
        .frame(minWidth: 210)
    }

    // MARK: - 连点模式：配置卡

    private var configCard: some View {
        card {
            cardHeader("slider.horizontal.3", "配置")
            VStack(spacing: 8) {
                configRow(label: "点间隔",
                          value: "\(Int(appState.clickIntervalMs))ms",
                          slider: $appState.clickIntervalMs, range: 50...5000, step: 50)
                configRow(label: "轮间隔",
                          value: "\(Int(appState.clickLoopIntervalMs))ms",
                          slider: $appState.clickLoopIntervalMs, range: 0...5000, step: 100)
                HStack {
                    Text("循环轮数")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                    Stepper(value: $appState.clickLoops, in: 1...999) {
                        Text(appState.clickLoops >= 999 ? "∞" : "\(appState.clickLoops)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(DesignTokens.textPrimary)
                            .frame(width: 30, alignment: .trailing)
                            .contentTransition(.numericText())
                    }
                    .controlSize(.small)
                }
            }
            Spacer()
        }
        .frame(minWidth: 200)
    }

    private func configRow(label: String, value: String, slider: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .contentTransition(.numericText())
            }
            Slider(value: slider, in: range, step: step)
                .tint(DesignTokens.brandBright)
                .controlSize(.small)
        }
    }

    // MARK: - 连点模式：控制卡

    private var clickControlCard: some View {
        card {
            cardHeader("play.circle.fill", "控制")
            Spacer()
            if appState.clickEngine.isRunning {
                Button {
                    appState.stopClicking()
                } label: {
                    Label("停止连点", systemImage: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.err)
                Text("第 \(appState.clickEngine.currentLoop)/\(appState.clickEngine.totalLoops) 轮")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    appState.startClicking()
                } label: {
                    Label("开始连点", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(GradientButtonStyle())
                .disabled(appState.clickPoints.isEmpty
                          || appState.player.isPlaying
                          || appState.recorder.isRecording)
                Text(appState.clickPoints.isEmpty ? "先点击画面添加点位" : "共 \(appState.clickPoints.count) 点 × \(appState.clickLoops >= 999 ? "无限" : "\(appState.clickLoops)") 轮")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            Spacer()
            Text("F8 全局启停 · 保持模拟器窗口可见")
                .font(.system(size: 9))
                .foregroundStyle(DesignTokens.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 170)
    }

    // MARK: - 录制模式：序列卡

    private var sequenceCard: some View {
        card {
            cardHeader("list.bullet.rectangle", "序列", count: appState.savedSequences.count)
            if appState.savedSequences.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text("还没有录制序列")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.textSecondary)
                    Text("录制后自动保存为 JSON")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(appState.savedSequences, id: \.self) { seq in
                        HStack(spacing: 6) {
                            Button {
                                appState.playSequence(seq)
                            } label: {
                                Image(systemName: appState.player.isPlaying ? "arrow.triangle.2.circlepath" : "play.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(appState.player.isPlaying ? DesignTokens.err : DesignTokens.brandBright)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(DesignTokens.brandTint))
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.player.isPlaying || appState.clickEngine.isRunning)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(seq.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(DesignTokens.textPrimary)
                                    .lineLimit(1)
                                Text("\(String(format: "%.1f", Double(seq.durationMs) / 1000))s · \(seq.points.count) 点")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        offsets.map { appState.savedSequences[$0] }
                            .forEach { appState.deleteSequence($0) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90)
            }
            Button("删除全部") {
                appState.savedSequences.forEach { appState.deleteSequence($0) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(appState.savedSequences.isEmpty)
        }
        .frame(minWidth: 220)
    }

    // MARK: - 录制模式：录制控制卡

    private var recordControlCard: some View {
        card {
            cardHeader("record.circle", "录制")
            Spacer()
            if appState.recorder.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(DesignTokens.record)
                        .frame(width: 7, height: 7)
                        .shadow(color: DesignTokens.record.opacity(0.7), radius: 3)
                    Text("录制中 · \(appState.recorder.recordedCount) 次")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DesignTokens.textPrimary)
                }
                .frame(maxWidth: .infinity)
                Button {
                    appState.stopRecording()
                } label: {
                    Label("停止录制", systemImage: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.record)
            } else {
                Button {
                    appState.startRecording()
                } label: {
                    Label("开始录制", systemImage: "record.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.brandBright)
                .disabled(appState.player.isPlaying)
                Text("捕获点击与拖拽")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            Spacer()
            Text("录制时在模拟器窗口上操作")
                .font(.system(size: 9))
                .foregroundStyle(DesignTokens.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 170)
    }

    // MARK: - 录制模式：回放卡

    private var replayCard: some View {
        card {
            cardHeader("arrow.counterclockwise", "回放")
            Spacer()
            if let last = appState.lastRecordedSequence ?? appState.savedSequences.first {
                Button {
                    appState.playSequence(last)
                } label: {
                    Label("回放上次录制", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(GradientButtonStyle())
                .disabled(appState.player.isPlaying || appState.clickEngine.isRunning)
                Text("\(last.points.count) 点 · \(String(format: "%.1f", Double(last.durationMs) / 1000))s")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    appState.playSequence(appState.savedSequences[0])
                } label: {
                    Label("回放上次录制", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(GradientButtonStyle())
                .disabled(true)
                Text("暂无序列")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            Spacer()
            Button {
                if let dir = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                          in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("QianShou/sequences", isDirectory: true) {
                    NSWorkspace.shared.open(dir)
                }
            } label: {
                Label("打开序列文件夹", systemImage: "folder")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 170)
    }
}

/// 主按钮样式：品牌渐变填充 + 发光阴影 + 按下缩放
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.brandGradient)
                    .shadow(color: DesignTokens.brandGlow, radius: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
