import Foundation

class RecordEmotionViewModel: ObservableObject {
    @Published var whatHappened: String = ""
    @Published var think: String = ""
    @Published var feel: String = ""
    @Published var severity: Int = 0
    @Published var reaction: String = ""
    @Published var need: String = ""
    
    // 沉浸式问答状态管理
    @Published var isImmersiveViewPresented: Bool = false
    @Published var currentEditingField: FormFieldType? = nil
    
    var allFields: [String] {
        [whatHappened, think, feel, reaction, need]
    }
    
    var isComplete: Bool {
        allFields.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    // 检查是否有任何内容（用于自动保存判断）
    var hasAnyContent: Bool {
        !whatHappened.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !think.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !feel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !reaction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !need.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        severity != 0 // 情绪强度不是默认值时也算有内容
    }
    
    // 获取所有第一页的字段类型（按顺序）
    var recordFields: [FormFieldType] {
        [.whatHappened, .think, .feel, .reaction, .need]
    }
    
    // 根据字段类型获取对应的文本绑定
    func getTextBinding(for fieldType: FormFieldType) -> String {
        switch fieldType {
        case .whatHappened: return whatHappened
        case .think: return think
        case .feel: return feel
        case .reaction: return reaction
        case .need: return need
        default: return ""
        }
    }
    
    // 根据字段类型设置对应的文本
    func setText(_ text: String, for fieldType: FormFieldType) {
        switch fieldType {
        case .whatHappened: whatHappened = text
        case .think: think = text
        case .feel: feel = text
        case .reaction: reaction = text
        case .need: need = text
        default: break
        }
    }
    
    // 打开沉浸式视图
    func openImmersiveView(for fieldType: FormFieldType) {
        currentEditingField = fieldType
        isImmersiveViewPresented = true
    }
    
    // 跳转到下一个问题
    func moveToNextQuestion() {
        guard let currentField = currentEditingField,
              let currentIndex = recordFields.firstIndex(of: currentField) else { return }
        
        let nextIndex = currentIndex + 1
        if nextIndex < recordFields.count {
            currentEditingField = recordFields[nextIndex]
        } else {
            // 最后一个问题，关闭沉浸式视图
            isImmersiveViewPresented = false
            currentEditingField = nil
        }
    }
    
    // 跳转到上一个问题
    func moveToPreviousQuestion() {
        guard let currentField = currentEditingField,
              let currentIndex = recordFields.firstIndex(of: currentField) else { return }
        
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            currentEditingField = recordFields[previousIndex]
        }
    }
    
    func reset() {
        whatHappened = ""
        think = ""
        feel = ""
        severity = 0 // 重置为0，与初始状态保持一致
        reaction = ""
        need = ""
        isImmersiveViewPresented = false
        currentEditingField = nil
    }
    
    // 临时状态属性，用于保存页面间切换时的数据
    private var temporaryEntry: EmotionEntry?
    
    // 临时保存方法：只保存到内存状态，不创建历史记录，用于页面切换时保持数据
    func saveToContextTemporary(contextVM: EmotionContextViewModel, historyVM: HistoryViewModel) {
        // 将当前表单数据保存到临时状态，供ProcessEmotionPage访问
        temporaryEntry = EmotionEntry(
            date: contextVM.date,
            place: contextVM.place,
            people: contextVM.people,
            whatHappened: whatHappened.isEmpty ? nil : whatHappened,
            think: think.isEmpty ? nil : think,
            feel: feel.isEmpty ? nil : feel,
            reaction: reaction.isEmpty ? nil : reaction,
            need: need.isEmpty ? nil : need,
            recordSeverity: severity
        )
        
        print("✓ 第一页数据已临时保存到内存，未创建历史记录")
    }
    
    // 获取临时保存的数据
    func getTemporarySavedEntry() -> EmotionEntry? {
        return temporaryEntry
    }
    
    // 最终保存方法：保存到上下文并重置表单，用于最终提交
    func saveToContext(contextVM: EmotionContextViewModel, historyVM: HistoryViewModel) {
        // 移除完整性检查，允许部分保存
        
        // 创建EmotionEntry对象（使用可选字段来处理空值）
        let newEntry = EmotionEntry(
            date: contextVM.date,
            place: contextVM.place,
            people: contextVM.people,
            whatHappened: whatHappened.isEmpty ? nil : whatHappened,
            think: think.isEmpty ? nil : think,
            feel: feel.isEmpty ? nil : feel,
            reaction: reaction.isEmpty ? nil : reaction,
            need: need.isEmpty ? nil : need,
            recordSeverity: severity
        )
        
        // 添加到历史记录
        let _ = historyVM.addHistoryItem(emotionEntry: newEntry)
        
        // 保存后重置表单和上下文
        reset()
        contextVM.reset()
        
        print("情绪记录已保存并重置表单，准备进入下一步")
    }
    
    // 原有的保存方法保留，用于完整保存并重置
    func save(contextVM: EmotionContextViewModel, historyVM: HistoryViewModel) {
        guard isComplete else { return }
        
        // 创建EmotionEntry对象
        let newEntry = EmotionEntry(
            date: contextVM.date,
            place: contextVM.place,
            people: contextVM.people,
            whatHappened: whatHappened.isEmpty ? nil : whatHappened,
            think: think.isEmpty ? nil : think,
            feel: feel.isEmpty ? nil : feel,
            reaction: reaction.isEmpty ? nil : reaction,
            need: need.isEmpty ? nil : need,
            recordSeverity: severity
        )
        
        // 添加到历史记录
        let _ = historyVM.addHistoryItem(emotionEntry: newEntry)
        
        // 重置表单
        reset()
        contextVM.reset()
        
        print("保存情绪记录成功")
    }
}