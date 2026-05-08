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
                name: "第一章格式",
                pattern: "^(第一章|第二章|第三章|第四章|第五章|第六章|第七章|第八章|第九章|第十章|第十一章|第十二章|第十三章|第十四章|第十五章|第十六章|第十七章|第十八章|第十九章|第二十章|[一二三四五六七八九十百千万\\d]+章)\\s*(.*)$",
                replacement: "$1 $2",
                priority: 99,
                ruleType: .chapter,
                description: "匹配中文数字章号"
            ),
            SegmentationRule(
                name: "卷名识别",
                pattern: "^【([^】]+)】\\s*(.*)$",
                replacement: "【$1】 $2",
                priority: 95,
                ruleType: .volume,
                description: "匹配【卷名】格式"
            ),
            SegmentationRule(
                name: "V1/V2卷标",
                pattern: "^\\[?V(olume)?\\s*(\\d+)\\]?\\s*[:\\-\\s]*(.*)$",
                replacement: "第$2卷 $3",
                priority: 94,
                ruleType: .volume,
                description: "匹配 V1, V2 或 Volume 1 格式"
            ),
            SegmentationRule(
                name: "卷部识别",
                pattern: "^(第?[卷部篇集篇部])\\s*([零一二三四五六七八九十百千万\\d]+)\\s*[:\\-\\s]*(.*)$",
                replacement: "$1$2 $3",
                priority: 92,
                ruleType: .volume,
                description: "匹配卷/部/篇/集编号"
            ),
            SegmentationRule(
                name: "章节编号",
                pattern: "^(第\\d+[章节篇集卷部])\\s*(.*)$",
                replacement: "$1 $2",
                priority: 90,
                ruleType: .chapter,
                description: "章节编号后添加空格"
            ),
            SegmentationRule(
                name: "第X回格式",
                pattern: "^第([零一二三四五六七八九十百千万\\d]+)回\\s*(.*)$",
                replacement: "第$1回 $2",
                priority: 88,
                ruleType: .chapter,
                description: "匹配「第X回」古典小说格式"
            ),
            SegmentationRule(
                name: "第X节格式",
                pattern: "^第(\\d+)节\\s*(.*)$",
                replacement: "第$1节 $2",
                priority: 86,
                ruleType: .section,
                description: "匹配「第X节」格式"
            ),
            SegmentationRule(
                name: "数字+章",
                pattern: "^(\\d+)\\s*[章节]\\s*(.*)$",
                replacement: "第$1章 $2",
                priority: 85,
                ruleType: .chapter,
                description: "纯数字+章节"
            ),
            SegmentationRule(
                name: "Chapter X格式",
                pattern: "^Chapter\\s*(\\d+)[\\.\\:\\s\\-]*(.*)$",
                replacement: "Chapter $1 $2",
                priority: 82,
                ruleType: .chapter,
                description: "匹配英文 Chapter 格式"
            ),
            SegmentationRule(
                name: "CH X格式",
                pattern: "^CH(?:apter)?\\.?\\s*(\\d+)[\\.\\:\\s\\-]*(.*)$",
                replacement: "CH $1 $2",
                priority: 80,
                ruleType: .chapter,
                description: "匹配 CH 或 CH. 格式"
            ),
            SegmentationRule(
                name: "数字编号.标题",
                pattern: "^(\\d+)\\.(\\d+)?\\s*[:\\-\\s]*(.*)$",
                replacement: "$1.$2 $3",
                priority: 78,
                ruleType: .chapter,
                description: "匹配 1.2 或 1 格式"
            ),
            SegmentationRule(
                name: "序章/楔子/尾声",
                pattern: "^(序章|楔子|前言|序言|尾声|后记|番外|外传|特别篇|附录|终章|破章|序幕|引子|开篇)\\s*[:\\-\\s]*(.*)$",
                replacement: "$1 $2",
                priority: 95,
                ruleType: .chapter,
                description: "匹配特殊章节名称"
            ),
            SegmentationRule(
                name: "上卷/下卷",
                pattern: "^(上卷|下卷|前卷|后卷|首卷|末卷)\\s*[:\\-\\s]*(.*)$",
                replacement: "$1 $2",
                priority: 88,
                ruleType: .volume,
                description: "匹配上卷/下卷格式"
            ),
            SegmentationRule(
                name: "第X部分",
                pattern: "^第([零一二三四五六七八九十百千万\\d]+)[部篇集]\\s*[:\\-\\s]*(.*)$",
                replacement: "第$1部 $2",
                priority: 87,
                ruleType: .volume,
                description: "匹配第X部分格式"
            ),
            SegmentationRule(
                name: "空格分隔章节",
                pattern: "^(第\\s*\\d+\\s*[章节回])[：:]?(.*)$",
                replacement: "$1 $2",
                priority: 70,
                ruleType: .chapter,
                description: "章节编号后添加分隔"
            ),
            SegmentationRule(
                name: "去除多余空格",
                pattern: "\\s+",
                replacement: " ",
                priority: 1,
                ruleType: .custom,
                description: "多个空格合并为一个"
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
            "第([零一二三四五六七八九十百千万\\d]+)回",
            "第([零一二三四五六七八九十百千万\\d]+)节",
            "第([\\d]+)[章节回节]",
            "第(\\d+)章",
            "(\\d+)(?=\\.\\s)",
            "Chapter\\s*(\\d+)",
            "CH(?:apter)?\\.?\\s*(\\d+)",
            "卷([零一二三四五六七八九十百千万\\d]+)",
            "V(?:olume)?\\s*(\\d+)",
            "上卷|下卷|前卷|后卷",
            "第一章|第二章|第三章|第四章|第五章|第六章|第七章|第八章|第九章|第十章|[一二三四五六七八九十]+章",
            "序章|楔子|尾声|后记|番外|外传|特别篇|终章|序幕|引子"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
                    if match.numberOfRanges > 1 {
                        let range = Range(match.range(at: 1), in: title)!
                        let numberStr = String(title[range])
                        return chineseToNumber(numberStr)
                    } else {
                        if pattern.contains("序章") || pattern.contains("楔子") {
                            return 0
                        } else if pattern.contains("尾声") || pattern.contains("后记") || pattern.contains("终章") {
                            return 9999
                        } else if pattern.contains("上卷") {
                            return 1
                        } else if pattern.contains("下卷") {
                            return 2
                        }
                    }
                }
            }
        }
        
        if let simpleNum = extractSimpleNumber(title) {
            return simpleNum
        }
        
        return nil
    }
    
    private func extractSimpleNumber(_ title: String) -> Int? {
        let pattern = "^(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            if let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
                if match.numberOfRanges > 1 {
                    let range = Range(match.range(at: 1), in: title)!
                    return Int(String(title[range]))
                }
            }
        }
        return nil
    }
    
    func isChapterTitle(_ line: String) -> Bool {
        let chapterIndicators = [
            "^第[零一二三四五六七八九十百千万\\d]+章",
            "^第[零一二三四五六七八九十百千万\\d]+回",
            "^第[\\d]+[章节回节]",
            "^Chapter\\s*\\d+",
            "^CH(?:apter)?\\.?\\s*\\d+",
            "^V(?:olume)?\\s*\\d+",
            "^\\d+\\.\\d+",
            "^\\d+\\s*[章节]",
            "^【[^】]+】",
            "^(序章|楔子|前言|序言|尾声|后记|番外|外传|特别篇|附录|终章|破章|序幕|引子|开篇)",
            "^(上卷|下卷|前卷|后卷|首卷|末卷)",
            "^第[零一二三四五六七八九十百千万\\d]+[部篇集]"
        ]
        
        for pattern in chapterIndicators {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    func classifyTitleType(_ title: String) -> TitleLevel {
        let titleWithoutSpaces = title.trimmingCharacters(in: .whitespaces)
        
        if titleWithoutSpaces.contains("【") && (titleWithoutSpaces.contains("卷") || titleWithoutSpaces.contains("部")) {
            return .volume
        }
        
        if titleWithoutSpaces.hasPrefix("第") && (titleWithoutSpaces.contains("章") || titleWithoutSpaces.contains("回")) {
            return .chapter
        }
        
        if let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\d+", options: []),
           regex.firstMatch(in: titleWithoutSpaces, options: [], range: NSRange(titleWithoutSpaces.startIndex..., in: titleWithoutSpaces)) != nil {
            return .section
        }
        
        if let regex = try? NSRegularExpression(pattern: "^\\d+\\.", options: []),
           regex.firstMatch(in: titleWithoutSpaces, options: [], range: NSRange(titleWithoutSpaces.startIndex..., in: titleWithoutSpaces)) != nil {
            return .subsection
        }
        
        let specialKeywords = ["序章", "楔子", "前言", "尾声", "后记", "番外", "外传", "开篇", "引子"]
        for keyword in specialKeywords {
            if titleWithoutSpaces.contains(keyword) {
                return .chapter
            }
        }
        
        return .normal
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
    
    struct ChapterMatch {
        var lineNumber: Int
        var title: String
        var formattedTitle: String
        var level: TitleLevel
        var chapterNumber: Int?
    }
    
    func parseTXTContent(_ content: String, minGapLines: Int = 2) -> [ChapterMatch] {
        var chapters: [ChapterMatch] = []
        let lines = content.components(separatedBy: .newlines)
        
        var lastChapterIndex = -minGapLines - 1
        var currentVolume: String?
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                continue
            }
            
            if index - lastChapterIndex < minGapLines {
                continue
            }
            
            if isChapterTitle(trimmedLine) {
                let level = classifyTitleType(trimmedLine)
                
                if level == .volume {
                    currentVolume = trimmedLine
                }
                
                let formattedTitle = formatTitle(trimmedLine)
                let chapterNumber = extractChapterNumber(trimmedLine)
                
                let chapter = ChapterMatch(
                    lineNumber: index,
                    title: trimmedLine,
                    formattedTitle: formattedTitle,
                    level: level,
                    chapterNumber: chapterNumber
                )
                
                chapters.append(chapter)
                lastChapterIndex = index
            }
        }
        
        if chapters.isEmpty && !lines.isEmpty {
            chapters.append(ChapterMatch(
                lineNumber: 0,
                title: "开始",
                formattedTitle: "开始",
                level: .chapter,
                chapterNumber: 1
            ))
        }
        
        return chapters
    }
    
    func estimateChapterCount(_ content: String) -> Int {
        let lines = content.components(separatedBy: .newlines)
        var count = 0
        var lastChapterIndex = -3
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty || index - lastChapterIndex < 2 {
                continue
            }
            
            if isChapterTitle(trimmedLine) {
                count += 1
                lastChapterIndex = index
            }
        }
        
        return max(count, 1)
    }
}
