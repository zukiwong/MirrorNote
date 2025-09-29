import Foundation

// 信件数据模型
struct InboxMessage: Codable {
    let id: String
    let date: String
    let content: String
    let isRead: Bool
    let emotionEntryId: String?  // 关联的情绪记录ID
    let tone: String?            // AI回信的语气
    let isAIReply: Bool          // 是否是AI回信
    
    init(id: String = UUID().uuidString, date: String, content: String, isRead: Bool = false, emotionEntryId: String? = nil, tone: String? = nil, isAIReply: Bool = false) {
        self.id = id
        self.date = date
        self.content = content
        self.isRead = isRead
        self.emotionEntryId = emotionEntryId
        self.tone = tone
        self.isAIReply = isAIReply
    }
}

class InboxViewModel: ObservableObject {
    @Published var isReplyEnabled: Bool = true // 回信开关状态
    @Published var messages: [InboxMessage] = [] // 收件箱消息列表
    @Published var currentIndex: Int = 0 // 当前显示的消息索引
    @Published var unreadCount: Int = 0 // 未读消息数量
    
    var currentMessage: InboxMessage? {
        guard !messages.isEmpty, currentIndex < messages.count else { return nil }
        return messages[currentIndex]
    }
    
    // 获取AI回信数量
    var aiReplyCount: Int {
        return messages.filter { $0.isAIReply }.count
    }
    
    init() {
        loadMessages()
        setupNotificationObservers()
    }
    
    // 加载消息数据
    func loadMessages() {
        // 从UserDefaults加载已保存的消息
        loadMessagesFromStorage()
        
        // 一次性清空旧的初始数据（用于清理测试数据）
        if !UserDefaults.standard.bool(forKey: "hasCleanedInitialData") {
            print("🧹 [InboxViewModel] 执行一次性数据清理")
            messages.removeAll()
            saveMessagesToStorage()
            UserDefaults.standard.set(true, forKey: "hasCleanedInitialData")
        }
        
        // 如果没有消息，初始化为空数组
        if messages.isEmpty {
            currentIndex = 0
        } else {
            // 确保当前索引有效
            currentIndex = min(currentIndex, messages.count - 1)
        }
        
        // 更新未读数量
        updateUnreadCount()
    }
    
    // 切换回信状态
    func toggleReplyEnabled() {
        isReplyEnabled.toggle()
    }
    
    // 处理反馈按钮点击
    func handleFeedback(type: FeedbackType) {
        print("收到反馈：\(type.rawValue)")
        // 这里可以添加实际的反馈处理逻辑
    }
    
    // 标记消息为已读
    func markAsRead(messageId: String) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index] = InboxMessage(
                id: messages[index].id,
                date: messages[index].date,
                content: messages[index].content,
                isRead: true,
                emotionEntryId: messages[index].emotionEntryId,
                tone: messages[index].tone,
                isAIReply: messages[index].isAIReply
            )
            
            // 保存到存储
            saveMessagesToStorage()
            
            // 更新未读数量
            updateUnreadCount()
        }
    }
    
    // 设置当前索引
    func setCurrentIndex(_ index: Int) {
        if index >= 0 && index < messages.count {
            currentIndex = index
        }
    }
    
    // 设置通知监听
    func setupNotificationObservers() {
        // 监听AI回信生成通知
        NotificationCenter.default.addObserver(
            forName: .aiReplyGenerated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAIReplyGenerated(notification)
        }
        
        // 监听AI回信接收通知
        NotificationCenter.default.addObserver(
            forName: .aiReplyReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAIReplyReceived(notification)
        }
        
        // 监听打开收件箱通知
        NotificationCenter.default.addObserver(
            forName: .openInbox,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleOpenInbox(notification)
        }
        
        // 监听数据清空通知
        NotificationCenter.default.addObserver(
            forName: .dataCleared,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDataCleared()
        }
    }
    
    // 处理数据清空通知
    private func handleDataCleared() {
        // 清空内存中的消息数据
        messages.removeAll()
        
        // 重置相关状态
        currentIndex = 0
        unreadCount = 0
        
        print("📥 [InboxViewModel] 收到数据清空通知，已清空所有收件箱消息")
    }
    
    // 处理AI回信生成通知（测试模式）
    private func handleAIReplyGenerated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let emotionEntryId = userInfo["emotionEntryId"] as? String,
              let replyContent = userInfo["replyContent"] as? String,
              let tone = userInfo["tone"] as? String else {
            return
        }
        
        // 创建AI回信消息
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        let dateString = dateFormatter.string(from: Date())
        
        let aiReplyMessage = InboxMessage(
            date: dateString,
            content: replyContent,
            isRead: false,
            emotionEntryId: emotionEntryId,
            tone: tone,
            isAIReply: true
        )
        
        print("💌 [InboxViewModel] 创建AI回信消息: \(aiReplyMessage.content)")
        
        // 添加到消息列表的最前面
        messages.insert(aiReplyMessage, at: 0)
        
        // 保存到存储
        saveMessagesToStorage()
        
        // 更新未读数量
        updateUnreadCount()
        
        // 发送本地通知
        Task {
            await NotificationService.shared.sendReplyNotification(for: AIReply(
                emotionEntryId: UUID(uuidString: emotionEntryId) ?? UUID(),
                content: replyContent,
                tone: AIReplyTone(rawValue: tone) ?? .warm,
                receivedDate: Date(),
                isRead: false
            ))
        }
    }
    
    // 处理AI回信接收通知（正式模式）
    private func handleAIReplyReceived(_ notification: Notification) {
        guard let aiReply = notification.object as? AIReply else {
            return
        }
        
        // 创建收件箱消息
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        let dateString = dateFormatter.string(from: aiReply.receivedDate)
        
        let inboxMessage = InboxMessage(
            date: dateString,
            content: aiReply.content,
            isRead: aiReply.isRead,
            emotionEntryId: aiReply.emotionEntryId.uuidString,
            tone: aiReply.tone.rawValue,
            isAIReply: true
        )
        
        // 添加到消息列表
        messages.insert(inboxMessage, at: 0)
        
        // 保存到存储
        saveMessagesToStorage()
        
        // 更新未读数量
        updateUnreadCount()
    }
    
    // 更新未读数量
    private func updateUnreadCount() {
        unreadCount = messages.filter { !$0.isRead }.count
    }
    
    // 添加AI回信到收件箱
    func addAIReply(_ aiReply: AIReply) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        let dateString = dateFormatter.string(from: aiReply.receivedDate)
        
        let inboxMessage = InboxMessage(
            date: dateString,
            content: aiReply.content,
            isRead: aiReply.isRead,
            emotionEntryId: aiReply.emotionEntryId.uuidString,
            tone: aiReply.tone.rawValue,
            isAIReply: true
        )
        
        messages.insert(inboxMessage, at: 0)
        saveMessagesToStorage()
        updateUnreadCount()
    }
    
    // 清除所有AI回信
    func clearAIReplies() {
        messages.removeAll { $0.isAIReply }
        saveMessagesToStorage()
        updateUnreadCount()
    }
    
    // 获取特定情绪记录的AI回信
    func getAIReply(for emotionEntryId: String) -> InboxMessage? {
        return messages.first { $0.emotionEntryId == emotionEntryId && $0.isAIReply }
    }
    
    // 处理打开收件箱通知
    private func handleOpenInbox(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            // 如果没有特定的userInfo，只是简单地打开收件箱
            print("📱 [InboxViewModel] 收到打开收件箱通知（无特定目标）")
            return
        }
        
        // 处理跳转到特定回信的情况
        if let replyId = userInfo["replyId"] as? String {
            // 通过回信ID查找
            if let index = messages.firstIndex(where: { $0.id == replyId }) {
                currentIndex = index
                markAsRead(messageId: replyId)
                print("📱 [InboxViewModel] 已跳转到回信: \(replyId)")
            }
        } else if let emotionEntryId = userInfo["emotionEntryId"] as? String {
            // 通过情绪记录ID查找对应的回信
            if let index = messages.firstIndex(where: { $0.emotionEntryId == emotionEntryId && $0.isAIReply }) {
                currentIndex = index
                markAsRead(messageId: messages[index].id)
                print("📱 [InboxViewModel] 已跳转到情绪记录 \(emotionEntryId) 的回信")
            } else {
                print("📱 [InboxViewModel] 没有找到情绪记录 \(emotionEntryId) 的回信")
            }
        }
    }
    
    // 从存储加载消息
    private func loadMessagesFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "InboxMessages"),
           let savedMessages = try? JSONDecoder().decode([InboxMessage].self, from: data) {
            messages = savedMessages
            print("📥 [InboxViewModel] 从存储加载了 \(messages.count) 条消息")
        } else {
            messages = []
            print("📥 [InboxViewModel] 没有找到已保存的消息")
        }
    }
    
    // 保存消息到存储
    private func saveMessagesToStorage() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: "InboxMessages")
            print("💾 [InboxViewModel] 已保存 \(messages.count) 条消息到存储")
        } else {
            print("❌ [InboxViewModel] 保存消息失败")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// 反馈类型枚举
enum FeedbackType: String, CaseIterable {
    case heart = "heart"
    case yeah = "yeah"
    case fuck = "fuck"
    
    var iconName: String {
        switch self {
        case .heart: return "icon-heart"
        case .yeah: return "icon-yeah"
        case .fuck: return "icon-fuck"
        }
    }
}