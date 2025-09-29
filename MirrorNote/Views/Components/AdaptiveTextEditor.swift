import SwiftUI

struct AdaptiveTextEditor: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var isFocused: Bool
    
    private let fixedHeight: CGFloat = 200
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("SecondaryBackground"))
                .frame(height: fixedHeight)
            
            // 文本编辑器
            TextEditor(text: $text)
                .font(.system(size: 18))
                .padding(16)
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(height: fixedHeight)
                .scrollDismissesKeyboard(.never) // 确保滚动时不收起键盘
            
            // 占位符
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.leading, 24) // 稍微向右移动，给光标留出空间
                    .padding(.top, 22) // 调整占位符位置，使其与TextEditor内部文本基线对齐
                    .allowsHitTesting(false) // 允许点击穿透到文本编辑器
            }
        }
    }
}

