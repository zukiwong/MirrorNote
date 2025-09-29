import SwiftUI

struct ArchiveConfirmDialog: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // 确认弹窗
            VStack(spacing: 20) {
                Text("确认封存一年？")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    // 取消按钮
                    Button(action: {
                        onCancel()
                    }) {
                        Text("取消")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // 确认按钮
                    Button(action: {
                        onConfirm()
                    }) {
                        Text("确认")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .frame(maxWidth: 320)
            .aspectRatio(16/9, contentMode: .fit)
        }
        .opacity(isPresented ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

// 自定义修饰符
struct ArchiveConfirmDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    func body(content: Content) -> some View {
        content
            .overlay(
                isPresented ? 
                ArchiveConfirmDialog(
                    isPresented: $isPresented,
                    onConfirm: onConfirm,
                    onCancel: onCancel
                ) : nil
            )
    }
}

extension View {
    func archiveConfirmDialog(
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        self.modifier(ArchiveConfirmDialogModifier(
            isPresented: isPresented,
            onConfirm: onConfirm,
            onCancel: onCancel
        ))
    }
}

// 预览
struct ArchiveConfirmDialog_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("主界面内容")
                .font(.title)
                .padding()
            
            Spacer()
        }
        .archiveConfirmDialog(
            isPresented: .constant(true),
            onConfirm: {},
            onCancel: {}
        )
    }
}