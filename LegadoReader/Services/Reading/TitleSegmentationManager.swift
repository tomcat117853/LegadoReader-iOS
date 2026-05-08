import Foundation
import Combine

class TitleSegmentationManager: BaseService, ObservableObject {
    static let shared = TitleSegmentationManager()
    
    @Published var customRules: [SegmentationRule] = []
    @Published var enabledRules: Set<String> = []
    @Published var lastSegmentationResult: SegmentationResult?
    
    private let rulesKey = "TitleSegmentationManager_rules"
    private let enabledKey = "TitleSegmentationManager_enabled"
    
    struct SegmentationRule: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var pattern: String
        var replacement: String
        var priority: Int
        var isEnabled: Bool
        var ruleType: RuleType
        var description: String
        
        enum RuleType: String, Codable, CaseIterable {
            case volume = "volume"
            case chapter = "chapter"
            case section = "section"
            case custom = "custom"
            
            var displayName: String {
                switch self {
                case .volume: return "分卷"
                case .chapter: return "章节"
                case .section: return "小节"
                case .custom: return "自定义"
                }
            }
            
            var icon: String {
                switch self {
                case .volume: return "books.vertical"
                case .chapter: return "book"
                case .section: return "text.badge.checkmark"
                case .custom: return "slider.horizontal.3"
                }
            }
        }
        
        init(id: String = UUID().uuidString,
             name: String,
             pattern: String,
             replacement: String = "",
             priority: Int = 0,
             isEnabled: Bool = true,
             ruleType: RuleType = .custom,
             description: String = "") {
            self.id = id
            self.name = name
            self.pattern = pattern
            self.replacement = replacement
            self.priority = priority
            self.isEnabled = isEnabled
            self.ruleType = ruleType
            self.description = description
        }
    }
    
    struct SegmentationResult {
        var originalTitle: String
        var formattedTitle: String
        var segments: [TitleSegment]
        var level: TitleLevel
        
        struct TitleSegment {
            var text: String
            var type: SegmentType
            var range: Range<String.Index>?
            
            enum SegmentType: String {
                case number = "number"
                case prefix = "prefix"
                case mainTitle = "mainTitle"
                case suffix = "suffix"
                case volume = "volume"
                case chapter = "chapter"
            }
        }
    }
    
    enum TitleLevel: Int, Comparable {
        case volume = 0
        case chapter = 1
        case section = 2
        case subsection = 3
        case normal = 4
        
        static func < (lhs: TitleLevel, rhs: TitleLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        var displayName: String {
            switch self {
            case .volume: return "卷"
            case .chapter: return "章"
            case .section: return "节"
            case .subsection: return "小节"
            case .normal: return "普通"
            }
        }
    }
    
    private override init() {
        super.init()
        loadRules()
        loadEnabledRules()
    }
    
    private func loadRules() {
        if let saved = loadCodable([SegmentationRule].self, key: rulesKey) {
            customRules = saved
        } else {
            customRules = defaultRules
            saveRules()
        }
    }
    
    private func saveRules() {
        saveCodable(customRules, key: rulesKey)
    }
    
    private func loadEnabledRules() {
        if let saved = loadCodable(Set<String>.self, key: enabledKey) {
            enabledRules = saved
        } else {
            enabledRules = Set(customRules.filter { $0.isEnabled }.map { $0.id })
            saveEnabledRules()
        }
    }
    
    private func saveEnabledRules() {
        saveCodable(enabledRules, key: enabledKey)
    }
    
    private var defaultRules: [SegmentationRule] {
        [
            SegmentationRule(
                name: "第X章格式",
                pattern: "^第([零一二三四五六七八九十百千万\\d]+)章\\s*(.*)$",
                replacement: "第$1章 $2",
                priority: 100,
                ruleType: .chapter,
                description: "匹配「第X章」格式"
            ),
            SegmentationRule(
                name: "卷名识别",
                pattern: "^【([^】]+)】\\s*(.*)$",
                replacement: "【$1】 $2",
                priority: 90,
                ruleType: .volume,
                description: "匹配【卷名】格式"
            ),
            SegmentationRule(
                name: "章节编号",
                pattern: "^(第\\d+[章节篇集卷部])\\s*(.*)$",
                replacement: "$1 $2",
                priority: 80,
                ruleType: .chapter,
                description: "章节编号后添加空格"
            ),
            SegmentationRule(
                name: "去除多余空格",
                pattern: "\\s+",
                replacement: " ",
                priority: 1,
                ruleType: .custom,
                description: "多个空格合并为一个"
            ),
            SegmentationRule(
                name: "卷部识别",
                pattern: "^(卷|部|篇|集)\\s*([零一二三四五六七八九十百千万\\d]+)$",
                replacement: "$1$2",
                priority: 85,
                ruleType: .volume,
                description: "匹配卷/部/篇/集编号"
            ),
            SegmentationRule(
                name: "小节识别",
                pattern: "^第\\d+节\\s*(.*)$",
                replacement: "$1",
                priority: 75,
                ruleType: .section,
                description: "匹配「第X节」格式"
            ),
            SegmentationRule(
                name: "数字章号",
                pattern: "^Chapter\\s*(\\d+)[\\.\\:\\s]*(.*)$",
                replacement: "第$1章 $2",
                priority: 70,
                ruleType: .chapter,
                description: "匹配英文 Chapter 格式"
            )
        ]
    }
    
    func addRule(_ rule: SegmentationRule) {
        customRules.append(rule)
        if rule.isEnabled {
            enabledRules.insert(rule.id)
        }
        saveRules()
        saveEnabledRules()
    }
    
    func updateRule(_ rule: SegmentationRule) {
        if let index = customRules.firstIndex(where: { $0.id == rule.id }) {
            customRules[index] = rule
            if rule.isEnabled {
                enabledRules.insert(rule.id)
            } else {
                enabledRules.remove(rule.id)
            }
            saveRules()
            saveEnabledRules()
        }
    }
    
    func deleteRule(_ rule: SegmentationRule) {
        customRules.removeAll { $0.id == rule.id }
        enabledRules.remove(rule.id)
        saveRules()
        saveEnabledRules()
    }
    
    func toggleRule(_ ruleId: String) {
        if enabledRules.contains(ruleId) {
            enabledRules.remove(ruleId)
        } else {
            enabledRules.insert(ruleId)
        }
        if let index = customRules.firstIndex(where: { $0.id == ruleId }) {
            customRules[index].isEnabled = enabledRules.contains(ruleId)
        }
        saveRules()
        saveEnabledRules()
    }
    
    func isRuleEnabled(_ ruleId: String) -> Bool {
        return enabledRules.contains(ruleId)
    }
    
    func segmentTitle(_ title: String) -> SegmentationResult {
        let enabledCustomRules = customRules
            .filter { enabledRules.contains($0.id) }
            .sorted { $0.priority > $1.priority }
        
        var currentTitle = title
        var segments: [SegmentationResult.TitleSegment] = []
        
        for rule in enabledCustomRules {
            if let regex = try? NSRegularExpression(pattern: rule.pattern, options: .caseInsensitive) {
                let range = NSRange(currentTitle.startIndex..., in: currentTitle)
                
                if rule.replacement.isEmpty {
                    if let match = regex.firstMatch(in: currentTitle, options: [], range: range) {
                        var segmentType: SegmentationResult.TitleSegment.SegmentType
                        switch rule.ruleType {
                        case .volume:
                            segmentType = .volume
                        case .chapter:
                            segmentType = .chapter
                        case .section:
                            segmentType = .suffix
                        case .custom:
                            segmentType = .prefix
                        }
                        
                        if let matchRange = Range(match.range, in: currentTitle) {
                            segments.append(SegmentationResult.TitleSegment(
                                text: String(currentTitle[matchRange]),
                                type: segmentType,
                                range: matchRange
                            ))
                        }
                    }
                } else {
                    currentTitle = regex.stringByReplacingMatches(
                        in: currentTitle,
                        options: [],
                        range: range,
                        withTemplate: rule.replacement
                    )
                }
            }
        }
        
        currentTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let level = detectTitleLevel(currentTitle)
        
        let result = SegmentationResult(
            originalTitle: title,
            formattedTitle: currentTitle,
            segments: segments,
            level: level
        )
        
        lastSegmentationResult = result
        return result
    }
    
    func formatTitle(_ title: String) -> String {
        return segmentTitle(title).formattedTitle
    }
    
    private func detectTitleLevel(_ title: String) -> TitleLevel {
        if title.contains("【") && (title.contains("卷") || title.contains("部")) {
            return .volume
        }
        
        if title.hasPrefix("第") && title.contains("章") {
            return .chapter
        }
        
        if let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\d+", options: []),
           regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) != nil {
            return .section
        }
        
        if let regex = try? NSRegularExpression(pattern: "^\\d+\\.", options: []),
           regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) != nil {
            return .subsection
        }
        
        return .normal
    }
    
    func extractChapterNumber(_ title: String) -> Int? {
        let patterns = [
            "第([零一二三四五六七八九十百千万\\d]+)章",
            "第(\\d+)章",
            "(\\d+)(?=\\.\\s)",
            "Chapter\\s*(\\d+)",
            "卷([零一二三四五六七八九十百千万\\d]+)",
            "第(\\d+)节"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
                    if match.numberOfRanges > 1 {
                        let range = Range(match.range(at: 1), in: title)!
                        let numberStr = String(title[range])
                        return chineseToNumber(numberStr)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func chineseToNumber(_ str: String) -> Int? {
        let chineseMap: [Character: Int] = [
            "零": 0, "一": 1, "二": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
            "百": 100, "千": 1000, "万": 10000
        ]
        
        var result = 0
        var temp = 0
        
        for char in str {
            if let value = chineseMap[char] {
                if value >= 100 {
                    temp = temp == 0 ? value : temp * value
                    result += temp
                    temp = 0
                } else {
                    temp += value
                }
            } else if let digit = Int(String(char)) {
                temp = temp == 0 ? digit : temp * 10 + digit
            }
        }
        
        result += temp
        return result == 0 && temp == 0 ? nil : result
    }
    
    func resetToDefaults() {
        customRules = defaultRules
        enabledRules = Set(defaultRules.filter { $0.isEnabled }.map { $0.id })
        saveRules()
        saveEnabledRules()
    }
    
    func getRules(for type: SegmentationRule.RuleType) -> [SegmentationRule] {
        return customRules.filter { $0.ruleType == type }
    }
    
    func exportRules() -> Data? {
        return encodeJSON(customRules)
    }
    
    func importRules(from data: Data) -> Bool {
        guard let imported = decodeJSON([SegmentationRule].self, from: data) else {
            return false
        }
        
        for rule in imported {
            if !customRules.contains(where: { $0.id == rule.id }) {
                customRules.append(rule)
                if rule.isEnabled {
                    enabledRules.insert(rule.id)
                }
            }
        }
        
        saveRules()
        saveEnabledRules()
        return true
    }
}
