import Foundation

struct EmotionEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let place: String
    let people: String
    
    let whatHappened: String?
    let think: String?
    let feel: String?
    let reaction: String?
    let need: String?
    let recordSeverity: Int
    
    let why: String?
    let ifElse: String?
    let nextTime: String?
    let processSeverity: Int?
    
    // AI回信相关字段
    let sentDate: Date?           // 寄出时间
    let replyTone: String?        // 回信语气设置
    let hasAIReply: Bool          // 是否有AI回信
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        place: String = "",
        people: String = "",
        whatHappened: String? = nil,
        think: String? = nil,
        feel: String? = nil,
        reaction: String? = nil,
        need: String? = nil,
        recordSeverity: Int = 0,
        why: String? = nil,
        ifElse: String? = nil,
        nextTime: String? = nil,
        processSeverity: Int? = nil,
        sentDate: Date? = nil,
        replyTone: String? = nil,
        hasAIReply: Bool = false
    ) {
        self.id = id
        self.date = date
        self.place = place
        self.people = people
        self.whatHappened = whatHappened
        self.think = think
        self.feel = feel
        self.reaction = reaction
        self.need = need
        self.recordSeverity = recordSeverity
        self.why = why
        self.ifElse = ifElse
        self.nextTime = nextTime
        self.processSeverity = processSeverity
        self.sentDate = sentDate
        self.replyTone = replyTone
        self.hasAIReply = hasAIReply
    }
}