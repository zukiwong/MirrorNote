import SwiftUI

struct EmotionInputField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    var onCommit: (() -> Void)? = nil

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 40, maxHeight: 120)
            .padding(8)
            .scrollContentBackground(.hidden) // 隐藏TextEditor的默认背景
            .background(Color("SecondaryBackground")) // 只显示我们的自定义背景
            .cornerRadius(8)
            .overlay(
                Group {
                    if text.isEmpty {
                        HStack {
                            Text(placeholder)
                                .foregroundColor(.gray)
                                .padding(.top, 12) // 将占位符文字往下移，更接近光标位置
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            )
            .onTapGesture {
                isFocused = true
            }
            .toolbar {
                if isFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完成") {
                            isFocused = false
                            onCommit?()
                        }
                    }
                }
            }
    }
}