// MirrorNote/Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @StateObject var contextVM = EmotionContextViewModel()
    @StateObject var historyVM = HistoryViewModel()
    @StateObject var inboxVM = InboxViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeView()
                    .environmentObject(contextVM)
                    .environmentObject(historyVM)
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Force single stack style to avoid iPad split view issues
                .tabItem {
                    Image("tab-home")
                    Text("Home")
                }
                .tag(0)
            HistoryView()
                .environmentObject(historyVM)
                .tabItem {
                    Image("tab-history")
                    Text("History")
                }
                .tag(1)
            InboxView()
                .environmentObject(inboxVM)
                .tabItem {
                    Image("tab-inbox")
                    Text("Inbox")
                }
                .tag(2)
            SettingView()
                .tabItem {
                    Image("tab-settings")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.red)
        .background(Color("PrimaryBackground"))
        .onAppear {
            // 配置Tab Bar外观
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.clear
            
            // 添加模糊效果
            let blurEffect = UIBlurEffect(style: .systemMaterial)
            let blurView = UIVisualEffectView(effect: blurEffect)
            appearance.backgroundEffect = blurEffect
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .onReceive(NotificationCenter.default.publisher(for: .openInbox)) { notification in
            // Switch to inbox tab when receiving open inbox notification
            selectedTab = 2
            
            // Forward notification to InboxViewModel (handled automatically through environment object)
            // InboxViewModel will navigate to specific reply based on notification content
            print("📱 [MainTabView] Received open inbox notification, switching to inbox tab")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openEmotionDetail)) { notification in
            // Switch to history tab when receiving open emotion detail notification
            selectedTab = 1
            
            // Forward notification to HistoryViewModel (handled automatically through environment object)
            // HistoryViewModel will navigate to specific detail based on notification content
            print("📱 [MainTabView] Received open emotion detail notification, switching to history tab")
        }
    }
}