import Foundation
import SwiftUI
import Combine

class ReaderSettings: ObservableObject {
    @Published var fontSize: CGFloat = 18
    @Published var lineSpacing: CGFloat = 1.5
    @Published var paragraphSpacing: CGFloat = 16
    @Published var fontFamily: String = "PingFang SC"
    @Published var backgroundColor: ReaderBackground = .white
    @Published var textColor: Color = .black
    @Published var pageTurnType: PageTurnType = .slide
    @Published var isNightMode: Bool = false
    @Published var keepScreenOn: Bool = true
    @Published var showStatusBar: Bool = true
    @Published var autoReadSpeed: Double = 3.0
    @Published var isAutoReading: Bool = false
    
    enum ReaderBackground: String, CaseIterable, Codable {
        case white = "FFFFFF"
        case sepia = "F5E6D3"
        case green = "E8F5E9"
        case dark = "1A1A1A"
        case black = "000000"
        
        var color: Color {
            Color(hex: self.rawValue) ?? .white
        }
        
        var displayName: String {
            switch self {
            case .white: return "白天"
            case .sepia: return "护眼"
            case .green: return "清新"
            case .dark: return "夜间"
            case .black: return "纯黑"
            }
        }
    }
    
    enum PageTurnType: String, CaseIterable, Codable {
        case slide = "滑动"
        case curl = "仿真"
        case scroll = "滚动"
        case none = "无动画"
    }
    
    var currentTextColor: Color {
        isNightMode ? .white : textColor
    }
    
    var currentBackground: Color {
        isNightMode ? .black : backgroundColor.color
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}
