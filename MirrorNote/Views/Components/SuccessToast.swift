import SwiftUI

struct SuccessToast: View {
    let message: String
    let icon: String
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // 提示框
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color("PrimaryBackground"))
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("PrimaryBackground"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color("PrimaryText").opacity(0.9))
            .cornerRadius(12)
            .frame(maxWidth: 280)
            .aspectRatio(16/9, contentMode: .fit)
        }
        .opacity(isPresented ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isPresented)
        .onAppear {
            // 1.5秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isPresented = false
            }
        }
    }
}

// 自定义修饰符，用于在视图上显示成功提示
struct SuccessToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    
    func body(content: Content) -> some View {
        content
            .overlay(
                isPresented ? 
                SuccessToast(message: message, icon: icon, isPresented: $isPresented) : nil
            )
    }
}

extension View {
    func successToast(
        isPresented: Binding<Bool>,
        message: String,
        icon: String
    ) -> some View {
        self.modifier(SuccessToastModifier(
            isPresented: isPresented,
            message: message,
            icon: icon
        ))
    }
}

// 预览
struct SuccessToast_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("主界面内容")
                .font(.title)
                .padding()
            
            Spacer()
        }
        .successToast(
            isPresented: .constant(true),
            message: "Successfully discarded",
            icon: "trash"
        )
    }
}