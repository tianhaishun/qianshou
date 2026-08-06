import SwiftUI

/// 控制面板：连点模式（点位+配置+启停）与录制模式（录制/回放/序列）
struct ControlPanelView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: PanelMode = .clicker

    enum PanelMode: String, CaseIterable {
        case clicker = "连点"
        case recorder = "录制"
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Picker("模式", selection: $mode) {
                ForEach(PanelMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .padding(.top, 8)

            HStack(alignment: .top, spacing: 16) {
                switch mode {
                case .clicker:
                    pointList
                    Divider().frame(height: nil)
                    configPanel
                    Divider().frame(height: nil)
                    clickControls
                case .recorder:
                    sequenceList
                    Divider().frame(height: nil)
                    recorderControls
                }
            }
            .padding(10)
        }
        .frame(height: 190)
        .background(.bar)
        .onAppear {
            appState.loadSequences()
        }
    }

    // MARK: - 连点模式

    private var pointList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("点位（\(appState.clickPoints.count)）")
                    .font(.headline)
                Spacer()
                Button("清空") { appState.clearClickPoints() }
                    .disabled(appState.clickEngine.isRunning)
            }
            if appState.clickPoints.isEmpty {
                Text("点击右侧镜像画面添加点位")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(appState.clickPoints.enumerated()), id: \.element.id) { index, point in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(point.label)
                            Spacer()
                            Text("(\(String(format: "%.2f", point.x)), \(String(format: "%.2f", point.y)))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .background(appState.clickEngine.currentPointIndex == index ? Color.accentColor.opacity(0.15) : .clear)
                    }
                    .onDelete { offsets in
                        appState.removeClickPoint(at: offsets)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 260)
    }

    private var configPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("配置")
                .font(.headline)

            HStack {
                Text("点间隔")
                Slider(value: $appState.clickIntervalMs, in: 50...5000, step: 50)
                Text("\(Int(appState.clickIntervalMs)) ms")
                    .font(.caption.monospacedDigit())
                    .frame(width: 60, alignment: .trailing)
            }

            HStack {
                Text("轮间隔")
                Slider(value: $appState.clickLoopIntervalMs, in: 0...5000, step: 100)
                Text("\(Int(appState.clickLoopIntervalMs)) ms")
                    .font(.caption.monospacedDigit())
                    .frame(width: 60, alignment: .trailing)
            }

            HStack {
                Text("循环轮数")
                Stepper(value: $appState.clickLoops, in: 1...999) {
                    Text(appState.clickLoops >= 999 ? "无限" : "\(appState.clickLoops)")
                        .font(.caption.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .frame(width: 240)
    }

    private var clickControls: some View {
        VStack(spacing: 8) {
            if appState.clickEngine.isRunning {
                Button {
                    appState.stopClicking()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Text("第 \(appState.clickEngine.currentLoop)/\(appState.clickEngine.totalLoops) 轮")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    appState.startClicking()
                } label: {
                    Label("开始连点", systemImage: "play.fill")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(appState.clickPoints.isEmpty || appState.player.isPlaying || appState.recorder.isRecording)

                Text(appState.clickPoints.isEmpty ? "先添加点位" : "共 \(appState.clickPoints.count) 点 × \(appState.clickLoops >= 999 ? "无限" : "\(appState.clickLoops)") 轮")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("连点前请保持模拟器窗口不被遮挡")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 录制模式

    private var sequenceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("已保存序列")
                .font(.headline)
            if appState.savedSequences.isEmpty {
                Text("录制后自动保存到这里")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.savedSequences, id: \.self) { seq in
                        HStack {
                            Text(seq.name)
                                .lineLimit(1)
                            Spacer()
                            Text("\(seq.points.count) 点 · \(seq.durationMs / 1000) s")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button {
                                appState.playSequence(seq)
                            } label: {
                                Image(systemName: "play.fill")
                            }
                            .buttonStyle(.borderless)
                            .disabled(appState.player.isPlaying || appState.clickEngine.isRunning)
                            .help("回放此序列")
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { appState.savedSequences[$0] }
                            .forEach { appState.deleteSequence($0) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 280)
    }

    private var recorderControls: some View {
        VStack(spacing: 8) {
            if appState.recorder.isRecording {
                Button {
                    appState.stopRecording()
                } label: {
                    Label("停止录制", systemImage: "stop.fill")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Text("已录 \(appState.recorder.recordedCount) 次点击")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    appState.startRecording()
                } label: {
                    Label("开始录制", systemImage: "record.circle")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(appState.player.isPlaying)
            }

            if let last = appState.lastRecordedSequence ?? appState.savedSequences.first {
                Text("上次录制：\(last.points.count) 点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    appState.playSequence(last)
                } label: {
                    Label("回放上次录制", systemImage: "play.fill")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .disabled(appState.player.isPlaying || appState.clickEngine.isRunning)
            }

            if appState.player.isPlaying {
                Button {
                    appState.player.stop()
                } label: {
                    Label("停止回放", systemImage: "stop.fill")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Spacer()

            Text("录制时请在模拟器窗口上操作\n点击列表中的序列即可回放")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
