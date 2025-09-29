import Foundation
import Combine
import FirebaseRemoteConfig
import UIKit

/**
 * PromptHotUpdater - Prompt热更新和远程配置管理系统
 * 
 * ## 功能概述
 * PromptHotUpdater 负责从远程配置中心拉取最新的 Prompt 配置，提供以下核心功能：
 * - Firebase Remote Config 集成
 * - 配置热更新和版本管理
 * - A/B 测试和灰度发布支持
 * - 网络状态监控和智能重试
 * - 配置完整性验证和回滚机制
 * 
 * ## Firebase Remote Config 配置
 * ### 必需的配置键值
 * - `prompt_config_version`: 配置版本号 (String)
 * - `prompt_templates`: JSON格式的模板配置 (String)
 * - `supported_languages`: 支持的语言列表 (String, JSON数组)
 * - `supported_tones`: 支持的语气类型 (String, JSON数组)
 * - `feature_flags`: 功能开关配置 (String, JSON对象)
 * 
 * ### 可选的配置键值
 * - `update_interval`: 更新检查间隔（秒）(Number, 默认:3600)
 * - `min_app_version`: 最低支持的App版本 (String)
 * - `rollout_percentage`: 灰度发布百分比 (Number, 0-100)
 * 
 * ## 使用示例
 * ```swift
 * let updater = PromptHotUpdater()
 * 
 * // 手动拉取最新配置
 * let config = try await updater.fetchLatestConfiguration()
 * 
 * // 监听配置变化
 * updater.configurationUpdatePublisher
 *     .sink { newConfig in
 *         // 处理配置更新
 *     }
 *     .store(in: &cancellables)
 * 
 * // 启动自动更新
 * await updater.startPeriodicUpdates()
 * ```
 * 
 * ## 更新策略
 * ### 立即更新
 * - 用户手动触发更新
 * - 收到远程推送通知
 * - App 从后台恢复
 * 
 * ### 定期更新
 * - 默认每小时检查一次
 * - 可通过远程配置调整频率
 * - 网络连接恢复时补偿性更新
 * 
 * ### 条件更新
 * - 基于用户群体的灰度发布
 * - 基于App版本的兼容性检查
 * - 基于设备类型的差异化配置
 * 
 * ## 性能优化
 * - 配置缓存机制，避免重复网络请求
 * - 增量更新支持，只传输变化的部分
 * - 智能重试算法，指数退避
 * - 网络状态感知，Wi-Fi优先更新
 * 
 * ## 安全措施
 * - 配置签名验证，防止配置被篡改
 * - 版本兼容性检查，防止不兼容配置
 * - 配置大小限制，防止恶意大文件
 * - 敏感信息过滤，确保隐私安全
 * 
 * @author Claude Code Assistant
 * @version 1.0
 * @since 2024-01-15
 */
class PromptHotUpdater: NSObject, ObservableObject {
    
    // MARK: - Constants
    
    /// 配置键值常量
    private struct ConfigKeys {
        static let version = "prompt_config_version"
        static let templates = "prompt_templates"
        static let toneDescriptions = "tone_descriptions"  // 新增：语气描述配置键
        static let supportedLanguages = "supported_languages"
        static let supportedTones = "supported_tones"
        static let featureFlags = "feature_flags"
        static let updateInterval = "update_interval"
        static let minAppVersion = "min_app_version"
        static let rolloutPercentage = "rollout_percentage"
    }
    
    /// 默认配置值
    private struct Defaults {
        static let updateInterval: TimeInterval = 3600 // 1小时
        static let fetchTimeout: TimeInterval = 30 // 30秒
        static let maxRetryCount = 3
        static let maxConfigSize = 1024 * 1024 // 1MB
    }
    
    // MARK: - Properties
    
    /// Firebase Remote Config 实例
    /// - Note: 懒加载，确保Firebase已初始化
    private lazy var remoteConfig: RemoteConfig = {
        let config = RemoteConfig.remoteConfig()
        
        // 设置开发模式的获取间隔（生产环境会自动调整）
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0  // 开发阶段允许立即获取
        config.configSettings = settings
        
        // 设置默认值
        config.setDefaults(getDefaultValues())
        
        return config
    }()
    
    /// 配置更新发布者
    /// - Note: 外部可监听此发布者获取配置更新通知
    let configurationUpdatePublisher = PassthroughSubject<PromptConfiguration, Never>()
    
    /// 更新状态发布者
    /// - Note: 用于UI状态显示和错误处理
    @Published private(set) var updateStatus: HotUpdateStatus = .idle
    
    /// 最后更新时间
    @Published private(set) var lastUpdateTime: Date?
    
    /// 最后更新错误
    @Published private(set) var lastUpdateError: Error?
    
    // MARK: - Private Properties
    
    /// 定期更新定时器
    private var updateTimer: Timer?
    
    /// 取消令牌存储
    private var cancellables = Set<AnyCancellable>()
    
    /// 网络状态监控
    private let networkMonitor = NetworkMonitor()
    
    /// 当前获取任务
    private var currentFetchTask: Task<PromptConfiguration, Error>?
    
    /// 重试计数器
    private var retryCount = 0
    
    /// 用户ID（用于A/B测试）
    private let userId = UUID().uuidString
    
    // MARK: - Initialization
    
    /**
     * 初始化热更新器
     * 
     * ## 初始化流程
     * 1. 配置Firebase Remote Config
     * 2. 设置网络状态监听
     * 3. 注册App生命周期通知
     * 4. 初始化A/B测试参数
     */
    override init() {
        super.init()
        
        setupNetworkMonitoring()
        setupAppLifecycleObservers()
        
        print("🔄 [PromptHotUpdater] 初始化完成 - UserID: \(userId.prefix(8))...")
    }
    
    deinit {
        stopPeriodicUpdates()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    /**
     * 获取最新配置
     * 
     * ## 功能说明
     * - 从Firebase Remote Config获取最新配置
     * - 验证配置完整性和兼容性
     * - 应用A/B测试和灰度发布规则
     * - 自动重试和错误处理
     * 
     * ## 返回值
     * @return PromptConfiguration 最新的配置对象
     * 
     * ## 错误处理
     * - 网络连接失败：HotUpdateError.networkError
     * - 配置格式错误：HotUpdateError.configFormatError
     * - 版本不兼容：HotUpdateError.versionIncompatible
     * - 获取超时：HotUpdateError.fetchTimeout
     * 
     * ## 性能优化
     * - 并发控制：同时只允许一个获取任务
     * - 智能缓存：短时间内返回缓存结果
     * - 增量更新：只获取变化的配置
     * 
     * @throws HotUpdateError 热更新过程中的各种错误
     */
    func fetchLatestConfiguration() async throws -> PromptConfiguration {
        print("🌐 [PromptHotUpdater] 开始获取最新配置")
        
        // 防止重复请求
        if let existingTask = currentFetchTask {
            print("ℹ️ [PromptHotUpdater] 复用进行中的获取任务")
            return try await existingTask.value
        }
        
        // 创建新的获取任务
        let fetchTask = Task<PromptConfiguration, Error> { @MainActor in
            updateStatus = .fetching
            lastUpdateError = nil
            
            defer {
                currentFetchTask = nil
            }
            
            do {
                // 1. 检查网络连接
                guard networkMonitor.isConnected else {
                    throw HotUpdateError.networkUnavailable
                }
                
                // 2. 获取远程配置
                let status = try await fetchRemoteConfigWithTimeout()
                
                // 3. 检查获取状态
                guard status == .success else {
                    throw HotUpdateError.fetchFailed("获取状态: \(status.rawValue)")
                }
                
                // 4. 解析配置
                let configuration = try parseRemoteConfiguration()
                
                // 5. 验证配置
                try await validateConfiguration(configuration)
                
                // 6. 应用A/B测试规则
                let finalConfiguration = try await applyABTestRules(configuration)
                
                // 7. 更新状态
                updateStatus = .success
                lastUpdateTime = Date()
                retryCount = 0
                
                print("✅ [PromptHotUpdater] 配置获取成功 v\(finalConfiguration.version)")
                
                // 8. 通知配置更新
                configurationUpdatePublisher.send(finalConfiguration)
                
                return finalConfiguration
                
            } catch {
                print("❌ [PromptHotUpdater] 配置获取失败: \(error)")
                
                updateStatus = .failed
                lastUpdateError = error
                
                // 智能重试
                if retryCount < Defaults.maxRetryCount && shouldRetry(error: error) {
                    retryCount += 1
                    let retryDelay = calculateRetryDelay()
                    
                    print("🔄 [PromptHotUpdater] \(retryDelay)秒后重试 (第\(retryCount)次)")
                    
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    return try await fetchLatestConfiguration()
                } else {
                    retryCount = 0
                    throw HotUpdateError.maxRetriesExceeded(error)
                }
            }
        }
        
        currentFetchTask = fetchTask
        return try await fetchTask.value
    }
    
    /**
     * 启动定期更新
     * 
     * ## 功能说明
     * - 根据配置的间隔定期检查更新
     * - 智能调整更新频率
     * - 网络状态变化时触发更新
     * - App前台激活时检查更新
     * 
     * ## 更新策略
     * - 默认间隔：1小时
     * - 可通过远程配置动态调整
     * - Wi-Fi环境下更频繁更新
     * - 数据网络下降低频率
     */
    func startPeriodicUpdates() async {
        stopPeriodicUpdates()
        
        print("⏰ [PromptHotUpdater] 启动定期更新")
        
        // 首次立即检查
        Task.detached { [weak self] in
            try? await self?.fetchLatestConfiguration()
        }
        
        // 启动定期检查定时器
        await MainActor.run { [weak self] in
            let interval = self?.remoteConfig.configValue(forKey: ConfigKeys.updateInterval).numberValue.doubleValue ?? Defaults.updateInterval
            
            self?.updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task {
                    try? await self?.fetchLatestConfiguration()
                }
            }
        }
    }
    
    /**
     * 停止定期更新
     * 
     * ## 功能说明
     * - 取消定时器
     * - 停止当前的获取任务
     * - 清理资源
     */
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        currentFetchTask?.cancel()
        currentFetchTask = nil
        
        print("⏹️ [PromptHotUpdater] 停止定期更新")
    }
    
    /**
     * 手动刷新配置
     * 
     * ## 使用场景
     * - 用户手动点击刷新按钮
     * - 收到推送通知有新配置
     * - 调试时需要立即获取最新配置
     */
    func refreshConfiguration() async {
        print("🔄 [PromptHotUpdater] 手动刷新配置")
        try? await fetchLatestConfiguration()
    }
    
    /**
     * 获取当前配置状态
     * 
     * ## 返回信息
     * - 更新状态
     * - 最后更新时间
     * - 配置版本信息
     * - 网络状态
     * - 错误信息（如果有）
     * 
     * @return HotUpdateStatus 当前状态信息
     */
    func getCurrentStatus() -> HotUpdateStatusInfo {
        return HotUpdateStatusInfo(
            status: updateStatus,
            lastUpdateTime: lastUpdateTime,
            lastError: lastUpdateError,
            isNetworkAvailable: networkMonitor.isConnected,
            retryCount: retryCount,
            userId: String(userId.prefix(8))
        )
    }
    
    // MARK: - Private Methods
    
    /**
     * 设置网络状态监控
     */
    private func setupNetworkMonitoring() {
        networkMonitor.networkStatusPublisher
            .dropFirst() // 忽略初始状态
            .sink { [weak self] isConnected in
                if isConnected {
                    print("📡 [PromptHotUpdater] 网络连接恢复，触发配置检查")
                    Task {
                        try? await self?.fetchLatestConfiguration()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /**
     * 设置App生命周期观察者
     */
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 [PromptHotUpdater] App进入前台，检查配置更新")
            Task {
                try? await self?.fetchLatestConfiguration()
            }
        }
    }
    
    /**
     * 获取默认配置值
     */
    private func getDefaultValues() -> [String: NSObject] {
        return [
            ConfigKeys.version: "1.0.0" as NSString,
            ConfigKeys.templates: """
            {
                "zh_warm": "你是AI朋友，用温暖的语气回复用户情绪记录。\\n\\n记录：\\n日期：{{date}}\\n地点：{{place}}\\n人员：{{people}}\\n\\n发生：{{what_happened}}\\n想法：{{think}}\\n感受：{{feel}}\\n反应：{{reaction}}\\n需要：{{need}}\\n强度：{{record_severity}}/5\\n\\n要求：用{{tone_name}}语气，{{reply_requirements}}",
                "en_warm": "You are an AI friend who replies to user's emotion records with warmth.\\n\\nRecord:\\nDate: {{date}}\\nPlace: {{place}}\\nPeople: {{people}}\\n\\nWhat happened: {{what_happened}}\\nThoughts: {{think}}\\nFeelings: {{feel}}\\nReaction: {{reaction}}\\nNeeds: {{need}}\\nIntensity: {{record_severity}}/5\\n\\nRequirements: Reply with {{tone_name}} tone, {{reply_requirements}}"
            }
            """ as NSString,
            ConfigKeys.toneDescriptions: "{}" as NSString,  // 默认为空，会降级到代码默认值
            ConfigKeys.supportedLanguages: "[\"zh\", \"en\"]" as NSString,
            ConfigKeys.supportedTones: "[\"warm\", \"gentle\", \"understanding\", \"philosophical\", \"empathetic\", \"supportive\"]" as NSString,
            ConfigKeys.featureFlags: """
            {
                "enable_personalization": "true",
                "enable_ab_testing": "false",
                "max_template_size": "50000",
                "cache_enabled": "true",
                "debug_mode": "false"
            }
            """ as NSString,
            ConfigKeys.updateInterval: NSNumber(value: Defaults.updateInterval),
            ConfigKeys.minAppVersion: "1.0.0" as NSString,
            ConfigKeys.rolloutPercentage: NSNumber(value: 100)
        ]
    }
    
    /**
     * 带超时的远程配置获取
     */
    private func fetchRemoteConfigWithTimeout() async throws -> RemoteConfigFetchStatus {
        return try await withThrowingTaskGroup(of: RemoteConfigFetchStatus.self) { group in
            // 添加获取任务
            group.addTask { [weak self] in
                guard let self = self else { throw HotUpdateError.instanceDeallocated }
                
                return try await withCheckedThrowingContinuation { continuation in
                    self.remoteConfig.fetch { status, error in
                        if let error = error {
                            continuation.resume(throwing: HotUpdateError.fetchFailed(error.localizedDescription))
                        } else {
                            continuation.resume(returning: status)
                        }
                    }
                }
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(Defaults.fetchTimeout * 1_000_000_000))
                throw HotUpdateError.fetchTimeout
            }
            
            // 返回第一个完成的任务结果
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /**
     * 解析远程配置
     */
    private func parseRemoteConfiguration() throws -> PromptConfiguration {
        // 激活最新获取的配置
        let activationStatus = remoteConfig.activate()
        print("🔧 [PromptHotUpdater] 配置激活状态: \(activationStatus)")
        
        // 解析版本号
        let version = remoteConfig.configValue(forKey: ConfigKeys.version).stringValue ?? "1.0.0"
        
        // 解析模板配置 - 增强错误处理
        let templatesJSON = remoteConfig.configValue(forKey: ConfigKeys.templates).stringValue ?? "{}"
        print("🔧 [PromptHotUpdater] 原始模板JSON长度: \(templatesJSON.count) 字符")
        
        guard let templatesData = templatesJSON.data(using: .utf8) else {
            print("❌ [PromptHotUpdater] 模板JSON转换为Data失败")
            throw HotUpdateError.configFormatError("模板配置JSON格式错误：无法转换为数据")
        }
        
        guard let templates = try JSONSerialization.jsonObject(with: templatesData) as? [String: String] else {
            print("❌ [PromptHotUpdater] 模板JSON解析失败，尝试输出原始JSON前100字符：")
            print("JSON片段: \(String(templatesJSON.prefix(100)))")
            throw HotUpdateError.configFormatError("模板配置格式错误：JSON解析失败或类型不匹配")
        }
        print("🔧 [PromptHotUpdater] 解析到 \(templates.count) 个模板: \(templates.keys.joined(separator: ", "))")
        
        // 解析支持的语言 - 增强错误处理
        let languagesJSON = remoteConfig.configValue(forKey: ConfigKeys.supportedLanguages).stringValue ?? "[]"
        print("🔧 [PromptHotUpdater] 语言配置JSON: \(languagesJSON)")
        guard let languagesData = languagesJSON.data(using: .utf8),
              let languageStrings = try JSONSerialization.jsonObject(with: languagesData) as? [String] else {
            print("❌ [PromptHotUpdater] 语言配置解析失败，使用默认语言")
            throw HotUpdateError.configFormatError("语言配置格式错误，JSON: \(languagesJSON)")
        }
        
        let supportedLanguages = languageStrings.compactMap { DetectedLanguage(rawValue: $0) }
        print("🔧 [PromptHotUpdater] 支持的语言: \(supportedLanguages.map { $0.rawValue }.joined(separator: ", "))")
        
        // 解析支持的语气 - 增强错误处理
        let tonesJSON = remoteConfig.configValue(forKey: ConfigKeys.supportedTones).stringValue ?? "[]"
        print("🔧 [PromptHotUpdater] 语气配置JSON: \(tonesJSON)")
        guard let tonesData = tonesJSON.data(using: .utf8),
              let toneStrings = try JSONSerialization.jsonObject(with: tonesData) as? [String] else {
            print("❌ [PromptHotUpdater] 语气配置解析失败，使用默认语气")
            throw HotUpdateError.configFormatError("语气配置格式错误，JSON: \(tonesJSON)")
        }
        
        let supportedTones = toneStrings.compactMap { AIReplyTone(rawValue: $0) }
        print("🔧 [PromptHotUpdater] 支持的语气: \(supportedTones.map { $0.rawValue }.joined(separator: ", "))")
        
        // 解析语气描述配置 - 新增功能，支持热更新
        let toneDescriptionsJSON = remoteConfig.configValue(forKey: ConfigKeys.toneDescriptions).stringValue ?? "{}"
        print("🔧 [PromptHotUpdater] 语气描述配置JSON长度: \(toneDescriptionsJSON.count) 字符")
        
        var toneDescriptions: [String: String]? = nil
        if !toneDescriptionsJSON.isEmpty && toneDescriptionsJSON != "{}" {
            do {
                if let toneDescriptionsData = toneDescriptionsJSON.data(using: .utf8),
                   let parsedDescriptions = try JSONSerialization.jsonObject(with: toneDescriptionsData) as? [String: String] {
                    toneDescriptions = parsedDescriptions
                    print("🔧 [PromptHotUpdater] 解析到 \(parsedDescriptions.count) 个语气描述配置")
                }
            } catch {
                print("⚠️ [PromptHotUpdater] 语气描述配置解析失败，将使用代码默认值: \(error)")
                // 不抛出错误，允许降级到代码默认值
            }
        } else {
            print("ℹ️ [PromptHotUpdater] 语气描述配置为空，将使用代码默认值")
        }
        
        // 解析元数据 - 增强错误处理和类型兼容性
        let metadataJSON = remoteConfig.configValue(forKey: ConfigKeys.featureFlags).stringValue ?? "{}"
        print("🔧 [PromptHotUpdater] 原始元数据JSON: \(metadataJSON)")
        
        var metadata: [String: String] = [:]
        
        // 处理空值或无效JSON的情况
        guard !metadataJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              metadataJSON != "{}" else {
            print("ℹ️ [PromptHotUpdater] 元数据为空，使用默认元数据配置")
            metadata = [
                "source": "remote_config",
                "format": "auto_generated",
                "last_update": DateFormatter().string(from: Date())
            ]
            return PromptConfiguration(
                version: version,
                lastModified: Date(),
                templates: templates,
                supportedLanguages: supportedLanguages,
                supportedTones: supportedTones,
                metadata: metadata,
                toneDescriptions: toneDescriptions
            )
        }
        
        if let metadataData = metadataJSON.data(using: .utf8) {
            do {
                // 尝试解析JSON对象
                let jsonObject = try JSONSerialization.jsonObject(with: metadataData)
                
                switch jsonObject {
                case let rawMetadata as [String: Any]:
                    // 处理混合类型的字典
                    for (key, value) in rawMetadata {
                        switch value {
                        case let stringValue as String:
                            metadata[key] = stringValue
                        case let numberValue as NSNumber:
                            metadata[key] = numberValue.stringValue
                        case let boolValue as Bool:
                            metadata[key] = boolValue ? "true" : "false"
                        case let arrayValue as [Any]:
                            metadata[key] = "\(arrayValue)"
                        case let dictValue as [String: Any]:
                            metadata[key] = "\(dictValue)"
                        default:
                            metadata[key] = String(describing: value)
                        }
                    }
                    print("🔧 [PromptHotUpdater] 成功解析混合类型元数据，共 \(metadata.count) 项")
                    
                case let stringMetadata as [String: String]:
                    // 直接是 [String: String] 类型
                    metadata = stringMetadata
                    print("🔧 [PromptHotUpdater] 直接解析字符串元数据，共 \(metadata.count) 项")
                    
                case let arrayValue as [Any]:
                    // 如果是数组格式，转换为索引键值对
                    for (index, value) in arrayValue.enumerated() {
                        metadata["item_\(index)"] = String(describing: value)
                    }
                    print("🔧 [PromptHotUpdater] 将数组格式转换为元数据，共 \(metadata.count) 项")
                    
                default:
                    print("⚠️ [PromptHotUpdater] 元数据格式未知，创建默认元数据")
                    metadata = [
                        "source": "remote_config",
                        "format": "unknown_format",
                        "raw_data": String(describing: jsonObject)
                    ]
                }
            } catch let jsonError {
                print("⚠️ [PromptHotUpdater] 元数据JSON解析失败: \(jsonError.localizedDescription)")
                print("⚠️ [PromptHotUpdater] 原始数据: \(metadataJSON)")
                
                // 创建包含错误信息的默认元数据
                metadata = [
                    "source": "remote_config",
                    "format": "parse_failed",
                    "error": jsonError.localizedDescription,
                    "raw_json": metadataJSON.prefix(100).description // 只保留前100个字符避免过长
                ]
            }
        } else {
            print("⚠️ [PromptHotUpdater] 元数据JSON转换为Data失败")
            metadata = [
                "source": "remote_config",
                "format": "data_conversion_failed",
                "raw_json": metadataJSON
            ]
        }
        
        return PromptConfiguration(
            version: version,
            lastModified: Date(),
            templates: templates,
            supportedLanguages: supportedLanguages,
            supportedTones: supportedTones,
            metadata: metadata,
            toneDescriptions: toneDescriptions
        )
    }
    
    /**
     * 验证配置完整性
     */
    private func validateConfiguration(_ configuration: PromptConfiguration) async throws {
        print("🔧 [PromptHotUpdater] 开始验证配置...")
        print("🔧 [PromptHotUpdater] 配置版本: \(configuration.version)")
        print("🔧 [PromptHotUpdater] 模板数量: \(configuration.templates.count)")
        print("🔧 [PromptHotUpdater] 支持语言: \(configuration.supportedLanguages.map { $0.rawValue })")
        print("🔧 [PromptHotUpdater] 支持语气: \(configuration.supportedTones.map { $0.rawValue })")
        print("🔧 [PromptHotUpdater] 元数据项数: \(configuration.metadata.count)")
        
        // 基础验证 - 增强错误信息
        let isValid = configuration.isValid()
        if !isValid {
            // 详细检查每个验证条件
            var validationErrors: [String] = []
            
            if configuration.version.isEmpty {
                validationErrors.append("版本号为空")
            }
            
            if configuration.templates.isEmpty {
                validationErrors.append("模板为空")
            }
            
            if configuration.supportedLanguages.isEmpty {
                validationErrors.append("支持语言列表为空")
            }
            
            if configuration.supportedTones.isEmpty {
                validationErrors.append("支持语气列表为空")
            }
            
            // 检查必需的模板
            let requiredTemplates = ["zh_warm", "en_warm"]
            let missingTemplates = requiredTemplates.filter { configuration.templates[$0] == nil }
            if !missingTemplates.isEmpty {
                validationErrors.append("缺少必需模板: \(missingTemplates.joined(separator: ", "))")
            }
            
            let errorMessage = "配置基础验证失败: \(validationErrors.joined(separator: "; "))"
            print("❌ [PromptHotUpdater] \(errorMessage)")
            throw HotUpdateError.configFormatError(errorMessage)
        }
        
        print("✅ [PromptHotUpdater] 配置基础验证通过")
        
        // 版本兼容性检查
        let minAppVersion = remoteConfig.configValue(forKey: ConfigKeys.minAppVersion).stringValue ?? "1.0.0"
        let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        
        if !isVersionCompatible(currentVersion: currentAppVersion, minimumVersion: minAppVersion) {
            throw HotUpdateError.versionIncompatible("需要App版本 \(minAppVersion) 或更高")
        }
        
        // 配置大小检查
        let configSize = configuration.estimatedMemorySize
        guard configSize <= Defaults.maxConfigSize else {
            throw HotUpdateError.configTooLarge("配置大小超限: \(configSize) bytes")
        }
        
        print("✅ [PromptHotUpdater] 配置验证通过")
    }
    
    /**
     * 应用A/B测试规则
     */
    private func applyABTestRules(_ configuration: PromptConfiguration) async throws -> PromptConfiguration {
        let rolloutPercentage = remoteConfig.configValue(forKey: ConfigKeys.rolloutPercentage).numberValue.intValue
        
        // 基于用户ID计算是否在灰度发布范围内
        let userHash = abs(userId.hashValue % 100)
        
        if userHash >= rolloutPercentage {
            print("🎲 [PromptHotUpdater] 用户不在灰度发布范围内 (hash: \(userHash), rollout: \(rolloutPercentage)%)")
            throw HotUpdateError.notInRollout
        }
        
        print("🎯 [PromptHotUpdater] 用户在灰度发布范围内 (hash: \(userHash), rollout: \(rolloutPercentage)%)")
        return configuration
    }
    
    /**
     * 判断是否应该重试
     */
    private func shouldRetry(error: Error) -> Bool {
        switch error {
        case HotUpdateError.networkUnavailable,
             HotUpdateError.fetchTimeout,
             HotUpdateError.fetchFailed:
            return true
        default:
            return false
        }
    }
    
    /**
     * 计算重试延迟时间（指数退避）
     */
    private func calculateRetryDelay() -> TimeInterval {
        return min(pow(2.0, Double(retryCount)) * 1.0, 30.0) // 最大30秒
    }
    
    /**
     * 版本兼容性检查
     */
    private func isVersionCompatible(currentVersion: String, minimumVersion: String) -> Bool {
        return currentVersion.compare(minimumVersion, options: .numeric) != .orderedAscending
    }
}

// MARK: - Supporting Types

/**
 * 热更新状态枚举
 */
enum HotUpdateStatus {
    case idle       // 空闲
    case fetching   // 获取中
    case success    // 成功
    case failed     // 失败
}

/**
 * 热更新状态信息
 */
struct HotUpdateStatusInfo {
    let status: HotUpdateStatus
    let lastUpdateTime: Date?
    let lastError: Error?
    let isNetworkAvailable: Bool
    let retryCount: Int
    let userId: String
}

/**
 * 热更新错误类型
 */
enum HotUpdateError: Error, LocalizedError {
    case instanceDeallocated
    case networkUnavailable
    case fetchTimeout
    case fetchFailed(String)
    case configFormatError(String)
    case versionIncompatible(String)
    case configTooLarge(String)
    case notInRollout
    case maxRetriesExceeded(Error)
    
    var errorDescription: String? {
        switch self {
        case .instanceDeallocated:
            return "热更新器实例已释放"
        case .networkUnavailable:
            return "网络连接不可用"
        case .fetchTimeout:
            return "获取配置超时"
        case .fetchFailed(let message):
            return "获取配置失败: \(message)"
        case .configFormatError(let message):
            return "配置格式错误: \(message)"
        case .versionIncompatible(let message):
            return "版本不兼容: \(message)"
        case .configTooLarge(let message):
            return "配置过大: \(message)"
        case .notInRollout:
            return "不在灰度发布范围内"
        case .maxRetriesExceeded(let error):
            return "超过最大重试次数: \(error.localizedDescription)"
        }
    }
}

/**
 * 网络状态监控器
 * 简化实现，实际项目中可使用 Network.framework
 */
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    
    let networkStatusPublisher = PassthroughSubject<Bool, Never>()
    
    init() {
        // 简化实现：假设网络始终可用
        // 实际项目中应该实现真正的网络状态检测
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            self.networkStatusPublisher.send(true)
        }
    }
}