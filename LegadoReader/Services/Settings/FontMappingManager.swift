import Foundation
import UIKit

class FontMappingManager: ObservableObject {
    static let shared = FontMappingManager()
    
    @Published var fontMappings: [FontMapping] = []
    @Published var defaultFont: String = "PingFang SC"
    @Published var enabled: Bool = true
    
    private let defaults = UserDefaults.standard
    private let fontMappingsKey = "FontMappingManager_mappings"
    private let defaultFontKey = "FontMappingManager_defaultFont"
    private let enabledKey = "FontMappingManager_enabled"
    
    private init() {
        loadSettings()
    }
    
    struct FontMapping: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var fontName: String
        var characterRanges: [CharacterRange]
        
        init(id: String = UUID().uuidString, name: String, fontName: String, characterRanges: [CharacterRange]) {
            self.id = id
            self.name = name
            self.fontName = fontName
            self.characterRanges = characterRanges
        }
        
        struct CharacterRange: Codable, Equatable {
            let start: String
            let end: String
            
            var isValid: Bool {
                return !start.isEmpty && !end.isEmpty && start.unicodeScalars.count == 1 && end.unicodeScalars.count == 1
            }
            
            func contains(_ char: Character) -> Bool {
                guard isValid,
                      let startScalar = start.unicodeScalars.first,
                      let endScalar = end.unicodeScalars.first,
                      let charScalar = char.unicodeScalars.first else {
                    return false
                }
                return charScalar.value >= startScalar.value && charScalar.value <= endScalar.value
            }
            
            var displayDescription: String {
                return "\(start) - \(end)"
            }
        }
    }
    
    private func loadSettings() {
        if let data = defaults.data(forKey: fontMappingsKey),
           let mappings = try? JSONDecoder().decode([FontMapping].self, from: data) {
            fontMappings = mappings
        } else {
            setupDefaultMappings()
        }
        
        defaultFont = defaults.string(forKey: defaultFontKey) ?? "PingFang SC"
        enabled = defaults.bool(forKey: enabledKey)
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(fontMappings) {
            defaults.set(data, forKey: fontMappingsKey)
        }
        defaults.set(defaultFont, forKey: defaultFontKey)
        defaults.set(enabled, forKey: enabledKey)
    }
    
    private func setupDefaultMappings() {
        fontMappings = [
            FontMapping(
                name: "中文",
                fontName: "PingFang SC",
                characterRanges: [
                    FontMapping.CharacterRange(start: "\u{4E00}", end: "\u{9FFF}"),
                    FontMapping.CharacterRange(start: "\u{3400}", end: "\u{4DBF}"),
                    FontMapping.CharacterRange(start: "\u{F900}", end: "\u{FAFF}")
                ]
            ),
            FontMapping(
                name: "英文",
                fontName: "SF Pro Display",
                characterRanges: [
                    FontMapping.CharacterRange(start: "A", end: "Z"),
                    FontMapping.CharacterRange(start: "a", end: "z")
                ]
            ),
            FontMapping(
                name: "数字",
                fontName: "SF Mono",
                characterRanges: [
                    FontMapping.CharacterRange(start: "0", end: "9")
                ]
            ),
            FontMapping(
                name: "日文假名",
                fontName: "Hiragino Sans",
                characterRanges: [
                    FontMapping.CharacterRange(start: "\u{3040}", end: "\u{30FF}")
                ]
            ),
            FontMapping(
                name: "韩文",
                fontName: "Apple SD Gothic Neo",
                characterRanges: [
                    FontMapping.CharacterRange(start: "\u{AC00}", end: "\u{D7AF}")
                ]
            )
        ]
        saveSettings()
    }
    
    func addMapping(_ mapping: FontMapping) {
        fontMappings.append(mapping)
        saveSettings()
    }
    
    func updateMapping(_ mapping: FontMapping) {
        if let index = fontMappings.firstIndex(where: { $0.id == mapping.id }) {
            fontMappings[index] = mapping
            saveSettings()
        }
    }
    
    func removeMapping(_ mapping: FontMapping) {
        fontMappings.removeAll { $0.id == mapping.id }
        saveSettings()
    }
    
    func setDefaultFont(_ fontName: String) {
        defaultFont = fontName
        saveSettings()
    }
    
    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        saveSettings()
    }
    
    func getFontName(for char: Character) -> String {
        guard enabled else { return defaultFont }
        
        for mapping in fontMappings {
            for range in mapping.characterRanges {
                if range.contains(char) {
                    return mapping.fontName
                }
            }
        }
        
        return defaultFont
    }
    
    func getFont(for char: Character, size: CGFloat) -> UIFont {
        let fontName = getFontName(for: char)
        return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size)
    }
    
    func getAttributedString(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        var currentFontName = ""
        var rangeStart = 0
        
        for (index, char) in text.enumerated() {
            let fontName = getFontName(for: char)
            
            if fontName != currentFontName {
                if rangeStart < index {
                    let range = NSRange(location: rangeStart, length: index - rangeStart)
                    let font = UIFont(name: currentFontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
                    attributedString.addAttribute(.font, value: font, range: range)
                }
                currentFontName = fontName
                rangeStart = index
            }
        }
        
        if rangeStart < text.count {
            let range = NSRange(location: rangeStart, length: text.count - rangeStart)
            let font = UIFont(name: currentFontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            attributedString.addAttribute(.font, value: font, range: range)
        }
        
        return attributedString
    }
    
    func getAllAvailableFonts() -> [String] {
        var fontNames: [String] = []
        
        for family in UIFont.familyNames {
            for font in UIFont.fontNames(forFamilyName: family) {
                fontNames.append(font)
            }
        }
        
        return fontNames.sorted()
    }
    
    func getFontFamilyName(_ fontName: String) -> String {
        for family in UIFont.familyNames {
            if UIFont.fontNames(forFamilyName: family).contains(fontName) {
                return family
            }
        }
        return fontName
    }
}

extension FontMappingManager {
    func validateMapping(_ mapping: FontMapping) -> String? {
        if mapping.name.isEmpty {
            return "映射名称不能为空"
        }
        
        if mapping.fontName.isEmpty {
            return "请选择字体"
        }
        
        if mapping.characterRanges.isEmpty {
            return "请至少添加一个字符范围"
        }
        
        for range in mapping.characterRanges {
            if !range.isValid {
                return "字符范围格式不正确"
            }
        }
        
        return nil
    }
    
    func duplicateMapping(_ mapping: FontMapping) -> FontMapping {
        return FontMapping(
            name: "\(mapping.name) (副本)",
            fontName: mapping.fontName,
            characterRanges: mapping.characterRanges
        )
    }
}