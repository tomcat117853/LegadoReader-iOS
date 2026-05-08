import Foundation
import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: Theme
    @Published var availableThemes: [Theme] = []
    @Published var customColors: [CustomColor] = []
    
    struct Theme: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let isCustom: Bool
        let backgroundColor: String
        let textColor: String
        let accentColor: String
        let secondaryColor: String
        let navigationBarColor: String
        let tabBarColor: String
        let cardColor: String
        let borderColor: String
        let linkColor: String
        let successColor: String
        let warningColor: String
        let errorColor: String
        
        static func == (lhs: Theme, rhs: Theme) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct CustomColor: Identifiable {
        let id = UUID()
        let name: String
        let hex: String
    }
    
    private let defaults = UserDefaults.standard
    private let themeKey = "ThemeManager_currentTheme"
    private let customColorsKey = "ThemeManager_customColors"
    
    private init() {
        loadAvailableThemes()
        loadCustomColors()
        
        if let savedThemeId = defaults.string(forKey: themeKey),
           let savedTheme = availableThemes.first(where: { $0.id == savedThemeId }) {
            currentTheme = savedTheme
        } else {
            currentTheme = availableThemes.first { $0.name == "浅色" } ?? availableThemes[0]
        }
    }
    
    private func loadAvailableThemes() {
        availableThemes = [
            Theme(
                id: "light",
                name: "浅色",
                description: "明亮清爽的浅色主题",
                isCustom: false,
                backgroundColor: "#FFFFFF",
                textColor: "#1C1C1E",
                accentColor: "#007AFF",
                secondaryColor: "#8E8E93",
                navigationBarColor: "#FFFFFF",
                tabBarColor: "#FFFFFF",
                cardColor: "#FFFFFF",
                borderColor: "#E8E8ED",
                linkColor: "#007AFF",
                successColor: "#34C759",
                warningColor: "#FF9500",
                errorColor: "#FF3B30"
            ),
            Theme(
                id: "dark",
                name: "深色",
                description: "护眼舒适的深色主题",
                isCustom: false,
                backgroundColor: "#1C1C1E",
                textColor: "#FFFFFF",
                accentColor: "#0A84FF",
                secondaryColor: "#8E8E93",
                navigationBarColor: "#1C1C1E",
                tabBarColor: "#1C1C1E",
                cardColor: "#2C2C2E",
                borderColor: "#3A3A3C",
                linkColor: "#0A84FF",
                successColor: "#30D158",
                warningColor: "#FF9F0A",
                errorColor: "#FF453A"
            ),
            Theme(
                id: "sepia",
                name: "护眼",
                description: "柔和温暖的护眼主题",
                isCustom: false,
                backgroundColor: "#FDF6E3",
                textColor: "#4B371C",
                accentColor: "#8B4513",
                secondaryColor: "#8B7355",
                navigationBarColor: "#FDF6E3",
                tabBarColor: "#FDF6E3",
                cardColor: "#FAF0E1",
                borderColor: "#E8DFC4",
                linkColor: "#8B4513",
                successColor: "#228B22",
                warningColor: "#DAA520",
                errorColor: "#DC143C"
            ),
            Theme(
                id: "night",
                name: "夜间",
                description: "极暗的夜间主题",
                isCustom: false,
                backgroundColor: "#0A0A0A",
                textColor: "#EFEFEF",
                accentColor: "#5856D6",
                secondaryColor: "#636366",
                navigationBarColor: "#0A0A0A",
                tabBarColor: "#0A0A0A",
                cardColor: "#151515",
                borderColor: "#272729",
                linkColor: "#5856D6",
                successColor: "#30D158",
                warningColor: "#FF9F0A",
                errorColor: "#FF453A"
            ),
            Theme(
                id: "ocean",
                name: "海洋",
                description: "清新海洋风格",
                isCustom: false,
                backgroundColor: "#E6F4F9",
                textColor: "#0A1628",
                accentColor: "#006994",
                secondaryColor: "#6B8E9F",
                navigationBarColor: "#E6F4F9",
                tabBarColor: "#E6F4F9",
                cardColor: "#FFFFFF",
                borderColor: "#B8D4E3",
                linkColor: "#006994",
                successColor: "#00A86B",
                warningColor: "#FF6B35",
                errorColor: "#DC2626"
            ),
            Theme(
                id: "sunset",
                name: "日落",
                description: "温暖日落风格",
                isCustom: false,
                backgroundColor: "#FFF5EB",
                textColor: "#5C2E0A",
                accentColor: "#D45A1A",
                secondaryColor: "#9B6A3A",
                navigationBarColor: "#FFF5EB",
                tabBarColor: "#FFF5EB",
                cardColor: "#FFFFFF",
                borderColor: "#F5D5B8",
                linkColor: "#D45A1A",
                successColor: "#4A7C23",
                warningColor: "#D97706",
                errorColor: "#DC2626"
            ),
            Theme(
                id: "forest",
                name: "森林",
                description: "自然森林风格",
                isCustom: false,
                backgroundColor: "#E8F5E9",
                textColor: "#1B3A1B",
                accentColor: "#2E7D32",
                secondaryColor: "#558B2F",
                navigationBarColor: "#E8F5E9",
                tabBarColor: "#E8F5E9",
                cardColor: "#FFFFFF",
                borderColor: "#C8E6C9",
                linkColor: "#2E7D32",
                successColor: "#388E3C",
                warningColor: "#F57C00",
                errorColor: "#C62828"
            ),
            Theme(
                id: "lavender",
                name: "薰衣草",
                description: "优雅薰衣草风格",
                isCustom: false,
                backgroundColor: "#F3E5F5",
                textColor: "#4A148C",
                accentColor: "#7B1FA2",
                secondaryColor: "#8E24AA",
                navigationBarColor: "#F3E5F5",
                tabBarColor: "#F3E5F5",
                cardColor: "#FFFFFF",
                borderColor: "#E1BEE7",
                linkColor: "#7B1FA2",
                successColor: "#66BB6A",
                warningColor: "#FFA726",
                errorColor: "#EF5350"
            )
        ]
    }
    
    private func loadCustomColors() {
        if let data = defaults.data(forKey: customColorsKey),
           let colors = try? JSONDecoder().decode([CustomColor].self, from: data) {
            customColors = colors
        } else {
            customColors = [
                CustomColor(name: "红色", hex: "#FF3B30"),
                CustomColor(name: "橙色", hex: "#FF9500"),
                CustomColor(name: "黄色", hex: "#FFCC00"),
                CustomColor(name: "绿色", hex: "#34C759"),
                CustomColor(name: "青色", hex: "#34AADC"),
                CustomColor(name: "蓝色", hex: "#007AFF"),
                CustomColor(name: "紫色", hex: "#AF52DE"),
                CustomColor(name: "粉色", hex: "#FF2D55")
            ]
        }
    }
    
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        defaults.set(theme.id, forKey: themeKey)
        applyTheme()
    }
    
    func createCustomTheme(name: String, backgroundColor: String, textColor: String, accentColor: String) -> Theme {
        let newTheme = Theme(
            id: "custom_\(UUID().uuidString)",
            name: name,
            description: "自定义主题",
            isCustom: true,
            backgroundColor: backgroundColor,
            textColor: textColor,
            accentColor: accentColor,
            secondaryColor: adjustBrightness(hex: textColor, percent: -40),
            navigationBarColor: backgroundColor,
            tabBarColor: backgroundColor,
            cardColor: adjustBrightness(hex: backgroundColor, percent: -5),
            borderColor: adjustBrightness(hex: textColor, percent: -60),
            linkColor: accentColor,
            successColor: "#34C759",
            warningColor: "#FF9500",
            errorColor: "#FF3B30"
        )
        
        availableThemes.append(newTheme)
        return newTheme
    }
    
    func deleteCustomTheme(_ theme: Theme) {
        guard theme.isCustom else { return }
        
        if currentTheme.id == theme.id {
            let defaultTheme = availableThemes.first { !$0.isCustom }
            if let defaultTheme = defaultTheme {
                setTheme(defaultTheme)
            }
        }
        
        availableThemes.removeAll { $0.id == theme.id }
    }
    
    func addCustomColor(name: String, hex: String) {
        if !customColors.contains(where: { $0.hex.lowercased() == hex.lowercased() }) {
            customColors.append(CustomColor(name: name, hex: hex))
            saveCustomColors()
        }
    }
    
    private func saveCustomColors() {
        if let data = try? JSONEncoder().encode(customColors) {
            defaults.set(data, forKey: customColorsKey)
        }
    }
    
    private func applyTheme() {
        UIApplication.shared.windows.forEach { window in
            window.overrideUserInterfaceStyle = currentTheme.id == "dark" || currentTheme.id == "night" ? .dark : .light
        }
    }
    
    private func adjustBrightness(hex: String, percent: Int) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000ff) / 255
        }
        
        let brightnessAdjustment = CGFloat(percent) / 100
        r = max(0, min(1, r + brightnessAdjustment))
        g = max(0, min(1, g + brightnessAdjustment))
        b = max(0, min(1, b + brightnessAdjustment))
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    
    func getThemeColor(_ colorType: ThemeColorType) -> Color {
        let hexString: String
        
        switch colorType {
        case .background:
            hexString = currentTheme.backgroundColor
        case .text:
            hexString = currentTheme.textColor
        case .accent:
            hexString = currentTheme.accentColor
        case .secondary:
            hexString = currentTheme.secondaryColor
        case .navigationBar:
            hexString = currentTheme.navigationBarColor
        case .tabBar:
            hexString = currentTheme.tabBarColor
        case .card:
            hexString = currentTheme.cardColor
        case .border:
            hexString = currentTheme.borderColor
        case .link:
            hexString = currentTheme.linkColor
        case .success:
            hexString = currentTheme.successColor
        case .warning:
            hexString = currentTheme.warningColor
        case .error:
            hexString = currentTheme.errorColor
        }
        
        return Color(hex: hexString)
    }
    
    func getThemeUIColor(_ colorType: ThemeColorType) -> UIColor {
        let hexString: String
        
        switch colorType {
        case .background:
            hexString = currentTheme.backgroundColor
        case .text:
            hexString = currentTheme.textColor
        case .accent:
            hexString = currentTheme.accentColor
        case .secondary:
            hexString = currentTheme.secondaryColor
        case .navigationBar:
            hexString = currentTheme.navigationBarColor
        case .tabBar:
            hexString = currentTheme.tabBarColor
        case .card:
            hexString = currentTheme.cardColor
        case .border:
            hexString = currentTheme.borderColor
        case .link:
            hexString = currentTheme.linkColor
        case .success:
            hexString = currentTheme.successColor
        case .warning:
            hexString = currentTheme.warningColor
        case .error:
            hexString = currentTheme.errorColor
        }
        
        return UIColor(hex: hexString)
    }
}

enum ThemeColorType {
    case background
    case text
    case accent
    case secondary
    case navigationBar
    case tabBar
    case card
    case border
    case link
    case success
    case warning
    case error
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
