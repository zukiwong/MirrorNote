import SwiftUI

struct ProcessEmotionPage: View {
    @EnvironmentObject var contextVM: EmotionContextViewModel
    @EnvironmentObject var historyVM: HistoryViewModel
    @ObservedObject var vm: ProcessEmotionViewModel // Use externally passed ViewModel
    @ObservedObject var recordVM: RecordEmotionViewModel // First page ViewModel for content checking
    @FocusState private var focusedField: FormFieldType?
    @State private var savedItemId: UUID? = nil // 保存的项目ID，用于导航
    @State private var showEmptyAlert: Bool = false // 控制空内容警告弹窗
    @State private var showSuccessToast: Bool = false // 控制成功提示toast显示
    @State private var shouldScrollToTop = false // 控制是否滚动到顶部

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    EmotionInfoBar(vm: contextVM)
                        .id("emotionInfo")
                    
                    QuestionBlock(
                        questionText: FormFieldType.why.rawValue,
                        answerText: Binding(
                            get: { vm.why },
                            set: { vm.why = $0 }
                        ),
                        isFocused: Binding(
                            get: { focusedField == .why },
                            set: { if $0 { focusedField = .why } }
                        ),
                        onTap: {
                            vm.openImmersiveView(for: .why)
                        }
                    )
                    .id(FormFieldType.why)
                    
                    QuestionBlock(
                        questionText: FormFieldType.ifElse.rawValue,
                        answerText: Binding(
                            get: { vm.ifElse },
                            set: { vm.ifElse = $0 }
                        ),
                        isFocused: Binding(
                            get: { focusedField == .ifElse },
                            set: { if $0 { focusedField = .ifElse } }
                        ),
                        onTap: {
                            vm.openImmersiveView(for: .ifElse)
                        }
                    )
                    .id(FormFieldType.ifElse)
                    
                    SeveritySlider(title: "Redefine Emotion Intensity", severity: $vm.severity)
                        .id("severitySlider")
                    
                    QuestionBlock(
                        questionText: FormFieldType.nextTime.rawValue,
                        answerText: Binding(
                            get: { vm.nextTime },
                            set: { vm.nextTime = $0 }
                        ),
                        isFocused: Binding(
                            get: { focusedField == .nextTime },
                            set: { if $0 { focusedField = .nextTime } }
                        ),
                        onTap: {
                            vm.openImmersiveView(for: .nextTime)
                        }
                    )
                    .id(FormFieldType.nextTime)
                    
                    // 保存按钮始终可见，无需回答所有问题
                    Button("Save") {
                        // 检查两个页面是否有任何内容
                        if vm.hasAnyContent || recordVM.hasAnyContent {
                            savedItemId = vm.save(contextVM: contextVM, historyVM: historyVM, recordVM: recordVM)
                            // 先显示成功提示Toast
                            if savedItemId != nil {
                                showSuccessToast = true
                                print("💾 [ProcessEmotionPage] 保存成功，历史记录项ID: \(savedItemId!.uuidString)")
                                // 延迟1.5秒后发送通知直接跳转到详情页（从首页跳转）
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    print("📤 [ProcessEmotionPage] 发送跳转通知，ID: \(savedItemId!.uuidString)")
                                    // 发送通知让HomeView直接跳转到详情页
                                    NotificationCenter.default.post(
                                        name: .openEmotionDetailFromHome,
                                        object: nil,
                                        userInfo: ["emotionEntryId": savedItemId!.uuidString]
                                    )
                                }
                            } else {
                                print("❌ [ProcessEmotionPage] 保存失败，savedItemId为nil")
                            }
                        } else {
                            showEmptyAlert = true
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color("PrimaryText"))
                    .foregroundColor(Color("PrimaryBackground"))
                    .cornerRadius(10)
                    .id("saveButton")
                }
                .padding(.horizontal, 8) // Reduce left/right margins
                .padding(.vertical, 16)
            }
            .onChange(of: focusedField) { field in
                if let field = field {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            .onChange(of: shouldScrollToTop) { _ in
                if shouldScrollToTop {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("emotionInfo", anchor: .top)
                    }
                    shouldScrollToTop = false
                }
            }
        }
        .onAppear {
            // 当页面出现时，触发滚动到顶部
            shouldScrollToTop = true
        }
        .alert("Please fill in content", isPresented: $showEmptyAlert) {
            Button("OK") { }
        } message: {
            Text("Please fill in at least one question or adjust emotion intensity")
        }
        .successToast(
            isPresented: $showSuccessToast,
            message: "Successfully saved",
            icon: "checkmark.circle"
        )
        .fullScreenCover(isPresented: $vm.isImmersiveViewPresented) {
            if let currentField = vm.currentEditingField {
                ImmersiveQuestionView(
                    questionType: currentField,
                    text: Binding(
                        get: { vm.getTextBinding(for: currentField) },
                        set: { vm.setText($0, for: currentField) }
                    ),
                    isPresented: $vm.isImmersiveViewPresented,
                    onNext: {
                        vm.moveToNextQuestion()
                    },
                    onPrevious: {
                        vm.moveToPreviousQuestion()
                    },
                    isFirst: vm.processFields.first == currentField,
                    isLast: vm.processFields.last == currentField
                )
            }
        }
        .fullScreenCover(isPresented: $contextVM.isImmersiveViewPresented) {
            if let currentContextField = contextVM.currentEditingContextField {
                ImmersiveContextView(
                    fieldType: currentContextField,
                    text: Binding(
                        get: { contextVM.getTextBinding(for: currentContextField) },
                        set: { contextVM.setText($0, for: currentContextField) }
                    ),
                    isPresented: $contextVM.isImmersiveViewPresented
                )
            }
        }
    }
}

