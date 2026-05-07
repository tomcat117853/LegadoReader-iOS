import Foundation
import Combine

class UnderlineManager: BaseDataManager<UnderlineManager.Underline> {
    static let shared = UnderlineManager()
    
    @Published var currentUnderlineStyle: UnderlineStyle = .single
    @Published var underlineColor: UnderlineColor = .blue
    
    private init() {
        super.init(dataKey: "UnderlineManager_underlines")
        loadSettings()
    }
    
    struct Underline: Identifiable, Codable, Equatable {
        let id: String
        let bookId: String
        let chapterId: String
        let startOffset: Int
        let endOffset: Int
        let text: String
        var style: UnderlineStyle
        var color: UnderlineColor
        let createdTime: Date
        var note: String
        
        enum UnderlineStyle: String, Codable, CaseIterable {
            case single = "single"
            case double = "double"
            case thick = "thick"
            case dotted = "dotted"
            case wavy = "wavy"
            
            var displayName: String {
                switch self {
                case .single: return "单下划线"
                case .double: return "双下划线"
                case .thick: return "粗下划线"
                case .dotted: return "点线下划线"
                case .wavy: return "波浪下划线"
                }
            }
            
            var cssValue: String {
                switch self {
                case .single: return "underline"
                case .double: return "double"
                case .thick: return "underline thick"
                case .dotted: return "dotted"
                case .wavy: return "wavy"
                }
            }
        }
        
        enum UnderlineColor: String, Codable, CaseIterable {
            case red = "red"
            case orange = "orange"
            case yellow = "yellow"
            case green = "green"
            case blue = "blue"
            case purple = "purple"
            case pink = "pink"
            
            var displayName: String {
                switch self {
                case .red: return "红色"
                case .orange: return "橙色"
                case .yellow: return "黄色"
                case .green: return "绿色"
                case .blue: return "蓝色"
                case .purple: return "紫色"
                case .pink: return "粉色"
                }
            }
            
            var hexColor: String {
                switch self {
                case .red: return "#FF3B30"
                case .orange: return "#FF9500"
                case .yellow: return "#FFCC00"
                case .green: return "#34C759"
                case .blue: return "#007AFF"
                case .purple: return "#AF52DE"
                case .pink: return "#FF2D55"
                }
            }
        }
    }
    
    private func loadSettings() {
        if let styleStr = storageManager.string(forKey: "UnderlineManager_style"),
           let style = Underline.UnderlineStyle(rawValue: styleStr) {
            currentUnderlineStyle = style
        }
        
        if let colorStr = storageManager.string(forKey: "UnderlineManager_color"),
           let color = Underline.UnderlineColor(rawValue: colorStr) {
            underlineColor = color
        }
    }
    
    private func saveSettings() {
        storageManager.set(currentUnderlineStyle.rawValue, forKey: "UnderlineManager_style")
        storageManager.set(underlineColor.rawValue, forKey: "UnderlineManager_color")
    }
    
    func addUnderline(bookId: String, chapterId: String, startOffset: Int, endOffset: Int, text: String) {
        let underline = Underline(
            id: UUID().uuidString,
            bookId: bookId,
            chapterId: chapterId,
            startOffset: startOffset,
            endOffset: endOffset,
            text: text,
            style: currentUnderlineStyle,
            color: underlineColor,
            createdTime: Date(),
            note: ""
        )
        
        items.insert(underline, at: 0)
        saveData()
    }
    
    func updateUnderlineStyle(_ underline: Underline, style: Underline.UnderlineStyle) {
        if let index = items.firstIndex(where: { $0.id == underline.id }) {
            var updated = items[index]
            updated.style = style
            items[index] = updated
            saveData()
        }
    }
    
    func updateUnderlineColor(_ underline: Underline, color: Underline.UnderlineColor) {
        if let index = items.firstIndex(where: { $0.id == underline.id }) {
            var updated = items[index]
            updated.color = color
            items[index] = updated
            saveData()
        }
    }
    
    func updateUnderlineNote(_ underline: Underline, note: String) {
        if let index = items.firstIndex(where: { $0.id == underline.id }) {
            var updated = items[index]
            updated.note = note
            items[index] = updated
            saveData()
        }
    }
    
    func getUnderlines(for bookId: String) -> [Underline] {
        return items.filter { $0.bookId == bookId }
    }
    
    func getUnderlines(for bookId: String, chapterId: String) -> [Underline] {
        return items.filter { $0.bookId == bookId && $0.chapterId == chapterId }
    }
    
    func getUnderline(at offset: Int, in chapterId: String) -> Underline? {
        return items.first { underline in
            underline.chapterId == chapterId &&
            offset >= underline.startOffset &&
            offset <= underline.endOffset
        }
    }
    
    func removeAllUnderlines(for bookId: String) {
        items.removeAll { $0.bookId == bookId }
        saveData()
    }
    
    func removeAllUnderlines(for bookId: String, chapterId: String) {
        items.removeAll { $0.bookId == bookId && $0.chapterId == chapterId }
        saveData()
    }
    
    func setCurrentStyle(_ style: Underline.UnderlineStyle) {
        currentUnderlineStyle = style
        saveSettings()
    }
    
    func setCurrentColor(_ color: Underline.UnderlineColor) {
        underlineColor = color
        saveSettings()
    }
    
    func searchUnderlines(keyword: String) -> [Underline] {
        guard !keyword.isEmpty else { return items }
        
        return items.filter { underline in
            underline.text.contains(keyword) ||
            underline.note.contains(keyword)
        }
    }
    
    func getRecentUnderlines(limit: Int = 20) -> [Underline] {
        return Array(items.prefix(limit))
    }
    
    func importUnderlines(from data: Data) -> Bool {
        guard let imported = decodeJSON([Underline].self, from: data) else {
            return false
        }
        
        var merged = items
        
        for item in imported {
            if !merged.contains(where: { $0.id == item.id }) {
                merged.append(item)
            }
        }
        
        items = merged
        saveData()
        return true
    }
}

extension UnderlineManager {
    func getUnderlineStatistics() -> UnderlineStatistics {
        let totalUnderlines = items.count
        let booksWithUnderlines = Set(items.map { $0.bookId }).count
        let chaptersWithUnderlines = Set(items.map { "\($0.bookId)_\($0.chapterId)" }).count
        
        let todayUnderlines = items.filter {
            Calendar.current.isDate($0.createdTime, inSameDayAs: Date())
        }.count
        
        return UnderlineStatistics(
            totalUnderlines: totalUnderlines,
            booksWithUnderlines: booksWithUnderlines,
            chaptersWithUnderlines: chaptersWithUnderlines,
            todayUnderlines: todayUnderlines
        )
    }
    
    struct UnderlineStatistics {
        let totalUnderlines: Int
        let booksWithUnderlines: Int
        let chaptersWithUnderlines: Int
        let todayUnderlines: Int
    }
}
