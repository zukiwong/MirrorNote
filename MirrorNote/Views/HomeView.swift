// MirrorNote/Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var contextVM: EmotionContextViewModel
    @EnvironmentObject var historyVM: HistoryViewModel
    @State private var selectedTab: Int = 0
    @State private var recordVM = RecordEmotionViewModel()
    @State private var processVM = ProcessEmotionViewModel()
    @State private var selectedDetailItem: EmotionHistoryItem? = nil
    
    // Method to switch to next tab
    func switchToNextTab() {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.9, blendDuration: 0)) {
            selectedTab = 1
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top switcher bar - using system safe area
            HStack {
                Button(action: { 
                    withAnimation(.spring(response: 0.9, dampingFraction: 1.2, blendDuration: 0)) {
                        selectedTab = 0
                    }
                }) {
                    HStack(spacing: 4) {
                        Image("mode-record")
                        Text("JOURNAL")
                    }
                    .foregroundColor(selectedTab == 0 ? .red : .primary)
                    .fontWeight(selectedTab == 0 ? .bold : .regular)
                }
                .frame(maxWidth: .infinity)
                Button(action: { 
                    withAnimation(.spring(response: 0.9, dampingFraction: 0.9, blendDuration: 0)) {
                        selectedTab = 1
                    }
                }) {
                    HStack(spacing: 4) {
                        Image("mode-process")
                        Text("REFLECT")
                    }
                    .foregroundColor(selectedTab == 1 ? .red : .primary)
                    .fontWeight(selectedTab == 1 ? .bold : .regular)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Main content with horizontal swiping
            TabView(selection: $selectedTab) {
                RecordEmotionPage(vm: recordVM, onNextStep: switchToNextTab)
                    .tag(0)
                ProcessEmotionPage(vm: processVM, recordVM: recordVM)
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: selectedTab) { newTab in
                // Temporarily save first page content when user switches from first to second page (if has content)
                if newTab == 1 && recordVM.hasAnyContent {
                    recordVM.saveToContextTemporary(contextVM: contextVM, historyVM: historyVM)
                }
            }
        }
        .background(Color(.systemBackground))
        .background(
            // 隐藏的导航链接用于程序化导航到详情页
            NavigationLink(
                destination: selectedDetailItem != nil ? 
                    EmotionDetailView(historyItem: selectedDetailItem!)
                        .environmentObject(historyVM) : nil,
                isActive: Binding(
                    get: { selectedDetailItem != nil },
                    set: { _ in selectedDetailItem = nil }
                )
            ) {
                EmptyView()
            }
            .opacity(0)
        )
        .onAppear {
            selectedTab = 0  // Ensure always showing first page when returning from detail view
            
            // 修复Tab栏模糊效果：延迟执行确保nested TabView不干扰
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let tabBarController = windowScene.windows.first?.rootViewController?.children.first(where: { $0 is UITabBarController }) as? UITabBarController {
                    
                    let appearance = UITabBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor.clear
                    
                    // 添加模糊效果
                    let blurEffect = UIBlurEffect(style: .systemMaterial)
                    appearance.backgroundEffect = blurEffect
                    
                    // 直接应用到实际的TabBarController
                    tabBarController.tabBar.standardAppearance = appearance
                    tabBarController.tabBar.scrollEdgeAppearance = appearance
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openEmotionDetailFromHome)) { notification in
            // 处理从首页直接跳转到详情页的通知
            if let userInfo = notification.userInfo,
               let historyItemIdString = userInfo["emotionEntryId"] as? String,
               let historyItemId = UUID(uuidString: historyItemIdString) {
                
                print("📱 [HomeView] 收到从首页跳转详情页通知，历史记录项ID: \(historyItemIdString)")
                print("📱 [HomeView] 当前历史记录数量: \(historyVM.historyItems.count)")
                
                // 用历史记录项ID查找对应的记录
                if let historyItem = historyVM.historyItems.first(where: { $0.id == historyItemId }) {
                    selectedDetailItem = historyItem
                    print("✅ [HomeView] 找到对应记录，开始导航到详情页")
                    print("✅ [HomeView] 记录详情: 日期=\(historyItem.emotionEntry.date), 地点=\(historyItem.emotionEntry.place)")
                } else {
                    print("⚠️ [HomeView] 未找到对应的历史记录")
                    print("⚠️ [HomeView] 现有历史记录IDs: \(historyVM.historyItems.map { $0.id.uuidString.prefix(8) })")
                }
            }
        }
    }
}