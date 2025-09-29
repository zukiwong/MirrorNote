import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    // 请求通知权限
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    // 检查通知权限状态
    func checkNotificationPermission() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    // 发送AI回信通知
    func sendReplyNotification(for aiReply: AIReply) async {
        // 检查权限
        let status = await checkNotificationPermission()
        guard status == .authorized else {
            print("Notification permission not authorized")
            return
        }
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "New Reply Received"
        content.subtitle = "From your AI friend"
        
        // 预览回信内容（限制在50字以内）
        let previewText = String(aiReply.content.prefix(50))
        content.body = previewText + (aiReply.content.count > 50 ? "..." : "")
        
        // 设置声音
        content.sound = .default
        
        // 设置角标
        content.badge = 1
        
        // 添加用户信息
        content.userInfo = [
            "replyId": aiReply.id.uuidString,
            "emotionEntryId": aiReply.emotionEntryId.uuidString,
            "type": "ai_reply"
        ]
        
        // 创建通知标识符
        let identifier = "ai_reply_\(aiReply.id.uuidString)"
        
        // 立即发送通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("AI reply notification sent")
        } catch {
            print("Failed to send AI reply notification: \(error)")
        }
    }
    
    // 安排延迟通知（用于正式模式）
    func scheduleDelayedReplyNotification(for aiReply: AIReply, at deliveryTime: Date) async {
        // 检查权限
        let status = await checkNotificationPermission()
        guard status == .authorized else {
            print("Notification permission not authorized")
            return
        }
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "New Reply Received"
        content.subtitle = "From your AI friend"
        
        // 预览回信内容
        let previewText = String(aiReply.content.prefix(50))
        content.body = previewText + (aiReply.content.count > 50 ? "..." : "")
        
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "replyId": aiReply.id.uuidString,
            "emotionEntryId": aiReply.emotionEntryId.uuidString,
            "type": "ai_reply"
        ]
        
        // 创建日期触发器
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: deliveryTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "ai_reply_\(aiReply.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled delayed notification for \(deliveryTime)")
        } catch {
            print("Failed to schedule delayed notification: \(error)")
        }
    }
    
    // 取消特定通知
    func cancelNotification(with identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // 取消所有待发送的通知
    func cancelAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // 清除所有已发送的通知
    func clearAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // 设置通知角标
    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
    
    // 获取待发送的通知数量
    func getPendingNotificationCount() async -> Int {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.count
    }
    
    // 获取已发送的通知数量
    func getDeliveredNotificationCount() async -> Int {
        let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
        return notifications.count
    }
}

// 通知处理委托
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    // 在前台时收到通知的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // 显示通知横幅、声音和角标
        completionHandler([.banner, .sound, .badge])
    }
    
    // 用户点击通知的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        // 检查通知类型
        if let type = userInfo["type"] as? String, type == "ai_reply" {
            // AI回信通知被点击
            if let replyId = userInfo["replyId"] as? String {
                // 通知应用跳转到收件箱
                NotificationCenter.default.post(
                    name: .openInbox,
                    object: nil,
                    userInfo: ["replyId": replyId]
                )
            }
        }
        
        completionHandler()
    }
}

// 通知名称扩展
extension Notification.Name {
    static let openInbox = Notification.Name("openInbox")
    static let openEmotionDetail = Notification.Name("openEmotionDetail")
    static let navigateToDetailInHistory = Notification.Name("navigateToDetailInHistory")
    static let openEmotionDetailFromHome = Notification.Name("openEmotionDetailFromHome")
}