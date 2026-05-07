import Foundation
import Combine

class BookmarkManager: BaseDataManager<BookmarkManager.Bookmark> {
    static let shared = BookmarkManager()
    
    private init() {
        super.init(dataKey: "BookmarkManager_bookmarks")
    }
    
    struct Bookmark: Identifiable, Codable, Equatable {
        let id: String
        let bookId: String
        let bookName: String
        let chapterId: String
        let chapterTitle: String
        var position: Int
        var content: String
        var note: String
        let createdTime: Date
        var updatedTime: Date
        var color: BookmarkColor
        
        enum BookmarkColor: String, Codable, CaseIterable {
            case red = "red"
            case orange = "orange"
            case yellow = "yellow"
            case green = "green"
            case blue = "blue"
            case purple = "purple"
            
            var displayName: String {
                switch self {
                case .red: return "红色"
                case .orange: return "橙色"
                case .yellow: return "黄色"
                case .green: return "绿色"
                case .blue: return "蓝色"
                case .purple: return "紫色"
                }
            }
            
            var colorValue: String {
                switch self {
                case .red: return "#FF3B30"
                case .orange: return "#FF9500"
                case .yellow: return "#FFCC00"
                case .green: return "#34C759"
                case .blue: return "#007AFF"
                case .purple: return "#AF52DE"
                }
            }
        }
    }
    
    func addBookmark(bookId: String, bookName: String, chapterId: String, chapterTitle: String, position: Int, content: String, note: String = "", color: Bookmark.BookmarkColor = .blue) {
        let bookmark = Bookmark(
            id: UUID().uuidString,
            bookId: bookId,
            bookName: bookName,
            chapterId: chapterId,
            chapterTitle: chapterTitle,
            position: position,
            content: content,
            note: note,
            createdTime: Date(),
            updatedTime: Date(),
            color: color
        )
        
        items.insert(bookmark, at: 0)
        saveData()
    }
    
    func updateBookmark(_ bookmark: Bookmark) {
        if let index = items.firstIndex(where: { $0.id == bookmark.id }) {
            var updatedBookmark = bookmark
            updatedBookmark.updatedTime = Date()
            items[index] = updatedBookmark
            saveData()
        }
    }
    
    func updateNote(id: String, note: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].note = note
            items[index].updatedTime = Date()
            saveData()
        }
    }
    
    func updateColor(id: String, color: Bookmark.BookmarkColor) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].color = color
            items[index].updatedTime = Date()
            saveData()
        }
    }
    
    func getBookmarks(for bookId: String) -> [Bookmark] {
        return items.filter { $0.bookId == bookId }
    }
    
    func getBookmarks(for bookId: String, chapterId: String) -> [Bookmark] {
        return items.filter { $0.bookId == bookId && $0.chapterId == chapterId }
    }
    
    func hasBookmark(bookId: String, chapterId: String, position: Int, range: Int = 50) -> Bool {
        return items.contains { bookmark in
            bookmark.bookId == bookId &&
            bookmark.chapterId == chapterId &&
            abs(bookmark.position - position) < range
        }
    }
    
    func removeAllBookmarks(for bookId: String) {
        items.removeAll { $0.bookId == bookId }
        saveData()
    }
    
    func getRecentBookmarks(limit: Int = 10) -> [Bookmark] {
        return Array(items.prefix(limit))
    }
    
    func searchBookmarks(keyword: String) -> [Bookmark] {
        guard !keyword.isEmpty else { return items }
        
        return items.filter { bookmark in
            bookmark.bookName.contains(keyword) ||
            bookmark.chapterTitle.contains(keyword) ||
            bookmark.content.contains(keyword) ||
            bookmark.note.contains(keyword)
        }
    }
    
    func importBookmarks(from data: Data) -> Bool {
        guard let importedBookmarks = decodeJSON([Bookmark].self, from: data) else {
            return false
        }
        
        var mergedBookmarks = items
        
        for imported in importedBookmarks {
            if !mergedBookmarks.contains(where: { $0.id == imported.id }) {
                mergedBookmarks.append(imported)
            }
        }
        
        mergedBookmarks.sort { $0.createdTime > $1.createdTime }
        
        items = mergedBookmarks
        saveData()
        
        return true
    }
}

extension BookmarkManager {
    func getBookmarkStatistics() -> BookmarkStatistics {
        let totalBookmarks = items.count
        let booksWithBookmarks = Set(items.map { $0.bookId }).count
        let chaptersWithBookmarks = Set(items.map { "\($0.bookId)_\($0.chapterId)" }).count
        
        let bookmarksWithNotes = items.filter { !$0.note.isEmpty }.count
        let recentBookmarks = items.filter {
            Calendar.current.isDate($0.createdTime, inSameDayAs: Date())
        }.count
        
        return BookmarkStatistics(
            totalBookmarks: totalBookmarks,
            booksWithBookmarks: booksWithBookmarks,
            chaptersWithBookmarks: chaptersWithBookmarks,
            bookmarksWithNotes: bookmarksWithNotes,
            todayBookmarks: recentBookmarks
        )
    }
    
    struct BookmarkStatistics {
        let totalBookmarks: Int
        let booksWithBookmarks: Int
        let chaptersWithBookmarks: Int
        let bookmarksWithNotes: Int
        let todayBookmarks: Int
    }
}
