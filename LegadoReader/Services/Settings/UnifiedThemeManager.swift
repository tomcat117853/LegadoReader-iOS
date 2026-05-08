import Foundation
import SwiftUI
import Combine

class UnifiedThemeManager: BaseService, ObservableObject {
    static let shared = UnifiedThemeManager()
    
    @Published var currentTheme: UnifiedTheme
    @Published var availableThemes: [UnifiedTheme] = []
    @Published var isChangingTheme: Bool = false
    @Published var currentLanguage: Language = .simplifiedChinese
    
    @Published var isEyeCareEnabled: Bool = false
    @Published var blueLightFilterLevel: Double = 0.0
    @Published var warmLightLevel: Double = 0.0
    @Published var contrastLevel: Double = 1.0
    
    private let themeKey = "UnifiedThemeManager_currentTheme"
    private let languageKey = "UnifiedThemeManager_language"
    private let customThemesKey = "UnifiedThemeManager_customThemes"
    private let eyeCareKey = "UnifiedThemeManager_eyeCare"
    
    struct UnifiedTheme: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var nameEn: String
        var nameTw: String
        var backgroundColor: String
        var surfaceColor: String
        var cardColor: String
        var textColor: String
        var secondaryTextColor: String
        var primaryColor: String
        var secondaryColor: String
        var accentColor: String
        var dividerColor: String
        var isDarkMode: Bool
        var isBuiltIn: Bool
        var previewColors: [String]
        
        var displayName: String {
            switch UnifiedThemeManager.shared.currentLanguage {
            case .simplifiedChinese: return name
            case .traditionalChinese: return nameTw.isEmpty ? name : nameTw
            case .english: return nameEn.isEmpty ? name : nameEn
            }
        }
        
        static func == (lhs: UnifiedTheme, rhs: UnifiedTheme) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum Language: String, Codable, CaseIterable {
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
    
    private override init() {
        currentTheme = UnifiedThemeManager.defaultTheme
        super.init()
        loadThemes()
        loadSettings()
    }
    
    private static var defaultTheme: UnifiedTheme {
        UnifiedTheme(
            id: "default",
            name: "默认主题",
            nameEn: "Default",
            nameTw: "預設主題",
            backgroundColor: "#FFFFFF",
            surfaceColor: "#F2F2F7",
            cardColor: "#FFFFFF",
            textColor: "#000000",
            secondaryTextColor: "#8E8E93",
            primaryColor: "#007AFF",
            secondaryColor: "#5856D6",
            accentColor: "#FF9500",
            dividerColor: "#C6C6C8",
            isDarkMode: false,
            isBuiltIn: true,
            previewColors: ["#007AFF", "#5856D6", "#FF9500", "#34C759"]
        )
    }
    
    private var builtInThemes: [UnifiedTheme] {
        [
            Self.defaultTheme,
            UnifiedTheme(
                id: "dark",
                name: "深色主题",
                nameEn: "Dark",
                nameTw: "深色主題",
                backgroundColor: "#000000",
                surfaceColor: "#1C1C1E",
                cardColor: "#2C2C2E",
                textColor: "#FFFFFF",
                secondaryTextColor: "#98989D",
                primaryColor: "#0A84FF",
                secondaryColor: "#5E5CE6",
                accentColor: "#FF9F0A",
                dividerColor: "#38383A",
                isDarkMode: true,
                isBuiltIn: true,
                previewColors: ["#0A84FF", "#5E5CE6", "#FF9F0A", "#30D158"]
            ),
            UnifiedTheme(
                id: "sepia",
                name: "护眼主题",
                nameEn: "Sepia",
                nameTw: "護眼主題",
                backgroundColor: "#F4ECD8",
                surfaceColor: "#FDF5E6",
                cardColor: "#FAF0E6",
                textColor: "#5D4037",
                secondaryTextColor: "#8D6E63",
                primaryColor: "#8B4513",
                secondaryColor: "#D2691E",
                accentColor: "#CD853F",
                dividerColor: "#D7CCC8",
                isDarkMode: false,
                isBuiltIn: true,
                previewColors: ["#8B4513", "#D2691E", "#CD853F", "#DEB887"]
            ),
            UnifiedTheme(
                id: "ocean",
                name: "海洋主题",
                nameEn: "Ocean",
                nameTw: "海洋主題",
                backgroundColor: "#CAF0F8",
                surfaceColor: "#ADE8F4",
                cardColor: "#FFFFFF",
                textColor: "#03045E",
                secondaryTextColor: "#0077B6",
                primaryColor: "#0077B6",
                secondaryColor: "#00B4D8",
                accentColor: "#90E0EF",
                dividerColor: "#90E0EF",
                isDarkMode: false,
                isBuiltIn: true,
                previewColors: ["#0077B6", "#00B4D8", "#90E0EF", "#CAF0F8"]
            ),
            UnifiedTheme(
                id: "forest",
                name: "森林主题",
                nameEn: "Forest",
                nameTw: "森林主題",
                backgroundColor: "#D8F3DC",
                surfaceColor: "#B7E4C7",
                cardColor: "#FFFFFF",
                textColor: "#1B4332",
                secondaryTextColor: "#2D6A4F",
                primaryColor: "#2D6A4F",
                secondaryColor: "#40916C",
                accentColor: "#74C69D",
                dividerColor: "#95D5B2",
                isDarkMode: false,
                isBuiltIn: true,
                previewColors: ["#2D6A4F", "#40916C", "#74C69D", "#D8F3DC"]
            ),
            UnifiedTheme(
                id: "sunset",
                name: "日落主题",
                nameEn: "Sunset",
                nameTw: "日落主題",
                backgroundColor: "#FFF1E6",
                surfaceColor: "#FFFFFF",
                cardColor: "#FFFFFF",
                textColor: "#1D3557",
                secondaryTextColor: "#457B9D",
                primaryColor: "#E63946",
                secondaryColor: "#F4A261",
                accentColor: "#E9C46A",
                dividerColor: "#E9C46A",
                isDarkMode: false,
                isBuiltIn: true,
                previewColors: ["#E63946", "#F4A261", "#E9C46A", "#2A9D8F"]
            ),
            UnifiedTheme(
                id: "midnight",
                name: "午夜主题",
                nameEn: "Midnight",
                nameTw: "午夜主題",
                backgroundColor: "#0F172A",
                surfaceColor: "#1E293B",
                cardColor: "#334155",
                textColor: "#F1F5F9",
                secondaryTextColor: "#94A3B8",
                primaryColor: "#6366F1",
                secondaryColor: "#8B5CF6",
                accentColor: "#A78BFA",
                dividerColor: "#475569",
                isDarkMode: true,
                isBuiltIn: true,
                previewColors: ["#6366F1", "#8B5CF6", "#A78BFA", "#F472B6"]
            ),
            UnifiedTheme(
                id: "monochrome",
                name: "黑白主题",
                nameEn: "Monochrome",
                nameTw: "黑白主題",
                backgroundColor: "#FFFFFF",
                surfaceColor: "#F9FAFB",
                cardColor: "#FFFFFF",
                textColor: "#111827",
                secondaryTextColor: "#6B7280",
                primaryColor: "#374151",
                secondaryColor: "#6B7280",
                accentColor: "#9CA3AF",
                dividerColor: "#E5E7EB",
                isDarkMode: false,
                isBuiltIn: true,
                previewColors: ["#374151", "#6B7280", "#9CA3AF", "#D1D5DB"]
            )
        ]
    }
    
    private func loadThemes() {
        availableThemes = builtInThemes
        
        if let customThemes = loadCodable([UnifiedTheme].self, key: customThemesKey) {
            availableThemes.append(contentsOf: customThemes)
        }
        
        if let savedThemeId = loadCodable(String.self, key: themeKey),
           let savedTheme = availableThemes.first(where: { $0.id == savedThemeId }) {
            currentTheme = savedTheme
        }
    }
    
    private func loadSettings() {
        if let savedLanguage = loadCodable(String.self, key: languageKey),
           let language = Language(rawValue: savedLanguage) {
            currentLanguage = language
        }
        
        if let eyeCareSettings = loadCodable(EyeCareSettings.self, key: eyeCareKey) {
            isEyeCareEnabled = eyeCareSettings.isEnabled
            blueLightFilterLevel = eyeCareSettings.blueLightLevel
            warmLightLevel = eyeCareSettings.warmLightLevel
            contrastLevel = eyeCareSettings.contrastLevel
        }
    }
    
    func applyTheme(_ theme: UnifiedTheme) {
        currentTheme = theme
        saveCodable(theme.id, key: themeKey)
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
    
    func randomSkin() {
        let randomIndex = Int.random(in: 1..<availableThemes.count)
        let randomTheme = availableThemes[randomIndex]
        changeTheme(to: randomTheme.id)
    }
    
    func resetToDefault() {
        applyTheme(builtInThemes.first!)
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        saveCodable(language.rawValue, key: languageKey)
        objectWillChange.send()
    }
    
    func createCustomTheme(from baseTheme: UnifiedTheme, name: String, nameEn: String, primaryColor: String) -> UnifiedTheme {
        let customTheme = UnifiedTheme(
            id: UUID().uuidString,
            name: name,
            nameEn: nameEn,
            nameTw: nameEn,
            backgroundColor: baseTheme.backgroundColor,
            surfaceColor: baseTheme.surfaceColor,
            cardColor: baseTheme.cardColor,
            textColor: baseTheme.textColor,
            secondaryTextColor: baseTheme.secondaryTextColor,
            primaryColor: primaryColor,
            secondaryColor: baseTheme.secondaryColor,
            accentColor: baseTheme.accentColor,
            dividerColor: baseTheme.dividerColor,
            isDarkMode: baseTheme.isDarkMode,
            isBuiltIn: false,
            previewColors: [primaryColor, baseTheme.secondaryColor, baseTheme.accentColor, baseTheme.primaryColor]
        )
        
        var customThemes = loadCodable([UnifiedTheme].self, key: customThemesKey) ?? []
        customThemes.append(customTheme)
        saveCodable(customThemes, key: customThemesKey)
        
        availableThemes.append(customTheme)
        
        return customTheme
    }
    
    func deleteCustomTheme(_ theme: UnifiedTheme) {
        guard !theme.isBuiltIn else { return }
        
        var customThemes = loadCodable([UnifiedTheme].self, key: customThemesKey) ?? []
        customThemes.removeAll { $0.id == theme.id }
        saveCodable(customThemes, key: customThemesKey)
        
        availableThemes.removeAll { $0.id == theme.id }
        
        if currentTheme.id == theme.id {
            applyTheme(builtInThemes.first!)
        }
    }
    
    struct EyeCareSettings: Codable {
        var isEnabled: Bool
        var blueLightLevel: Double
        var warmLightLevel: Double
        var contrastLevel: Double
    }
    
    func enableEyeCare() {
        isEyeCareEnabled = true
        saveEyeCareSettings()
    }
    
    func disableEyeCare() {
        isEyeCareEnabled = false
        saveEyeCareSettings()
    }
    
    func toggleEyeCare() {
        isEyeCareEnabled.toggle()
        saveEyeCareSettings()
    }
    
    func setBlueLightFilter(_ level: Double) {
        blueLightFilterLevel = max(0, min(1, level))
        saveEyeCareSettings()
    }
    
    func setWarmLight(_ level: Double) {
        warmLightLevel = max(0, min(1, level))
        saveEyeCareSettings()
    }
    
    func setContrast(_ level: Double) {
        contrastLevel = max(0.8, min(1.5, level))
        saveEyeCareSettings()
    }
    
    private func saveEyeCareSettings() {
        let settings = EyeCareSettings(
            isEnabled: isEyeCareEnabled,
            blueLightLevel: blueLightFilterLevel,
            warmLightLevel: warmLightLevel,
            contrastLevel: contrastLevel
        )
        saveCodable(settings, key: eyeCareKey)
    }
    
    var effectiveBackgroundColor: Color {
        if !isEyeCareEnabled {
            return Color(hex: currentTheme.backgroundColor) ?? .white
        }
        let warmEffect = warmLightLevel * 0.3
        let blueReduction = blueLightFilterLevel * 0.2
        return Color(
            red: 1.0 - blueReduction * 0.3,
            green: 1.0 - blueReduction * 0.1,
            blue: warmEffect * 0.7
        )
    }
    
    var effectiveTextColor: Color {
        if !isEyeCareEnabled {
            return Color(hex: currentTheme.textColor) ?? .black
        }
        let warmEffect = warmLightLevel * 0.4
        return Color(
            red: 0.15 + warmEffect * 0.2,
            green: 0.12 + warmEffect * 0.15,
            blue: 0.1 + warmEffect * 0.05
        )
    }
    
    var effectivePrimaryColor: Color {
        return Color(hex: currentTheme.primaryColor) ?? .blue
    }
}

extension UnifiedThemeManager {
    var primaryColor: Color {
        effectivePrimaryColor
    }
    
    var backgroundColor: Color {
        effectiveBackgroundColor
    }
    
    var textColor: Color {
        effectiveTextColor
    }
    
    var accentColor: Color {
        Color(hex: currentTheme.accentColor) ?? .orange
    }
    
    var cardBackgroundColor: Color {
        Color(hex: currentTheme.cardColor) ?? .white
    }
    
    var surfaceColor: Color {
        Color(hex: currentTheme.surfaceColor) ?? .gray.opacity(0.1)
    }
}
