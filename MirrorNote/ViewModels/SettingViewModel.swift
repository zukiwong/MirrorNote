// MirrorNote/ViewModels/SettingViewModel.swift
import Foundation
import SwiftUI

// Reply tone options
enum ReplyTone: String, CaseIterable {
    case gentle = "Gentle Companion"
    case rational = "Rational Friend"
    case philosopher = "Philosopher"
    case soft = "Soft-hearted"
    case stern = "Stern & Sincere"
    case random = "Random Personality"
    
    var description: String {
        switch self {
        case .gentle: return "I know you've done your best"
        case .rational: return "I understand you, but we can work together to find solutions"
        case .philosopher: return "What you're experiencing isn't wrong, it's change"
        case .soft: return "I care about your feelings, even if you haven't figured it out yet..."
        case .stern: return "You need to face reality, but you can do it"
        case .random: return ""
        }
    }
    
    // 映射到AIReplyTone枚举
    var toAIReplyTone: AIReplyTone {
        switch self {
        case .gentle:
            return .gentle      // 温柔陪伴 → 温和平静
        case .rational:
            return .understanding // 理性朋友 → 理解包容
        case .philosopher:
            return .philosophical // 哲学家 → 哲学思辨
        case .soft:
            return .empathetic   // 心软派 → 共情理解
        case .stern:
            return .supportive   // 严厉真诚 → 支持陪伴（比鼓励更适合"严厉真诚"的含义）
        case .random:
            // 随机人格 → 从所有可用语气中随机选择
            return AIReplyTone.allCases.randomElement() ?? .warm
        }
    }
}

// Archive time options
enum ArchiveTime: String, CaseIterable {
    case oneWeek = "After 1 week"
    case oneMonth = "After 1 month"
    case threeMonths = "After 3 months"
    case halfYear = "After 6 months"
    case oneYear = "After 1 year"
    case twoYears = "After 2 years"
    case threeYears = "After 3 years"
    
    // Calculate archive end date from specified start date
    func archiveEndDate(from startDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .oneWeek:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .oneMonth:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .threeMonths:
            return calendar.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        case .halfYear:
            return calendar.date(byAdding: .month, value: 6, to: startDate) ?? startDate
        case .oneYear:
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        case .twoYears:
            return calendar.date(byAdding: .year, value: 2, to: startDate) ?? startDate
        case .threeYears:
            return calendar.date(byAdding: .year, value: 3, to: startDate) ?? startDate
        }
    }
    
    // Get confirmation text
    var confirmationText: String {
        switch self {
        case .oneWeek:
            return "Confirm archive for 1 week?"
        case .oneMonth:
            return "Confirm archive for 1 month?"
        case .threeMonths:
            return "Confirm archive for 3 months?"
        case .halfYear:
            return "Confirm archive for 6 months?"
        case .oneYear:
            return "Confirm archive for 1 year?"
        case .twoYears:
            return "Confirm archive for 2 years?"
        case .threeYears:
            return "Confirm archive for 3 years?"
        }
    }
}

class SettingViewModel: ObservableObject {
    // 折叠状态管理
    @Published var isReplyToneExpanded: Bool = false
    @Published var isArchiveTimeExpanded: Bool = false
    @Published var isDataManagementExpanded: Bool = false
    
    // 数据管理相关状态
    @Published var showClearDataAlert: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var isClearingData: Bool = false
    
    // 回信语气设置（单选）
    @Published var selectedReplyTone: ReplyTone? = .gentle
    
    // 封存时间设置（单选）
    @Published var selectedArchiveTime: ArchiveTime = .halfYear
    
    // 设置项是否被选中
    func isReplyToneSelected(_ tone: ReplyTone) -> Bool {
        return selectedReplyTone == tone
    }
    
    // 获取当前选择的AI语气
    func getCurrentAIReplyTone() -> AIReplyTone {
        return selectedReplyTone?.toAIReplyTone ?? .warm
    }
    
    // 获取当前选择的封存时间
    func getCurrentArchiveTime() -> ArchiveTime {
        return selectedArchiveTime
    }
    
    // 设置回信语气选择
    func setReplyTone(_ tone: ReplyTone) {
        selectedReplyTone = tone
        saveSettings()
    }
    
    // 设置封存时间
    func setArchiveTime(_ time: ArchiveTime) {
        selectedArchiveTime = time
        saveSettings()
    }
    
    // 切换回信语气展开状态
    func toggleReplyToneExpansion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isReplyToneExpanded.toggle()
        }
    }
    
    // 切换封存设置展开状态
    func toggleArchiveTimeExpansion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isArchiveTimeExpanded.toggle()
        }
    }
    
    // 切换数据管理展开状态
    func toggleDataManagementExpansion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDataManagementExpanded.toggle()
        }
    }
    
    // MARK: - 数据管理功能
    
    /// 显示清空数据确认对话框
    func showClearDataConfirmation() {
        showClearDataAlert = true
    }
    
    /// 执行清空所有数据操作
    func clearAllData() {
        isClearingData = true
        
        DataManager.shared.clearAllData { [weak self] success in
            DispatchQueue.main.async {
                self?.isClearingData = false
                if success {
                    self?.showSuccessAlert = true
                } else {
                    // 可以在这里添加失败提示
                }
            }
        }
    }
    
    /// 获取当前数据统计信息
    func getDataStatistics() -> (historyCount: Int, inboxCount: Int) {
        return (
            historyCount: DataManager.shared.getHistoryItemsCount(),
            inboxCount: DataManager.shared.getInboxMessagesCount()
        )
    }
    
    /// 检查是否有数据可以清空
    var hasDataToClear: Bool {
        return DataManager.shared.hasAnyData()
    }
    
    // 保存设置到 UserDefaults
    private func saveSettings() {
        if let selectedReplyTone = selectedReplyTone {
            UserDefaults.standard.set(selectedReplyTone.rawValue, forKey: "selectedReplyTone")
        }
        UserDefaults.standard.set(selectedArchiveTime.rawValue, forKey: "selectedArchiveTime")
    }
    
    // 从 UserDefaults 加载设置
    func loadSettings() {
        if let toneRawValue = UserDefaults.standard.string(forKey: "selectedReplyTone"),
           let tone = ReplyTone(rawValue: toneRawValue) {
            selectedReplyTone = tone
        }
        
        if let archiveTimeRawValue = UserDefaults.standard.string(forKey: "selectedArchiveTime"),
           let archiveTime = ArchiveTime(rawValue: archiveTimeRawValue) {
            selectedArchiveTime = archiveTime
        }
    }
    
    init() {
        loadSettings()
    }
}