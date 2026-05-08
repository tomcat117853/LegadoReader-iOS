import Foundation
import SwiftUI
import Combine

class ThemeStore: BaseService, ObservableObject {
    static let shared = ThemeStore()
    
    @Published var currentTheme: AppTheme
    @Published var availableThemes: [AppTheme] = []
    @Published var isChangingTheme: Bool = false
    
    private let currentThemeKey = "ThemeStore_currentTheme"
    private let customThemesKey = "ThemeStore_customThemes"
    
    struct AppTheme: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var nameEn: String
        var displayName: String { ThemeStore.shared.currentLanguage == .simplifiedChinese ? name : nameEn }
        var primaryColor: String
        var secondaryColor: String
        var accentColor: String
        var backgroundColor: String
        var surfaceColor: String
        var cardBackgroundColor: String
        var textPrimaryColor: String
        var textSecondaryColor: String
        var dividerColor: String
        var isDarkMode: Bool
        var isBuiltIn: Bool
        var isPro: Bool
        var previewColors: [String]
        
        static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum Language: String, CaseIterable {
        case simplifiedChinese = "zh-Hans"
        case traditionalChinese = "zh-Hant"
        case english = "en"
        
        var displayName: String {
            switch self {
            case .simplifiedChinese: return "简体中文"
            case .traditionalChinese: return "繁體中文"
            case .english: return "English"
            }
        }
    }
    
    var currentLanguage: Language {
        let saved = loadCodable(String.self, key: "ThemeStore_language") ?? Language.simplifiedChinese.rawValue
        return Language(rawValue: saved) ?? .simplifiedChinese
    }
    
    func setLanguage(_ language: Language) {
        saveCodable(language.rawValue, key: "ThemeStore_language")
        objectWillChange.send()
    }
    
    private override init() {
        currentTheme = ThemeStore.defaultTheme
        super.init()
        loadThemes()
    }
    
    private static var defaultTheme: AppTheme {
        AppTheme(
            id: "default",
            name: "默认主题",
            nameEn: "Default",
            primaryColor: "#007AFF",
            secondaryColor: "#5856D6",
            accentColor: "#FF9500",
            backgroundColor: "#F2F2F7",
            surfaceColor: "#FFFFFF",
            cardBackgroundColor: "#FFFFFF",
            textPrimaryColor: "#000000",
            textSecondaryColor: "#8E8E93",
            dividerColor: "#C6C6C8",
            isDarkMode: false,
            isBuiltIn: true,
            isPro: false,
            previewColors: ["#007AFF", "#5856D6", "#FF9500", "#34C759"]
        )
    }
    
    private var builtInThemes: [AppTheme] {
        [
            Self.defaultTheme,
            AppTheme(
                id: "dark",
                name: "深色主题",
                nameEn: "Dark",
                primaryColor: "#0A84FF",
                secondaryColor: "#5E5CE6",
                accentColor: "#FF9F0A",
                backgroundColor: "#000000",
                surfaceColor: "#1C1C1E",
                cardBackgroundColor: "#2C2C2E",
                textPrimaryColor: "#FFFFFF",
                textSecondaryColor: "#98989D",
                dividerColor: "#38383A",
                isDarkMode: true,
                isBuiltIn: true,
                isPro: false,
                previewColors: ["#0A84FF", "#5E5CE6", "#FF9F0A", "#30D158"]
            ),
            AppTheme(
                id: "sepia",
                name: "护眼主题",
                nameEn: "Sepia",
                primaryColor: "#8B4513",
                secondaryColor: "#D2691E",
                accentColor: "#CD853F",
                backgroundColor: "#F4ECD8",
                surfaceColor: "#FDF5E6",
                cardBackgroundColor: "#FAF0E6",
                textPrimaryColor: "#5D4037",
                textSecondaryColor: "#8D6E63",
                dividerColor: "#D7CCC8",
                isDarkMode: false,
                isBuiltIn: true,
                isPro: false,
                previewColors: ["#8B4513", "#D2691E", "#CD853F", "#DEB887"]
            ),
            AppTheme(
                id: "ocean",
                name: "海洋主题",
                nameEn: "Ocean",
                primaryColor: "#0077B6",
                secondaryColor: "#00B4D8",
                accentColor: "#90E0EF",
                backgroundColor: "#CAF0F8",
                surfaceColor: "#ADE8F4",
                cardBackgroundColor: "#FFFFFF",
                textPrimaryColor: "#03045E",
                textSecondaryColor: "#0077B6",
                dividerColor: "#90E0EF",
                isDarkMode: false,
                isBuiltIn: true,
                isPro: false,
                previewColors: ["#0077B6", "#00B4D8", "#90E0EF", "#CAF0F8"]
            ),
            AppTheme(
                id: "forest",
                name: "森林主题",
                nameEn: "Forest",
                primaryColor: "#2D6A4F",
                secondaryColor: "#40916C",
                accentColor: "#74C69D",
                backgroundColor: "#D8F3DC",
                surfaceColor: "#B7E4C7",
                cardBackgroundColor: "#FFFFFF",
                textPrimaryColor: "#1B4332",
                textSecondaryColor: "#2D6A4F",
                dividerColor: "#95D5B2",
                isDarkMode: false,
                isBuiltIn: true,
                isPro: false,
                previewColors: ["#2D6A4F", "#40916C", "#74C69D", "#D8F3DC"]
            ),
            AppTheme(
                id: "sunset",
                name: "日落主题",
                nameEn: "Sunset",
                primaryColor: "#E63946",
                secondaryColor: "#F4A261",
                accentColor: "#E9C46A",
                backgroundColor: "#FFF1E6",
                surfaceColor: "#FFFFFF",
                cardBackgroundColor: "#FFFFFF",
                textPrimaryColor: "#1D3557",
                textSecondaryColor: "#457B9D",
                dividerColor: "#E9C46A",
                isDarkMode: false,
                isBuiltIn: true,
                isPro: false,
                previewColors: ["#E63946", "#F4A261", "#E9C46A", "#2A9D8F"]
            ),
            AppTheme(
                id: "midnight",
                name: "午夜主题",
                nameEn: "Midnight",
                primaryColor: "#6366F1",
                secondaryColor: "#8B5CF6",
                accentColor: "#A78BFA",
                backgroundColor: "#0F172A",
                surfaceColor: "#1E293B",
                cardBackgroundColor: "#334155",
                textPrimaryColor: "#F1F5F9",
                textSecondaryColor: "#94A3B8",
                dividerColor: "#475569",
                isDarkMode: true,
                isBuiltIn: true,
                isPro: false,
                previewColors: ["#6366F1", "#8B5CF6", "#A78BFA", "#F472B6"]
            ),
            AppTheme(
                id: "monochrome",
                name: "黑白主题",
                nameEn: "Monochrome",
                primaryColor: "#374151",
                secondaryColor: "#6B7280",
                accentColor: "#9CA3AF",
                backgroundColor: "#FFFFFF",
                surfaceColor: "#F9FAFB",
                cardBackgroundColor: "#FFFFFF",
                textPrimaryColor: "#111827",
                textSecondaryColor: "#6B7280",
                dividerColor: "#E5E7EB",
                isDarkMode: false,
                isBuiltIn: true,
                isPro: false,
                previewColors: ["#374151", "#6B7280", "#9CA3AF", "#D1D5DB"]
            )
        ]
    }
    
    private func loadThemes() {
        availableThemes = builtInThemes
        
        if let customThemes = loadCodable([AppTheme].self, key: customThemesKey) {
            availableThemes.append(contentsOf: customThemes)
        }
        
        if let savedThemeId = loadCodable(String.self, key: currentThemeKey),
           let savedTheme = availableThemes.first(where: { $0.id == savedThemeId }) {
            currentTheme = savedTheme
        }
    }
    
    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveCodable(theme.id, key: currentThemeKey)
        
        objectWillChange.send()
    }
    
    func changeTheme(to themeId: String, completion: (() -> Void)? = nil) {
        guard let theme = availableThemes.first(where: { $0.id == themeId }) else { return }
        
        isChangingTheme = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.applyTheme(theme)
            self?.isChangingTheme = false
            completion?()
        }
    }
    
    func createCustomTheme(from baseTheme: AppTheme, name: String, nameEn: String, primaryColor: String) -> AppTheme {
        let customTheme = AppTheme(
            id: UUID().uuidString,
            name: name,
            nameEn: nameEn,
            primaryColor: primaryColor,
            secondaryColor: baseTheme.secondaryColor,
            accentColor: baseTheme.accentColor,
            backgroundColor: baseTheme.backgroundColor,
            surfaceColor: baseTheme.surfaceColor,
            cardBackgroundColor: baseTheme.cardBackgroundColor,
            textPrimaryColor: baseTheme.textPrimaryColor,
            textSecondaryColor: baseTheme.textSecondaryColor,
            dividerColor: baseTheme.dividerColor,
            isDarkMode: baseTheme.isDarkMode,
            isBuiltIn: false,
            isPro: false,
            previewColors: [primaryColor, baseTheme.secondaryColor, baseTheme.accentColor, baseTheme.primaryColor]
        )
        
        var customThemes = loadCodable([AppTheme].self, key: customThemesKey) ?? []
        customThemes.append(customTheme)
        saveCodable(customThemes, key: customThemesKey)
        
        availableThemes.append(customTheme)
        
        return customTheme
    }
    
    func deleteCustomTheme(_ theme: AppTheme) {
        guard !theme.isBuiltIn else { return }
        
        var customThemes = loadCodable([AppTheme].self, key: customThemesKey) ?? []
        customThemes.removeAll { $0.id == theme.id }
        saveCodable(customThemes, key: customThemesKey)
        
        availableThemes.removeAll { $0.id == theme.id }
        
        if currentTheme.id == theme.id {
            applyTheme(builtInThemes.first!)
        }
    }
    
    func resetToDefault() {
        applyTheme(builtInThemes.first!)
    }
}

extension ThemeStore {
    var primaryColor: Color {
        Color(hex: currentTheme.primaryColor) ?? .blue
    }
    
    var secondaryColor: Color {
        Color(hex: currentTheme.secondaryColor) ?? .purple
    }
    
    var accentColor: Color {
        Color(hex: currentTheme.accentColor) ?? .orange
    }
    
    var backgroundColor: Color {
        Color(hex: currentTheme.backgroundColor) ?? Color(.systemBackground)
    }
    
    var surfaceColor: Color {
        Color(hex: currentTheme.surfaceColor) ?? Color(.secondarySystemBackground)
    }
    
    var cardBackgroundColor: Color {
        Color(hex: currentTheme.cardBackgroundColor) ?? Color(.systemBackground)
    }
    
    var textPrimaryColor: Color {
        Color(hex: currentTheme.textPrimaryColor) ?? .primary
    }
    
    var textSecondaryColor: Color {
        Color(hex: currentTheme.textSecondaryColor) ?? .secondary
    }
}

extension ThemeStore {
    func oneClickChangeSkin(to themeId: String) {
        changeTheme(to: themeId)
    }
    
    func randomSkin() {
        let randomIndex = Int.random(in: 1..<availableThemes.count)
        let randomTheme = availableThemes[randomIndex]
        changeTheme(to: randomTheme.id)
    }
}
