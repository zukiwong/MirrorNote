import Foundation

// AI回信语气枚举
enum AIReplyTone: String, CaseIterable, Codable {
    case warm = "warm"                    // 温暖的
    case gentle = "gentle"               // 温和的
    case understanding = "understanding"  // 理解的
    case philosophical = "philosophical" // 哲学的
    case empathetic = "empathetic"       // 共情的
    case supportive = "supportive"       // 支持的
    
    // 自定义反序列化方法，增强容错性
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // 尝试初始化，如果失败则使用默认值
        if let validTone = AIReplyTone(rawValue: rawValue) {
            self = validTone
        } else {
            // 记录无效值并使用默认语气
            print("⚠️ [AIReplyTone] 无效的语气值 '\(rawValue)'，使用默认语气 'warm'")
            self = .warm  // 默认降级到 warm 语气
        }
    }
    
    // 获取英文显示名称
    var displayName: String {
        switch self {
        case .warm:
            return "Warm"
        case .gentle:
            return "Gentle"
        case .understanding:
            return "Understanding"
        case .philosophical:
            return "Philosophical"
        case .empathetic:
            return "Empathetic"
        case .supportive:
            return "Supportive"
        }
    }
    
    // 获取中文显示名称
    var chineseDisplayName: String {
        switch self {
        case .warm:
            return "温暖"
        case .gentle:
            return "温和"
        case .understanding:
            return "理解"
        case .philosophical:
            return "哲学"
        case .empathetic:
            return "共情"
        case .supportive:
            return "支持"
        }
    }
    
    // 获取英文显示名称（与displayName相同，为了明确区分）
    var englishDisplayName: String {
        return displayName
    }
    
    // 获取中文提示词描述
    var chinesePromptDescription: String {
        switch self {
        case .warm:
            return """
用温暖关怀的语气回复，像老朋友一样：
- 用词温和亲切，多用"我理解"、"陪伴"等词汇
- 语调温暖包容，传达安全感和归属感
- 适当分享类似经历，让用户感到不孤单
- 用"你"来拉近距离，避免说教的语气
"""
        case .understanding:
            return """
用理解包容的语气回复，表达深度共鸣：
- 深度分析用户的感受和处境，体现理性思考
- 使用"确实"、"的确"等词汇表达认同
- 从多个角度解释情况，帮助用户看清全貌
- 语调平和理性，既有情感关怀又有逻辑分析
"""
        case .gentle:
            return """
用温和平静的语气回复，带来安慰：
- 语调轻柔舒缓，多用"慢慢来"、"没关系"等安抚词汇
- 避免任何可能造成压力的表达
- 专注于当下的感受接纳，而非急于解决问题
- 用温柔的语言包围用户，创造安全的情感空间
"""
        case .supportive:
            return """
用支持陪伴的语气回复，表达坚定支持：
- 明确表达"我支持你"、"我相信你"等支持立场
- 强调陪伴和不离不弃的态度
- 在用户质疑自己时，坚定地站在用户一边
- 语调真诚坚定，让用户感受到有力的后盾
"""
        case .philosophical:
            return """
用哲学思辨的语气回复，引导深度思考：
- 从哲学角度思考人生、情感和存在的意义
- 提出深刻的问题，引导用户自我反思
- 使用哲学概念和思辨方式分析问题
- 语调深沉思辨，帮助用户获得更深层的理解
"""
        case .empathetic:
            return """
用共情理解的语气回复，感同身受：
- 完全站在用户的角度感受和体验
- 使用"我也会"、"换作是我"等共鸣表达
- 详细描述对用户感受的理解和体验
- 语调充满同理心，让用户感到被深深理解
"""
        }
    }
    
    // 获取英文提示词描述
    var englishPromptDescription: String {
        switch self {
        case .warm:
            return """
a warm and caring tone, like an old friend:
- Use gentle and affectionate words, often using "I understand", "accompany" and similar expressions
- Convey warmth and inclusiveness, providing a sense of safety and belonging
- Share similar experiences appropriately to make the user feel less alone
- Use "you" to create closeness, avoiding preachy tone
"""
        case .understanding:
            return """
an understanding and accepting tone, expressing deep empathy:
- Deeply analyze the user's feelings and situation, showing rational thinking
- Use words like "indeed", "certainly" to express agreement
- Explain the situation from multiple angles to help the user see the full picture
- Use a calm and rational tone, combining emotional care with logical analysis
"""
        case .gentle:
            return """
a gentle and calm tone, bringing comfort:
- Use soft and soothing tone, often using comforting words like "take your time", "it's okay"
- Avoid any expressions that might cause pressure
- Focus on accepting current feelings rather than rushing to solve problems
- Surround the user with gentle language, creating a safe emotional space
"""
        case .supportive:
            return """
a supportive and accompanying tone, expressing firm support:
- Clearly express supportive positions like "I support you", "I believe in you"
- Emphasize companionship and unwavering attitude
- Stand firmly on the user's side when they doubt themselves
- Use sincere and firm tone, letting the user feel strong backing
"""
        case .philosophical:
            return """
a philosophical and contemplative tone, guiding deep thinking:
- Think about the meaning of life, emotions, and existence from a philosophical perspective
- Ask profound questions to guide the user's self-reflection
- Use philosophical concepts and speculative ways to analyze problems
- Use deep and contemplative tone, helping the user gain deeper understanding
"""
        case .empathetic:
            return """
an empathetic and understanding tone, feeling what the user feels:
- Completely stand from the user's perspective to feel and experience
- Use empathetic expressions like "I would too", "if it were me"
- Describe in detail the understanding and experience of the user's feelings
- Use a tone full of empathy, making the user feel deeply understood
"""
        }
    }
}

// AI回信数据模型
struct AIReply: Identifiable, Codable {
    let id: UUID
    let emotionEntryId: UUID        // 对应的情绪记录ID
    let content: String             // 回信内容
    let tone: AIReplyTone          // 回信语气
    let receivedDate: Date         // 收到回信的时间
    let wordCount: Int             // 字数统计
    let isRead: Bool               // 是否已读
    
    init(
        id: UUID = UUID(),
        emotionEntryId: UUID,
        content: String,
        tone: AIReplyTone,
        receivedDate: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.emotionEntryId = emotionEntryId
        self.content = content
        self.tone = tone
        self.receivedDate = receivedDate
        self.wordCount = content.count
        self.isRead = isRead
    }
}

// AI回信请求数据模型
struct AIReplyRequest: Codable {
    let emotionData: EmotionData
    let tone: AIReplyTone
    let wordCount: Int
    let isTestMode: Bool
    
    struct EmotionData: Codable {
        let date: String
        let place: String
        let people: String
        let whatHappened: String
        let think: String
        let feel: String
        let reaction: String
        let need: String
        let recordSeverity: Int
        let why: String?
        let ifElse: String?
        let nextTime: String?
        let processSeverity: Int?
    }
}

// AI回信响应数据模型
struct AIReplyResponse: Codable {
    let reply: String
    let tone: String
    let wordCount: Int
    let timestamp: String
}