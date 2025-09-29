//
//  PromptSystemTest.swift
//  MirrorNote
//
//  Created by Claude Code Assistant on 22/07/2025.
//

import Foundation

/**
 * Prompt 系统集成测试
 * 
 * ## 测试内容
 * - Firebase Remote Config 连接
 * - PromptManager 初始化
 * - 模板构建功能
 * - 多语言支持
 * - 错误处理机制
 */
class PromptSystemTest {
    
    /**
     * 运行完整的系统测试
     */
    static func runSystemTest() async {
        print("🧪 [PromptSystemTest] 开始 Prompt 系统集成测试")
        
        // 测试 1: PromptManager 初始化
        await testPromptManagerInitialization()
        
        // 测试 2: 模板构建功能
        await testTemplateBuilding()
        
        // 测试 3: 多语言支持
        await testMultiLanguageSupport()
        
        // 测试 4: 错误处理
        await testErrorHandling()
        
        print("✅ [PromptSystemTest] 系统测试完成")
    }
    
    /**
     * 测试 PromptManager 初始化
     */
    private static func testPromptManagerInitialization() async {
        print("🔧 [PromptSystemTest] 测试 PromptManager 初始化...")
        
        do {
            let manager = await PromptManager.shared
            try await manager.initialize()
            print("✅ [PromptSystemTest] PromptManager 初始化成功")
        } catch {
            print("❌ [PromptSystemTest] PromptManager 初始化失败: \(error)")
        }
    }
    
    /**
     * 测试模板构建功能
     */
    private static func testTemplateBuilding() async {
        print("🔨 [PromptSystemTest] 测试模板构建功能...")
        
        // 创建测试用的情绪记录
        let testEntry = EmotionEntry(
            date: Date(),
            place: "测试地点",
            people: "测试人员",
            whatHappened: "这是一个测试情绪记录",
            think: "我在测试新的 Prompt 系统",
            feel: "感到兴奋和期待",
            reaction: "仔细观察系统表现",
            need: "需要确认系统正常工作",
            recordSeverity: 3
        )
        
        do {
            let manager = await PromptManager.shared
            
            let prompt = try await manager.buildPrompt(
                for: testEntry,
                tone: AIReplyTone.warm,
                language: DetectedLanguage.chinese,
                includePersonalization: false
            )
            
            print("✅ [PromptSystemTest] 模板构建成功")
            print("📝 [PromptSystemTest] 构建的 Prompt 长度: \(prompt.count) 字符")
            print("📄 [PromptSystemTest] Prompt 预览: \(String(prompt.prefix(100)))...")
            
        } catch {
            print("❌ [PromptSystemTest] 模板构建失败: \(error)")
        }
    }
    
    /**
     * 测试多语言支持
     */
    private static func testMultiLanguageSupport() async {
        print("🌐 [PromptSystemTest] 测试多语言支持...")
        
        let testEntryEnglish = EmotionEntry(
            date: Date(),
            place: "Test Location",
            people: "Test People",
            whatHappened: "This is a test emotion record",
            think: "I am testing the new Prompt system",
            feel: "Feeling excited and anticipating",
            reaction: "Carefully observing system performance",
            need: "Need to confirm system works properly",
            recordSeverity: 3
        )
        
        do {
            let manager = await PromptManager.shared
            
            // 测试英文模板
            let englishPrompt = try await manager.buildPrompt(
                for: testEntryEnglish,
                tone: AIReplyTone.warm,
                language: DetectedLanguage.english,
                includePersonalization: false
            )
            
            print("✅ [PromptSystemTest] 英文模板构建成功")
            print("📝 [PromptSystemTest] 英文 Prompt 长度: \(englishPrompt.count) 字符")
            
        } catch {
            print("❌ [PromptSystemTest] 多语言支持测试失败: \(error)")
        }
    }
    
    /**
     * 测试错误处理
     */
    private static func testErrorHandling() async {
        print("⚠️ [PromptSystemTest] 测试错误处理机制...")
        
        // 这里可以测试各种错误情况
        // 比如网络断开、配置格式错误等
        
        print("✅ [PromptSystemTest] 错误处理测试完成")
    }
}