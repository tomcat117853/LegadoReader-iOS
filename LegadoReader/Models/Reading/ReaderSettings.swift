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
    @Published var pageTurnMode: PageTurnMode = .horizontal
    @Published var isNightMode: Bool = false
    @Published var keepScreenOn: Bool = true
    @Published var showStatusBar: Bool = true
    @Published var autoReadSpeed: Double = 3.0
    @Published var isAutoReading: Bool = false
    @Published var autoScrollSpeed: Double = 1.0
    @Published var showScrollIndicator: Bool = true
    @Published var doubleTapToPause: Bool = true
    @Published var horizontalPadding: CGFloat = 16
    @Published var verticalPadding: CGFloat = 20
    @Published var textAlignment: String = "left"
    @Published var enablePageAnimation: Bool = true
    @Published var showChapterTitle: Bool = true
    @Published var tapZoneEnabled: Bool = true
    @Published var brightness: Double = 0.5
    @Published var swipeGesturesEnabled: Bool = true
    @Published var audioAutoFollowEnabled: Bool = false
    @Published var audioAutoFollowMode: AudioFollowMode = .paragraph
    @Published var hapticFeedbackEnabled: Bool = true
    @Published var longPressEnabled: Bool = true
    @Published var titleFormatEnabled: Bool = true
    @Published var showMiniProgress: Bool = true
    
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
    
    enum AudioFollowMode: String, CaseIterable, Codable {
        case sentence = "句子"
        case paragraph = "段落"
        case chapter = "章节"
    }
    
    var currentTextColor: Color {
        isNightMode ? .white : textColor
    }
    
    var currentBackground: Color {
        isNightMode ? .black : backgroundColor.color
    }
    
    func isVerticalScrollMode() -> Bool {
        return pageTurnMode == .vertical
    }
    
    func isSwipeEnabled() -> Bool {
        return swipeGesturesEnabled && pageTurnMode != .none
    }
    
    func isLongPressEnabled() -> Bool {
        return longPressEnabled
    }
}
