// MirrorNote/Views/Components/SettingSection.swift
import SwiftUI

struct SettingSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: Content
    
    init(title: String, isExpanded: Bool, onToggle: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            Button(action: onToggle) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image("icon-add")
                        .rotationEffect(.degrees(isExpanded ? 45 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .background(Color("SecondaryBackground"))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 内容区域
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color("PrimaryBackground"))
                .cornerRadius(12)
                .shadow(color: Color("ShadowColor"), radius: 2, x: 0, y: 1)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// 设置选项行组件
struct SettingOptionRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let selectionType: SelectionType
    let onToggle: () -> Void
    
    enum SelectionType {
        case checkbox  // 多选框
        case radio     // 单选框
    }
    
    init(title: String, subtitle: String? = nil, isSelected: Bool, selectionType: SelectionType, onToggle: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.selectionType = selectionType
        self.onToggle = onToggle
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                // 选择指示器
                selectionIndicator
                
                // 文本内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var selectionIndicator: some View {
        switch selectionType {
        case .checkbox:
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 18))
                .foregroundColor(isSelected ? Color("PrimaryText") : .gray)
        case .radio:
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 18))
                .foregroundColor(isSelected ? Color("PrimaryText") : .gray)
        }
    }
}