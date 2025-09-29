// MirrorNote/Views/Components/DetailQuestionRow.swift
import SwiftUI

struct DetailQuestionRow: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 分隔线 - 问题标题居中
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 10, height: 1)
                
                Text(question)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .fixedSize(horizontal: false, vertical: true)
                
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 10, height: 1)
                Spacer()
            }
            
            // 答案内容 - 左对齐
            HStack {
                Text(answer)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color("PrimaryText"))
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

// 圆形评分组件
struct CircularRatingView: View {
    let currentRating: Int
    let maxRating: Int = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 分隔线和标题 - 标题居中
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 10, height: 1)
                
                Text("定义情绪强度")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .fixedSize(horizontal: false, vertical: true)
                
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 10, height: 1)
                Spacer()
            }
            
            // 圆形评分 - 居中对齐
            HStack(spacing: 16) {
                ForEach(1...maxRating, id: \.self) { rating in
                    ZStack {
                        Circle()
                            .fill(rating == currentRating ? Color.black : Color.clear)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                            .frame(width: 32, height: 32)
                        
                        Text("\(rating)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(rating == currentRating ? .white : .black)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}


// 确认对话框
struct ConfirmationDialog: View {
    let action: ActionStatus
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    private var iconName: String {
        switch action {
        case .discarded:
            return "icon-delete"
        case .sent:
            return "icon-send"
        case .sealed:
            return "icon-sealed"
        default:
            return "icon-delete"
        }
    }
    
    private var confirmText: String {
        switch action {
        case .discarded:
            return "确认丢弃吗？"
        case .sent:
            return "确认寄出吗？"
        case .sealed:
            return "确认封存一年？"
        default:
            return "确认操作吗？"
        }
    }
    
    private var actionColor: Color {
        switch action {
        case .discarded:
            return .red
        case .sent:
            return .blue
        case .sealed:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // 对话框
            VStack(spacing: 32) {
                // 图标
                Image(iconName)
                    .renderingMode(.template)
                    .foregroundColor(actionColor)
                    .frame(width: 32, height: 32)
                
                // 确认文字
                Text(confirmText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(actionColor)
                    .tracking(2)
                    .multilineTextAlignment(.center)
                
                // 按钮
                HStack(spacing: 16) {
                    // 取消按钮
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("PrimaryText"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .cornerRadius(8)
                    }
                    
                    // 确认按钮
                    Button(action: onConfirm) {
                        Text("确认")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(actionColor)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
    }
}