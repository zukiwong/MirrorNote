import SwiftUI

// 手势状态枚举
enum GestureState {
    case idle          // 未开始
    case horizontal    // 水平滑动
    case vertical      // 垂直滑动
}

struct InboxView: View {
    @EnvironmentObject var viewModel: InboxViewModel
    @State private var animatingFeedback: FeedbackType? = nil
    @State private var cardOffset: CGFloat = 0 // 卡片偏移量
    @State private var screenWidth: CGFloat = 0 // 屏幕宽度
    @State private var gestureState: GestureState = .idle // 手势状态
    @State private var initialTranslation: CGSize = .zero // 初始移动距离
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部切换器
            replyToggleSection
            
            // 分割线
            Divider()
                .background(Color("DividerColor"))
                .padding(.horizontal, 24)
            
            // 主内容区域
            if !viewModel.isReplyEnabled {
                disabledReplySection
             } else if !viewModel.messages.isEmpty {
                messageContentSection
            } else {
                emptyStateSection
            }
        }
        .background(Color("PrimaryBackground"))
        .onAppear {
            viewModel.loadMessages()
            // 初始时如果有当前消息，标记为已读
            if let currentMessage = viewModel.currentMessage {
                viewModel.markAsRead(messageId: currentMessage.id)
            }
        }
        .onChange(of: viewModel.currentIndex) { newIndex in
            // 当切换到新消息时，标记为已读
            if let currentMessage = viewModel.currentMessage {
                viewModel.markAsRead(messageId: currentMessage.id)
            }
        }
    }
    
    // 顶部回信切换器
    private var replyToggleSection: some View {
        HStack {
            HStack(spacing: 2) {
                // Enable reply button
                Button(action: {
                    if !viewModel.isReplyEnabled {
                        viewModel.toggleReplyEnabled()
                    }
                }) {
                    Text("Enable Reply")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(viewModel.isReplyEnabled ? Color("PrimaryText") : Color("SecondaryText"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(viewModel.isReplyEnabled ? Color("PrimaryBackground") : Color.clear)
                        .cornerRadius(100)
                }
                
                // Disable reply button
                Button(action: {
                    if viewModel.isReplyEnabled {
                        viewModel.toggleReplyEnabled()
                    }
                }) {
                    Text("Disable Reply")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(!viewModel.isReplyEnabled ? Color("PrimaryText") : Color("SecondaryText"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(!viewModel.isReplyEnabled ? Color("PrimaryBackground") : Color.clear)
                        .cornerRadius(100)
                }
            }
            .padding(4)
            .background(Color("TertiaryBackground"))
            .cornerRadius(100)
            
            Spacer()
            
            // AI reply status display
            if viewModel.isReplyEnabled {
                VStack(alignment: .trailing, spacing: 2) {
                    if viewModel.aiReplyCount > 0 {
                        Text("AI Reply \(viewModel.aiReplyCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    if viewModel.unreadCount > 0 {
                        Text("Unread \(viewModel.unreadCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // 消息内容区域
    private var messageContentSection: some View {
        VStack(spacing: 0) {
            // 可滑动的信件卡片区域
            messageCardsSection
            
            // 页面指示器
            pageIndicatorSection
            
            Spacer()
            
            // 底部反馈按钮组
            feedbackButtonsSection
        }
    }
    
    // 可滑动的信件卡片区域
    private var messageCardsSection: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width - 48 // 主卡片宽度，占据大部分屏幕
            let cardSpacing: CGFloat = 8 // 较小的间距，让侧边卡片紧贴
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: cardSpacing) {
                    ForEach(0..<viewModel.messages.count, id: \.self) { index in
                        messageCard(message: viewModel.messages[index])
                            .frame(width: cardWidth)
                            .opacity(index == viewModel.currentIndex ? 1.0 : 0.6) // 当前卡片完全不透明，侧边卡片透明
                    }
                }
                .padding(.horizontal, 24) // 标准padding
                .offset(x: cardOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleGestureChanged(value: value)
                        }
                        .onEnded { value in
                            handleGestureEnded(value: value, cardWidth: cardWidth, spacing: cardSpacing)
                        }
                )
            }
            .onAppear {
                screenWidth = geometry.size.width
                // 初始化时设置正确的偏移量
                let cardTotalWidth = (screenWidth - 48) + 8
                cardOffset = -CGFloat(viewModel.currentIndex) * cardTotalWidth
            }
        }
        .frame(height: 500)
        .padding(.top, 16) // 缩小顶部间距，让卡片更靠近横线
        .mask(
            // 使用渐变遮罩来创建更自然的边缘效果
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0),
                            .init(color: Color.black, location: 0.05),
                            .init(color: Color.black, location: 0.95),
                            .init(color: Color.clear, location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
    
    // 页面指示器
    private var pageIndicatorSection: some View {
        HStack(spacing: 8) {
            if viewModel.messages.count <= 7 {
                // 消息数量少时，显示所有圆点
                ForEach(0..<viewModel.messages.count, id: \.self) { index in
                    Circle()
                        .fill(viewModel.currentIndex == index ? Color("PrimaryText") : Color("DividerColor"))
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.currentIndex == index ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
                }
            } else {
                // 消息数量多时，使用智能显示
                smartPageIndicator
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
    
    // 智能页面指示器
    private var smartPageIndicator: some View {
        HStack(spacing: 8) {
            let totalCount = viewModel.messages.count
            let currentIndex = viewModel.currentIndex
            
            // 计算左右剩余数量
            let leftCount = currentIndex // 当前邮件前面的数量
            let rightCount = max(0, totalCount - currentIndex - 1) // 当前邮件后面的数量
            
            // 左侧剩余数量
            if leftCount > 0 {
                Text("\(leftCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            
            if currentIndex <= 2 {
                // 在前几个位置时，显示前5个 + 省略号
                ForEach(0..<min(5, totalCount), id: \.self) { index in
                    indicatorDot(index: index)
                }
                if totalCount > 5 {
                    Text("•••")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                }
            } else if currentIndex >= totalCount - 3 {
                // 在后几个位置时，显示省略号 + 后5个
                Text("•••")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
                ForEach(max(0, totalCount - 5)..<totalCount, id: \.self) { index in
                    indicatorDot(index: index)
                }
            } else {
                // 在中间位置时，显示省略号 + 当前前后2个 + 省略号
                Text("•••")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
                ForEach(max(0, currentIndex - 2)...min(totalCount - 1, currentIndex + 2), id: \.self) { index in
                    indicatorDot(index: index)
                }
                Text("•••")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            // 右侧剩余数量
            if rightCount > 0 {
                Text("\(rightCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
    }
    
    // 指示器圆点
    private func indicatorDot(index: Int) -> some View {
        Circle()
            .fill(viewModel.currentIndex == index ? Color("PrimaryText") : Color("DividerColor"))
            .frame(width: 8, height: 8)
            .scaleEffect(viewModel.currentIndex == index ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
    }
    
    
    // 获取最近的卡片索引
    private func getNearestCardIndex(cardWidth: CGFloat, spacing: CGFloat) -> Int {
        let cardTotalWidth = cardWidth + spacing
        let adjustedOffset = -cardOffset
        let rawIndex = adjustedOffset / cardTotalWidth
        let nearestIndex = Int(round(rawIndex))
        return max(0, min(nearestIndex, viewModel.messages.count - 1))
    }
    
    // 吸附到指定卡片
    private func snapToCard(index: Int, cardWidth: CGFloat, spacing: CGFloat) {
        let cardTotalWidth = cardWidth + spacing
        let targetOffset = -CGFloat(index) * cardTotalWidth
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
            cardOffset = targetOffset
        }
        
        // 更新viewModel的当前索引
        viewModel.currentIndex = index
    }
    
    // 处理手势变化
    private func handleGestureChanged(value: DragGesture.Value) {
        let horizontalDistance = abs(value.translation.width)
        let verticalDistance = abs(value.translation.height)
        
        // 设置触发阈值
        let minimumDistance: CGFloat = 20
        let horizontalToVerticalRatio: CGFloat = 2.0
        
        // 如果还未确定手势方向
        if gestureState == .idle {
            // 如果移动距离还不够，保持idle状态
            if horizontalDistance < minimumDistance && verticalDistance < minimumDistance {
                return
            }
            
            // 根据移动距离比例确定手势方向
            if horizontalDistance > verticalDistance * horizontalToVerticalRatio {
                gestureState = .horizontal
                initialTranslation = value.translation
            } else if verticalDistance > horizontalDistance * horizontalToVerticalRatio {
                gestureState = .vertical
                initialTranslation = value.translation
            }
        }
        
        // 只有在水平手势状态下才更新卡片偏移
        if gestureState == .horizontal {
            // 修复偏移量计算：基于当前卡片位置和手势偏移量
            let currentCardOffset = getCurrentCardOffset()
            cardOffset = currentCardOffset + value.translation.width
        }
    }
    
    // 获取当前卡片的基础偏移量
    private func getCurrentCardOffset() -> CGFloat {
        let cardTotalWidth = (screenWidth - 48) + 8 // cardWidth + spacing
        return -CGFloat(viewModel.currentIndex) * cardTotalWidth
    }
    
    // 处理手势结束
    private func handleGestureEnded(value: DragGesture.Value, cardWidth: CGFloat, spacing: CGFloat) {
        // 只有在水平手势状态下才进行卡片切换
        if gestureState == .horizontal {
            let cardIndex = getNearestCardIndex(cardWidth: cardWidth, spacing: spacing)
            snapToCard(index: cardIndex, cardWidth: cardWidth, spacing: spacing)
        }
        
        // 重置手势状态
        gestureState = .idle
        initialTranslation = .zero
    }
    
    // 信件卡片
    private func messageCard(message: InboxMessage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部信息
            HStack(alignment: .center) {
                // 信箱图标（带圆形背景）
                ZStack {
                    Circle()
                        .fill(Color("PrimaryBackground"))
                        .frame(width: 45, height: 45)
                    
                    Image("icon-mailbox2")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color("PrimaryText"))
                }
                
                // 日期文本（垂直居中）
                Text(message.date)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color("PrimaryText"))
                    .tracking(3)
                    .padding(.leading, 8)
                
                Spacer()
                
                // AI reply identifier
                if message.isAIReply {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Text("AI Reply")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Unread identifier
                if !message.isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(height: 45)
            
            // 信件内容（支持滚动）
            ScrollView {
                Text(message.content)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(Color("PrimaryText"))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
            }
            .frame(maxHeight: 400) // 限制最大高度，超出则滚动
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 25)
        .background(Color("SecondaryBackground"))
        .cornerRadius(12)
        .shadow(
            color: Color("ShadowColor"),
            radius: 4,
            x: 0,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("DividerColor").opacity(0.5), lineWidth: 1)
        )
    }
    
    // 底部反馈按钮组
    private var feedbackButtonsSection: some View {
        HStack(spacing: 60) {
            ForEach(FeedbackType.allCases, id: \.self) { feedbackType in
                Button(action: {
                    // 触发动画
                    animatingFeedback = feedbackType
                    
                    // 添加触觉反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // 处理反馈
                    viewModel.handleFeedback(type: feedbackType)
                    
                    // 延迟后重置动画状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        animatingFeedback = nil
                    }
                }) {
                    Image(feedbackType.iconName)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(Color("PrimaryText"))
                        .scaleEffect(animatingFeedback == feedbackType ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.15).repeatCount(2, autoreverses: true), value: animatingFeedback)
                }
            }
        }
        .padding(.bottom, 30)
    }
    
    // Disable reply state
    private var disabledReplySection: some View {
        VStack {
            Spacer()
            
            // 纯内容居中
            VStack(spacing: 24) {
                // 图标
                Image("icon-404")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.black)
                
                // 提示文字
                VStack(spacing: 12) {
                    Text("You haven't enabled the AI reply feature yet,")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                    
                    Text("Please try sending a letter and let it arrive in the future,")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                    
                    Text("Receive a gentle response")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                }
                .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
    
    // 空状态 - 等待回信中
    private var emptyStateSection: some View {
        VStack {
            Spacer()
            
            // 旅途中状态
            VStack(spacing: 24) {
                // 邮箱图标
                Image("icon-mailbox")
                    .resizable()
                    .frame(width: 35, height: 35)
                    .foregroundColor(.black)
                
                // 提示文字
                VStack(spacing: 12) {
                    Text("The emotion letter you sent is on its journey...")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                    
                    Text("The reply will arrive at some moment in the future")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                }
                .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
}