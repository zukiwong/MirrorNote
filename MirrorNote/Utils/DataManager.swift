//
//  DataManager.swift
//  MirrorNote
//
//  数据管理工具类，提供统一的数据清空和管理功能
//

import Foundation

// MARK: - 通知名称扩展
extension Notification.Name {
    static let dataCleared = Notification.Name("dataCleared")
}

class DataManager {
    static let shared = DataManager()
    
    private init() {}
    
    // MARK: - 数据清空功能
    
    /// 清空所有应用数据
    /// - Parameter completion: 完成回调
    func clearAllData(completion: @escaping (Bool) -> Void) {
        // 清空历史记录数据
        clearHistoryData()
        
        // 清空收件箱数据
        clearInboxData()
        
        // 清空用户画像数据
        clearUserProfileData()
        
        // 重置数据清理标志
        resetDataCleanupFlags()
        
        // 清空设置数据（可选，根据需求决定）
        // clearSettingsData()
        
        // 发送通知给ViewModels刷新数据
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dataCleared, object: nil)
        }
        
        print("✅ [DataManager] 所有数据已成功清空")
        completion(true)
    }
    
    // MARK: - 具体数据清空方法
    
    /// 清空历史记录数据
    private func clearHistoryData() {
        UserDefaults.standard.removeObject(forKey: "HistoryItems")
        print("🗑️ [DataManager] 历史记录数据已清空")
    }
    
    /// 清空收件箱数据
    private func clearInboxData() {
        UserDefaults.standard.removeObject(forKey: "InboxMessages")
        print("🗑️ [DataManager] 收件箱数据已清空")
    }
    
    /// 重置数据清理标志
    private func resetDataCleanupFlags() {
        UserDefaults.standard.removeObject(forKey: "hasCleanedInitialData")
        print("🗑️ [DataManager] 数据清理标志已重置")
    }
    
    /// 清空设置数据（谨慎使用）
    private func clearSettingsData() {
        UserDefaults.standard.removeObject(forKey: "selectedReplyTone")
        UserDefaults.standard.removeObject(forKey: "selectedArchiveTime")
        print("🗑️ [DataManager] 设置数据已清空")
    }
    
    /// 清空用户画像数据
    private func clearUserProfileData() {
        UserDefaults.standard.removeObject(forKey: "UserProfile")
        UserDefaults.standard.removeObject(forKey: "UserProfileBackup")
        print("🗑️ [DataManager] 用户画像数据已清空")
    }
    
    // MARK: - 数据统计方法
    
    /// 获取历史记录数量
    func getHistoryItemsCount() -> Int {
        guard let data = UserDefaults.standard.data(forKey: "HistoryItems"),
              let items = try? JSONDecoder().decode([EmotionHistoryItem].self, from: data) else {
            return 0
        }
        return items.count
    }
    
    /// 获取收件箱消息数量
    func getInboxMessagesCount() -> Int {
        guard let data = UserDefaults.standard.data(forKey: "InboxMessages"),
              let messages = try? JSONDecoder().decode([InboxMessage].self, from: data) else {
            return 0
        }
        return messages.count
    }
    
    /// 获取用户画像数据大小（字节）
    func getUserProfileDataSize() -> Int {
        guard let data = UserDefaults.standard.data(forKey: "UserProfile") else {
            return 0
        }
        return data.count
    }
    
    /// 检查是否存在用户画像数据
    func hasUserProfileData() -> Bool {
        return UserDefaults.standard.data(forKey: "UserProfile") != nil
    }
    
    /// 获取用户画像创建时间
    func getUserProfileCreatedDate() -> Date? {
        guard let data = UserDefaults.standard.data(forKey: "UserProfile") else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let profile = try decoder.decode(UserProfile.self, from: data)
            return profile.createdDate
        } catch {
            print("❌ [DataManager] 解析用户画像创建时间失败: \(error)")
            return nil
        }
    }
    
    /// 获取用户画像标签数量
    func getUserProfileTagsCount() -> Int {
        guard let data = UserDefaults.standard.data(forKey: "UserProfile") else {
            return 0
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let profile = try decoder.decode(UserProfile.self, from: data)
            return profile.personalTags.count
        } catch {
            print("❌ [DataManager] 解析用户画像标签数量失败: \(error)")
            return 0
        }
    }
    
    /// 检查是否有任何数据
    func hasAnyData() -> Bool {
        return getHistoryItemsCount() > 0 || getInboxMessagesCount() > 0 || hasUserProfileData()
    }
    
    // MARK: - 数据备份和恢复（未来功能）
    
    /// 导出数据到文件（预留接口）
    func exportDataToFile() -> URL? {
        // TODO: 实现数据导出功能
        return nil
    }
    
    /// 从文件导入数据（预留接口）
    func importDataFromFile(_ url: URL) -> Bool {
        // TODO: 实现数据导入功能
        return false
    }
}