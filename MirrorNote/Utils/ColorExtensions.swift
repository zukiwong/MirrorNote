import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - 深色模式支持
    // 
    // 颜色集已在Assets.xcassets中定义，支持自动深色模式适配：
    //
    // - PrimaryBackground: 主背景色（白天：白色，深色：黑色）
    // - SecondaryBackground: 次要背景色（白天：#F2F2F2，深色：#1C1C1E）
    // - TertiaryBackground: 第三级背景色（白天：#E0E0E0，深色：#2C2C2E）
    // - PrimaryText: 主文本色（白天：黑色，深色：白色）
    // - SecondaryText: 次要文本色（白天：#323232，深色：#EBEBF5）
    // - DividerColor: 分割线颜色（白天：30%灰，深色：60%灰）
    // - ShadowColor: 阴影颜色（白天：8%黑，深色：30%黑）
    //
    // 使用方式：Color("PrimaryBackground"), Color("PrimaryText") 等
    // SwiftUI会自动根据系统外观模式选择合适的颜色
}