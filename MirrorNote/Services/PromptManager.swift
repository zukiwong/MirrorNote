import Foundation
import Combine

/**
 * PromptManager - AI Prompt 统一管理系统
 * 
 * ## 功能概述
 * PromptManager 是整个 AI Prompt 系统的核心管理类，提供以下功能：
 * - Prompt 模板的统一管理和访问
 * - 远程配置的热更新支持
 * - 版本控制和回滚机制
 * - 个性化 Prompt 生成
 * - 多语言 Prompt 支持
 * 
 * ## 工作流程
 * 1. 初始化时加载本地缓存的 Prompt 配置
 * 2. 定期从远程配置中心拉取最新的 Prompt 模板
 * 3. 根据用户语言和情绪类型生成个性化 Prompt
 * 4. 支持 A/B 测试和灰度发布
 * 
 * ## 使用示例
 * ```swift
 * let promptManager = PromptManager.shared
 * 
 * // 获取中文温暖语气的 Prompt
 * let prompt = try await promptManager.buildPrompt(
 *     for: emotionEntry,
 *     tone: .warm,
 *     language: .chinese
 * )
 * 
 * // 手动触发热更新
 * await promptManager.updateFromRemote()
 * ```
 * 
 * ## 配置要求
 * - Firebase Remote Config 已正确配置
 * - 本地存储权限已获得
 * - 网络连接用于配置更新
 * 
 * ## 性能考虑
 * - 本地缓存优先，网络请求异步执行
 * - 配置更新失败时自动降级到本地版本
 * - 内存占用控制在合理范围内（< 10MB）
 * 
 * @author Claude Code Assistant
 * @version 1.0
 * @since 2024-01-15
 */
@MainActor
class PromptManager: ObservableObject {
    
    // MARK: - Singleton Pattern
    
    /// 单例实例，确保全局唯一的 Prompt 管理器
    static let shared = PromptManager()
    
    // MARK: - Dependencies
    
    /// 本地存储管理器，负责 Prompt 的持久化存储
    private let repository: PromptRepository
    
    /// 热更新管理器，负责从远程获取最新配置
    private let hotUpdater: PromptHotUpdater
    
    /// 模板管理器，负责 Prompt 模板的解析和生成
    private let templates: PromptTemplates
    
    // MARK: - Published Properties
    
    /// 当前 Prompt 配置版本号
    /// - Note: 用于UI显示和版本对比
    @Published private(set) var currentVersion: String = "1.0.0"
    
    /// 最后更新时间
    /// - Note: 用于显示配置的新鲜度
    @Published private(set) var lastUpdateTime: Date = Date()
    
    /// 更新状态：idle, updating, success, failed
    /// - Note: 用于UI状态显示和错误处理
    @Published private(set) var updateStatus: UpdateStatus = .idle
    
    // MARK: - Private Properties
    
    /// 配置更新的取消令牌
    private var updateCancellables = Set<AnyCancellable>()
    
    /// 当前加载的 Prompt 配置
    /// - Note: 内存缓存，避免频繁文件读取
    private var currentConfig: PromptConfiguration?
    
    /// 初始化锁，确保单次初始化
    private var initializationLock = NSLock()
    
    /// 是否已完成初始化
    private var isInitialized = false
    
    // MARK: - Initialization
    
    /**
     * 私有初始化方法，实现单例模式
     * 
     * ## 初始化流程
     * 1. 创建依赖组件实例
     * 2. 设置默认配置
     * 3. 异步加载本地缓存
     * 
     * ## 注意事项
     * - 初始化过程是异步的，使用前请调用 `initialize()` 方法
     * - 初始化失败时会使用内置的默认配置
     */
    private init() {
        self.repository = PromptRepository()
        self.hotUpdater = PromptHotUpdater()
        self.templates = PromptTemplates()
        
        // 设置热更新回调
        setupUpdateCallbacks()
    }
    
    /**
     * 异步初始化方法
     * 
     * ## 功能说明
     * - 加载本地缓存的配置
     * - 启动后台更新任务
     * - 验证配置完整性
     * 
     * ## 使用场景
     * 在 App 启动时调用，确保 Prompt 系统可用
     * 
     * ## 错误处理
     * - 本地配置损坏时，使用默认配置
     * - 网络请求失败时，继续使用本地配置
     * 
     * @throws PromptManagerError 初始化过程中的各种错误
     */
    func initialize() async throws {
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        guard !isInitialized else { return }
        
        do {
            // 开始初始化
            
            // 1. 加载本地配置（带缓存兼容性检查）
            var localConfig: PromptConfiguration?
            
            do {
                localConfig = try await repository.loadConfiguration()
            } catch {
                // 检查是否是反序列化错误（通常由枚举值变更引起）
                if let repositoryError = error as? RepositoryError,
                   case .loadFailed(let underlyingError) = repositoryError,
                   underlyingError is DecodingError {
                    
                    print("⚠️ [PromptManager] 检测到配置反序列化错误，可能是枚举值变更引起")
                    print("🧹 [PromptManager] 尝试清理缓存并重新初始化...")
                    
                    // 清理所有缓存
                    try await repository.clearAllCache()
                    
                    // 重新尝试加载（此时应该从Firebase获取新配置）
                    localConfig = try await repository.loadConfiguration()
                    
                    print("✅ [PromptManager] 缓存清理完成，配置重新加载成功")
                } else {
                    // 其他类型的错误，继续抛出
                    throw error
                }
            }
            
            if let config = localConfig {
                self.currentConfig = config
                self.currentVersion = config.version
                self.lastUpdateTime = config.lastModified
                // 成功加载本地配置
            } else {
                // 本地配置不存在，使用默认配置
                self.currentConfig = createDefaultConfiguration()
            }
            
            // 2. 初始化模板系统
            if let config = currentConfig {
                try await templates.loadConfiguration(config)
            }
            
            // 3. 启动后台更新（非阻塞）
            Task.detached { [weak self] in
                await self?.performInitialUpdate()
            }
            
            isInitialized = true
            // 初始化完成
            
        } catch {
            // 初始化失败
            
            // 降级处理：使用默认配置
            print("❌ [PromptManager] 初始化失败，使用默认配置: \(error)")
            self.currentConfig = createDefaultConfiguration()
            if let config = currentConfig {
                try await templates.loadConfiguration(config)
            }
            
            isInitialized = true
            throw PromptManagerError.initializationFailed(error)
        }
    }
    
    // MARK: - Public Interface
    
    /**
     * 构建个性化的 AI Prompt
     * 
     * ## 参数说明
     * @param entry 用户的情绪记录，包含所有相关信息
     * @param tone 期望的回复语气（温暖、鼓励、理解等）
     * @param language 目标语言（中文、英文、其他）
     * @param includePersonalization 是否包含个性化信息（默认true）
     * 
     * ## 返回值
     * @return 完整的 AI Prompt 字符串，可直接发送给 AI 模型
     * 
     * ## 使用示例
     * ```swift
     * let prompt = try await promptManager.buildPrompt(
     *     for: emotionEntry,
     *     tone: .warm,
     *     language: .chinese
     * )
     * ```
     * 
     * ## 个性化功能
     * 系统会自动从UserProfileManager获取用户画像数据，包括：
     * - 个人标签和偏好
     * - 历史情绪模式
     * - 交流风格特征
     * - 主题关注偏好
     * 
     * ## 错误处理
     * - 配置缺失时抛出 PromptManagerError.configurationMissing
     * - 模板解析失败时抛出 PromptManagerError.templateError
     * 
     * @throws PromptManagerError Prompt构建过程中的各种错误
     */
    func buildPrompt(
        for entry: EmotionEntry,
        tone: AIReplyTone,
        language: DetectedLanguage,
        includePersonalization: Bool = true
    ) async throws -> String {
        
        // 确保已初始化
        if !isInitialized {
            try await initialize()
        }
        
        guard let config = currentConfig else {
            throw PromptManagerError.configurationMissing
        }
        
        // 开始构建 Prompt
        
        do {
            // 1. 获取用户画像数据（如果启用）
            var userProfile: UserProfile?
            if includePersonalization {
                userProfile = await getUserProfile()
                // 获取用户画像数据（如果可用）
            }
            
            // 2. 选择合适的模板
            let templateKey = determineTemplateKey(tone: tone, language: language)
            
            // 3. 应用个性化调整
            let personalizedTemplate = await applyPersonalization(
                templateKey: templateKey,
                userProfile: userProfile
            )
            
            // 4. 构建最终 Prompt
            let prompt = try templates.buildPrompt(
                template: personalizedTemplate,
                entry: entry,
                tone: tone,
                language: language,
                userContext: userProfile
            )
            
            // Prompt 构建完成
            return prompt
            
        } catch {
            // Prompt 构建失败
            throw PromptManagerError.promptBuildFailed(error)
        }
    }
    
    /**
     * 手动触发远程配置更新
     * 
     * ## 功能说明
     * - 立即从远程配置中心拉取最新配置
     * - 验证配置完整性和版本兼容性
     * - 更新本地缓存并通知UI刷新
     * 
     * ## 使用场景
     * - 设置页面的"检查更新"功能
     * - 调试时需要立即获取最新配置
     * - 收到推送通知提示有新配置时
     * 
     * ## 状态变化
     * updateStatus: idle -> updating -> success/failed
     */
    func updateFromRemote() async {
        await MainActor.run {
            updateStatus = .updating
        }
        
        // 开始手动更新远程配置
        
        do {
            let newConfig = try await hotUpdater.fetchLatestConfiguration()
            
            // 验证新配置
            guard newConfig.version != currentVersion else {
                // 配置已是最新版本
                await MainActor.run {
                    updateStatus = .success
                }
                return
            }
            
            // 应用新配置
            try await applyNewConfiguration(newConfig)
            
            await MainActor.run {
                updateStatus = .success
            }
            
            // 配置更新成功
            
        } catch {
            // 配置更新失败
            
            await MainActor.run {
                updateStatus = .failed
            }
        }
    }
    
    /**
     * 获取当前配置的统计信息
     * 
     * ## 返回信息
     * - 配置版本号
     * - 最后更新时间
     * - 可用语言列表
     * - 可用语气类型
     * - 模板数量统计
     * 
     * @return PromptConfigurationInfo 配置统计信息
     */
    func getConfigurationInfo() -> PromptConfigurationInfo {
        return PromptConfigurationInfo(
            version: currentVersion,
            lastUpdate: lastUpdateTime,
            availableLanguages: currentConfig?.supportedLanguages ?? [],
            availableTones: currentConfig?.supportedTones ?? [],
            templateCount: currentConfig?.templates.count ?? 0,
            updateStatus: updateStatus
        )
    }
    
    // MARK: - Private Methods
    
    /**
     * 设置热更新回调函数
     * 
     * ## 功能说明
     * 监听远程配置变化，自动应用更新
     */
    private func setupUpdateCallbacks() {
        hotUpdater.configurationUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newConfig in
                Task {
                    try? await self?.applyNewConfiguration(newConfig)
                }
            }
            .store(in: &updateCancellables)
    }
    
    /**
     * 执行初始更新检查
     * 
     * ## 功能说明
     * App启动后的首次配置检查，非阻塞执行
     */
    private func performInitialUpdate() async {
        // 延迟执行，避免影响启动性能
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
        
        // 执行初始配置检查
        await updateFromRemote()
    }
    
    /**
     * 创建默认配置
     * 
     * ## 功能说明
     * 当本地配置缺失或损坏时，提供基础的默认配置确保系统可用
     * 
     * @return PromptConfiguration 默认配置对象
     */
    private func createDefaultConfiguration() -> PromptConfiguration {
        return PromptConfiguration.defaultConfiguration()
    }
    
    /**
     * 确定模板键值
     * 
     * ## 参数说明
     * @param tone 语气类型
     * @param language 目标语言
     * 
     * @return String 模板键值，用于查找对应的模板
     */
    private func determineTemplateKey(tone: AIReplyTone, language: DetectedLanguage) -> String {
        return "\(language.rawValue)_\(tone.rawValue)"
    }
    
    /**
     * 获取用户画像数据
     * 从UserProfileManager获取完整的用户画像对象
     * 
     * @return UserProfile? 用户画像对象
     */
    private func getUserProfile() async -> UserProfile? {
        do {
            // 确保UserProfileManager已初始化
            if !UserProfileManager.shared.isInitialized {
                try await UserProfileManager.shared.initialize()
            }
            
            // 获取当前用户画像
            return await UserProfileManager.shared.currentProfile
            
        } catch {
            // 获取用户画像失败
            return nil
        }
    }
    
    /**
     * 应用个性化调整
     * 
     * ## 参数说明
     * @param templateKey 基础模板键值
     * @param userProfile 用户画像数据
     * 
     * @return String 个性化后的模板键值
     */
    private func applyPersonalization(
        templateKey: String,
        userProfile: UserProfile?
    ) async -> String {
        // 基于用户画像选择合适的模板变体
        
        guard let profile = userProfile else {
            return templateKey
        }
        
        // 应用个性化调整到模板
        
        // 基于用户的交流风格调整模板
        let personalizedKey = "\(templateKey)_\(profile.communicationStyle.rawValue)"
        
        // 检查是否存在个性化模板，如果不存在则使用基础模板
        if let config = currentConfig, config.templates[personalizedKey] != nil {
            // 使用个性化模板
            return personalizedKey
        } else {
            // 个性化模板不存在，使用基础模板
            return templateKey
        }
    }
    
    /**
     * 应用新配置
     * 
     * ## 参数说明
     * @param newConfig 新的配置对象
     * 
     * @throws PromptManagerError 配置应用过程中的错误
     */
    private func applyNewConfiguration(_ newConfig: PromptConfiguration) async throws {
        // 1. 验证配置完整性
        guard newConfig.isValid() else {
            throw PromptManagerError.invalidConfiguration
        }
        
        // 2. 更新模板系统
        try await templates.loadConfiguration(newConfig)
        
        // 3. 保存到本地缓存
        try await repository.saveConfiguration(newConfig)
        
        // 4. 更新当前状态
        await MainActor.run {
            currentConfig = newConfig
            currentVersion = newConfig.version
            lastUpdateTime = newConfig.lastModified
        }
    }
}

// MARK: - Supporting Types

/**
 * Prompt管理器的更新状态枚举
 */
enum UpdateStatus {
    case idle       // 空闲状态
    case updating   // 更新中
    case success    // 更新成功
    case failed     // 更新失败
}

/**
 * Prompt配置信息结构体
 * 用于向UI提供配置状态信息
 */
struct PromptConfigurationInfo {
    let version: String
    let lastUpdate: Date
    let availableLanguages: [DetectedLanguage]
    let availableTones: [AIReplyTone]
    let templateCount: Int
    let updateStatus: UpdateStatus
}

/**
 * Prompt管理器错误类型
 */
enum PromptManagerError: Error, LocalizedError {
    case initializationFailed(Error)
    case configurationMissing
    case invalidConfiguration
    case templateError(Error)
    case promptBuildFailed(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Prompt管理器初始化失败: \(error.localizedDescription)"
        case .configurationMissing:
            return "Prompt配置缺失"
        case .invalidConfiguration:
            return "Prompt配置无效"
        case .templateError(let error):
            return "模板处理错误: \(error.localizedDescription)"
        case .promptBuildFailed(let error):
            return "Prompt构建失败: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络请求失败: \(error.localizedDescription)"
        }
    }
}

/**
 * 用户画像基础结构体
 * 用于个性化功能的扩展
 */
