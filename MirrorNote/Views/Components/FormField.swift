import SwiftUI

enum FormFieldType: String, CaseIterable {
    case whatHappened = "What happened at that time?"
    case think = "What were your emotional feelings/thoughts at that time?"
    case feel = "What physical sensations did you have at that time?"
    case reaction = "What was my reaction/what did I do when it happened?"
    case need = "What need of mine caused this emotion?"
    case why = "Why do I think this way? Is this thought a fact, or am I exaggerating?"
    case ifElse = "If this happened to someone else today, I would tell them..."
    case nextTime = "If something similar happens next time, I could do this?"
}

struct FormField: View {
    let type: FormFieldType
    @Binding var text: String
    @FocusState.Binding var focusedField: FormFieldType?
    var onLastFieldComplete: (() -> Void)? = nil // Last field completion callback for first page
    
    // Helper function to get next field
    private func nextField() -> FormFieldType? {
        let allCases = FormFieldType.allCases
        guard let currentIndex = allCases.firstIndex(of: type) else { return nil }
        let nextIndex = currentIndex + 1
        return nextIndex < allCases.count ? allCases[nextIndex] : nil
    }
    
    // Check if this is the last field of first page
    private var isLastFieldOfFirstPage: Bool {
        return type == .need
    }
    
    var body: some View {
        QuestionBlock(
            questionText: type.rawValue,
            answerText: $text,
            isFocused: Binding(
                get: { focusedField == type },
                set: { if $0 { focusedField = type } }
            ),
            onCommit: {
                // Automatically jump to next question after clicking done
                if isLastFieldOfFirstPage {
                    // Last field of first page: dismiss keyboard and notify parent component
                    focusedField = nil
                    onLastFieldComplete?()
                } else if let next = nextField() {
                    focusedField = next
                } else {
                    focusedField = nil // If it's the last field, remove focus
                }
            }
        )
        .focused($focusedField, equals: type)
    }
}

struct SeveritySlider: View {
    let title: String // Add custom title parameter
    @Binding var severity: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title) // Use custom title
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                ForEach(1...5, id: \.self) { number in
                    Button(action: {
                        severity = number
                    }) {
                        Text("\(number)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(severity == number ? .primary : .secondary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(severity == number ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer() // Add Spacer for left alignment
            }
        }
        .padding(.horizontal, 8) // Consistent margin with other components
        .padding(.vertical, 12)
    }
}