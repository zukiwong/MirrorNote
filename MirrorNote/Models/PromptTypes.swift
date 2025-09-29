//
//  PromptTypes.swift
//  MirrorNote
//
//  Created by Claude Code Assistant on 22/07/2025.
//

import Foundation

/**
 * Prompt 系统相关类型定义
 * 
 * ## 包含的类型
 * - DetectedLanguage: 语言检测枚举
 * - PromptConfiguration: Prompt配置结构
 * - UserProfile: 用户画像结构
 */

// MARK: - 语言类型

/**
 * 检测到的语言类型
 */
enum DetectedLanguage: String, CaseIterable, Codable {
    case chinese = "zh"
    case english = "en" 
    case other = "other"
    
    var displayName: String {
        switch self {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        case .other:
            return "其他语言"
        }
    }
}

// MARK: - 配置类型

/**
 * Prompt 配置结构
 */
class PromptConfiguration: Codable {
    let version: String
    let lastModified: Date
    let templates: [String: String]
    let supportedLanguages: [DetectedLanguage]
    let supportedTones: [AIReplyTone]
    let metadata: [String: String]
    let toneDescriptions: [String: String]?  // 新增：语气描述配置
    
    /**
     * 初始化方法
     */
    init(version: String, lastModified: Date, templates: [String: String], supportedLanguages: [DetectedLanguage], supportedTones: [AIReplyTone], metadata: [String: String], toneDescriptions: [String: String]? = nil) {
        self.version = version
        self.lastModified = lastModified
        self.templates = templates
        self.supportedLanguages = supportedLanguages
        self.supportedTones = supportedTones
        self.metadata = metadata
        self.toneDescriptions = toneDescriptions
    }
    
    /**
     * 验证配置是否有效
     */
    func isValid() -> Bool {
        guard !version.isEmpty,
              !templates.isEmpty,
              !supportedLanguages.isEmpty,
              !supportedTones.isEmpty else {
            return false
        }
        
        // 检查必需的模板是否存在
        let requiredTemplates = ["zh_warm", "en_warm"]
        for required in requiredTemplates {
            if templates[required] == nil {
                return false
            }
        }
        
        return true
    }
    
    /**
     * 估算配置占用的内存大小
     */
    var estimatedMemorySize: Int {
        let templatesSize = templates.values.reduce(0) { $0 + $1.count }
        let metadataSize = metadata.values.reduce(0) { $0 + $1.count }
        return templatesSize + metadataSize + 1000 // 额外1KB for other data
    }
    
    /**
     * 配置内容的哈希值，用于快速比较
     */
    var contentHash: String {
        // 简化实现：基于版本和模板数量计算
        return "\(version)_\(templates.count)"
    }
    
    /**
     * 创建默认配置
     */
    static func defaultConfiguration() -> PromptConfiguration {
        return PromptConfiguration(
            version: "1.0.0",
            lastModified: Date(),
            templates: [
                "zh_warm": "你是一个温暖的AI朋友...",
                "en_warm": "You are a warm AI friend..."
            ],
            supportedLanguages: [.chinese, .english],
            supportedTones: AIReplyTone.allCases,
            metadata: [
                "source": "default",
                "description": "Default configuration"
            ],
            toneDescriptions: nil  // 默认配置不包含语气描述，会降级到代码默认值
        )
    }
}

// MARK: - 用户画像类型

/**
 * 用户画像结构 - 完整版本
 * 用于AI个性化回复和用户行为分析
 */
struct UserProfile: Codable {
    let userId: String
    let displayName: String?
    let createdDate: Date
    let lastUpdatedDate: Date
    
    // 基础偏好设置
    let preferredLanguage: DetectedLanguage?
    let preferredTone: AIReplyTone?
    let communicationStyle: CommunicationStyle
    
    // 个性化标签系统
    let personalTags: [UserTag]
    let topicPreferences: [TopicCategory: Double]  // 主题偏好权重 0.0-1.0
    let emotionPatterns: EmotionPatternAnalysis    // 情绪模式分析
    
    // 表达风格特征
    let writingStyle: WritingStyleProfile
    let behaviorStats: UserBehaviorStats
    
    // 内容概括历史
    let recentSummaries: [ContentSummary]
    let keyInsights: [PersonalInsight]
    
    init(
        userId: String = UUID().uuidString,
        displayName: String? = nil,
        createdDate: Date = Date(),
        lastUpdatedDate: Date = Date(),
        preferredLanguage: DetectedLanguage? = nil,
        preferredTone: AIReplyTone? = nil,
        communicationStyle: CommunicationStyle = .supportive,
        personalTags: [UserTag] = [],
        topicPreferences: [TopicCategory: Double] = [:],
        emotionPatterns: EmotionPatternAnalysis = EmotionPatternAnalysis(),
        writingStyle: WritingStyleProfile = WritingStyleProfile(),
        behaviorStats: UserBehaviorStats = UserBehaviorStats(),
        recentSummaries: [ContentSummary] = [],
        keyInsights: [PersonalInsight] = []
    ) {
        self.userId = userId
        self.displayName = displayName
        self.createdDate = createdDate
        self.lastUpdatedDate = lastUpdatedDate
        self.preferredLanguage = preferredLanguage
        self.preferredTone = preferredTone
        self.communicationStyle = communicationStyle
        self.personalTags = personalTags
        self.topicPreferences = topicPreferences
        self.emotionPatterns = emotionPatterns
        self.writingStyle = writingStyle
        self.behaviorStats = behaviorStats
        self.recentSummaries = recentSummaries
        self.keyInsights = keyInsights
    }
}

// MARK: - 用户标签类型

/**
 * 用户个人标签
 */
struct UserTag: Codable, Identifiable {
    let id: String
    let tagName: String           // 标签名称，如"工作压力型"、"情感敏感型"
    let category: TagCategory     // 标签分类
    let weight: Double           // 标签权重 0.0-1.0
    let createdDate: Date        // 创建时间
    let lastOccurrence: Date?    // 最后出现时间
    
    enum TagCategory: String, CaseIterable, Codable {
        case personality = "personality"     // 性格特征
        case emotion = "emotion"            // 情绪特点
        case topic = "topic"               // 主题偏好
        case behavior = "behavior"         // 行为模式
        case relationship = "relationship"  // 人际关系
    }
}

/**
 * 主题分类枚举
 */
enum TopicCategory: String, CaseIterable, Codable {
    case work = "work"                    // 工作相关
    case love = "love"                    // 恋爱情感
    case family = "family"                // 家庭关系
    case friendship = "friendship"         // 友谊
    case health = "health"                // 身心健康
    case study = "study"                  // 学习成长
    case life = "life"                    // 生活日常
    case finance = "finance"              // 财务状况
    case career = "career"                // 职业发展
    case hobby = "hobby"                  // 兴趣爱好
    
    var displayName: String {
        switch self {
        case .work: return "工作"
        case .love: return "恋爱"
        case .family: return "家庭"
        case .friendship: return "友谊"
        case .health: return "健康"
        case .study: return "学习"
        case .life: return "生活"
        case .finance: return "财务"
        case .career: return "职业"
        case .hobby: return "爱好"
        }
    }
}

/**
 * 情绪模式分析数据
 */
struct EmotionPatternAnalysis: Codable {
    let emotionDistribution: [String: Int]      // 情绪分布统计
    let averageSeverity: Double                 // 平均严重程度
    let emotionTrends: [EmotionTrend]          // 情绪趋势
    let triggerKeywords: [String]              // 触发情绪的关键词
    let commonTimePatterns: [String]           // 常见时间模式
    
    init() {
        self.emotionDistribution = [:]
        self.averageSeverity = 0.0
        self.emotionTrends = []
        self.triggerKeywords = []
        self.commonTimePatterns = []
    }
    
    init(emotionDistribution: [String: Int], averageSeverity: Double, emotionTrends: [EmotionTrend], triggerKeywords: [String], commonTimePatterns: [String]) {
        self.emotionDistribution = emotionDistribution
        self.averageSeverity = averageSeverity
        self.emotionTrends = emotionTrends
        self.triggerKeywords = triggerKeywords
        self.commonTimePatterns = commonTimePatterns
    }
}

/**
 * 情绪趋势数据点
 */
struct EmotionTrend: Codable {
    let date: Date
    let severity: Int
    let dominantEmotion: String
    let topicCategory: TopicCategory?
}

/**
 * 写作风格画像
 */
struct WritingStyleProfile: Codable {
    let averageTextLength: Int                  // 平均文本长度
    let wordComplexity: WordComplexity          // 词汇复杂度
    let sentimentTendency: SentimentTendency    // 情感倾向
    let expressionStyle: ExpressionStyle        // 表达风格
    let punctuationUsage: [String: Int]         // 标点使用习惯
    
    init() {
        self.averageTextLength = 0
        self.wordComplexity = .moderate
        self.sentimentTendency = .neutral
        self.expressionStyle = .balanced
        self.punctuationUsage = [:]
    }
    
    init(averageTextLength: Int, wordComplexity: WordComplexity, sentimentTendency: SentimentTendency, expressionStyle: ExpressionStyle, punctuationUsage: [String: Int]) {
        self.averageTextLength = averageTextLength
        self.wordComplexity = wordComplexity
        self.sentimentTendency = sentimentTendency
        self.expressionStyle = expressionStyle
        self.punctuationUsage = punctuationUsage
    }
    
    enum WordComplexity: String, Codable {
        case simple = "simple"       // 简单直白
        case moderate = "moderate"   // 适中
        case complex = "complex"     // 复杂深刻
    }
    
    enum SentimentTendency: String, Codable {
        case positive = "positive"   // 积极倾向
        case neutral = "neutral"     // 中性
        case negative = "negative"   // 消极倾向
        case mixed = "mixed"         // 复杂多样
    }
    
    enum ExpressionStyle: String, Codable {
        case emotional = "emotional"     // 情感丰富
        case rational = "rational"       // 理性分析
        case descriptive = "descriptive" // 描述详细
        case concise = "concise"         // 简洁明了
        case balanced = "balanced"       // 平衡综合
    }
}

/**
 * 用户行为统计
 */
struct UserBehaviorStats: Codable {
    let totalEntries: Int                      // 总记录数
    let activeUsageDays: Int                   // 活跃使用天数
    let averageEntriesPerWeek: Double          // 周平均记录数
    let preferredWritingTimes: [String]        // 偏好的写作时间段
    let topEmotionKeywords: [String]           // 高频情绪关键词
    let improvementTrends: [ImprovementTrend]  // 改善趋势
    
    init() {
        self.totalEntries = 0
        self.activeUsageDays = 0
        self.averageEntriesPerWeek = 0.0
        self.preferredWritingTimes = []
        self.topEmotionKeywords = []
        self.improvementTrends = []
    }
    
    init(totalEntries: Int, activeUsageDays: Int, averageEntriesPerWeek: Double, preferredWritingTimes: [String], topEmotionKeywords: [String], improvementTrends: [ImprovementTrend]) {
        self.totalEntries = totalEntries
        self.activeUsageDays = activeUsageDays
        self.averageEntriesPerWeek = averageEntriesPerWeek
        self.preferredWritingTimes = preferredWritingTimes
        self.topEmotionKeywords = topEmotionKeywords
        self.improvementTrends = improvementTrends
    }
}

/**
 * 改善趋势数据
 */
struct ImprovementTrend: Codable {
    let timeRange: String              // 时间范围
    let initialSeverity: Double        // 初始严重程度
    let currentSeverity: Double        // 当前严重程度
    let improvementRate: Double        // 改善比率
    let keyFactors: [String]           // 关键因素
}

/**
 * 内容概括
 */
struct ContentSummary: Codable, Identifiable {
    let id: String
    let emotionEntryId: String         // 对应的情绪记录ID
    let summaryText: String            // 概括文本
    let keyTopics: [String]            // 关键主题
    let emotionKeywords: [String]      // 情绪关键词
    let importance: Double             // 重要程度 0.0-1.0
    let createdDate: Date              // 创建时间
    
    init(emotionEntryId: String, summaryText: String, keyTopics: [String] = [], emotionKeywords: [String] = []) {
        self.id = UUID().uuidString
        self.emotionEntryId = emotionEntryId
        self.summaryText = summaryText
        self.keyTopics = keyTopics
        self.emotionKeywords = emotionKeywords
        self.importance = 0.5
        self.createdDate = Date()
    }
}

/**
 * 个人洞察
 */
struct PersonalInsight: Codable, Identifiable {
    let id: String
    let insightText: String            // 洞察内容
    let insightType: InsightType       // 洞察类型
    let confidence: Double             // 置信度 0.0-1.0
    let supportingEvidence: [String]   // 支持证据
    let actionSuggestions: [String]    // 行动建议
    let createdDate: Date              // 创建时间
    
    enum InsightType: String, CaseIterable, Codable {
        case emotionPattern = "emotion_pattern"       // 情绪模式
        case behaviorTrend = "behavior_trend"         // 行为趋势  
        case topicPreference = "topic_preference"     // 主题偏好
        case improvementArea = "improvement_area"     // 改善领域
        case strength = "strength"                    // 优势特点
    }
    
    init(insightText: String, insightType: InsightType, confidence: Double = 0.7) {
        self.id = UUID().uuidString
        self.insightText = insightText
        self.insightType = insightType
        self.confidence = confidence
        self.supportingEvidence = []
        self.actionSuggestions = []
        self.createdDate = Date()
    }
}

/**
 * 交流风格枚举
 */
enum CommunicationStyle: String, CaseIterable, Codable {
    case formal = "formal"             // 正式严谨
    case casual = "casual"             // 轻松随意
    case supportive = "supportive"     // 支持鼓励
    case analytical = "analytical"     // 分析理性
    case empathetic = "empathetic"     // 共情理解
    case encouraging = "encouraging"   // 积极激励
    
    var displayName: String {
        switch self {
        case .formal: return "正式严谨"
        case .casual: return "轻松随意"
        case .supportive: return "支持鼓励"
        case .analytical: return "分析理性"
        case .empathetic: return "共情理解"
        case .encouraging: return "积极激励"
        }
    }
}