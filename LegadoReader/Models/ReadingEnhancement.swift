import Foundation

struct TitleFormatter {
    static func format(_ title: String) -> String {
        var formatted = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        formatted = removeChapterPrefixes(formatted)
        formatted = cleanExtraSpaces(formatted)
        formatted = normalizeNumbers(formatted)
        
        return formatted
    }
    
    private static func removeChapterPrefixes(_ title: String) -> String {
        let prefixes = [
            "^第[一二三四五六七八九十百千万\\d]+[章节篇集卷部部\\s]+",
            "^[一二三四五六七八九十百千万\\d]+[\\.、\\:\\s]+",
            "^Chapter\\s*\\d+[\\.\\:\\s]*",
            "^CHAPTER\\s*\\d+[\\.\\:\\s]*",
            "^第\\d+[章节篇集卷部]\\s*",
            "^\\[第\\d+章\\]",
            "^\\(\\d+\\)",
            "^\\d+\\.\\s*"
        ]
        
        var result = title
        for pattern in prefixes {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func cleanExtraSpaces(_ text: String) -> String {
        var result = text
        
        if let regex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func normalizeNumbers(_ text: String) -> String {
        let chineseToArabic: [Character: Character] = [
            "零": "0", "一": "1", "二": "2", "三": "3", "四": "4",
            "五": "5", "六": "6", "七": "7", "八": "8", "九": "9", "十": "10"
        ]
        
        var result = text
        
        for (chinese, arabic) in chineseToArabic {
            result = result.replacingOccurrences(of: String(chinese), with: String(arabic))
        }
        
        return result
    }
    
    static func extractChapterNumber(_ title: String) -> Int? {
        let patterns = [
            "第\\d+章",
            "\\d+(?=\\.\\s)",
            "Chapter\\s*(\\d+)",
            "第([一二三四五六七八九十百千万\\d]+)章"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
                    if match.numberOfRanges > 1 {
                        let range = Range(match.range(at: 1), in: title)!
                        let numberStr = String(title[range])
                        return Int(numberStr)
                    }
                }
            }
        }
        
        return nil
    }
    
    static func detectTitleLevel(_ title: String) -> TitleLevel {
        if title.hasPrefix("第") && (title.contains("卷") || title.contains("部")) {
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
    
    enum TitleLevel: Int {
        case volume = 0
        case chapter = 1
        case section = 2
        case subsection = 3
        case normal = 4
        
        var displayPrefix: String {
            switch self {
            case .volume: return "【卷】"
            case .chapter: return ""
            case .section: return "§ "
            case .subsection: return ""
            case .normal: return ""
            }
        }
    }
}

struct BookmarkNote: Identifiable, Codable, Equatable {
    var id: String
    var bookmarkId: String
    var content: String
    var createdTime: Date
    var updatedTime: Date
    var tags: [String]
    var highlightColor: HighlightColor
    var pageNumber: Int?
    var lineNumber: Int?
    var chapterTitle: String?
    
    init(id: String = UUID().uuidString,
         bookmarkId: String,
         content: String) {
        self.id = id
        self.bookmarkId = bookmarkId
        self.content = content
        self.createdTime = Date()
        self.updatedTime = Date()
        self.tags = []
        self.highlightColor = .yellow
        self.pageNumber = nil
        self.lineNumber = nil
        self.chapterTitle = nil
    }
    
    var contentPreview: String {
        if content.count > 50 {
            return String(content.prefix(50)) + "..."
        }
        return content
    }
}

enum HighlightColor: String, Codable, CaseIterable {
    case yellow
    case green
    case blue
    case pink
    case orange
    
    var color: String {
        switch self {
        case .yellow: return "#FFEB3B"
        case .green: return "#4CAF50"
        case .blue: return "#2196F3"
        case .pink: return "#E91E63"
        case .orange: return "#FF9800"
        }
    }
}

class BookmarkNoteManager: BaseService, ObservableObject {
    static let shared = BookmarkNoteManager()
    
    @Published var notes: [BookmarkNote] = []
    
    private let storageKey = "BookmarkNoteManager_notes"
    
    private init() {
        super.init()
        loadNotes()
    }
    
    func addNote(bookmarkId: String, content: String) -> BookmarkNote {
        let note = BookmarkNote(bookmarkId: bookmarkId, content: content)
        notes.append(note)
        saveNotes()
        return note
    }
    
    func updateNote(_ note: BookmarkNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updated = note
            updated.updatedTime = Date()
            notes[index] = updated
            saveNotes()
        }
    }
    
    func deleteNote(_ note: BookmarkNote) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }
    
    func getNotes(for bookmarkId: String) -> [BookmarkNote] {
        return notes.filter { $0.bookmarkId == bookmarkId }
    }
    
    func addTag(_ tag: String, to noteId: String) {
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            if !notes[index].tags.contains(tag) {
                notes[index].tags.append(tag)
                notes[index].updatedTime = Date()
                saveNotes()
            }
        }
    }
    
    func removeTag(_ tag: String, from noteId: String) {
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            notes[index].tags.removeAll { $0 == tag }
            notes[index].updatedTime = Date()
            saveNotes()
        }
    }
    
    func setHighlightColor(_ color: HighlightColor, for noteId: String) {
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            notes[index].highlightColor = color
            notes[index].updatedTime = Date()
            saveNotes()
        }
    }
    
    private func saveNotes() {
        saveCodable(notes, key: storageKey)
    }
    
    private func loadNotes() {
        if let saved = loadCodable([BookmarkNote].self, key: storageKey) {
            notes = saved
        }
    }
}

struct ReadingPosition: Identifiable, Codable {
    var id: String
    var bookId: String
    var chapterIndex: Int
    var scrollOffset: CGFloat
    var pageIndex: Int
    var timestamp: Date
    
    init(bookId: String, chapterIndex: Int, scrollOffset: CGFloat = 0, pageIndex: Int = 0) {
        self.id = UUID().uuidString
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.scrollOffset = scrollOffset
        self.pageIndex = pageIndex
        self.timestamp = Date()
    }
}

class ReadingHistoryManager: BaseService, ObservableObject {
    static let shared = ReadingHistoryManager()
    
    @Published var positions: [ReadingPosition] = []
    @Published var readingStreak: Int = 0
    @Published var totalReadingDays: Int = 0
    
    private let positionsKey = "ReadingHistoryManager_positions"
    private let statsKey = "ReadingHistoryManager_stats"
    
    private init() {
        super.init()
        loadPositions()
        loadStats()
    }
    
    func savePosition(bookId: String, chapterIndex: Int, scrollOffset: CGFloat = 0, pageIndex: Int = 0) {
        if let index = positions.firstIndex(where: { $0.bookId == bookId }) {
            positions[index].chapterIndex = chapterIndex
            positions[index].scrollOffset = scrollOffset
            positions[index].pageIndex = pageIndex
            positions[index].timestamp = Date()
        } else {
            let position = ReadingPosition(bookId: bookId, chapterIndex: chapterIndex, scrollOffset: scrollOffset, pageIndex: pageIndex)
            positions.append(position)
        }
        savePositions()
    }
    
    func getPosition(for bookId: String) -> ReadingPosition? {
        return positions.first { $0.bookId == bookId }
    }
    
    func getRecentBooks(limit: Int = 10) -> [ReadingPosition] {
        return positions.sorted { $0.timestamp > $1.timestamp }.prefix(limit).map { $0 }
    }
    
    func getReadingStreak() -> Int {
        var streak = 0
        var checkDate = Date()
        
        while true {
            let dateStr = formatDate(checkDate)
            let hasReading = positions.contains { formatDate($0.timestamp) == dateStr }
            
            if hasReading {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func savePositions() {
        saveCodable(positions, key: positionsKey)
    }
    
    private func loadPositions() {
        if let saved = loadCodable([ReadingPosition].self, key: positionsKey) {
            positions = saved
        }
    }
    
    private func loadStats() {
        if let saved = loadCodable(ReadingStats.self, key: statsKey) {
            readingStreak = saved.readingStreak
            totalReadingDays = saved.totalReadingDays
        }
    }
    
    private func saveStats() {
        let stats = ReadingStats(readingStreak: readingStreak, totalReadingDays: totalReadingDays)
        saveCodable(stats, key: statsKey)
    }
}

struct ReadingStats: Codable {
    var readingStreak: Int
    var totalReadingDays: Int
}
