import SwiftUI

/// 顶部 toast 反馈（F8 全局操作等）
struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.ok)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignTokens.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DesignTokens.borderCard, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }
}
