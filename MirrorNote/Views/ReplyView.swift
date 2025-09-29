import SwiftUI

struct ReplyView: View {
    var body: some View {
        VStack {
            Text("回复页面")
                .font(.title)
                .padding()
            
            Text("此页面正在开发中...")
                .foregroundColor(.gray)
            
            Spacer()
        }
        .navigationTitle("回复")
    }
}

#Preview {
    ReplyView()
}