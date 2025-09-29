import SwiftUI

struct QuestionBlock: View {
    let questionText: String
    @Binding var answerText: String
    @Binding var isFocused: Bool
    var onCommit: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil // 新增点击回调用于打开沉浸式视图

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 问题标题
            Text(questionText)
                .font(.system(size: answerText.isEmpty ? 18 : 16, weight: .light))
                .foregroundColor(answerText.isEmpty ? .primary : .gray)
                .lineLimit(nil)
            
            // 简化的输入指示器
            Button(action: {
                onTap?() // 点击时调用回调打开沉浸式视图
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    // 答案预览或占位符
                    if answerText.isEmpty {
                        Text("Tap to start answering...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                    } else {
                        Text(answerText)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                            .lineSpacing(17 * 0.3) // 130%行高 = 17 * 1.3，额外间距 = 17 * 0.3
                            .lineLimit(nil) // 移除行数限制，显示完整内容
                            .multilineTextAlignment(.leading)
                    }
                    
                    // 底部横线指示器
                    Rectangle()
                        .fill(answerText.isEmpty ? Color("DividerColor") : Color.blue.opacity(0.6))
                        .frame(height: 1)
                }
            }
            .buttonStyle(PlainButtonStyle()) // 移除按钮默认样式
        }
        .padding(.horizontal, 8) // 减少左右边距，保持左对齐
        .padding(.vertical, 12)
    }
}
