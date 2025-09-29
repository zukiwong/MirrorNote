import Foundation
import SwiftUI

// 历史记录操作状态枚举
enum ActionStatus: String, CaseIterable, Codable {
    case normal = "normal"              // 正常状态
    case selecting = "selecting"        // 选择中状态
    case discarded = "discarded"        // 已丢弃
    case discardingConfirm = "discardingConfirm"  // 丢弃确认状态
    case sent = "sent"                 // 已寄出
    case sendingConfirm = "sendingConfirm"  // 寄出确认状态
    case sealed = "sealed"             // 已封存
    case sealingConfirm = "sealingConfirm"  // 封存确认状态
    case locked = "locked"             // 已锁定
}

// 历史记录项目，扩展EmotionEntry
struct EmotionHistoryItem: Identifiable, Codable {
    let id: UUID
    let emotionEntry: EmotionEntry
    var actionStatus: ActionStatus
    let createdAt: Date
    
    init(emotionEntry: EmotionEntry, actionStatus: ActionStatus = .normal) {
        self.id = UUID()
        self.emotionEntry = emotionEntry
        self.actionStatus = actionStatus
        self.createdAt = emotionEntry.date
    }
    
    init(id: UUID, emotionEntry: EmotionEntry, actionStatus: ActionStatus) {
        self.id = id
        self.emotionEntry = emotionEntry
        self.actionStatus = actionStatus
        self.createdAt = emotionEntry.date
    }
}

// 历史记录视图模型
class HistoryViewModel: ObservableObject {
    @Published var historyItems: [EmotionHistoryItem] = []
    @Published var searchText: String = ""
    @Published var selectedDate: Date? = nil
    @Published var isSearching: Bool = false
    @Published var isDataLoaded: Bool = false
    
    // AI回信服务
    private let aiReplyService = AIReplyService()
    
    // 通知服务
    private let notificationService = NotificationService.shared
    
    // 过滤后的历史记录
    var filteredHistoryItems: [EmotionHistoryItem] {
        var items = historyItems
        
        // 按关键词搜索
        if !searchText.isEmpty {
            items = items.filter { item in
                let entry = item.emotionEntry
                return entry.place.localizedCaseInsensitiveContains(searchText) ||
                       entry.people.localizedCaseInsensitiveContains(searchText) ||
                       (entry.whatHappened?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (entry.think?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (entry.feel?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (entry.reaction?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (entry.need?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (entry.why?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (entry.ifElse?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (entry.nextTime?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 按日期搜索
        if let selectedDate = selectedDate {
            let calendar = Calendar.current
            items = items.filter { item in
                calendar.isDate(item.emotionEntry.date, inSameDayAs: selectedDate)
            }
        }
        
        // 按状态和创建时间排序：locked状态排在最后，其他按创建时间降序排序
        return items.sorted { item1, item2 in
            // 如果两个都是locked状态，按创建时间排序
            if item1.actionStatus == .locked && item2.actionStatus == .locked {
                return item1.createdAt > item2.createdAt
            }
            // 如果只有一个是locked状态，locked排在后面
            if item1.actionStatus == .locked {
                return false
            }
            if item2.actionStatus == .locked {
                return true
            }
            // 其他情况按创建时间降序排序
            return item1.createdAt > item2.createdAt
        }
    }
    
    // 更新历史记录项目的操作状态
    func updateActionStatus(for itemId: UUID, to status: ActionStatus, shouldTriggerAIReply: Bool = true) {
        if let index = historyItems.firstIndex(where: { $0.id == itemId }) {
            historyItems[index].actionStatus = status
            
            // 保存状态变更到持久化存储
            saveHistoryItems()
            
            // 如果状态更新为已寄出，且需要触发AI回信生成，则异步触发AI回信生成
            if status == .sent && shouldTriggerAIReply {
                // 检查是否已经寄出过，防止重复寄出
                let historyItem = historyItems[index]
                let wasAlreadySent = historyItem.emotionEntry.sentDate != nil || historyItem.emotionEntry.hasAIReply
                
                if !wasAlreadySent {
                    Task {
                        let result = await sendEmotionEntry(for: itemId)
                        await MainActor.run {
                            print("AI回信结果: \(result)")
                        }
                    }
                } else {
                    print("⚠️ [HistoryViewModel] 记录已寄出过，跳过重复寄出操作")
                }
            }
        }
    }
    
    // 删除历史记录项目
    func deleteHistoryItem(with itemId: UUID) {
        historyItems.removeAll { $0.id == itemId }
        // 保存变更到持久化存储
        saveHistoryItems()
    }
    
    // 移动项目到列表最后
    func moveToLast(itemId: UUID) {
        if let index = historyItems.firstIndex(where: { $0.id == itemId }) {
            let item = historyItems.remove(at: index)
            historyItems.append(item)
            // 保存变更到持久化存储
            saveHistoryItems()
        }
    }
    
    // 添加新的历史记录项
    func addHistoryItem(emotionEntry: EmotionEntry) -> UUID {
        let newItem = EmotionHistoryItem(emotionEntry: emotionEntry, actionStatus: .normal)
        historyItems.insert(newItem, at: 0)
        print("📝 [HistoryViewModel] 添加新历史记录项")
        print("📝 [HistoryViewModel] 历史记录项ID: \(newItem.id.uuidString)")
        print("📝 [HistoryViewModel] 情绪记录ID: \(emotionEntry.id.uuidString)")
        print("📝 [HistoryViewModel] 记录详情: 日期=\(emotionEntry.date), 地点=\(emotionEntry.place)")
        print("📝 [HistoryViewModel] 总历史记录数: \(historyItems.count)")
        // 保存变更到持久化存储
        saveHistoryItems()
        return newItem.id
    }
    
    // 更新历史记录项
    func updateHistoryItem(itemId: UUID, newEntry: EmotionEntry) {
        if let index = historyItems.firstIndex(where: { $0.id == itemId }) {
            historyItems[index] = EmotionHistoryItem(
                id: itemId,
                emotionEntry: newEntry,
                actionStatus: historyItems[index].actionStatus
            )
            // 保存变更到持久化存储
            saveHistoryItems()
        }
    }
    
    // 加载历史记录数据
    func loadHistoryData() {
        // 只在首次加载时加载数据
        if !isDataLoaded {
            // 从持久化存储加载数据
            loadHistoryItems()
            
            // 不再创建模拟数据，应用初始状态为空列表
            print("✓ 历史记录初始化完成，当前记录数: \(historyItems.count)")
            
            isDataLoaded = true
        }
    }
    
    
    // 清空搜索
    func clearSearch() {
        searchText = ""
        selectedDate = nil
        isSearching = false
    }
    
    // 处理寄出操作并触发AI回信
    func sendEmotionEntry(for itemId: UUID) async -> String {
        guard let index = historyItems.firstIndex(where: { $0.id == itemId }) else {
            return "找不到对应的记录"
        }
        
        let historyItem = historyItems[index]
        
        // 创建带有寄出信息的新EmotionEntry
        let updatedEntry = EmotionEntry(
            date: historyItem.emotionEntry.date,
            place: historyItem.emotionEntry.place,
            people: historyItem.emotionEntry.people,
            whatHappened: historyItem.emotionEntry.whatHappened,
            think: historyItem.emotionEntry.think,
            feel: historyItem.emotionEntry.feel,
            reaction: historyItem.emotionEntry.reaction,
            need: historyItem.emotionEntry.need,
            recordSeverity: historyItem.emotionEntry.recordSeverity,
            why: historyItem.emotionEntry.why,
            ifElse: historyItem.emotionEntry.ifElse,
            nextTime: historyItem.emotionEntry.nextTime,
            processSeverity: historyItem.emotionEntry.processSeverity,
            sentDate: Date(), // 设置寄出时间
            replyTone: nil,   // 测试模式使用随机语气
            hasAIReply: false // 初始状态
        )
        
        // 更新历史记录
        updateHistoryItem(itemId: itemId, newEntry: updatedEntry)
        
        // 触发AI回信生成
        let replyResult = await aiReplyService.generateReply(for: updatedEntry)
        
        // 在测试模式下，立即将回信添加到收件箱
        if aiReplyService.isInTestMode {
            // 通知InboxViewModel有新的AI回信
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiReplyGenerated,
                    object: nil,
                    userInfo: [
                        "emotionEntryId": updatedEntry.id.uuidString,
                        "replyContent": replyResult,
                        "tone": "warm"  // 使用具体的语气而不是"random"
                    ]
                )
                
                print("🔔 [HistoryViewModel] 已发送AI回信生成通知")
            }
        }
        
        return replyResult
    }
    
    // 初始化通知监听
    func setupNotificationObservers() {
        // 监听通知权限请求
        Task {
            await notificationService.requestNotificationPermission()
        }
        
        // 运行API连接测试
        Task {
            await aiReplyService.testAPIConnection()
        }
        
        // 监听数据清空通知
        NotificationCenter.default.addObserver(
            forName: .dataCleared,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDataCleared()
        }
        
        // 监听打开情绪详情通知
        NotificationCenter.default.addObserver(
            forName: .openEmotionDetail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleOpenEmotionDetail(notification)
        }
    }
    
    // 处理数据清空通知
    private func handleDataCleared() {
        // 清空内存中的数据
        historyItems.removeAll()
        
        // 重置搜索状态
        searchText = ""
        selectedDate = nil
        isSearching = false
        
        print("📥 [HistoryViewModel] 收到数据清空通知，已清空所有历史记录")
    }
    
    // 处理打开情绪详情通知
    private func handleOpenEmotionDetail(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let emotionEntryIdString = userInfo["emotionEntryId"] as? String,
              let emotionEntryId = UUID(uuidString: emotionEntryIdString) else {
            print("❌ [HistoryViewModel] 无效的情绪记录ID")
            return
        }
        
        print("📱 [HistoryViewModel] 收到打开详情页通知，ID: \(emotionEntryIdString)")
        
        // 查找对应的历史记录项
        if let historyItem = historyItems.first(where: { $0.emotionEntry.id == emotionEntryId }) {
            // 使用DispatchQueue确保在主线程上执行UI更新
            DispatchQueue.main.async { [weak self] in
                // 通过HistoryView的selectedDetailItem触发导航
                NotificationCenter.default.post(
                    name: .navigateToDetailInHistory,
                    object: nil,
                    userInfo: ["historyItem": historyItem]
                )
            }
            print("✅ [HistoryViewModel] 找到对应历史记录，触发导航到详情页")
        } else {
            print("⚠️ [HistoryViewModel] 未找到对应的历史记录项，ID: \(emotionEntryIdString)")
        }
    }
    
    // MARK: - 持久化存储方法
    
    // 保存历史记录到UserDefaults
    private func saveHistoryItems() {
        do {
            let data = try JSONEncoder().encode(historyItems)
            UserDefaults.standard.set(data, forKey: "HistoryItems")
            print("💾 [HistoryViewModel] 已保存 \(historyItems.count) 条历史记录")
        } catch {
            print("❌ [HistoryViewModel] 保存历史记录失败: \(error)")
        }
    }
    
    // 从UserDefaults加载历史记录
    private func loadHistoryItems() {
        guard let data = UserDefaults.standard.data(forKey: "HistoryItems") else {
            print("📥 [HistoryViewModel] 没有找到已保存的历史记录")
            return
        }
        
        do {
            historyItems = try JSONDecoder().decode([EmotionHistoryItem].self, from: data)
            print("📥 [HistoryViewModel] 成功加载 \(historyItems.count) 条历史记录")
        } catch {
            print("❌ [HistoryViewModel] 加载历史记录失败: \(error)")
            historyItems = []
        }
    }
    
    // MARK: - 快捷日期筛选方法
    
    // 检查本周是否有记录
    func hasRecordsInCurrentWeek() -> Bool {
        return getRecordCountInCurrentWeek() > 0
    }
    
    // 检查本月是否有记录
    func hasRecordsInCurrentMonth() -> Bool {
        return getRecordCountInCurrentMonth() > 0
    }
    
    // 检查本年是否有记录
    func hasRecordsInCurrentYear() -> Bool {
        return getRecordCountInCurrentYear() > 0
    }
    
    // 获取本周记录数量
    func getRecordCountInCurrentWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本周的开始和结束日期
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }
        
        return historyItems.filter { item in
            let itemDate = item.emotionEntry.date
            return itemDate >= weekInterval.start && itemDate < weekInterval.end
        }.count
    }
    
    // 获取本月记录数量
    func getRecordCountInCurrentMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本月的开始和结束日期
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            return 0
        }
        
        return historyItems.filter { item in
            let itemDate = item.emotionEntry.date
            return itemDate >= monthInterval.start && itemDate < monthInterval.end
        }.count
    }
    
    // 获取本年记录数量
    func getRecordCountInCurrentYear() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本年的开始和结束日期
        guard let yearInterval = calendar.dateInterval(of: .year, for: now) else {
            return 0
        }
        
        return historyItems.filter { item in
            let itemDate = item.emotionEntry.date
            return itemDate >= yearInterval.start && itemDate < yearInterval.end
        }.count
    }
    
    // 获取本周最早的记录日期
    func getFirstRecordDateInCurrentWeek() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本周的开始和结束日期
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return nil
        }
        
        let weekRecords = historyItems.filter { item in
            let itemDate = item.emotionEntry.date
            return itemDate >= weekInterval.start && itemDate < weekInterval.end
        }.sorted { $0.emotionEntry.date < $1.emotionEntry.date }
        
        return weekRecords.first?.emotionEntry.date
    }
    
    // 获取本月最早的记录日期
    func getFirstRecordDateInCurrentMonth() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本月的开始和结束日期
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            return nil
        }
        
        let monthRecords = historyItems.filter { item in
            let itemDate = item.emotionEntry.date
            return itemDate >= monthInterval.start && itemDate < monthInterval.end
        }.sorted { $0.emotionEntry.date < $1.emotionEntry.date }
        
        return monthRecords.first?.emotionEntry.date
    }
    
    // 获取本年最早的记录日期
    func getFirstRecordDateInCurrentYear() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本年的开始和结束日期
        guard let yearInterval = calendar.dateInterval(of: .year, for: now) else {
            return nil
        }
        
        let yearRecords = historyItems.filter { item in
            let itemDate = item.emotionEntry.date
            return itemDate >= yearInterval.start && itemDate < yearInterval.end
        }.sorted { $0.emotionEntry.date < $1.emotionEntry.date }
        
        return yearRecords.first?.emotionEntry.date
    }
}