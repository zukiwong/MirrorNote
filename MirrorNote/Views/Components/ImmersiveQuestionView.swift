import SwiftUI

struct ImmersiveQuestionView: View {
    let questionType: FormFieldType
    @Binding var text: String
    @Binding var isPresented: Bool
    let onNext: (() -> Void)?
    let onPrevious: (() -> Void)?
    let isFirst: Bool
    let isLast: Bool
    
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button("Cancel") {
                        isTextEditorFocused = false // 主动取消焦点
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        if !isFirst {
                            Button(action: {
                                onPrevious?()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if !isLast {
                            Button(action: {
                                onNext?()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Button("Done") {
                                isTextEditorFocused = false // 主动取消焦点
                                isPresented = false
                            }
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // 固定的问题标题
                VStack(spacing: 12) {
                    Text(questionType.rawValue)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(.systemBackground))
                
                // 可滚动的内容区域
                ScrollView {
                    VStack(spacing: 20) {
                        // 自适应文本编辑器
                        AdaptiveTextEditor(
                            text: $text,
                            placeholder: "Tap to start typing...",
                            isFocused: $isTextEditorFocused
                        )
                        .padding(.horizontal, 20)
                        
                        // 添加额外间距确保键盘显示时内容可滚动
                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 10)
                }
                .onTapGesture {
                    // 点击空白处收起键盘
                    isTextEditorFocused = false
                }
                
                // 底部操作按钮 - 水平排列
                HStack(spacing: 12) {
                    // 返回总览按钮
                    Button(action: {
                        isTextEditorFocused = false // 主动取消焦点
                        isPresented = false
                    }) {
                        Text("Back to Overview")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // 下一个问题按钮
                    if !isLast && !text.isEmpty {
                        Button(action: {
                            onNext?()
                        }) {
                            HStack {
                                Text("Next")
                                    .font(.system(size: 16, weight: .medium))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .background(Color(.systemBackground)) // 确保按钮区域有背景
            }
            .navigationBarHidden(true)
            .onAppear {
                // 延迟一点自动聚焦，确保视图完全加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextEditorFocused = true
                }
            }
            .onDisappear {
                // 视图消失时确保取消焦点
                isTextEditorFocused = false
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // 确保在 iPad 上也是全屏
        .keyboardAdaptive() // 添加键盘适配支持
    }
}

// 预览支持
struct ImmersiveQuestionView_Previews: PreviewProvider {
    static var previews: some View {
        ImmersiveQuestionView(
            questionType: .whatHappened,
            text: .constant(""),
            isPresented: .constant(true),
            onNext: {},
            onPrevious: nil,
            isFirst: true,
            isLast: false
        )
    }
}