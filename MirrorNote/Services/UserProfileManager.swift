import Foundation
import NaturalLanguage
import Combine

/**
 * UserProfileManager - 用户画像数据管理器
 * 
 * ## 功能概述
 * UserProfileManager 负责管理用户的个性化数据，包括：
 * - 用户画像的创建、更新、保存和加载
 * - 情绪记录数据的智能分析
 * - 个人标签的自动生成和管理
 * - 内容概括和个人洞察的生成
 * - 与AI回复系统的数据集成
 * 
 * ## 工作原理
 * 1. 分析用户的情绪记录数据
 * 2. 使用NaturalLanguage框架进行文本分析
 * 3. 生成个性化标签和洞察
 * 4. 将数据保存到本地UserDefaults
 * 5. 为AI回复提供个性化上下文
 * 
 * ## 数据存储
 * - 使用UserDefaults进行本地存储（完全免费）
 * - 不依赖任何外部付费服务
 * - 数据完全存储在用户设备本地
 * 
 * @author Claude Code Assistant
 * @version 1.0
 * @since 2024-07-22
 */
@MainActor
class UserProfileManager: ObservableObject {
    
    // MARK: - Singleton Pattern
    
    /// 单例实例，确保全局唯一的用户画像管理器
    static let shared = UserProfileManager()
    
    // MARK: - Published Properties
    
    /// 当前用户画像
    @Published private(set) var currentProfile: UserProfile?
    
    /// 最后更新时间
    @Published private(set) var lastUpdateTime: Date = Date()
    
    /// 更新状态
    @Published private(set) var isUpdating: Bool = false
    
    // MARK: - Private Properties
    
    /// UserDefaults键名
    private let userProfileKey = "UserProfile"
    private let userProfileBackupKey = "UserProfileBackup"
    
    /// 自然语言处理器
    private let nlProcessor = NLLanguageRecognizer()
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .language])
    
    /// 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    /// 初始化锁
    private var initializationLock = NSLock()
    private var _isInitialized = false
    
    /// 公开的初始化状态检查属性
    var isInitialized: Bool {
        return _isInitialized
    }
    
    // MARK: - Initialization
    
    private init() {
        // 静默初始化，不输出日志
    }
    
    /**
     * 异步初始化方法
     * 加载现有的用户画像或创建新的用户画像
     */
    func initialize() async throws {
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        guard !_isInitialized else { return }
        
        do {
            // 静默初始化
            
            // 尝试加载现有画像
            if let existingProfile = loadUserProfile() {
                currentProfile = existingProfile
                lastUpdateTime = existingProfile.lastUpdatedDate
                // 加载成功
            } else {
                // 创建新用户画像
                currentProfile = createNewUserProfile()
                try await saveUserProfile()
                // 创建新画像
            }
            
            // 启动后台分析任务
            Task.detached { [weak self] in
                await self?.performProfileAnalysis()
            }
            
            _isInitialized = true
            
        } catch {
            // 初始化失败，静默处理
            throw UserProfileError.initializationFailed(error)
        }
    }
    
    // MARK: - Public Interface
    
    /**
     * 分析情绪记录并更新用户画像
     * @param emotionEntry 新的情绪记录
     */
    func analyzeEmotionEntry(_ emotionEntry: EmotionEntry) async throws {
        guard let profile = currentProfile else {
            throw UserProfileError.profileNotFound
        }
        
        // 开始分析
        
        isUpdating = true
        defer { isUpdating = false }
        
        do {
            // 1. 生成内容概括
            let summary = await generateContentSummary(for: emotionEntry)
            
            // 2. 分析主题偏好
            let detectedTopics = await analyzeTopicPreferences(from: emotionEntry)
            
            // 3. 提取情绪关键词
            let emotionKeywords = await extractEmotionKeywords(from: emotionEntry)
            
            // 4. 分析写作风格
            let styleUpdate = await analyzeWritingStyle(from: emotionEntry)
            
            // 5. 更新用户标签
            let newTags = await generatePersonalTags(from: emotionEntry, keywords: emotionKeywords, topics: detectedTopics)
            
            // 6. 更新用户画像
            let updatedProfile = updateUserProfile(
                profile,
                with: summary,
                topics: detectedTopics,
                keywords: emotionKeywords,
                styleUpdate: styleUpdate,
                newTags: newTags,
                emotionEntry: emotionEntry
            )
            
            currentProfile = updatedProfile
            lastUpdateTime = Date()
            
            // 7. 保存更新后的画像
            try await saveUserProfile()
            
            // 分析完成
            
        } catch {
            // 分析失败，静默处理
            throw error
        }
    }
    
    /**
     * 获取个性化AI Prompt上下文信息
     * @return AI回复所需的个性化上下文字符串
     */
    func getPersonalizedContext() -> String {
        guard let profile = currentProfile else {
            return ""
        }
        
        var context = ""
        
        // 添加个人标签信息
        if !profile.personalTags.isEmpty {
            let topTags = profile.personalTags.sorted { $0.weight > $1.weight }.prefix(3)
            context += "用户个性标签: " + topTags.map { $0.tagName }.joined(separator: ", ") + "; "
        }
        
        // 添加主题偏好
        let topTopics = profile.topicPreferences.sorted { $0.value > $1.value }.prefix(3)
        if !topTopics.isEmpty {
            context += "关注话题: " + topTopics.map { $0.key.displayName }.joined(separator: ", ") + "; "
        }
        
        // 添加交流风格
        context += "偏好交流风格: \(profile.communicationStyle.displayName); "
        
        // 添加情绪模式信息
        if profile.emotionPatterns.averageSeverity > 0 {
            context += "平均情绪强度: \(String(format: "%.1f", profile.emotionPatterns.averageSeverity)); "
        }
        
        // 添加写作风格
        context += "表达风格: \(profile.writingStyle.expressionStyle.rawValue); "
        
        return context
    }
    
    /**
     * 获取用户画像摘要信息用于UI显示
     */
    func getProfileSummary() -> UserProfileSummary? {
        guard let profile = currentProfile else { return nil }
        
        return UserProfileSummary(
            totalTags: profile.personalTags.count,
            topTopics: Array(profile.topicPreferences.sorted { $0.value > $1.value }.prefix(3).map { $0.key }),
            averageEmotionSeverity: profile.emotionPatterns.averageSeverity,
            totalAnalyzedEntries: profile.behaviorStats.totalEntries,
            lastUpdated: profile.lastUpdatedDate,
            keyInsights: Array(profile.keyInsights.prefix(5))
        )
    }
    
    // MARK: - Private Analysis Methods
    
    /**
     * 生成内容概括
     */
    private func generateContentSummary(for entry: EmotionEntry) async -> ContentSummary {
        var summaryText = ""
        var keyTopics: [String] = []
        var emotionKeywords: [String] = []
        
        // 组合所有文本内容
        var fullText = ""
        if let happened = entry.whatHappened, !happened.isEmpty {
            fullText += happened + " "
        }
        if let think = entry.think, !think.isEmpty {
            fullText += think + " "
        }
        if let feel = entry.feel, !feel.isEmpty {
            fullText += feel + " "
        }
        
        if !fullText.isEmpty {
            // 简化版概括：取前30个字符
            summaryText = String(fullText.prefix(30)) + (fullText.count > 30 ? "..." : "")
            
            // 提取关键词
            tokenizer.string = fullText
            var keywords: [String] = []
            
            tokenizer.enumerateTokens(in: fullText.startIndex..<fullText.endIndex) { tokenRange, _ in
                let token = String(fullText[tokenRange])
                if token.count > 2 { // 过滤短词
                    keywords.append(token)
                }
                return keywords.count < 5 // 限制关键词数量
            }
            
            keyTopics = Array(keywords.prefix(3))
            emotionKeywords = Array(keywords.suffix(2))
        }
        
        return ContentSummary(
            emotionEntryId: entry.id.uuidString,
            summaryText: summaryText,
            keyTopics: keyTopics,
            emotionKeywords: emotionKeywords
        )
    }
    
    /**
     * 分析主题偏好
     */
    private func analyzeTopicPreferences(from entry: EmotionEntry) async -> [TopicCategory: Double] {
        var topicWeights: [TopicCategory: Double] = [:]
        
        // 简化的关键词匹配规则
        let textContent = [entry.whatHappened, entry.think, entry.feel, entry.place]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        
        // 工作相关关键词
        if textContent.contains("工作") || textContent.contains("公司") || textContent.contains("老板") || textContent.contains("同事") {
            topicWeights[.work] = 0.8
        }
        
        // 恋爱相关关键词
        if textContent.contains("恋人") || textContent.contains("男友") || textContent.contains("女友") || textContent.contains("恋爱") {
            topicWeights[.love] = 0.9
        }
        
        // 家庭相关关键词
        if textContent.contains("家") || textContent.contains("父母") || textContent.contains("妈妈") || textContent.contains("爸爸") {
            topicWeights[.family] = 0.8
        }
        
        // 健康相关关键词
        if textContent.contains("身体") || textContent.contains("健康") || textContent.contains("病") || textContent.contains("医院") {
            topicWeights[.health] = 0.7
        }
        
        // 友谊相关关键词
        if textContent.contains("朋友") || textContent.contains("友谊") || textContent.contains("聚会") {
            topicWeights[.friendship] = 0.6
        }
        
        // 如果没有匹配到特定主题，归类为生活
        if topicWeights.isEmpty {
            topicWeights[.life] = 0.5
        }
        
        return topicWeights
    }
    
    /**
     * 提取情绪关键词
     */
    private func extractEmotionKeywords(from entry: EmotionEntry) async -> [String] {
        let emotionWords = [
            "开心", "快乐", "兴奋", "满足", "幸福", "愉快",
            "难过", "伤心", "失望", "沮丧", "绝望", "痛苦",
            "愤怒", "生气", "恼火", "愤慨", "抓狂", "烦躁",
            "焦虑", "紧张", "担心", "恐惧", "害怕", "不安",
            "压力", "疲惫", "累", "疲劳", "无力", "倦怠"
        ]
        
        let textContent = [entry.whatHappened, entry.think, entry.feel]
            .compactMap { $0 }
            .joined(separator: " ")
        
        return emotionWords.filter { textContent.contains($0) }
    }
    
    /**
     * 分析写作风格
     */
    private func analyzeWritingStyle(from entry: EmotionEntry) async -> WritingStyleProfile {
        let textContent = [entry.whatHappened, entry.think, entry.feel, entry.reaction, entry.need]
            .compactMap { $0 }
            .joined(separator: " ")
        
        let textLength = textContent.count
        let wordComplexity: WritingStyleProfile.WordComplexity = textLength > 100 ? .complex : textLength > 50 ? .moderate : .simple
        
        // 简化的情感倾向分析
        let sentimentTendency: WritingStyleProfile.SentimentTendency = {
            if textContent.contains("开心") || textContent.contains("快乐") || textContent.contains("满足") {
                return .positive
            } else if textContent.contains("难过") || textContent.contains("痛苦") || textContent.contains("绝望") {
                return .negative
            } else {
                return .neutral
            }
        }()
        
        let expressionStyle: WritingStyleProfile.ExpressionStyle = textLength > 150 ? .descriptive : .concise
        
        return WritingStyleProfile(
            averageTextLength: textLength,
            wordComplexity: wordComplexity,
            sentimentTendency: sentimentTendency,
            expressionStyle: expressionStyle,
            punctuationUsage: [:]
        )
    }
    
    /**
     * 生成个人标签
     */
    private func generatePersonalTags(
        from entry: EmotionEntry,
        keywords: [String],
        topics: [TopicCategory: Double]
    ) async -> [UserTag] {
        var tags: [UserTag] = []
        
        // 基于情绪强度生成标签
        if entry.recordSeverity >= 4 {
            tags.append(UserTag(
                id: UUID().uuidString,
                tagName: "高敏感型",
                category: .emotion,
                weight: 0.8,
                createdDate: Date(),
                lastOccurrence: Date()
            ))
        }
        
        // 基于主题偏好生成标签
        for (topic, weight) in topics {
            if weight > 0.7 {
                tags.append(UserTag(
                    id: UUID().uuidString,
                    tagName: "\(topic.displayName)关注型",
                    category: .topic,
                    weight: weight,
                    createdDate: Date(),
                    lastOccurrence: Date()
                ))
            }
        }
        
        // 基于情绪关键词生成标签
        if keywords.contains("焦虑") || keywords.contains("紧张") {
            tags.append(UserTag(
                id: UUID().uuidString,
                tagName: "焦虑倾向型",
                category: .emotion,
                weight: 0.7,
                createdDate: Date(),
                lastOccurrence: Date()
            ))
        }
        
        return tags
    }
    
    /**
     * 更新用户画像
     */
    private func updateUserProfile(
        _ profile: UserProfile,
        with summary: ContentSummary,
        topics: [TopicCategory: Double],
        keywords: [String],
        styleUpdate: WritingStyleProfile,
        newTags: [UserTag],
        emotionEntry: EmotionEntry
    ) -> UserProfile {
        
        // 更新主题偏好
        var updatedTopicPreferences = profile.topicPreferences
        for (topic, weight) in topics {
            let currentWeight = updatedTopicPreferences[topic] ?? 0.0
            updatedTopicPreferences[topic] = (currentWeight + weight) / 2.0 // 平滑更新
        }
        
        // 更新个人标签
        var updatedTags = profile.personalTags
        for newTag in newTags {
            if let existingIndex = updatedTags.firstIndex(where: { $0.tagName == newTag.tagName }) {
                // 更新现有标签的权重
                let existingTag = updatedTags[existingIndex]
                let updatedWeight = (existingTag.weight + newTag.weight) / 2.0
                updatedTags[existingIndex] = UserTag(
                    id: existingTag.id,
                    tagName: existingTag.tagName,
                    category: existingTag.category,
                    weight: updatedWeight,
                    createdDate: existingTag.createdDate,
                    lastOccurrence: Date()
                )
            } else {
                // 添加新标签
                updatedTags.append(newTag)
            }
        }
        
        // 限制标签数量
        updatedTags = Array(updatedTags.sorted { $0.weight > $1.weight }.prefix(20))
        
        // 更新概括历史
        var updatedSummaries = profile.recentSummaries
        updatedSummaries.append(summary)
        updatedSummaries = Array(updatedSummaries.suffix(10)) // 保持最近10条
        
        // 更新行为统计
        let updatedBehaviorStats = UserBehaviorStats(
            totalEntries: profile.behaviorStats.totalEntries + 1,
            activeUsageDays: profile.behaviorStats.activeUsageDays + 1,
            averageEntriesPerWeek: Double(profile.behaviorStats.totalEntries + 1) / max(1.0, Double(profile.behaviorStats.activeUsageDays + 1) / 7.0),
            preferredWritingTimes: profile.behaviorStats.preferredWritingTimes,
            topEmotionKeywords: Array(Set(profile.behaviorStats.topEmotionKeywords + keywords).prefix(10)),
            improvementTrends: profile.behaviorStats.improvementTrends
        )
        
        // 更新情绪模式
        let updatedEmotionPatterns = EmotionPatternAnalysis(
            emotionDistribution: profile.emotionPatterns.emotionDistribution,
            averageSeverity: (profile.emotionPatterns.averageSeverity * Double(profile.behaviorStats.totalEntries) + Double(emotionEntry.recordSeverity)) / Double(profile.behaviorStats.totalEntries + 1),
            emotionTrends: profile.emotionPatterns.emotionTrends + [EmotionTrend(
                date: emotionEntry.date,
                severity: emotionEntry.recordSeverity,
                dominantEmotion: keywords.first ?? "neutral",
                topicCategory: topics.max { $0.value < $1.value }?.key
            )],
            triggerKeywords: Array(Set(profile.emotionPatterns.triggerKeywords + keywords).prefix(15)),
            commonTimePatterns: profile.emotionPatterns.commonTimePatterns
        )
        
        // 生成新的个人洞察
        let newInsights = generatePersonalInsights(from: updatedTags, emotionPatterns: updatedEmotionPatterns)
        let updatedInsights = Array((profile.keyInsights + newInsights).suffix(10))
        
        // 创建更新后的用户画像
        return UserProfile(
            userId: profile.userId,
            displayName: profile.displayName,
            createdDate: profile.createdDate,
            lastUpdatedDate: Date(),
            preferredLanguage: profile.preferredLanguage,
            preferredTone: profile.preferredTone,
            communicationStyle: profile.communicationStyle,
            personalTags: updatedTags,
            topicPreferences: updatedTopicPreferences,
            emotionPatterns: updatedEmotionPatterns,
            writingStyle: styleUpdate,
            behaviorStats: updatedBehaviorStats,
            recentSummaries: updatedSummaries,
            keyInsights: updatedInsights
        )
    }
    
    /**
     * 生成个人洞察
     */
    private func generatePersonalInsights(from tags: [UserTag], emotionPatterns: EmotionPatternAnalysis) -> [PersonalInsight] {
        var insights: [PersonalInsight] = []
        
        // 基于标签生成洞察
        if let strongestTag = tags.max(by: { $0.weight < $1.weight }), strongestTag.weight > 0.8 {
            insights.append(PersonalInsight(
                insightText: "你的主要性格特征是\(strongestTag.tagName)，这影响了你处理情绪的方式。",
                insightType: .emotionPattern,
                confidence: strongestTag.weight
            ))
        }
        
        // 基于情绪模式生成洞察
        if emotionPatterns.averageSeverity > 3.0 {
            insights.append(PersonalInsight(
                insightText: "你的情绪强度相对较高，建议关注情绪管理技巧。",
                insightType: .improvementArea,
                confidence: 0.8
            ))
        }
        
        return insights
    }
    
    // MARK: - Storage Methods
    
    /**
     * 保存用户画像到加密存储
     */
    private func saveUserProfile() async throws {
        guard let profile = currentProfile else {
            throw UserProfileError.profileNotFound
        }
        
        do {
            // 创建备份
            if SecureStorage.shared.hasSecureData(forKey: userProfileKey) {
                if let existingProfile: UserProfile = SecureStorage.shared.securelyLoad(UserProfile.self, forKey: userProfileKey) {
                    try SecureStorage.shared.securelyStore(existingProfile, forKey: userProfileBackupKey)
                }
            }
            
            // 保存新数据到加密存储
            try SecureStorage.shared.securelyStore(profile, forKey: userProfileKey)
            
        } catch {
            throw UserProfileError.saveFailed(error)
        }
    }
    
    /**
     * 从加密存储加载用户画像
     */
    private func loadUserProfile() -> UserProfile? {
        // 首先尝试从加密存储加载
        if let profile: UserProfile = SecureStorage.shared.securelyLoad(UserProfile.self, forKey: userProfileKey) {
            return profile
        }
        
        // 如果加密存储没有数据，尝试从旧的明文存储迁移
        SecureStorage.shared.migrateToSecureStorage(UserProfile.self, forKey: userProfileKey)
        
        // 再次尝试从加密存储加载
        if let profile: UserProfile = SecureStorage.shared.securelyLoad(UserProfile.self, forKey: userProfileKey) {
            return profile
        }
        
        // 尝试从备份恢复
        if let profile: UserProfile = SecureStorage.shared.securelyLoad(UserProfile.self, forKey: userProfileBackupKey) {
            return profile
        }
        
        return nil
    }
    
    /**
     * 创建新用户画像
     */
    private func createNewUserProfile() -> UserProfile {
        return UserProfile(
            userId: UUID().uuidString,
            displayName: "Mirror Note 用户",
            createdDate: Date(),
            lastUpdatedDate: Date()
        )
    }
    
    /**
     * 执行定期画像分析
     */
    private func performProfileAnalysis() async {
        // 延迟执行，避免影响启动性能
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒
        
        // 定期分析，静默执行
        
        // 这里可以添加更多的分析逻辑
        // 比如分析历史数据趋势、更新洞察等
    }
}

// MARK: - Supporting Types

/**
 * 用户画像摘要信息（用于UI显示）
 */
struct UserProfileSummary {
    let totalTags: Int
    let topTopics: [TopicCategory]
    let averageEmotionSeverity: Double
    let totalAnalyzedEntries: Int
    let lastUpdated: Date
    let keyInsights: [PersonalInsight]
}

/**
 * 用户画像管理器错误类型
 */
enum UserProfileError: Error, LocalizedError {
    case initializationFailed(Error)
    case profileNotFound
    case analysisError(Error)
    case saveFailed(Error)
    case loadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "用户画像管理器初始化失败: \(error.localizedDescription)"
        case .profileNotFound:
            return "用户画像数据不存在"
        case .analysisError(let error):
            return "数据分析错误: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "用户画像保存失败: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "用户画像加载失败: \(error.localizedDescription)"
        }
    }
}