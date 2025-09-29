import SwiftUI

struct EmotionHistoryCard: View {
    let historyItem: EmotionHistoryItem
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSelectAction: (ActionStatus) -> Void
    let onConfirmTap: () -> Void
    let onViewReply: () -> Void
    @State private var isPressed = false
    
    // 计算显示的情绪等级：优先第二个表单，其次第一个表单，都没有则显示"/"
    private var displayedEmotionLevel: String {
        if let processSeverity = historyItem.emotionEntry.processSeverity, processSeverity > 0 {
            return "\(processSeverity)"
        } else if historyItem.emotionEntry.recordSeverity > 0 {
            return "\(historyItem.emotionEntry.recordSeverity)"
        } else {
            return "/"
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"
        return formatter
    }()
    
    var body: some View {
        Group {
            switch historyItem.actionStatus {
            case .normal:
                normalCard
            case .selecting:
                selectingCard
            case .discarded:
                discardedCard
            case .discardingConfirm:
                discardingConfirmCard
            case .sent:
                sentCard
            case .sendingConfirm:
                sendingConfirmCard
            case .sealed:
                sealedCard
            case .sealingConfirm:
                sealingConfirmCard
            case .locked:
                lockedCard
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: historyItem.actionStatus)
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50) {
            handleLongPress()
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
    
    // 处理点击事件
    private func handleTap() {
        switch historyItem.actionStatus {
        case .normal, .locked: // Normal state, archived state can be clicked to enter detail page
            onTap() // Navigate to detail page
        case .sent: // Sent state directly navigates to detail page
            onTap() // Navigate to detail page
        case .discarded, .discardingConfirm, .sendingConfirm, .sealed, .sealingConfirm:
            onConfirmTap() // 显示成功提示框或执行最终操作
        default:
            break
        }
    }
    
    // 处理长按事件
    private func handleLongPress() {
        // 对于正常状态的记录，允许长按进入选择状态
        if historyItem.actionStatus == .normal {
            onLongPress() // 进入选择状态
        }
        // 对于已寄出的记录，也允许长按进入选择状态（但Send按钮会被禁用）
        else if historyItem.actionStatus == .sent {
            onLongPress() // 进入选择状态
        }
        // 其他状态不响应长按
    }
    
    // Normal state card
    private var normalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: historyItem.emotionEntry.date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("PrimaryText"))
                    .tracking(2)
                
                Text(historyItem.emotionEntry.place)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color("PrimaryText"))
                    .tracking(2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(historyItem.emotionEntry.people)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color("PrimaryText"))
                    .tracking(2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            HStack {
                Text("Emotion Level")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(Color("PrimaryText"))
                    .tracking(1)
                
                Text(":")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color("PrimaryText"))
                
                Text(displayedEmotionLevel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color("PrimaryText"))
                    .tracking(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color("PrimaryBackground"))
            .overlay(
                RoundedRectangle(cornerRadius: 100)
                    .stroke(Color(.systemGray4), lineWidth: 2)
            )
            .cornerRadius(100)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 20)
        .frame(width: 165, height: 170)
        .background(Color("SecondaryBackground"))
        .cornerRadius(8)
    }
    
    // 选择中状态卡片
    private var selectingCard: some View {
        VStack(spacing: 0) {
            // Discard option
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    onSelectAction(.discardingConfirm)
                }
            }) {
                Text("Discard")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("PrimaryText"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("SecondaryBackground"))
            }
            .buttonStyle(PlainButtonStyle())
            
            // 分割线
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
            
            // Send/view reply option
            Button(action: {
                // 重要：检查是否已经寄出过，防止重复寄出
                let wasSent = historyItem.emotionEntry.sentDate != nil || historyItem.emotionEntry.hasAIReply
                if wasSent {
                    // 已寄出的记录不允许再次寄出，直接返回
                    print("⚠️ [EmotionHistoryCard] 记录已寄出，拒绝重复寄出操作")
                    return
                } else {
                    // 正常记录允许寄出
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        onSelectAction(.sendingConfirm)
                    }
                }
            }) {
                // Display different text and style based on whether already sent
                let wasSent = historyItem.emotionEntry.sentDate != nil || historyItem.emotionEntry.hasAIReply
                Text(wasSent ? "Sent" : "Send")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(wasSent ? Color("SecondaryText").opacity(0.6) : Color("PrimaryText"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("SecondaryBackground"))
            }
            .disabled(historyItem.emotionEntry.sentDate != nil || historyItem.emotionEntry.hasAIReply)
            .buttonStyle(PlainButtonStyle())
            
            // 分割线
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
            
            // Archive option
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    onSelectAction(.sealingConfirm)
                }
            }) {
                Text("Seal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("PrimaryText"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("SecondaryBackground"))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 165, height: 170)
        .background(Color("SecondaryBackground"))
        .cornerRadius(8)
    }
    
    // 丢弃确认状态卡片
    private var discardingConfirmCard: some View {
        VStack(spacing: 24) {
            Image("icon-delete")
                .renderingMode(.template)
                .foregroundColor(.red)
                .frame(width: 25, height: 24)
            
            Text("Confirm discard?")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .tracking(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .frame(width: 165, height: 170)
        .background(Color("PrimaryBackground"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red, lineWidth: 2)
        )
        .cornerRadius(8)
    }
    
    // Discarded state card
    private var discardedCard: some View {
        VStack(spacing: 24) {
            Image("icon-delete")
                .renderingMode(.template)
                .foregroundColor(.white)
                .frame(width: 25, height: 24)
            
            Text("Discarded")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .tracking(3)
        }
        .frame(width: 165, height: 170)
        .background(Color(.systemGray2))
        .cornerRadius(8)
    }
    
    // 寄出确认状态卡片
    private var sendingConfirmCard: some View {
        VStack(spacing: 24) {
            Image("icon-send")
                .renderingMode(.template)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
            
            Text("Confirm send?")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .tracking(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .frame(width: 165, height: 170)
        .background(Color("PrimaryBackground"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 2)
        )
        .cornerRadius(8)
    }
    
    // 已寄出状态卡片
    private var sentCard: some View {
        ZStack {
            // 基础卡片内容（与正常状态相同的新布局）
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: historyItem.emotionEntry.date))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(2)
                    
                    Text(historyItem.emotionEntry.place)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(historyItem.emotionEntry.people)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                HStack {
                    Text("Emotion Level")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(1)
                    
                    Text(":")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(Color("PrimaryText"))
                    
                    Text(displayedEmotionLevel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color("PrimaryBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                        .stroke(Color(.systemGray4), lineWidth: 2)
                )
                .cornerRadius(100)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 20)
            .frame(width: 165, height: 170)
            .background(Color("SecondaryBackground"))
            .cornerRadius(8)
            
            // 右上角"已寄出"标签
            VStack {
                HStack {
                    Spacer()
                    Text("Sent")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("SecondaryText"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray4))
                        .cornerRadius(4)
                        .offset(x: -8, y: 8)
                }
                Spacer()
            }
        }
    }
    
    // 封存确认状态卡片
    private var sealingConfirmCard: some View {
        VStack(spacing: 24) {
            Image("icon-sealed")
                .renderingMode(.template)
                .foregroundColor(.orange)
                .frame(width: 32, height: 32)
            
            Text(getUserArchiveTimeConfirmationText())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.orange)
                .tracking(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .frame(width: 165, height: 170)
        .background(Color("PrimaryBackground"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 2)
        )
        .cornerRadius(8)
    }
    
    // 已封存状态卡片
    private var sealedCard: some View {
        VStack(spacing: 24) {
            Image("icon-sealed")
                .renderingMode(.template)
                .foregroundColor(.black)
                .frame(width: 32, height: 32)
            
            Text("Sealed")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .tracking(3)
        }
        .frame(width: 165, height: 170)
        .background(Color("PrimaryBackground"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black, lineWidth: 1)
        )
        .cornerRadius(8)
    }
    
    // 已锁定状态卡片
    private var lockedCard: some View {
        VStack(spacing: 24) {
            Image("icon-locked")
                .renderingMode(.template)
                .foregroundColor(.gray)
                .frame(width: 32, height: 32)
            
            Text(dateFormatter.string(from: getUserArchiveEndDate()))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .tracking(3)
                .lineLimit(1)
        }
        .frame(width: 165, height: 170)
        .background(Color("PrimaryBackground"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .cornerRadius(8)
        .contentShape(Rectangle()) // 确保点击事件可以正确传递
    }
    
    // 获取用户设置的封存时间确认文本
    private func getUserArchiveTimeConfirmationText() -> String {
        // 从UserDefaults读取用户设置的封存时间
        guard let archiveTimeRawValue = UserDefaults.standard.string(forKey: "selectedArchiveTime"),
              let archiveTime = ArchiveTime(rawValue: archiveTimeRawValue) else {
            return "Confirm seal for 6 months?"  // 默认值
        }
        return archiveTime.confirmationText
    }
    
    // 获取用户设置的封存结束日期
    private func getUserArchiveEndDate() -> Date {
        // 从UserDefaults读取用户设置的封存时间
        guard let archiveTimeRawValue = UserDefaults.standard.string(forKey: "selectedArchiveTime"),
              let archiveTime = ArchiveTime(rawValue: archiveTimeRawValue) else {
            // 默认封存半年
            return Calendar.current.date(byAdding: .month, value: 6, to: historyItem.emotionEntry.date) ?? Date()
        }
        return archiveTime.archiveEndDate(from: historyItem.emotionEntry.date)
    }
}


// 预览
struct EmotionHistoryCard_Previews: PreviewProvider {
    static var previews: some View {
        let mockEntry = EmotionEntry(
            date: Date(),
            place: "家中",
            people: "无名氏",
            whatHappened: "工作上遇到了困难",
            think: "我觉得自己能力不够",
            feel: "感到焦虑和不安",
            reaction: "开始怀疑自己",
            need: "需要更多的支持和鼓励",
            recordSeverity: 5
        )
        
        VStack(spacing: 20) {
            // 正常状态
            EmotionHistoryCard(
                historyItem: EmotionHistoryItem(emotionEntry: mockEntry, actionStatus: .normal),
                onTap: {},
                onLongPress: {},
                onSelectAction: { _ in },
                onConfirmTap: {},
                onViewReply: {}
            )
            
            // 选择中状态
            EmotionHistoryCard(
                historyItem: EmotionHistoryItem(emotionEntry: mockEntry, actionStatus: .selecting),
                onTap: {},
                onLongPress: {},
                onSelectAction: { _ in },
                onConfirmTap: {},
                onViewReply: {}
            )
            
            // 已丢弃状态
            EmotionHistoryCard(
                historyItem: EmotionHistoryItem(emotionEntry: mockEntry, actionStatus: .discarded),
                onTap: {},
                onLongPress: {},
                onSelectAction: { _ in },
                onConfirmTap: {},
                onViewReply: {}
            )
            
            // 已寄出状态
            EmotionHistoryCard(
                historyItem: EmotionHistoryItem(emotionEntry: mockEntry, actionStatus: .sent),
                onTap: {},
                onLongPress: {},
                onSelectAction: { _ in },
                onConfirmTap: {},
                onViewReply: {}
            )
            
            // 已封存状态
            EmotionHistoryCard(
                historyItem: EmotionHistoryItem(emotionEntry: mockEntry, actionStatus: .sealed),
                onTap: {},
                onLongPress: {},
                onSelectAction: { _ in },
                onConfirmTap: {},
                onViewReply: {}
            )
            
            // 已锁定状态
            EmotionHistoryCard(
                historyItem: EmotionHistoryItem(emotionEntry: mockEntry, actionStatus: .locked),
                onTap: {},
                onLongPress: {},
                onSelectAction: { _ in },
                onConfirmTap: {},
                onViewReply: {}
            )
        }
        .padding()
    }
}