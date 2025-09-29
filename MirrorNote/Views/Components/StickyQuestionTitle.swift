import SwiftUI

struct StickyQuestionTitle: View {
    let currentField: FormFieldType?
    
    var body: some View {
        Group {
            if let field = currentField {
                HStack {
                    Text(field.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    Spacer()
                }
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4)),
                    alignment: .bottom
                )
            } else {
                // 没有聚焦字段时显示默认提示
                HStack {
                    Text("Select a question to start typing")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    Spacer()
                }
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4)),
                    alignment: .bottom
                )
            }
        }
    }
}