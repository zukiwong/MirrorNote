import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: HistoryViewModel
    @State private var showingSearchDatePicker = false
    @State private var showingSuccessToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = ""
    @State private var selectedDetailItem: EmotionHistoryItem? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom title bar
                titleSection
                
                // Search bar
                searchSection
                
                // History list
                historyListSection
            }
            .navigationBarHidden(true)
            .onTapGesture {
                // 点击页面任意区域取消选择操作
                cancelSelecting()
            }
            .onAppear {
                viewModel.loadHistoryData()
                viewModel.setupNotificationObservers()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToDetailInHistory)) { notification in
                // 处理导航到详情页的通知
                if let userInfo = notification.userInfo,
                   let historyItem = userInfo["historyItem"] as? EmotionHistoryItem {
                    print("📱 [HistoryView] 收到导航到详情页通知，开始导航")
                    selectedDetailItem = historyItem
                }
            }
        }
        .successToast(
            isPresented: $showingSuccessToast,
            message: toastMessage,
            icon: toastIcon
        )
    }
    
    // Title area
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(3)
                    
                    Text("LONG PRESS CARDS TO MANAGE")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(3)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 21)
            .background(Color("PrimaryBackground"))
        }
    }
    
    // Search bar area
    private var searchSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Logo
                Image(systemName: "circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color("PrimaryText"))
                    .frame(width: 24, height: 24)
                
                // Divider
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(width: 1, height: 24)
                
                // Search input field
                TextField("Search keywords...", text: $viewModel.searchText)
                    .font(.system(size: 16))
                    .textFieldStyle(PlainTextFieldStyle())
                    .onTapGesture {
                        viewModel.isSearching = true
                    }
                
                // Clear button
                if !viewModel.searchText.isEmpty || viewModel.selectedDate != nil {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                
                // Date selection button
                Button(action: {
                    showingSearchDatePicker.toggle()
                }) {
                    Image(systemName: viewModel.selectedDate != nil ? "calendar.badge.checkmark" : "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.selectedDate != nil ? .blue : Color("PrimaryText"))
                }
                .popover(isPresented: $showingSearchDatePicker) {
                    VStack(spacing: 16) {
                        DatePicker(
                            "Select Date",
                            selection: Binding(
                                get: { viewModel.selectedDate ?? Date() },
                                set: { viewModel.selectedDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        
                        // 快捷日期选择按钮组
                        HStack(spacing: 0) {
                            // 本周记录按钮
                            Button(action: {
                                if let firstDate = viewModel.getFirstRecordDateInCurrentWeek() {
                                    viewModel.selectedDate = firstDate
                                    showingSearchDatePicker = false
                                }
                            }) {
                                Text("本周记录 (\(viewModel.getRecordCountInCurrentWeek()))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.hasRecordsInCurrentWeek() ? Color("PrimaryText") : Color("SecondaryText"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color("SecondaryBackground"))
                            }
                            .disabled(!viewModel.hasRecordsInCurrentWeek())
                            
                            // 分隔线
                            Rectangle()
                                .fill(Color("DividerColor"))
                                .frame(width: 1, height: 20)
                            
                            // 本月记录按钮
                            Button(action: {
                                if let firstDate = viewModel.getFirstRecordDateInCurrentMonth() {
                                    viewModel.selectedDate = firstDate
                                    showingSearchDatePicker = false
                                }
                            }) {
                                Text("本月记录 (\(viewModel.getRecordCountInCurrentMonth()))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.hasRecordsInCurrentMonth() ? Color("PrimaryText") : Color("SecondaryText"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color("SecondaryBackground"))
                            }
                            .disabled(!viewModel.hasRecordsInCurrentMonth())
                            
                            // 分隔线
                            Rectangle()
                                .fill(Color("DividerColor"))
                                .frame(width: 1, height: 20)
                            
                            // 本年记录按钮
                            Button(action: {
                                if let firstDate = viewModel.getFirstRecordDateInCurrentYear() {
                                    viewModel.selectedDate = firstDate
                                    showingSearchDatePicker = false
                                }
                            }) {
                                Text("本年记录 (\(viewModel.getRecordCountInCurrentYear()))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.hasRecordsInCurrentYear() ? Color("PrimaryText") : Color("SecondaryText"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color("SecondaryBackground"))
                            }
                            .disabled(!viewModel.hasRecordsInCurrentYear())
                        }
                        .background(Color("SecondaryBackground"))
                        .cornerRadius(8)
                        
                        // 原有的Clear Date和OK按钮
                        HStack {
                            Button("Clear Date") {
                                viewModel.selectedDate = nil
                                showingSearchDatePicker = false
                            }
                            .foregroundColor(.red)
                            
                            Spacer()
                            
                            Button("OK") {
                                showingSearchDatePicker = false
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
                
                // Search icon
                Image("icon-search")
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 100)
                    .stroke(Color("DividerColor"), lineWidth: 2)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            
            // 分割线
            Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 1)
                .padding(.horizontal, 24)
        }
        .background(Color("PrimaryBackground"))
    }
    
    // History list area
    private var historyListSection: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 24),
                GridItem(.flexible(), spacing: 24)
            ], spacing: 24) {
                ForEach(viewModel.filteredHistoryItems) { historyItem in
                    EmotionHistoryCard(
                        historyItem: historyItem,
                        onTap: {
                            // 点击正常状态、封存状态和已寄出状态跳转详情页
                            if historyItem.actionStatus == .normal || historyItem.actionStatus == .locked || historyItem.actionStatus == .sent {
                                navigateToDetail(historyItem)
                            }
                        },
                        onLongPress: {
                            // 长按进入选择状态
                            if historyItem.actionStatus == .normal || historyItem.actionStatus == .sent {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    viewModel.updateActionStatus(for: historyItem.id, to: .selecting)
                                }
                            }
                        },
                        onSelectAction: { action in
                            // 选择操作后进入确认状态
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                viewModel.updateActionStatus(for: historyItem.id, to: action)
                            }
                        },
                        onConfirmTap: {
                            // 点击确认状态执行最终操作
                            handleFinalAction(for: historyItem)
                        },
                        onViewReply: {
                            // 查看回信，跳转到收件箱
                            navigateToInbox(emotionEntryId: historyItem.emotionEntry.id.uuidString)
                        }
                    )
                    .background(
                        // 程序化导航
                        NavigationLink(
                            destination: selectedDetailItem != nil ? EmotionDetailView(historyItem: selectedDetailItem!).environmentObject(viewModel) : nil,
                            isActive: Binding(
                                get: { selectedDetailItem?.id == historyItem.id },
                                set: { _ in selectedDetailItem = nil }
                            )
                        ) {
                            EmptyView()
                        }
                        .opacity(0)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        //.background(Color(red: 0.95, green: 0.95, blue: 0.95))
    }
    
    // 导航到详情页
    private func navigateToDetail(_ historyItem: EmotionHistoryItem) {
        selectedDetailItem = historyItem
    }
    
    // 导航到收件箱
    private func navigateToInbox(emotionEntryId: String? = nil) {
        // 发送通知让MainTabView切换到收件箱标签
        var userInfo: [String: Any] = [:]
        if let emotionEntryId = emotionEntryId {
            userInfo["emotionEntryId"] = emotionEntryId
        }
        
        NotificationCenter.default.post(name: .openInbox, object: nil, userInfo: userInfo)
        
        // 显示确认提示
        toastMessage = "Navigated to Inbox"
        toastIcon = "envelope"
        showingSuccessToast = true
    }
    
    // 显示成功提示
    private func showSuccessToast(for status: ActionStatus) {
        switch status {
        case .discarded:
            toastMessage = "Successfully discarded"
            toastIcon = "trash"
        case .sent:
            toastMessage = "Successfully sent"
            toastIcon = "paperplane"
        case .sealed:
            toastMessage = "Successfully sealed"
            toastIcon = "archivebox.fill"
        default:
            return
        }
        
        showingSuccessToast = true
    }
    
    // 取消选择操作
    private func cancelSelecting() {
        // 将所有处于selecting和确认状态的卡片返回适当的状态
        for item in viewModel.filteredHistoryItems {
            if item.actionStatus == .selecting || 
               item.actionStatus == .discardingConfirm ||
               item.actionStatus == .sendingConfirm ||
               item.actionStatus == .sealingConfirm {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    // 根据情绪记录的寄出状态决定恢复到什么状态
                    let wasAlreadySent = item.emotionEntry.sentDate != nil || item.emotionEntry.hasAIReply
                    let targetStatus: ActionStatus = wasAlreadySent ? .sent : .normal
                    // 状态恢复时不触发AI回信生成，避免重复寄出
                    viewModel.updateActionStatus(for: item.id, to: targetStatus, shouldTriggerAIReply: false)
                }
            }
        }
    }
    
    // 处理最终操作
    private func handleFinalAction(for historyItem: EmotionHistoryItem) {
        switch historyItem.actionStatus {
        case .discarded:
            // 丢弃：显示成功提示（已经是最终状态）
            showSuccessToast(for: .discarded)
        case .discardingConfirm:
            // 丢弃确认：从列表删除
            viewModel.deleteHistoryItem(with: historyItem.id)
        case .sent:
            // 寄出：显示成功提示（已经是最终状态）
            showSuccessToast(for: .sent)
        case .sendingConfirm:
            // 寄出确认：变成已寄出状态并更新寄出时间（AI回信生成会在状态更新时自动触发）
            viewModel.updateActionStatus(for: historyItem.id, to: .sent)
            
            // 同时更新emotionEntry的sentDate字段，确保数据一致性
            let updatedEntry = EmotionEntry(
                id: historyItem.emotionEntry.id,
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
                sentDate: Date(), // 设置寄出时间为当前时间
                replyTone: historyItem.emotionEntry.replyTone,
                hasAIReply: historyItem.emotionEntry.hasAIReply
            )
            viewModel.updateHistoryItem(itemId: historyItem.id, newEntry: updatedEntry)
            
            showSuccessToast(for: .sent)
        case .sealed:
            // 封存：显示成功提示（已经是最终状态）
            showSuccessToast(for: .sealed)
        case .sealingConfirm:
            // 封存确认：变成锁定状态并移到列表最后
            viewModel.updateActionStatus(for: historyItem.id, to: .locked)
            viewModel.moveToLast(itemId: historyItem.id)
            showSuccessToast(for: .sealed)
        default:
            break
        }
    }
}

