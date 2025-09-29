import Foundation
import UserNotifications
import NaturalLanguage

/**
 * AIReplyService - AI回信生成服务（重构版本）
 * 
 * ## 重构说明
 * 本次重构集成了新的 Prompt 管理系统，主要变化：
 * - 移除硬编码的 Prompt 构建逻辑
 * - 集成 PromptManager 进行统一管理
 * - 支持热更新和版本管理
 * - 改善了错误处理和日志记录
 * - 保持了原有的API兼容性
 * 
 * ## 新增功能
 * - Prompt 热更新支持
 * - 个性化 Prompt 生成
 * - 多语言智能检测和适配
 * - 配置驱动的语气调整
 * - 增强的错误恢复机制
 * 
 * @author Claude Code Assistant  
 * @version 2.0 (重构版本)
 * @since 2024-01-15
 */
class AIReplyService: ObservableObject {
    // Gemini API配置
    private let apiKey = "AIzaSyBt9Cy6FB_cSF3PDu1Dh4VAS13BJyveSAE"
    private let apiURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    // 测试模式配置
    let isTestMode = false  // 测试阶段设为true，正式版本设为false
    private let testWordCount = 1000 // 测试阶段字数限制（移除限制，允许更长回复）
    private let productionWordCount = 2000 // 正式版本字数限制（移除限制，允许更长回复）
    
    // 公开属性用于外部检查
    var isInTestMode: Bool {
        return isTestMode
    }
    
    // 随机语气列表（测试用）
    private let randomTones = AIReplyTone.allCases
    
    // 通知服务
    private let notificationService = NotificationService.shared
    
    // Prompt 管理器（新增）
    private nonisolated(unsafe) let promptManager = PromptManager.shared
    
    // API连接测试结果
    @Published var apiConnectionStatus: APIConnectionStatus = .unknown
    
    // 生成AI回信的主要方法
    func generateReply(for entry: EmotionEntry) async -> String {
        print("🤖 [AIReplyService] 开始生成AI回信")
        
        // 选择语气：优先使用用户设置的语气，无设置时使用默认或随机语气
        let selectedTone: AIReplyTone
        // 尝试从用户设置中获取语气
        if let userTone = getUserSelectedTone() {
            selectedTone = userTone
            print("🎭 [AIReplyService] 使用用户设置语气: \(selectedTone.displayName)")
        } else if let entryTone = entry.replyTone, let tone = AIReplyTone(rawValue: entryTone) {
            selectedTone = tone
            print("🎭 [AIReplyService] 使用记录语气: \(selectedTone.displayName)")
        } else if isTestMode {
            selectedTone = randomTones.randomElement() ?? .warm
            print("🎭 [AIReplyService] 测试模式使用随机语气: \(selectedTone.displayName)")
        } else {
            selectedTone = .warm
            print("🎭 [AIReplyService] 使用默认语气: \(selectedTone.displayName)")
        }
        print("🎭 [AIReplyService] 选择语气: \(selectedTone.displayName)")
        
        // 确定字数限制
        let wordCount = isTestMode ? testWordCount : productionWordCount
        print("📝 [AIReplyService] 字数限制: \(wordCount)字")
        
        do {
            let reply = try await requestGeminiReply(for: entry, tone: selectedTone, wordCount: wordCount)
            print("✅ [AIReplyService] AI回信生成成功，长度: \(reply.count)字")
            
            // 如果是测试模式，立即返回回信
            if isTestMode {
                print("⚡ [AIReplyService] 测试模式，立即返回回信")
                return reply
            }
            
            // 正式模式：延迟2-8小时后发送回信
            print("⏰ [AIReplyService] 正式模式，安排延迟回信")
            scheduleDelayedReply(reply: reply, for: entry, tone: selectedTone)
            return "已安排回信，将在2-8小时内收到"
            
        } catch {
            print("❌ [AIReplyService] 生成AI回信失败: \(error)")
            
            // 如果是API错误，尝试生成简化回复
            if let aiError = error as? AIReplyError {
                print("🔄 [AIReplyService] 检测到API错误：\(aiError.localizedDescription)，尝试生成简化回复")
                do {
                    let fallbackReply = try await generateFallbackReply(for: entry, tone: selectedTone, wordCount: min(wordCount, 30))
                    
                    // 如果是测试模式，立即返回简化回信
                    if isTestMode {
                        return fallbackReply
                    }
                    
                    // 正式模式：延迟发送简化回信
                    scheduleDelayedReply(reply: fallbackReply, for: entry, tone: selectedTone)
                    return "已安排回信，将在2-8小时内收到"
                } catch {
                    print("❌ [AIReplyService] 备用回复生成失败: \(error)")
                    return "回信生成失败，请稍后重试"
                }
            }
            
            // 其他错误类型的处理
            return "回信生成失败，请稍后重试"
        }
    }
    
    // 调用Gemini API生成回信
    private func requestGeminiReply(for entry: EmotionEntry, tone: AIReplyTone, wordCount: Int) async throws -> String {
        print("🌐 [AIReplyService] 开始调用Gemini API")
        
        // 构建请求URL
        guard let url = URL(string: "\(apiURL)?key=\(apiKey)") else {
            print("❌ [AIReplyService] 无效的API URL: \(apiURL)")
            throw AIReplyError.invalidURL
        }
        print("🔗 [AIReplyService] API URL: \(url)")
        
        // 使用新的 Prompt 管理系统构建提示词
        let prompt = try await buildPromptWithManager(for: entry, tone: tone, wordCount: wordCount)
        print("📄 [AIReplyService] 提示词长度: \(prompt.count)字符")
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 8192, // 移除字数限制，使用最大token数
                "stopSequences": []
            ]
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📤 [AIReplyService] 请求体创建成功，大小: \(request.httpBody?.count ?? 0) bytes")
            
            // 调试：打印请求体内容
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("📋 [AIReplyService] 请求体内容: \(jsonString)")
            }
        } catch {
            print("❌ [AIReplyService] 请求体序列化失败: \(error)")
            throw AIReplyError.requestFailed(statusCode: 0, message: "请求体序列化失败")
        }
        
        // 发送请求
        print("🚀 [AIReplyService] 发送API请求...")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ [AIReplyService] 网络请求失败: \(error)")
            throw AIReplyError.networkError(underlying: error)
        }
        
        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [AIReplyService] 无效的HTTP响应")
            throw AIReplyError.requestFailed(statusCode: 0, message: "无效的HTTP响应")
        }
        
        print("📥 [AIReplyService] HTTP状态码: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            print("❌ [AIReplyService] API请求失败，状态码: \(httpResponse.statusCode)")
            let responseString = String(data: data, encoding: .utf8) ?? "无法解析响应"
            print("📄 [AIReplyService] 错误响应: \(responseString)")
            
            // 根据状态码抛出具体错误
            switch httpResponse.statusCode {
            case 401:
                throw AIReplyError.apiKeyInvalid
            case 429:
                throw AIReplyError.rateLimitExceeded
            case 500...599:
                throw AIReplyError.serviceBusy
            default:
                throw AIReplyError.requestFailed(statusCode: httpResponse.statusCode, message: responseString)
            }
        }
        
        // 解析响应
        guard let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ [AIReplyService] 响应JSON解析失败")
            throw AIReplyError.invalidResponse(details: "JSON解析失败")
        }
        
        print("📊 [AIReplyService] 响应JSON解析成功")
        
        // 检查candidates数组
        guard let candidates = responseJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first else {
            print("❌ [AIReplyService] 响应中没有candidates")
            print("📄 [AIReplyService] 响应内容: \(responseJSON)")
            let details = "响应结构: \(responseJSON.keys.joined(separator: ", "))"
            throw AIReplyError.invalidResponse(details: details)
        }
        
        // 检查finishReason
        if let finishReason = firstCandidate["finishReason"] as? String {
            print("🏁 [AIReplyService] 完成原因: \(finishReason)")
            
            switch finishReason {
            case "SAFETY":
                throw AIReplyError.contentFiltered
            case "MAX_TOKENS":
                print("⚠️ [AIReplyService] 回复因token限制被截断")
                // 继续处理，可能仍有部分内容
            case "STOP":
                print("✅ [AIReplyService] 回复正常完成")
            default:
                print("❓ [AIReplyService] 未知完成原因: \(finishReason)")
            }
        }
        
        // 尝试获取content
        guard let content = firstCandidate["content"] as? [String: Any] else {
            print("❌ [AIReplyService] content字段缺失")
            print("📄 [AIReplyService] candidate内容: \(firstCandidate)")
            
            // 特殊处理：如果是MAX_TOKENS导致的content缺失，尝试降级处理
            if let finishReason = firstCandidate["finishReason"] as? String,
               finishReason == "MAX_TOKENS" {
                print("🔄 [AIReplyService] 检测到MAX_TOKENS，尝试生成简化回复")
                return generateSyncFallbackReply(for: entry, tone: tone, wordCount: min(wordCount, 10))
            }
            
            // 检查是否有其他可用的内容字段
            if let text = firstCandidate["text"] as? String {
                print("🔄 [AIReplyService] 在candidate层级找到text字段，直接使用")
                return text  // 移除字数限制
            }
            
            throw AIReplyError.invalidResponse(details: "content字段缺失")
        }
        
        // 尝试获取parts数组和text
        if let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            print("📝 [AIReplyService] 成功获取回复文本")
            print("📝 [AIReplyService] AI回复长度: \(text.count)字符")
            
            // 移除字数限制，直接返回AI的完整回复
            return text
        } else {
            print("❌ [AIReplyService] 无法获取回复文本")
            print("📄 [AIReplyService] content结构: \(content)")
            
            // 详细分析content结构，帮助调试
            if let parts = content["parts"] as? [[String: Any]] {
                print("📊 [AIReplyService] parts数组长度: \(parts.count)")
                for (index, part) in parts.enumerated() {
                    print("📊 [AIReplyService] part[\(index)]的键: \(part.keys.joined(separator: ", "))")
                    if let text = part["text"] as? String {
                        print("📊 [AIReplyService] part[\(index)]的text长度: \(text.count)")
                    }
                }
            } else {
                print("📊 [AIReplyService] content的键: \(content.keys.joined(separator: ", "))")
            }
            
            // 检查是否因为token限制导致内容为空
            if let finishReason = firstCandidate["finishReason"] as? String,
               finishReason == "MAX_TOKENS" {
                print("🔄 [AIReplyService] 检测到MAX_TOKENS，使用备用回复")
                return generateSyncFallbackReply(for: entry, tone: tone, wordCount: min(wordCount, 20))
            }
            
            // 如果是role字段问题，可能是新的API响应格式
            if content["role"] != nil {
                print("🔄 [AIReplyService] 检测到role字段，可能是新API格式")
                
                // 尝试在content中查找文本内容
                if let text = content["text"] as? String {
                    print("🔄 [AIReplyService] 在content中找到text字段，直接使用")
                    return text  // 移除字数限制
                }
                
                // 如果没有找到text字段，使用备用回复
                print("🔄 [AIReplyService] 新API格式中没有找到text字段，使用备用回复")
                return generateSyncFallbackReply(for: entry, tone: tone, wordCount: min(wordCount, 20))
            }
            
            throw AIReplyError.invalidResponse(details: "parts数组或text字段缺失")
        }
    }
    
    // 生成备用回复（当token不足时使用）
    private func generateSyncFallbackReply(for entry: EmotionEntry, tone: AIReplyTone, wordCount: Int, language: DetectedLanguage = .chinese) -> String {
        print("🔄 [AIReplyService] 生成备用回复，语言: \(language.rawValue)，字数限制: \(wordCount)")
        
        let baseReply: String
        let backupPrefix: String
        
        switch language {
        case .chinese:
            baseReply = generateChineseFallbackReply(tone: tone)
            backupPrefix = "【备用】"
        case .english:
            baseReply = generateEnglishFallbackReply(tone: tone)
            backupPrefix = "[Backup] "
        case .other:
            // 对于其他语言，默认使用英文备用回复
            baseReply = generateEnglishFallbackReply(tone: tone)
            backupPrefix = "[Backup] "
        }
        
        let finalReply = "\(backupPrefix)\(baseReply)"
        print("✅ [AIReplyService] 备用回复生成完成: \(finalReply)")
        return finalReply
    }
    
    // 生成中文备用回复
    private func generateChineseFallbackReply(tone: AIReplyTone) -> String {
        let templates: [String]
        switch tone {
        case .warm:
            templates = [
                "我理解你的感受，这种情况确实不容易。无论如何，你都不是一个人。",
                "听到你的分享，我能感受到你内心的情绪。你的感受很真实，也很重要。",
                "感谢你愿意分享这些真实的感受。我会一直陪伴在你身边。"
            ]
        case .understanding:
            templates = [
                "你的感受是完全可以理解的，任何人在这种情况下都会有类似的反应。",
                "我深深理解你现在的感受，这些情绪都是正常的。",
                "你的每一个感受都是有意义的，我完全理解你的心情。"
            ]
        case .gentle:
            templates = [
                "轻轻地拥抱你，让时间慢慢地疗愈这些情绪。",
                "温柔地告诉你，这些感受都会过去的，请对自己温柔一些。",
                "慢慢来，给自己一些时间和空间去处理这些感受。"
            ]
        case .supportive:
            templates = [
                "我会一直支持你，无论发生什么。你不是一个人在战斗。",
                "你有我的全力支持，我们一起面对这个挑战。",
                "我永远站在你这边，支持你的每一个决定。"
            ]
        case .philosophical:
            templates = [
                "情绪如潮水，它们来了又去，但你的本质始终如一。",
                "在这个瞬息万变的世界中，你的感受是最真实的存在。",
                "每一个情绪都是人生体验的一部分，它们构成了完整的你。"
            ]
        case .empathetic:
            templates = [
                "我能感受到你的痛苦，就像我也在经历一样。你并不孤单。",
                "你的感受深深地触动了我，我完全理解你现在的心情。",
                "我感同身受你的情绪，这种共鸣让我们更加紧密地连接。"
            ]
        }
        
        return templates.randomElement() ?? "我理解你的感受，陪伴着你。"
    }
    
    // 生成英文备用回复
    private func generateEnglishFallbackReply(tone: AIReplyTone) -> String {
        let templates: [String]
        switch tone {
        case .warm:
            templates = [
                "I understand your feelings, and this situation is indeed not easy. No matter what, you are not alone.",
                "Hearing your sharing, I can feel the emotions in your heart. Your feelings are real and important.",
                "Thank you for being willing to share these genuine feelings. I will always be by your side."
            ]
        case .understanding:
            templates = [
                "Your feelings are completely understandable, anyone would have similar reactions in this situation.",
                "I deeply understand how you feel right now, these emotions are all normal.",
                "Every feeling you have is meaningful, and I completely understand your mood."
            ]
        case .gentle:
            templates = [
                "Gently embrace you, let time slowly heal these emotions.",
                "Gently tell you that these feelings will pass, please be gentle with yourself.",
                "Take your time, give yourself some time and space to process these feelings."
            ]
        case .supportive:
            templates = [
                "I will always support you, no matter what happens. You are not fighting alone.",
                "You have my full support, we will face this challenge together.",
                "I will always stand by your side and support every decision you make."
            ]
        case .philosophical:
            templates = [
                "Emotions are like tides, they come and go, but your essence remains unchanged.",
                "In this ever-changing world, your feelings are the most real existence.",
                "Every emotion is part of life experience, they make up the complete you."
            ]
        case .empathetic:
            templates = [
                "I can feel your pain, as if I am experiencing it too. You are not alone.",
                "Your feelings deeply touch me, I completely understand how you feel right now.",
                "I empathize with your emotions, this resonance connects us more closely."
            ]
        }
        
        return templates.randomElement() ?? "I understand your feelings and am here with you."
    }
    
    // MARK: - 新版 Prompt 构建方法
    
    /**
     * 使用 PromptManager 构建 AI 提示词
     * 
     * ## 功能说明
     * - 自动检测用户输入语言
     * - 使用配置驱动的模板系统
     * - 支持个性化调整
     * - 集成热更新机制
     * 
     * @param entry 用户情绪记录
     * @param tone 回复语气
     * @param wordCount 期望字数（传递给API配置）
     * @return String 完整的 AI Prompt
     * @throws AIReplyError Prompt构建失败的错误
     */
    private func buildPromptWithManager(
        for entry: EmotionEntry, 
        tone: AIReplyTone, 
        wordCount: Int
    ) async throws -> String {
        
        do {
            // 1. 检测用户输入语言
            let detectedLanguage = detectUserLanguage(from: entry)
            print("🌐 [AIReplyService] 检测到的语言: \(detectedLanguage.rawValue)")
            
            // 2. 使用 PromptManager 构建 Prompt
            let prompt = try await promptManager.buildPrompt(
                for: entry,
                tone: tone,
                language: detectedLanguage,
                includePersonalization: true // 启用个性化功能
            )
            
            print("✅ [AIReplyService] 使用新系统构建 Prompt 成功")
            return prompt
            
        } catch {
            print("❌ [AIReplyService] 新系统构建 Prompt 失败，降级到旧方法: \(error)")
            
            // 降级处理：使用旧的构建方法
            let detectedLanguage = detectUserLanguage(from: entry)
            return buildLegacyPrompt(for: entry, tone: tone, language: detectedLanguage)
        }
    }
    
    /**
     * 降级使用的旧版 Prompt 构建方法
     * 
     * ## 功能说明
     * 当新的 Prompt 管理系统失败时使用此方法作为备用
     * 保持基本的 AI 回信功能可用
     */
    private func buildLegacyPrompt(
        for entry: EmotionEntry, 
        tone: AIReplyTone, 
        language: DetectedLanguage
    ) -> String {
        
        // 简化的备用 Prompt 构建逻辑
        let dateFormatter = DateFormatter()
        let dateString: String
        
        switch language {
        case .chinese:
            dateFormatter.dateFormat = "yyyy年MM月dd日"
            dateString = dateFormatter.string(from: entry.date)
            return buildChinesePrompt(entry: entry, tone: tone, dateString: dateString)
        case .english:
            dateFormatter.dateFormat = "MM/dd/yyyy" 
            dateString = dateFormatter.string(from: entry.date)
            return buildEnglishPrompt(entry: entry, tone: tone, dateString: dateString)
        case .other:
            dateFormatter.dateFormat = "yyyy/MM/dd"
            dateString = dateFormatter.string(from: entry.date)
            return buildOtherLanguagePrompt(entry: entry, tone: tone, dateString: dateString)
        }
    }
    
    // MARK: - 重构后的备用回复生成
    
    /**
     * 生成备用回复（重构版本）
     * 
     * ## 重构变化
     * - 支持异步执行
     * - 集成语言检测
     * - 改善错误处理
     * - 支持个性化调整
     */
    private func generateFallbackReply(
        for entry: EmotionEntry, 
        tone: AIReplyTone, 
        wordCount: Int
    ) async throws -> String {
        
        print("🔄 [AIReplyService] 生成备用回复，字数限制: \(wordCount)")
        
        do {
            // 尝试使用 PromptManager 的轻量级模板
            let detectedLanguage = detectUserLanguage(from: entry)
            
            // 尝试获取备用模板
            if let lightweightPrompt = try? await promptManager.buildPrompt(
                for: entry,
                tone: tone,
                language: detectedLanguage,
                includePersonalization: false // 备用模板不使用个性化以保证简洁
            ) {
                // 截取适当长度作为备用回复
                let truncatedPrompt = String(lightweightPrompt.prefix(wordCount * 2))
                return "【智能备用】\(truncatedPrompt)"
            }
            
        } catch {
            print("⚠️ [AIReplyService] PromptManager 备用模板生成失败: \(error)")
        }
        
        // 最终降级：使用硬编码的备用回复
        return generateHardcodedFallbackReply(for: entry, tone: tone, language: detectUserLanguage(from: entry))
    }
    
    /**
     * 生成硬编码的备用回复
     * 
     * ## 使用场景
     * 当所有其他方法都失败时的最后保障
     */
    private func generateHardcodedFallbackReply(
        for entry: EmotionEntry, 
        tone: AIReplyTone, 
        language: DetectedLanguage
    ) -> String {
        
        let baseReply: String
        let prefix: String
        
        switch language {
        case .chinese:
            baseReply = generateChineseFallbackReply(tone: tone)
            prefix = "【备用】"
        case .english:
            baseReply = generateEnglishFallbackReply(tone: tone)
            prefix = "[Backup] "
        case .other:
            baseReply = generateEnglishFallbackReply(tone: tone)
            prefix = "[Backup] "
        }
        
        return "\(prefix)\(baseReply)"
    }
    
    // MARK: - 保留的旧版构建方法（用于降级）
    
    
    // 构建中文提示词
    private func buildChinesePrompt(entry: EmotionEntry, tone: AIReplyTone, dateString: String) -> String {
        let prompt = """
        你是AI朋友，\(tone.chinesePromptDescription)回复用户情绪记录。
        
        记录：
        日期：\(dateString)
        地点：\(entry.place)
        人员：\(entry.people)
        
        发生：\(entry.whatHappened ?? "未填写")
        想法：\(entry.think ?? "未填写")
        感受：\(entry.feel ?? "未填写")
        反应：\(entry.reaction ?? "未填写")
        需要：\(entry.need ?? "未填写")
        强度：\(entry.recordSeverity)/5
        """
        
        // 如果有处理内容，添加到提示词中
        var additionalInfo = ""
        if let why = entry.why {
            additionalInfo += "\n原因：\(why)"
        }
        if let ifElse = entry.ifElse {
            additionalInfo += "\n重来：\(ifElse)"
        }
        if let nextTime = entry.nextTime {
            additionalInfo += "\n下次：\(nextTime)"
        }
        if let processSeverity = entry.processSeverity {
            additionalInfo += "\n处理后：\(processSeverity)/5"
        }
        
        return prompt + additionalInfo + """
        
        要求：用\(tone.chineseDisplayName)语气，理解陪伴，自然回复。
        直接回复，无格式。
        """
    }
    
    // 构建英文提示词
    private func buildEnglishPrompt(entry: EmotionEntry, tone: AIReplyTone, dateString: String) -> String {
        let prompt = """
        You are an AI friend who replies to user's emotion records with \(tone.englishPromptDescription).
        
        Record:
        Date: \(dateString)
        Place: \(entry.place)
        People: \(entry.people)
        
        What happened: \(entry.whatHappened ?? "Not filled")
        Thoughts: \(entry.think ?? "Not filled")
        Feelings: \(entry.feel ?? "Not filled")
        Reaction: \(entry.reaction ?? "Not filled")
        Needs: \(entry.need ?? "Not filled")
        Intensity: \(entry.recordSeverity)/5
        """
        
        // 如果有处理内容，添加到提示词中
        var additionalInfo = ""
        if let why = entry.why {
            additionalInfo += "\nReason: \(why)"
        }
        if let ifElse = entry.ifElse {
            additionalInfo += "\nIf I could redo: \(ifElse)"
        }
        if let nextTime = entry.nextTime {
            additionalInfo += "\nNext time: \(nextTime)"
        }
        if let processSeverity = entry.processSeverity {
            additionalInfo += "\nAfter processing: \(processSeverity)/5"
        }
        
        return prompt + additionalInfo + """
        
        Requirements: Reply with \(tone.englishDisplayName) tone, understand and accompany, natural response.
        Reply directly, no formatting.
        """
    }
    
    // 构建其他语言提示词
    private func buildOtherLanguagePrompt(entry: EmotionEntry, tone: AIReplyTone, dateString: String) -> String {
        let prompt = """
        You are an AI friend. Please detect the language used in the user's emotion record and reply in the same language with \(tone.englishPromptDescription).
        
        Record:
        Date: \(dateString)
        Place: \(entry.place)
        People: \(entry.people)
        
        What happened: \(entry.whatHappened ?? "Not filled")
        Thoughts: \(entry.think ?? "Not filled")
        Feelings: \(entry.feel ?? "Not filled")
        Reaction: \(entry.reaction ?? "Not filled")
        Needs: \(entry.need ?? "Not filled")
        Intensity: \(entry.recordSeverity)/5
        """
        
        // 如果有处理内容，添加到提示词中
        var additionalInfo = ""
        if let why = entry.why {
            additionalInfo += "\nReason: \(why)"
        }
        if let ifElse = entry.ifElse {
            additionalInfo += "\nIf I could redo: \(ifElse)"
        }
        if let nextTime = entry.nextTime {
            additionalInfo += "\nNext time: \(nextTime)"
        }
        if let processSeverity = entry.processSeverity {
            additionalInfo += "\nAfter processing: \(processSeverity)/5"
        }
        
        return prompt + additionalInfo + """
        
        IMPORTANT: Detect the primary language from the user's input text above and reply in the SAME language. Use \(tone.englishDisplayName) tone.
        Reply directly, no formatting.
        """
    }
    
    // 安排延迟回信（正式模式）
    private func scheduleDelayedReply(reply: String, for entry: EmotionEntry, tone: AIReplyTone) {
        // 生成2-8小时的随机延迟
        let minDelay: TimeInterval = 2 * 60 * 60  // 2小时
        let maxDelay: TimeInterval = 8 * 60 * 60  // 8小时
        let randomDelay = TimeInterval.random(in: minDelay...maxDelay)
        
        // 计算回信时间
        let replyTime = Date().addingTimeInterval(randomDelay)
        
        // 安排延迟执行
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) { [weak self] in
            Task {
                await self?.deliverReply(reply, for: entry, tone: tone, at: replyTime)
            }
        }
    }
    
    // 发送回信并显示通知
    private func deliverReply(_ reply: String, for entry: EmotionEntry, tone: AIReplyTone, at deliveryTime: Date) async {
        // 创建AI回信对象
        let aiReply = AIReply(
            emotionEntryId: entry.id,
            content: reply,
            tone: tone,
            receivedDate: deliveryTime,
            isRead: false
        )
        
        // 添加到收件箱（这里需要通知InboxViewModel）
        await MainActor.run {
            NotificationCenter.default.post(
                name: .aiReplyReceived,
                object: aiReply
            )
        }
        
        // 发送本地通知
        await notificationService.sendReplyNotification(for: aiReply)
    }
    
    // API连接测试
    func testAPIConnection() async {
        print("🔍 [AIReplyService] 开始API连接测试")
        
        await MainActor.run {
            apiConnectionStatus = .testing
        }
        
        // 创建测试用的简单情绪记录
        let testEntry = EmotionEntry(
            date: Date(),
            place: "测试地点",
            people: "测试人员",
            whatHappened: "进行API连接测试",
            think: "希望连接正常",
            feel: "有些紧张",
            reaction: "仔细观察结果",
            need: "需要确认连接状态",
            recordSeverity: 3
        )
        
        do {
            let _ = try await requestGeminiReply(for: testEntry, tone: .warm, wordCount: 10)
            print("✅ [AIReplyService] API连接测试成功")
            
            await MainActor.run {
                apiConnectionStatus = .connected
            }
        } catch {
            print("❌ [AIReplyService] API连接测试失败: \(error)")
            
            await MainActor.run {
                if let aiError = error as? AIReplyError {
                    switch aiError {
                    case .apiKeyInvalid:
                        apiConnectionStatus = .invalidAPIKey
                    case .networkError:
                        apiConnectionStatus = .networkError
                    case .rateLimitExceeded:
                        apiConnectionStatus = .rateLimited
                    default:
                        apiConnectionStatus = .failed
                    }
                } else {
                    apiConnectionStatus = .failed
                }
            }
        }
    }
    
    
    // 检测用户输入内容的主要语言
    private func detectUserLanguage(from entry: EmotionEntry) -> DetectedLanguage {
        print("🔍 [AIReplyService] 开始检测用户输入语言...")
        // 收集所有用户输入的文本内容
        var allText = ""
        
        if let whatHappened = entry.whatHappened, !whatHappened.isEmpty {
            allText += whatHappened + " "
        }
        if let think = entry.think, !think.isEmpty {
            allText += think + " "
        }
        if let feel = entry.feel, !feel.isEmpty {
            allText += feel + " "
        }
        if let reaction = entry.reaction, !reaction.isEmpty {
            allText += reaction + " "
        }
        if let need = entry.need, !need.isEmpty {
            allText += need + " "
        }
        if let why = entry.why, !why.isEmpty {
            allText += why + " "
        }
        if let ifElse = entry.ifElse, !ifElse.isEmpty {
            allText += ifElse + " "
        }
        if let nextTime = entry.nextTime, !nextTime.isEmpty {
            allText += nextTime + " "
        }
        
        // 如果没有文本内容，默认返回中文
        guard !allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("📝 [AIReplyService] 无文本内容，默认使用中文")
            return .chinese
        }
        
        // 使用 NaturalLanguage 框架进行语言检测
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(allText)
        
        if let dominantLanguage = recognizer.dominantLanguage {
            print("📝 [AIReplyService] 检测到的主要语言: \(dominantLanguage.rawValue)")
            
            switch dominantLanguage {
            case .simplifiedChinese, .traditionalChinese:
                return .chinese
            case .english:
                return .english
            default:
                return .other
            }
        } else {
            // 如果检测失败，尝试简单的字符判断
            let chineseCharacterSet = CharacterSet(charactersIn: "\u{4e00}"..."\u{9fff}")
            let englishCharacterSet = CharacterSet.letters
            
            let chineseCount = allText.unicodeScalars.filter { chineseCharacterSet.contains($0) }.count
            let englishCount = allText.unicodeScalars.filter { englishCharacterSet.contains($0) && !chineseCharacterSet.contains($0) }.count
            
            print("📝 [AIReplyService] 字符统计 - 中文字符: \(chineseCount), 英文字符: \(englishCount)")
            
            if chineseCount > englishCount {
                return .chinese
            } else if englishCount > chineseCount {
                return .english
            } else {
                return .chinese // 默认中文
            }
        }
    }
    
    // 获取用户设置的语气
    private func getUserSelectedTone() -> AIReplyTone? {
        // 从UserDefaults中读取用户设置的语气
        guard let toneRawValue = UserDefaults.standard.string(forKey: "selectedReplyTone"),
              let replyTone = ReplyTone(rawValue: toneRawValue) else {
            return nil
        }
        
        print("🎭 [AIReplyService] 从设置中获取语气: \(replyTone.rawValue)")
        
        // 直接使用 toAIReplyTone 属性，它已经处理了随机逻辑
        let selectedTone = replyTone.toAIReplyTone
        
        if replyTone == .random {
            print("🎭 [AIReplyService] 用户选择随机人格，随机选择: \(selectedTone.displayName)")
        }
        
        return selectedTone
    }
}

// API连接状态枚举
enum APIConnectionStatus {
    case unknown        // 未知状态
    case testing        // 测试中
    case connected      // 连接成功
    case failed         // 连接失败
    case invalidAPIKey  // API密钥无效
    case networkError   // 网络错误
    case rateLimited    // 频率限制
    
    var description: String {
        switch self {
        case .unknown:
            return "未知"
        case .testing:
            return "测试中..."
        case .connected:
            return "连接正常"
        case .failed:
            return "连接失败"
        case .invalidAPIKey:
            return "API密钥无效"
        case .networkError:
            return "网络错误"
        case .rateLimited:
            return "频率限制"
        }
    }
    
    var color: String {
        switch self {
        case .unknown:
            return "gray"
        case .testing:
            return "blue"
        case .connected:
            return "green"
        case .failed, .invalidAPIKey, .networkError, .rateLimited:
            return "red"
        }
    }
}

// AI回信错误类型
enum AIReplyError: Error, Equatable {
    case invalidURL
    case requestFailed(statusCode: Int, message: String)
    case invalidResponse(details: String)
    case networkError(underlying: Error)
    case apiKeyInvalid
    case rateLimitExceeded
    case contentFiltered
    case serviceBusy
    
    // 自定义Equatable实现
    static func == (lhs: AIReplyError, rhs: AIReplyError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.requestFailed(let lhsCode, let lhsMessage), .requestFailed(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.invalidResponse(let lhsDetails), .invalidResponse(let rhsDetails)):
            return lhsDetails == rhsDetails
        case (.networkError, .networkError):
            return true // 简化比较，只比较错误类型
        case (.apiKeyInvalid, .apiKeyInvalid):
            return true
        case (.rateLimitExceeded, .rateLimitExceeded):
            return true
        case (.contentFiltered, .contentFiltered):
            return true
        case (.serviceBusy, .serviceBusy):
            return true
        default:
            return false
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的API地址"
        case .requestFailed(let statusCode, let message):
            return "请求失败（状态码：\(statusCode)）：\(message)"
        case .invalidResponse(let details):
            return "无效的响应格式：\(details)"
        case .networkError(let underlying):
            return "网络连接错误：\(underlying.localizedDescription)"
        case .apiKeyInvalid:
            return "API密钥无效，请检查配置"
        case .rateLimitExceeded:
            return "API调用频率超限，请稍后重试"
        case .contentFiltered:
            return "内容被过滤，请调整情绪记录内容"
        case .serviceBusy:
            return "AI服务繁忙，请稍后重试"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "系统配置错误，请联系开发者"
        case .requestFailed(let statusCode, _):
            switch statusCode {
            case 401:
                return "认证失败，请检查API密钥"
            case 403:
                return "访问被拒绝，请检查API权限"
            case 429:
                return "请求过于频繁，请稍后重试"
            case 500...599:
                return "AI服务暂时不可用，请稍后重试"
            default:
                return "请求失败，请稍后重试"
            }
        case .invalidResponse:
            return "AI回复格式异常，已为您重新生成"
        case .networkError:
            return "网络连接失败，请检查网络连接"
        case .apiKeyInvalid:
            return "API密钥无效，请联系开发者"
        case .rateLimitExceeded:
            return "使用过于频繁，请稍后重试"
        case .contentFiltered:
            return "内容不符合要求，请重新编辑情绪记录"
        case .serviceBusy:
            return "AI服务繁忙，正在为您重新生成回复"
        }
    }
}

// 通知名称扩展
extension Notification.Name {
    static let aiReplyReceived = Notification.Name("aiReplyReceived")
    static let aiReplyGenerated = Notification.Name("aiReplyGenerated")
}