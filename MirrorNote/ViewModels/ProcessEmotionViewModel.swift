import Foundation

class ProcessEmotionViewModel: ObservableObject {
    @Published var why: String = ""
    @Published var ifElse: String = ""
    @Published var severity: Int = 0
    @Published var nextTime: String = ""
    
    // 沉浸式问答状态管理
    @Published var isImmersiveViewPresented: Bool = false
    @Published var currentEditingField: FormFieldType? = nil
    
    var allFields: [String] {
        [why, ifElse, nextTime]
    }
    
    var isComplete: Bool {
        allFields.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    // 检查是否有任何内容（用于保存验证）
    var hasAnyContent: Bool {
        !why.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !ifElse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !nextTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        severity != 0 // 情绪强度不是默认值时也算有内容
    }
    
    // 获取所有第二页的字段类型（按顺序）
    var processFields: [FormFieldType] {
        [.why, .ifElse, .nextTime]
    }
    
    // 根据字段类型获取对应的文本绑定
    func getTextBinding(for fieldType: FormFieldType) -> String {
        switch fieldType {
        case .why: return why
        case .ifElse: return ifElse
        case .nextTime: return nextTime
        default: return ""
        }
    }
    
    // 根据字段类型设置对应的文本
    func setText(_ text: String, for fieldType: FormFieldType) {
        switch fieldType {
        case .why: why = text
        case .ifElse: ifElse = text
        case .nextTime: nextTime = text
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
              let currentIndex = processFields.firstIndex(of: currentField) else { return }
        
        let nextIndex = currentIndex + 1
        if nextIndex < processFields.count {
            currentEditingField = processFields[nextIndex]
        } else {
            // 最后一个问题，关闭沉浸式视图
            isImmersiveViewPresented = false
            currentEditingField = nil
        }
    }
    
    // 跳转到上一个问题
    func moveToPreviousQuestion() {
        guard let currentField = currentEditingField,
              let currentIndex = processFields.firstIndex(of: currentField) else { return }
        
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            currentEditingField = processFields[previousIndex]
        }
    }
    
    func reset() {
        why = ""
        ifElse = ""
        severity = 0 // 重置为0，与初始状态保持一致
        nextTime = ""
        isImmersiveViewPresented = false
        currentEditingField = nil
    }
    
    func save(contextVM: EmotionContextViewModel, historyVM: HistoryViewModel, recordVM: RecordEmotionViewModel) -> UUID? {
        // 优先使用临时保存的数据，如果没有则使用当前表单数据
        let temporaryEntry = recordVM.getTemporarySavedEntry()
        
        // 创建完整的记录（整合第一页和第二页的数据）
        let newEntry = EmotionEntry(
            date: contextVM.date,
            place: contextVM.place,
            people: contextVM.people,
            // 优先使用临时保存的数据，如果没有则使用当前recordVM的数据
            whatHappened: temporaryEntry?.whatHappened ?? (recordVM.whatHappened.isEmpty ? nil : recordVM.whatHappened),
            think: temporaryEntry?.think ?? (recordVM.think.isEmpty ? nil : recordVM.think),
            feel: temporaryEntry?.feel ?? (recordVM.feel.isEmpty ? nil : recordVM.feel),
            reaction: temporaryEntry?.reaction ?? (recordVM.reaction.isEmpty ? nil : recordVM.reaction),
            need: temporaryEntry?.need ?? (recordVM.need.isEmpty ? nil : recordVM.need),
            recordSeverity: temporaryEntry?.recordSeverity ?? recordVM.severity,
            why: why.isEmpty ? nil : why,
            ifElse: ifElse.isEmpty ? nil : ifElse,
            nextTime: nextTime.isEmpty ? nil : nextTime,
            processSeverity: severity
        )
        
        // 创建历史记录项
        let savedItemId = historyVM.addHistoryItem(emotionEntry: newEntry)
        
        // 重置两个表单和上下文
        reset()
        recordVM.reset()
        contextVM.reset()
        
        print("保存情绪处理成功，已重置所有表单")
        return savedItemId
    }
}