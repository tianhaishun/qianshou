import SwiftUI

/// 序列编辑器 —— 时序/循环/动作管理
///
/// 能力：改名、循环轮数、动作列表（增删/调 offset/类型）、保存
struct SequenceEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var sequence: ClickSequence
    @State private var name: String
    @State private var loops: Int

    init(sequence: ClickSequence) {
        _sequence = State(initialValue: sequence)
        _name = State(initialValue: sequence.name)
        _loops = State(initialValue: sequence.loops)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(DesignTokens.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    metaSection
                    Divider().overlay(DesignTokens.border)
                    actionsSection
                }
                .padding(14)
            }

            Divider().overlay(DesignTokens.border)
            footer
        }
        .frame(width: 400, height: 480)
        .background(DesignTokens.bgBase)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.accentText)
            Text("序列编辑")
                .font(DesignTokens.ui(13, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(DesignTokens.bgCardRaised))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
        .padding(12)
    }

    // MARK: - 元信息

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Controls.EditorialSection(title: "元信息", note: "META", count: nil)
            TextField("序列名称", text: $name)
                .textFieldStyle(.plain)
                .font(DesignTokens.ui(12, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: DesignTokens.radiusControl).fill(DesignTokens.bgCardRaised))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.radiusControl).stroke(DesignTokens.border, lineWidth: 1))

            HStack {
                Text("循环轮数")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Stepper(value: $loops, in: 1...999) {
                    Text(loops >= 999 ? "∞" : "\(loops)")
                        .font(DesignTokens.mono(12, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .frame(width: 32, alignment: .trailing)
                }
                .controlSize(.small)
            }

            Text("总时长 \(String(format: "%.1f", Double(sequence.durationMs * max(loops, 1)) / 1000))s")
                .font(DesignTokens.mono(10))
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }

    // MARK: - 动作列表

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Controls.EditorialSection(title: "动作", note: "ACTIONS", count: sequence.points.count)

            if sequence.points.isEmpty {
                Text("无动作 —— 点击「添加」或重新录制")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(sequence.points.enumerated()), id: \.offset) { index, point in
                    actionRow(point, index: index)
                }
            }

            HStack(spacing: 6) {
                Button {
                    addAction(kind: .click)
                } label: {
                    Label("添加点击", systemImage: "plus")
                        .font(DesignTokens.ui(11, weight: .medium))
                }
                .buttonStyle(Controls.SecondaryButtonStyle())

                Button {
                    addAction(kind: .drag)
                } label: {
                    Label("添加拖动", systemImage: "plus")
                        .font(DesignTokens.ui(11, weight: .medium))
                }
                .buttonStyle(Controls.SecondaryButtonStyle())
            }
        }
    }

    private func actionRow(_ point: SequencePoint, index: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: point.kind == .click ? "circle" : "arrow.up.and.down")
                .font(.system(size: 9))
                .foregroundStyle(point.kind == .click ? DesignTokens.accentText : DesignTokens.textSecondary)
                .frame(width: 14)

            Text(point.kind == .click
                 ? "点 (\(String(format: "%.2f", point.x)), \(String(format: "%.2f", point.y)))"
                 : "拖 (\(String(format: "%.2f", point.x)),\(String(format: "%.2f", point.y)))→(\(String(format: "%.2f", point.endX ?? point.x)),\(String(format: "%.2f", point.endY ?? point.y)))")
                .font(DesignTokens.mono(9))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)

            if point.kind == .click, let label = point.elementLabel, !label.isEmpty {
                Image(systemName: "scope")
                    .font(.system(size: 8))
                    .foregroundStyle(DesignTokens.accentText)
                    .help("元素定位:\(label)（回放优先按元素点）")
                Text("\(label)")
                    .font(DesignTokens.mono(8))
                    .foregroundStyle(DesignTokens.accentText)
                    .lineLimit(1)
            }

            Spacer()

            // 时序调整
            HStack(spacing: 2) {
                Button {
                    adjustOffset(index, delta: -100)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("提前 100ms")

                Text("\(point.offsetMs)ms")
                    .font(DesignTokens.mono(9))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .frame(width: 48, alignment: .trailing)

                Button {
                    adjustOffset(index, delta: 100)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("延后 100ms")
            }

            Button {
                removeAction(index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除动作 \(index + 1)")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                .fill(DesignTokens.bgCardRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }

    private func addAction(kind: SequencePoint.Kind) {
        let base = sequence.points.map(\.offsetMs).max() ?? 0
        var point = SequencePoint(kind: kind, x: 0.5, y: 0.5, offsetMs: base + 1000)
        if kind == .drag {
            point = SequencePoint(kind: .drag, x: 0.3, y: 0.6, offsetMs: base + 1000,
                                  endX: 0.3, endY: 0.4, durationMs: 400)
        }
        sequence.points.append(point)
    }

    private func removeAction(_ index: Int) {
        guard sequence.points.indices.contains(index) else { return }
        sequence.points.remove(at: index)
    }

    private func adjustOffset(_ index: Int, delta: Int) {
        guard sequence.points.indices.contains(index) else { return }
        sequence.points[index].offsetMs = max(0, sequence.points[index].offsetMs + delta)
    }

    // MARK: - 底部

    private var footer: some View {
        HStack(spacing: 8) {
            Button("取消") {
                dismiss()
            }
            .buttonStyle(Controls.SecondaryButtonStyle())

            Spacer()

            Button {
                var updated = sequence
                updated.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? sequence.name : name
                updated.loops = max(loops, 1)
                appState.updateSequence(updated)
                dismiss()
            } label: {
                Label("保存", systemImage: "checkmark")
                    .font(DesignTokens.ui(12, weight: .semibold))
            }
            .buttonStyle(Controls.PrimaryButtonStyle())
            .accessibilityLabel("保存序列")
        }
        .padding(12)
    }
}
