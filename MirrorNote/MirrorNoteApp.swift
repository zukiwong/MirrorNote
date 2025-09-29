//
//  MirrorNoteApp.swift
//  MirrorNote
//
//  Created by 王老吉 on 14/07/2025.
//

import SwiftUI
import UserNotifications
import FirebaseCore

@main
struct MirrorNoteApp: App {
    
    // 注册 Firebase 设置的应用代理
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

// 应用委托
class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationDelegate = NotificationDelegate()
    
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 初始化 Firebase 
        FirebaseApp.configure()
        
        // 初始化 Prompt 管理系统
        Task {
            do {
                try await PromptManager.shared.initialize()
                print("✅ [MirrorNoteApp] Prompt 管理系统初始化成功")
                
                // 运行系统测试（仅在 Debug 模式）
                #if DEBUG
                await PromptSystemTest.runSystemTest()
                #endif
                
            } catch {
                print("❌ [MirrorNoteApp] Prompt 管理系统初始化失败: \(error)")
            }
        }

        // 设置通知委托
        UNUserNotificationCenter.current().delegate = notificationDelegate
        
        // 请求通知权限
        Task {
            await NotificationService.shared.requestNotificationPermission()
        }
        
        return true
    }
}

