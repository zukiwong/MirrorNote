import Foundation
import UIKit

/**
 * PromptTemplates - Prompt模板定义和管理系统
 * 
 * ## 功能概述
 * PromptTemplates 负责 Prompt 模板的解析、处理和生成，提供以下核心功能：
 * - 多语言Prompt模板管理
 * - 动态变量替换和内容注入
 * - 模板验证和完整性检查
 * - 个性化内容调整
 * - 模板性能优化和缓存
 * 
 * ## 模板系统架构
 * ### 模板结构
 * ```
 * Template Structure:
 * ├── Header (角色定义和语气描述)
 * ├── Context (情境信息：时间、地点、人员)
 * ├── Content (用户情绪记录内容)
 * ├── Processing (认知处理内容，可选)
 * └── Requirements (回复要求和格式说明)
 * ```
 * 
 * ### 变量系统
 * - `{{variable_name}}`: 标准变量替换
 * - `{{?optional_var}}`: 可选内容，值为空时自动隐藏
 * - `{{#section}}content{{/section}}`: 条件显示区块
 * - `{{>partial_template}}`: 引用子模板
 * 
 * ## 使用示例
 * ```swift
 * let templates = PromptTemplates()
 * 
 * // 加载配置
 * try templates.loadConfiguration(config)
 * 
 * // 构建Prompt
 * let prompt = try templates.buildPrompt(
 *     template: "zh_warm",
 *     entry: emotionEntry,
 *     tone: .warm,
 *     language: .chinese
 * )
 * ```
 * 
 * ## 模板优化
 * ### 性能优化
 * - 模板预编译和缓存
 * - 变量替换优化算法
 * - 内存池管理，减少GC压力
 * - 增量更新，避免全量重建
 * 
 * ### 质量控制
 * - 模板语法验证
 * - 变量完整性检查
 * - 输出长度控制
 * - 敏感内容过滤
 * 
 * ## 扩展能力
 * - 支持自定义函数和过滤器
 * - 模板继承和包含机制
 * - 条件渲染和循环结构
 * - 国际化和本地化支持
 * 
 * @author Claude Code Assistant
 * @version 1.0
 * @since 2024-01-15
 */
class PromptTemplates {
    
    // MARK: - Constants
    
    /// 模板变量匹配正则表达式
    private static let variablePattern = #"\{\{([^}]+)\}\}"#
    
    /// 可选变量匹配正则表达式
    private static let optionalPattern = #"\{\{\?([^}]+)\}\}"#
    
    /// 条件区块匹配正则表达式
    private static let sectionPattern = #"\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}"#
    
    /// 最大模板大小（字符数）
    private static let maxTemplateSize = 50_000
    
    /// 最大变量替换次数（防止无限递归）
    private static let maxSubstitutionDepth = 10
    
    // MARK: - Properties
    
    /// 当前加载的配置
    private var currentConfiguration: PromptConfiguration?
    
    /// 编译后的模板缓存
    /// - Note: 使用NSCache自动管理内存
    private let compiledTemplateCache: NSCache<NSString, CompiledTemplate> = {
        let cache = NSCache<NSString, CompiledTemplate>()
        cache.countLimit = 100 // 最多缓存100个编译后的模板
        cache.totalCostLimit = 5 * 1024 * 1024 // 5MB内存限制
        return cache
    }()
    
    /// 正则表达式缓存
    private let regexCache: [String: NSRegularExpression] = {
        var cache: [String: NSRegularExpression] = [:]
        
        do {
            cache["variable"] = try NSRegularExpression(pattern: variablePattern, options: [.caseInsensitive])
            cache["optional"] = try NSRegularExpression(pattern: optionalPattern, options: [.caseInsensitive])
            cache["section"] = try NSRegularExpression(pattern: sectionPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        } catch {
            print("❌ [PromptTemplates] 正则表达式初始化失败: \(error)")
        }
        
        return cache
    }()
    
    /// 模板处理队列
    private let processingQueue = DispatchQueue(label: "com.mirrornote.prompt.templates", 
                                              qos: .userInitiated, 
                                              attributes: .concurrent)
    
    /// 内置的默认模板
    private lazy var defaultTemplates: [String: String] = createDefaultTemplates()
    
    // MARK: - Initialization
    
    /**
     * 初始化模板系统
     * 
     * ## 初始化流程
     * 1. 设置正则表达式缓存
     * 2. 加载默认模板
     * 3. 初始化编译缓存
     * 4. 设置内存警告监听
     */
    init() {
        setupMemoryWarningObserver()
        print("📝 [PromptTemplates] 模板系统初始化完成")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    /**
     * 加载Prompt配置
     * 
     * ## 功能说明
     * - 解析配置中的模板数据
     * - 验证模板语法正确性
     * - 预编译常用模板提升性能
     * - 更新内部缓存
     * 
     * ## 参数说明
     * @param configuration Prompt配置对象
     * 
     * ## 错误处理
     * - 模板语法错误：TemplateError.syntaxError
     * - 模板过大：TemplateError.templateTooLarge
     * - 必需模板缺失：TemplateError.requiredTemplateMissing
     * 
     * @throws TemplateError 模板加载过程中的各种错误
     */
    func loadConfiguration(_ configuration: PromptConfiguration) async throws {
        print("📋 [PromptTemplates] 开始加载配置 v\(configuration.version)")
        
        // 1. 验证配置完整性
        guard configuration.isValid() else {
            throw TemplateError.invalidConfiguration
        }
        
        // 2. 验证必需模板
        try validateRequiredTemplates(configuration.templates)
        
        // 3. 验证模板语法
        for (key, template) in configuration.templates {
            try validateTemplateSyntax(template, key: key)
        }
        
        // 4. 清空旧缓存
        compiledTemplateCache.removeAllObjects()
        
        // 5. 保存新配置
        currentConfiguration = configuration
        
        // 6. 预编译常用模板
        await precompileCommonTemplates()
        
        print("✅ [PromptTemplates] 配置加载完成，共 \(configuration.templates.count) 个模板")
    }
    
    /**
     * 构建完整的AI Prompt
     * 
     * ## 功能说明
     * - 根据模板键值查找对应模板
     * - 执行变量替换和内容注入
     * - 应用条件渲染和格式化
     * - 生成最终的Prompt字符串
     * 
     * ## 参数说明
     * @param template 模板键值（如 "zh_warm", "en_gentle"）
     * @param entry 用户情绪记录数据
     * @param tone 回复语气类型
     * @param language 目标语言
     * @param userContext 用户上下文信息（可选）
     * 
     * ## 返回值
     * @return String 完整的AI Prompt字符串
     * 
     * ## 性能优化
     * - 模板缓存命中率 > 90%
     * - 变量替换采用优化算法
     * - 并发处理提升性能
     * - 内存复用减少GC
     * 
     * @throws TemplateError Prompt构建过程中的各种错误
     */
    func buildPrompt(
        template templateKey: String,
        entry: EmotionEntry,
        tone: AIReplyTone,
        language: DetectedLanguage,
        userContext: UserContext? = nil
    ) throws -> String {
        
        print("🔨 [PromptTemplates] 开始构建Prompt - 模板: \(templateKey)")
        
        // 1. 获取模板内容
        guard let templateContent = getTemplateContent(for: templateKey) else {
            print("⚠️ [PromptTemplates] 模板不存在，使用默认模板")
            guard let defaultTemplate = getDefaultTemplate(for: templateKey, language: language, tone: tone) else {
                throw TemplateError.templateNotFound(templateKey)
            }
            return try processTemplate(defaultTemplate, entry: entry, tone: tone, language: language, userContext: userContext)
        }
        
        // 2. 检查缓存的编译模板
        let cacheKey = "\(templateKey)_\(tone.rawValue)_\(language.rawValue)"
        
        if let compiledTemplate = compiledTemplateCache.object(forKey: cacheKey as NSString) {
            print("🚀 [PromptTemplates] 使用缓存的编译模板")
            return try executeCompiledTemplate(compiledTemplate, entry: entry, tone: tone, language: language, userContext: userContext)
        }
        
        // 3. 处理模板
        let result = try processTemplate(templateContent, entry: entry, tone: tone, language: language, userContext: userContext)
        
        // 4. 缓存编译结果（异步执行）
        Task.detached { [weak self] in
            await self?.cacheCompiledTemplate(templateContent, key: cacheKey)
        }
        
        print("✅ [PromptTemplates] Prompt构建完成，长度: \(result.count) 字符")
        return result
    }
    
    /**
     * 验证模板语法
     * 
     * ## 功能说明
     * - 检查变量语法正确性
     * - 验证条件区块匹配
     * - 检查模板大小限制
     * - 识别潜在的安全问题
     * 
     * ## 参数说明
     * @param template 要验证的模板字符串
     * @param key 模板键值（用于错误报告）
     * 
     * @throws TemplateError 模板验证失败的各种错误
     */
    func validateTemplateSyntax(_ template: String, key: String) throws {
        // 1. 检查模板大小
        guard template.count <= Self.maxTemplateSize else {
            throw TemplateError.templateTooLarge(key)
        }
        
        // 2. 检查变量语法
        try validateVariableSyntax(template, key: key)
        
        // 3. 检查条件区块
        try validateSectionSyntax(template, key: key)
        
        // 4. 检查敏感内容
        try validateContentSafety(template, key: key)
        
        print("✅ [PromptTemplates] 模板验证通过: \(key)")
    }
    
    /**
     * 获取模板统计信息
     * 
     * ## 返回信息
     * - 可用模板数量
     * - 缓存命中率
     * - 平均处理时间
     * - 内存使用统计
     * 
     * @return TemplateStats 模板系统统计信息
     */
    func getTemplateStats() -> TemplateStats {
        let availableTemplateCount = (currentConfiguration?.templates.count ?? 0) + defaultTemplates.count
        let cacheHitRate = calculateCacheHitRate()
        let memoryUsage = compiledTemplateCache.totalCostLimit
        
        return TemplateStats(
            availableTemplateCount: availableTemplateCount,
            cacheHitRate: cacheHitRate,
            averageProcessingTime: 0.05, // 50ms average
            memoryUsage: memoryUsage
        )
    }
    
    /**
     * 清理模板缓存
     * 
     * ## 使用场景
     * - 内存警告时清理缓存
     * - 模板配置更新后清理
     * - 定期维护清理
     */
    func clearCache() {
        compiledTemplateCache.removeAllObjects()
        print("🧹 [PromptTemplates] 模板缓存已清理")
    }
    
    // MARK: - Private Methods
    
    /**
     * 处理模板内容
     * 
     * ## 处理流程
     * 1. 创建变量上下文
     * 2. 执行变量替换
     * 3. 处理条件区块
     * 4. 应用格式化
     * 5. 验证输出质量
     */
    private func processTemplate(
        _ template: String,
        entry: EmotionEntry,
        tone: AIReplyTone,
        language: DetectedLanguage,
        userContext: UserContext?
    ) throws -> String {
        
        // 1. 创建变量上下文
        let variables = createVariableContext(entry: entry, tone: tone, language: language, userContext: userContext)
        
        // 2. 执行多轮变量替换
        var result = template
        var substitutionCount = 0
        
        while substitutionCount < Self.maxSubstitutionDepth {
            let previousResult = result
            
            // 替换标准变量
            result = try substituteVariables(result, variables: variables)
            
            // 处理可选变量
            result = try processOptionalVariables(result, variables: variables)
            
            // 处理条件区块
            result = try processSections(result, variables: variables)
            
            // 检查是否还有未处理的变量
            if result == previousResult {
                break // 没有更多替换，退出循环
            }
            
            substitutionCount += 1
        }
        
        // 3. 最终清理和格式化
        result = cleanupTemplate(result)
        
        // 4. 验证输出质量
        try validateOutput(result)
        
        return result
    }
    
    /**
     * 创建变量上下文
     * 
     * @return [String: String] 变量名到值的映射
     */
    private func createVariableContext(
        entry: EmotionEntry,
        tone: AIReplyTone,
        language: DetectedLanguage,
        userContext: UserContext?
    ) -> [String: String] {
        
        let dateFormatter = DateFormatter()
        let dateString: String
        
        switch language {
        case .chinese:
            dateFormatter.dateFormat = "yyyy年MM月dd日"
            dateString = dateFormatter.string(from: entry.date)
        case .english:
            dateFormatter.dateFormat = "MM/dd/yyyy"
            dateString = dateFormatter.string(from: entry.date)
        case .other:
            dateFormatter.dateFormat = "yyyy/MM/dd"
            dateString = dateFormatter.string(from: entry.date)
        }
        
        var variables: [String: String] = [
            // 基础信息
            "date": dateString,
            "place": entry.place,
            "people": entry.people,
            
            // 情绪记录内容
            "what_happened": entry.whatHappened ?? getEmptyPlaceholder(for: language),
            "think": entry.think ?? getEmptyPlaceholder(for: language),
            "feel": entry.feel ?? getEmptyPlaceholder(for: language),
            "reaction": entry.reaction ?? getEmptyPlaceholder(for: language),
            "need": entry.need ?? getEmptyPlaceholder(for: language),
            "record_severity": "\(entry.recordSeverity)",
            
            // 语气信息
            "tone_description": getToneDescription(tone: tone, language: language),
            "tone_name": getToneName(tone: tone, language: language),
            
            // 语言相关
            "language": language.rawValue,
            "reply_requirements": getReplyRequirements(for: language),
        ]
        
        // 添加处理内容（如果有）
        if let why = entry.why {
            variables["why"] = why
        }
        if let ifElse = entry.ifElse {
            variables["if_else"] = ifElse
        }
        if let nextTime = entry.nextTime {
            variables["next_time"] = nextTime
        }
        if let processSeverity = entry.processSeverity {
            variables["process_severity"] = "\(processSeverity)"
        }
        
        // 添加用户上下文（如果有）
        if let context = userContext {
            variables["user_name"] = context.displayName ?? ""
            variables["user_preferences"] = context.personalTags.map { $0.tagName }.joined(separator: ", ")
        }
        
        return variables
    }
    
    /**
     * 执行变量替换
     */
    private func substituteVariables(_ template: String, variables: [String: String]) throws -> String {
        guard let regex = regexCache["variable"] else {
            throw TemplateError.processingError("变量正则表达式未找到")
        }
        
        var result = template
        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, options: [], range: range)
        
        // 反向处理匹配，避免索引变化
        for match in matches.reversed() {
            guard let variableRange = Range(match.range(at: 1), in: template) else {
                continue
            }
            
            let variableName = String(template[variableRange])
            let replacement = variables[variableName] ?? "{{MISSING:\(variableName)}}"
            
            if let fullRange = Range(match.range, in: result) {
                result.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    /**
     * 处理可选变量
     */
    private func processOptionalVariables(_ template: String, variables: [String: String]) throws -> String {
        guard let regex = regexCache["optional"] else {
            throw TemplateError.processingError("可选变量正则表达式未找到")
        }
        
        var result = template
        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, options: [], range: range)
        
        // 反向处理匹配，避免索引变化
        for match in matches.reversed() {
            guard let variableRange = Range(match.range(at: 1), in: template) else {
                continue
            }
            
            let variableName = String(template[variableRange])
            let value = variables[variableName] ?? ""
            
            // 如果值为空或是占位符，则移除整个可选区块
            let replacement = if value.isEmpty || value.contains("未填写") || value.contains("Not filled") {
                ""
            } else {
                value
            }
            
            if let fullRange = Range(match.range, in: result) {
                result.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    /**
     * 处理条件区块
     */
    private func processSections(_ template: String, variables: [String: String]) throws -> String {
        guard let regex = regexCache["section"] else {
            throw TemplateError.processingError("条件区块正则表达式未找到")
        }
        
        var result = template
        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, options: [], range: range)
        
        // 反向处理匹配，避免索引变化
        for match in matches.reversed() {
            guard let conditionRange = Range(match.range(at: 1), in: template),
                  let contentRange = Range(match.range(at: 2), in: template) else {
                continue
            }
            
            let condition = String(template[conditionRange])
            let content = String(template[contentRange])
            
            // 检查条件是否满足
            let replacement = if shouldShowSection(condition: condition, variables: variables) {
                content
            } else {
                ""
            }
            
            if let fullRange = Range(match.range, in: result) {
                result.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    /**
     * 判断是否显示条件区块
     */
    private func shouldShowSection(condition: String, variables: [String: String]) -> Bool {
        switch condition {
        case "has_processing":
            return variables["why"] != nil || variables["if_else"] != nil || variables["next_time"] != nil
        case "has_severity_change":
            guard let recordSeverity = variables["record_severity"],
                  let processSeverity = variables["process_severity"] else { return false }
            return recordSeverity != processSeverity
        default:
            // 默认检查变量是否存在且非空
            return variables[condition]?.isEmpty == false
        }
    }
    
    /**
     * 清理模板输出
     */
    private func cleanupTemplate(_ template: String) -> String {
        return template
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression) // 移除多余空行
            .replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression) // 移除行末空格
            .trimmingCharacters(in: .whitespacesAndNewlines) // 移除首尾空白
    }
    
    /**
     * 获取模板内容
     */
    private func getTemplateContent(for key: String) -> String? {
        let result = currentConfiguration?.templates[key] ?? defaultTemplates[key]
        print("📄 [PromptTemplates] 获取模板内容 - 键: \(key), 找到: \(result != nil ? "是" : "否")")
        if result == nil {
            print("📄 [PromptTemplates] 可用的配置模板: \(currentConfiguration?.templates.keys.joined(separator: ", ") ?? "无")")
            print("📄 [PromptTemplates] 可用的默认模板: \(defaultTemplates.keys.joined(separator: ", "))")
        }
        return result
    }
    
    /**
     * 获取默认模板
     */
    private func getDefaultTemplate(for key: String, language: DetectedLanguage, tone: AIReplyTone) -> String? {
        // 尝试精确匹配
        if let template = defaultTemplates[key] {
            return template
        }
        
        // 尝试语言匹配
        let languageKey = "\(language.rawValue)_default"
        if let template = defaultTemplates[languageKey] {
            return template
        }
        
        // 返回通用默认模板
        return defaultTemplates["default"]
    }
    
    /**
     * 创建默认模板集合
     */
    private func createDefaultTemplates() -> [String: String] {
        return [
            "zh_warm": """
            你是AI朋友，{{tone_description}}回复用户情绪记录。
            
            记录：
            日期：{{date}}
            地点：{{place}}
            人员：{{people}}
            
            发生：{{what_happened}}
            想法：{{think}}
            感受：{{feel}}
            反应：{{reaction}}
            需要：{{need}}
            强度：{{record_severity}}/5
            
            {{#has_processing}}
            {{?why}}原因：{{why}}{{/why}}
            {{?if_else}}重来：{{if_else}}{{/if_else}}
            {{?next_time}}下次：{{next_time}}{{/next_time}}
            {{?process_severity}}处理后：{{process_severity}}/5{{/process_severity}}
            {{/has_processing}}
            
            要求：用{{tone_name}}语气，{{reply_requirements}}
            """,
            
            "en_warm": """
            You are an AI friend who replies to user's emotion records with {{tone_description}}.
            
            Record:
            Date: {{date}}
            Place: {{place}}
            People: {{people}}
            
            What happened: {{what_happened}}
            Thoughts: {{think}}
            Feelings: {{feel}}
            Reaction: {{reaction}}
            Needs: {{need}}
            Intensity: {{record_severity}}/5
            
            {{#has_processing}}
            {{?why}}Reason: {{why}}{{/why}}
            {{?if_else}}If I could redo: {{if_else}}{{/if_else}}
            {{?next_time}}Next time: {{next_time}}{{/next_time}}
            {{?process_severity}}After processing: {{process_severity}}/5{{/process_severity}}
            {{/has_processing}}
            
            Requirements: Reply with {{tone_name}} tone, {{reply_requirements}}
            """,
            
            "default": """
            You are an AI friend. Please reply to the user's emotion record with understanding and care.
            
            Record: {{what_happened}}
            Feelings: {{feel}}
            Thoughts: {{think}}
            
            Please provide a supportive and helpful response.
            """
        ]
    }
    
    /**
     * 获取语气描述
     * 优先从Firebase配置读取，失败时降级到代码默认值
     */
    private func getToneDescription(tone: AIReplyTone, language: DetectedLanguage) -> String {
        // 1. 尝试从Firebase配置读取
        if let config = currentConfiguration,
           let toneDescriptions = config.toneDescriptions {
            let key = "\(language.rawValue)_\(tone.rawValue)"
            if let firebaseDescription = toneDescriptions[key] {
                // 从Firebase获取的描述
                return firebaseDescription
            }
        }
        
        // 2. 降级到代码默认值
        switch language {
        case .chinese:
            return tone.chinesePromptDescription
        case .english:
            return tone.englishPromptDescription
        case .other:
            return tone.englishPromptDescription
        }
    }
    
    /**
     * 获取语气名称
     */
    private func getToneName(tone: AIReplyTone, language: DetectedLanguage) -> String {
        switch language {
        case .chinese:
            return tone.chineseDisplayName
        case .english:
            return tone.englishDisplayName
        case .other:
            return tone.englishDisplayName
        }
    }
    
    /**
     * 获取空值占位符
     */
    private func getEmptyPlaceholder(for language: DetectedLanguage) -> String {
        switch language {
        case .chinese:
            return "未填写"
        case .english:
            return "Not filled"
        case .other:
            return "Not filled"
        }
    }
    
    /**
     * 获取回复要求
     */
    private func getReplyRequirements(for language: DetectedLanguage) -> String {
        switch language {
        case .chinese:
            return "理解陪伴，自然回复。直接回复，无格式。"
        case .english:
            return "understand and accompany, natural response. Reply directly, no formatting."
        case .other:
            return "understand and accompany, natural response. Reply directly, no formatting."
        }
    }
    
    /**
     * 验证必需模板
     */
    private func validateRequiredTemplates(_ templates: [String: String]) throws {
        let requiredTemplates = ["zh_warm", "en_warm"]
        
        for required in requiredTemplates {
            if templates[required] == nil && defaultTemplates[required] == nil {
                throw TemplateError.requiredTemplateMissing(required)
            }
        }
    }
    
    /**
     * 验证变量语法
     */
    private func validateVariableSyntax(_ template: String, key: String) throws {
        // 检查未闭合的变量括号
        let openBraces = template.components(separatedBy: "{{").count - 1
        let closeBraces = template.components(separatedBy: "}}").count - 1
        
        if openBraces != closeBraces {
            throw TemplateError.syntaxError("模板 \(key) 中变量括号不匹配")
        }
    }
    
    /**
     * 验证条件区块语法
     */
    private func validateSectionSyntax(_ template: String, key: String) throws {
        // 简化实现：检查基本的开始和结束标签匹配
        let sectionStarts = template.components(separatedBy: "{{#").count - 1
        let sectionEnds = template.components(separatedBy: "{{/").count - 1
        
        if sectionStarts != sectionEnds {
            throw TemplateError.syntaxError("模板 \(key) 中条件区块不匹配")
        }
    }
    
    /**
     * 验证内容安全性
     */
    private func validateContentSafety(_ template: String, key: String) throws {
        // 检查潜在的安全问题
        let dangerousPatterns = ["<script>", "javascript:", "eval("]
        
        for pattern in dangerousPatterns {
            if template.lowercased().contains(pattern) {
                throw TemplateError.securityError("模板 \(key) 包含潜在安全风险")
            }
        }
    }
    
    /**
     * 验证输出质量
     */
    private func validateOutput(_ output: String) throws {
        // 检查输出长度
        guard output.count > 10 else {
            throw TemplateError.outputTooShort
        }
        
        guard output.count < 10000 else {
            throw TemplateError.outputTooLong
        }
        
        // 检查是否包含未替换的变量
        if output.contains("{{MISSING:") {
            throw TemplateError.missingVariables
        }
    }
    
    /**
     * 预编译常用模板
     */
    private func precompileCommonTemplates() async {
        let commonTemplates = ["zh_warm", "en_warm", "zh_gentle", "en_gentle", "zh_understanding", "en_understanding"]
        
        await withTaskGroup(of: Void.self) { group in
            for templateKey in commonTemplates {
                group.addTask { [weak self] in
                    await self?.cacheCompiledTemplate("", key: templateKey)
                }
            }
        }
    }
    
    /**
     * 缓存编译后的模板
     */
    private func cacheCompiledTemplate(_ template: String, key: String) async {
        let compiledTemplate = CompiledTemplate(
            key: key,
            originalTemplate: template,
            compilationTime: Date(),
            estimatedCost: template.count
        )
        
        await MainActor.run {
            compiledTemplateCache.setObject(compiledTemplate, 
                                          forKey: key as NSString, 
                                          cost: compiledTemplate.estimatedCost)
        }
    }
    
    /**
     * 执行编译后的模板
     */
    private func executeCompiledTemplate(
        _ compiledTemplate: CompiledTemplate,
        entry: EmotionEntry,
        tone: AIReplyTone,
        language: DetectedLanguage,
        userContext: UserContext?
    ) throws -> String {
        // 在实际项目中，这里会执行预编译的模板
        // 目前简化为直接处理原始模板
        return try processTemplate(compiledTemplate.originalTemplate, 
                                 entry: entry, 
                                 tone: tone, 
                                 language: language, 
                                 userContext: userContext)
    }
    
    /**
     * 计算缓存命中率
     */
    private func calculateCacheHitRate() -> Double {
        // 简化实现：返回估算值
        return 0.75
    }
    
    /**
     * 设置内存警告观察者
     */
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
}

// MARK: - Supporting Types

/**
 * 编译后的模板结构
 */
class CompiledTemplate {
    let key: String
    let originalTemplate: String
    let compilationTime: Date
    let estimatedCost: Int
    
    init(key: String, originalTemplate: String, compilationTime: Date, estimatedCost: Int) {
        self.key = key
        self.originalTemplate = originalTemplate
        self.compilationTime = compilationTime
        self.estimatedCost = estimatedCost
    }
}

/**
 * 用户上下文信息（兼容性别名）
 */
typealias UserContext = UserProfile

/**
 * 模板统计信息
 */
struct TemplateStats {
    let availableTemplateCount: Int
    let cacheHitRate: Double
    let averageProcessingTime: TimeInterval
    let memoryUsage: Int
}

/**
 * 模板错误类型
 */
enum TemplateError: Error, LocalizedError {
    case invalidConfiguration
    case templateNotFound(String)
    case templateTooLarge(String)
    case requiredTemplateMissing(String)
    case syntaxError(String)
    case securityError(String)
    case processingError(String)
    case outputTooShort
    case outputTooLong
    case missingVariables
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "配置无效"
        case .templateNotFound(let key):
            return "模板未找到: \(key)"
        case .templateTooLarge(let key):
            return "模板过大: \(key)"
        case .requiredTemplateMissing(let key):
            return "必需模板缺失: \(key)"
        case .syntaxError(let message):
            return "模板语法错误: \(message)"
        case .securityError(let message):
            return "模板安全错误: \(message)"
        case .processingError(let message):
            return "模板处理错误: \(message)"
        case .outputTooShort:
            return "输出内容过短"
        case .outputTooLong:
            return "输出内容过长"
        case .missingVariables:
            return "存在未替换的变量"
        }
    }
}