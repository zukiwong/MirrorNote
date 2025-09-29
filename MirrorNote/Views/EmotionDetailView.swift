import SwiftUI

struct EmotionDetailView: View {
    let historyItem: EmotionHistoryItem
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var historyViewModel: HistoryViewModel
    @State private var showActionSheet = false
    @State private var showSuccessToast = false
    @State private var toastMessage = ""
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showConfirmationDialog = false
    @State private var pendingAction: ActionStatus? = nil
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"
        return formatter
    }()
    
    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    private let sealedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()
    
    // 计算封存状态
    private var isSealed: Bool {
        historyItem.actionStatus == .locked
    }
    
    // 简化的初始化器
    init(historyItem: EmotionHistoryItem) {
        self.historyItem = historyItem
    }
    
    // 计算封存结束时间（根据用户设置的封存时间）
    private var sealedUntilDate: Date {
        // 从UserDefaults读取用户设置的封存时间
        guard let archiveTimeRawValue = UserDefaults.standard.string(forKey: "selectedArchiveTime"),
              let archiveTime = ArchiveTime(rawValue: archiveTimeRawValue) else {
            // 默认封存半年
            return Calendar.current.date(byAdding: .month, value: 6, to: historyItem.emotionEntry.date) ?? Date()
        }
        return archiveTime.archiveEndDate(from: historyItem.emotionEntry.date)
    }
    
    // 统一的返回方法
    private func handleBackNavigation() {
        // 简化返回逻辑，直接返回到上一页
        presentationMode.wrappedValue.dismiss()
    }
    
    var body: some View {
        ZStack {
            // 底层：原有详情页内容
            VStack(spacing: 0) {
                // 自定义导航栏
                customNavigationBar
                
                // 主内容
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 状态信息
                        statusSection
                        
                        // 记录内容
                        recordSection
                        
                        // 处理内容（如果有）
                        if hasProcessContent {
                            processSection
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                .blur(radius: isSealed ? 8 : 0) // 封存状态下添加模糊效果
            }
            
            // 顶层：封存覆盖层
            if isSealed {
                SealedOverlayView(sealedUntilDate: sealedUntilDate)
            }
        }
        .navigationBarHidden(true)
        .offset(x: dragOffset.width)
        .opacity(isDragging ? 1 - abs(dragOffset.width) / 300.0 : 1)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 只有从左边缘开始拖拽且向右拖拽时才响应
                    if value.startLocation.x < 30 && value.translation.width > 0 {
                        isDragging = true
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if value.translation.width > 100 {
                            // 拖拽距离足够，触发返回
                            handleBackNavigation()
                        } else {
                            // 拖拽距离不够，回弹
                            dragOffset = .zero
                        }
                        isDragging = false
                    }
                }
        )
        .confirmationDialog("Select Action", isPresented: $showActionSheet) {
            Button("Discard") {
                showConfirmation(.discarded)
            }
            .foregroundColor(Color("PrimaryText"))
            
            if historyItem.actionStatus == .sent {
                Button("View Reply") {
                    // 查看回信，跳转到收件箱
                    navigateToInbox(emotionEntryId: historyItem.emotionEntry.id.uuidString)
                }
                .foregroundColor(Color("PrimaryText"))
            } else {
                Button("Send") {
                    showConfirmation(.sent)
                }
                .foregroundColor(Color("PrimaryText"))
            }
            
            Button("Seal") {
                showConfirmation(.sealed)
            }
            .foregroundColor(Color("PrimaryText"))
            
            Button("Cancel", role: .cancel) { }
            .foregroundColor(Color("PrimaryText"))
        }
        .confirmationDialog(
            getConfirmationTitle(),
            isPresented: $showConfirmationDialog,
            titleVisibility: .visible
        ) {
            if let action = pendingAction {
                Button("Confirm", role: .destructive) {
                    executeAction(action)
                    showConfirmationDialog = false
                }
                .foregroundColor(Color("PrimaryText"))
                
                Button("Cancel", role: .cancel) {
                    showConfirmationDialog = false
                    pendingAction = nil
                }
                .foregroundColor(Color("PrimaryText"))
            }
        }
        .successToast(
            isPresented: $showSuccessToast,
            message: toastMessage,
            icon: "checkmark.circle"
        )
    }
    
    // 自定义导航栏
    private var customNavigationBar: some View {
        HStack {
            // 返回按钮
            Button(action: {
                handleBackNavigation()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color("PrimaryText"))
            }
            
            Spacer()
            
            // 日期标题或封存状态
            VStack(spacing: 0) {
                Text(isSealed ? "Sealed" : "\(dateFormatter.string(from: historyItem.emotionEntry.date)) \(weekdayFormatter.string(from: historyItem.emotionEntry.date))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("PrimaryText"))
            }
            
            Spacer()
            
            // 三点菜单（封存状态下隐藏）
            if !isSealed {
                Button(action: {
                    showActionSheet = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("PrimaryText"))
                        .rotationEffect(.degrees(90))
                }
            } else {
                // 封存状态下的空白占位符，保持布局对称
                Spacer()
                    .frame(width: 18, height: 18)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("PrimaryBackground"))
    }
    
    // 状态信息区域 - 只显示有内容的字段
    private var statusSection: some View {
        let hasPlace = !historyItem.emotionEntry.place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPeople = !historyItem.emotionEntry.people.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return Group {
            if hasPlace || hasPeople {
                VStack(alignment: .center, spacing: 8) {
                    // 只有当地点不为空时才显示
                    if hasPlace {
                        Text(historyItem.emotionEntry.place)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("PrimaryText"))
                            .tracking(1)
                    }
                    
                    // 只有当人物不为空时才显示
                    if hasPeople {
                        Text(historyItem.emotionEntry.people)
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(Color("PrimaryText"))
                            .tracking(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }
    
    
    // 记录内容区域
    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 只显示用户填写了内容的问题
            if let whatHappened = historyItem.emotionEntry.whatHappened, !whatHappened.isEmpty {
                DetailQuestionRow(question: "What happened", answer: whatHappened)
            }
            if let think = historyItem.emotionEntry.think, !think.isEmpty {
                DetailQuestionRow(question: "My thoughts", answer: think)
            }
            if let feel = historyItem.emotionEntry.feel, !feel.isEmpty {
                DetailQuestionRow(question: "My feelings", answer: feel)
            }
            if let reaction = historyItem.emotionEntry.reaction, !reaction.isEmpty {
                DetailQuestionRow(question: "My reaction", answer: reaction)
            }
            if let need = historyItem.emotionEntry.need, !need.isEmpty {
                DetailQuestionRow(question: "My needs", answer: need)
            }
            
            // 情绪等级显示 - 只有当用户选择了强度时才显示
            if historyItem.emotionEntry.recordSeverity > 0 {
                VStack(alignment: .leading, spacing: 16) {
                    // 分隔线和标题 - 标题居中
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 10, height: 1)
                        
                        Text("Define Emotion Intensity")
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
                        ForEach(1...5, id: \.self) { rating in
                            ZStack {
                                Circle()
                                    .fill(rating == historyItem.emotionEntry.recordSeverity ? Color("PrimaryText") : Color.clear)
                                    .frame(width: 32, height: 32)
                                
                                Circle()
                                    .stroke(Color("PrimaryText"), lineWidth: 1)
                                    .frame(width: 32, height: 32)
                                
                                Text("\(rating)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(rating == historyItem.emotionEntry.recordSeverity ? Color("PrimaryBackground") : Color("PrimaryText"))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
    }
    
    // 处理内容区域
    private var processSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let why = historyItem.emotionEntry.why, !why.isEmpty {
                DetailQuestionRow(question: "Why did this happen", answer: why)
            }
            if let ifElse = historyItem.emotionEntry.ifElse, !ifElse.isEmpty {
                DetailQuestionRow(question: "If I could redo", answer: ifElse)
            }
            if let nextTime = historyItem.emotionEntry.nextTime, !nextTime.isEmpty {
                DetailQuestionRow(question: "What to do next time", answer: nextTime)
            }
            
            // 处理后情绪等级显示 - 只有当用户选择了强度且大于0时才显示
            if let processSeverity = historyItem.emotionEntry.processSeverity, processSeverity > 0 {
                VStack(alignment: .leading, spacing: 16) {
                    // 分隔线和标题 - 标题居中
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 10, height: 1)
                        
                        Text("Redefined Intensity")
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
                        ForEach(1...5, id: \.self) { rating in
                            ZStack {
                                Circle()
                                    .fill(rating == processSeverity ? Color("PrimaryText") : Color.clear)
                                    .frame(width: 32, height: 32)
                                
                                Circle()
                                    .stroke(Color("PrimaryText"), lineWidth: 1)
                                    .frame(width: 32, height: 32)
                                
                                Text("\(rating)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(rating == processSeverity ? Color("PrimaryBackground") : Color("PrimaryText"))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
    }
    
    // 计算属性
    private var hasProcessContent: Bool {
        historyItem.emotionEntry.why != nil ||
        historyItem.emotionEntry.ifElse != nil ||
        historyItem.emotionEntry.nextTime != nil ||
        historyItem.emotionEntry.processSeverity != nil
    }
    
    private var statusIcon: String {
        switch historyItem.actionStatus {
        case .discarded:
            return "trash"
        case .sent:
            return "paperplane"
        case .sealed:
            return "archivebox"
        case .locked:
            return "lock"
        default:
            return "circle"
        }
    }
    
    private var statusText: String {
        switch historyItem.actionStatus {
        case .discarded:
            return "Discarded"
        case .sent:
            return "Sent"
        case .sealed:
            return "Sealed"
        case .locked:
            return "Locked"
        default:
            return "Normal"
        }
    }
    
    private var statusColor: Color {
        switch historyItem.actionStatus {
        case .discarded:
            return .white
        case .sent:
            return Color("PrimaryText")
        case .sealed:
            return Color("PrimaryText")
        case .locked:
            return Color(.systemGray2)
        default:
            return .primary
        }
    }
    
    private var statusBackgroundColor: Color {
        switch historyItem.actionStatus {
        case .discarded:
            return Color(.systemGray2)
        case .sent:
            return Color(.systemBackground)
        case .sealed:
            return Color(.systemBackground)
        case .locked:
            return Color(.systemGray6)
        default:
            return Color(.systemGray6)
        }
    }
    
    // 显示确认对话框
    private func showConfirmation(_ action: ActionStatus) {
        pendingAction = action
        showConfirmationDialog = true
    }
    
    // 获取确认标题
    private func getConfirmationTitle() -> String {
        guard let action = pendingAction else { return "" }
        switch action {
        case .discarded:
            return "Confirm discard?"
        case .sent:
            return "Confirm send?"
        case .sealed:
            return getUserArchiveTimeConfirmationText()
        default:
            return "Confirm action?"
        }
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
    
    // 执行操作
    private func executeAction(_ action: ActionStatus) {
        switch action {
        case .discarded:
            // 丢弃操作：直接删除记录（避免在历史页面重复确认）
            historyViewModel.deleteHistoryItem(with: historyItem.id)
            toastMessage = "Successfully discarded"
            showSuccessToast = true
            // 延迟返回上一页
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presentationMode.wrappedValue.dismiss()
            }
        case .sent:
            // 寄出操作：更新状态（AI回信生成会在HistoryViewModel中统一处理）
            historyViewModel.updateActionStatus(for: historyItem.id, to: .sent)
            toastMessage = "Successfully sent"
            showSuccessToast = true
        case .sealed:
            // 封存操作：更新状态为锁定并显示提示
            historyViewModel.updateActionStatus(for: historyItem.id, to: .locked)
            historyViewModel.moveToLast(itemId: historyItem.id)
            toastMessage = "Successfully sealed"
            showSuccessToast = true
            // 延迟返回上一页
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presentationMode.wrappedValue.dismiss()
            }
        default:
            break
        }
        
        // 清理状态
        pendingAction = nil
    }
    
    // 导航到收件箱
    private func navigateToInbox(emotionEntryId: String) {
        // 发送通知让MainTabView切换到收件箱标签
        NotificationCenter.default.post(
            name: .openInbox, 
            object: nil, 
            userInfo: ["emotionEntryId": emotionEntryId]
        )
        
        // 关闭当前详情页
        presentationMode.wrappedValue.dismiss()
    }
}

// 封存覆盖层组件
struct SealedOverlayView: View {
    let sealedUntilDate: Date
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 主内容区域
            VStack(spacing: 24) {
                // 主标题
                Text("I leave this page to time")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color("PrimaryText"))
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                // 封存信息
                VStack(spacing: 8) {
                    Text("Will be sealed until \(dateFormatter.string(from: sealedUntilDate))")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    Text("When opened again, I hope you have changed")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.secondary)
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(Color.clear)
    }
}

// 信息行组件
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// 详细文本块组件
struct DetailTextBlock: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(content)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
    }
}

// 预览
struct EmotionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EmotionDetailView(historyItem: EmotionHistoryItem(
                emotionEntry: EmotionEntry(
                    date: Date(),
                    place: "家中",
                    people: "无名氏",
                    whatHappened: "工作上遇到了困难",
                    think: "我觉得自己能力不够",
                    feel: "感到焦虑和不安",
                    reaction: "开始怀疑自己",
                    need: "需要更多的支持和鼓励",
                    recordSeverity: 5,
                    why: "因为没有足够的经验",
                    ifElse: "会更早寻求帮助",
                    nextTime: "先分析问题再行动",
                    processSeverity: 3
                ),
                actionStatus: .sent
            ))
        }
    }
}