import SwiftUI

struct RecordEmotionPage: View {
    @EnvironmentObject var contextVM: EmotionContextViewModel
    @EnvironmentObject var historyVM: HistoryViewModel
    @ObservedObject var vm: RecordEmotionViewModel // 使用外部传入的ViewModel
    @FocusState private var focusedField: FormFieldType?
    @State private var shouldScrollToTop = false // 控制是否滚动到顶部
    
    let onNextStep: () -> Void // Add callback parameter for switching to next step
    let tabBarHeight: CGFloat = 56 // Top tab bar + divider height

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    EmotionInfoBar(vm: contextVM)
                        .id("emotionInfo")
                    
                    QuestionBlock(
                        questionText: FormFieldType.whatHappened.rawValue,
                        answerText: Binding(
                            get: { vm.whatHappened },
                            set: { vm.whatHappened = $0 }
                        ),
                        isFocused: Binding(
                            get: { focusedField == .whatHappened },
                            set: { if $0 { focusedField = .whatHappened } }
                        ),
                        onTap: {
                            vm.openImmersiveView(for: .whatHappened)
                        }
                    )
                    .id(FormFieldType.whatHappened)
                    
                    QuestionBlock(
                        questionText: FormFieldType.think.rawValue,
                        answerText: Binding(
                            get: { vm.think },
                            set: { vm.think = $0 }
                        ),
                        isFocused: Binding(
                            get: { focusedField == .think },
                            set: { if $0 { focusedField = .think } }
                        ),
                        onTap: {
                            vm.openImmersiveView(for: .think)
                        }
                    )
                    .id(FormFieldType.think)
                    
                    QuestionBlock(
                        questionText: FormFieldType.feel.rawValue,
                        answerText: Binding(
                            get: { vm.feel },
                            set: { vm.feel = $0 }
                        ),
                        isFocused: Binding(
                            get: { focusedField == .feel },
                            set: { if $0 { focusedField = .feel } }
                        ),
                        onTap: {
                            vm.openImmersiveView(for: .feel)
                        }
                    )
                    .id(FormFieldType.feel)
                    
                    SeveritySlider(title: "Define Emotion Intensity", severity: $vm.severity)
                        .id("severitySlider")
                    
                    QuestionBlock(
                        questionText: FormFieldType.reaction.rawValue,
                        answerText: Binding(
                            get: { vm.reaction },
                            set: { vm.reaction = $0 }
                        ),
                        isFocused: Binding(
                            get: { focusedField == .reaction },
                            set: { if $0 { focusedField = .reaction } }
                        ),
                        onTap: {
                            vm.openImmersiveView(for: .reaction)
                        }
                    )
                    .id(FormFieldType.reaction)
                    
                    QuestionBlock(
                        questionText: FormFieldType.need.rawValue,
                        answerText: Binding(
                            get: { vm.need },
                            set: { vm.need = $0 }
                        ),
                        isFocused: Binding(
                            get: { focusedField == .need },
                            set: { if $0 { focusedField = .need } }
                        ),
                        onTap: {
                            vm.openImmersiveView(for: .need)
                        }
                    )
                    .id(FormFieldType.need)
                    
                    // Page indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color("DividerColor"))
                            .frame(width: 8, height: 8)
                    }
                    .padding(.top, 20)
                    .id("pageIndicator")
                    
                    // Next page button always visible, doesn't require completing all questions
                    Button("Next") {
                        // If has content, temporarily save current record data (don't reset form)
                        if vm.hasAnyContent {
                            vm.saveToContextTemporary(contextVM: contextVM, historyVM: historyVM)
                        }
                        // Switch to next step (process emotions page)
                        onNextStep()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color("PrimaryText"))  // Consistent with primary text color
                    .foregroundColor(Color("PrimaryBackground"))
                    .cornerRadius(10)
                    .id("nextButton")
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
                    isFirst: vm.recordFields.first == currentField,
                    isLast: vm.recordFields.last == currentField
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
