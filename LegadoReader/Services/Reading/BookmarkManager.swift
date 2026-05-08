import Foundation
import Combine

class BookmarkManager: BaseService, ObservableObject {
    static let shared = BookmarkManager()
    
    @Published var bookmarks: [Bookmark] = []
    @Published var folders: [BookmarkFolder] = []
    @Published var currentSortOption: BookmarkSortOption = .custom
    @Published var currentFilter: BookmarkFilter = BookmarkFilter()
    @Published var isEditing = false
    
    private let bookmarksKey = "BookmarkManager_bookmarks"
    private let foldersKey = "BookmarkManager_folders"
    private let sortKey = "BookmarkManager_sortOption"
    
    private init() {
        super.init()
        loadBookmarks()
        loadFolders()
        loadSortOption()
    }
    
    var filteredBookmarks: [Bookmark] {
        let filtered = bookmarks.filter { currentFilter.matches($0) }
        
        return filtered.sorted { b1, b2 in
            if b1.isPinned != b2.isPinned {
                return b1.isPinned
            }
            return currentSortOption.compare(b1, b2)
        }
    }
    
    var pinnedBookmarks: [Bookmark] {
        return bookmarks.filter { $0.isPinned }
    }
    
    var favoriteBookmarks: [Bookmark] {
        return bookmarks.filter { $0.isFavorite }
    }
    
    var bookmarksByCategory: [BookmarkCategory: [Bookmark]] {
        return Dictionary(grouping: bookmarks) { $0.category }
    }
    
    func loadBookmarks() {
        if let saved = loadCodable([Bookmark].self, key: bookmarksKey) {
            bookmarks = saved
        }
    }
    
    func saveBookmarks() {
        saveCodable(bookmarks, key: bookmarksKey)
    }
    
    func loadFolders() {
        if let saved = loadCodable([BookmarkFolder].self, key: foldersKey) {
            folders = saved
        }
    }
    
    func saveFolders() {
        saveCodable(folders, key: foldersKey)
    }
    
    func loadSortOption() {
        if let saved = loadCodable(String.self, key: sortKey),
           let option = BookmarkSortOption(rawValue: saved) {
            currentSortOption = option
        }
    }
    
    func saveSortOption() {
        saveCodable(currentSortOption.rawValue, key: sortKey)
    }
    
    func addBookmark(name: String, url: String, icon: String = "link", category: BookmarkCategory = .general) {
        let bookmark = Bookmark(name: name, url: url, icon: icon, category: category)
        bookmarks.append(bookmark)
        saveBookmarks()
        logInfo("Added bookmark: \(name)")
    }
    
    func deleteBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        removeFromAllFolders(bookmark.id)
        saveBookmarks()
        logInfo("Deleted bookmark: \(bookmark.name)")
    }
    
    func updateBookmark(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
            logInfo("Updated bookmark: \(bookmark.name)")
        }
    }
    
    func updateBookmarkInfo(_ bookmarkId: String, editInfo: BookmarkEditInfo) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            editInfo.apply(to: &bookmarks[index])
            saveBookmarks()
        }
    }
    
    func moveBookmark(from source: IndexSet, to destination: Int) {
        let filtered = filteredBookmarks
        var movedBookmark = filtered[source.first!]
        bookmarks.removeAll { $0.id == movedBookmark.id }
        
        var targetIndex = 0
        if destination < filtered.count {
            let targetBookmark = filtered[destination]
            if let index = bookmarks.firstIndex(where: { $0.id == targetBookmark.id }) {
                targetIndex = index
            }
        }
        
        bookmarks.insert(movedBookmark, at: min(targetIndex, bookmarks.count))
        
        for (index, _) in bookmarks.enumerated() {
            bookmarks[index].customOrder = index
        }
        
        saveBookmarks()
    }
    
    func togglePin(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index].isPinned.toggle()
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
            logInfo("Toggled pin for bookmark: \(bookmark.name) -> \(bookmarks[index].isPinned)")
        }
    }
    
    func toggleFavorite(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index].isFavorite.toggle()
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
            logInfo("Toggled favorite for bookmark: \(bookmark.name) -> \(bookmarks[index].isFavorite)")
        }
    }
    
    func visitBookmark(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index].visitCount += 1
            bookmarks[index].lastVisitTime = Date()
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
        }
    }
    
    func addReadingDuration(_ bookmarkId: String, duration: TimeInterval) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            bookmarks[index].readingDuration += duration
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
            logInfo("Added reading duration: \(duration) seconds to bookmark: \(bookmarks[index].name)")
        }
    }
    
    func addListeningDuration(_ bookmarkId: String, duration: TimeInterval) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            bookmarks[index].listeningDuration += duration
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
            logInfo("Added listening duration: \(duration) seconds to bookmark: \(bookmarks[index].name)")
        }
    }
    
    func setReadingDuration(_ bookmarkId: String, duration: TimeInterval) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            bookmarks[index].readingDuration = duration
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
        }
    }
    
    func setListeningDuration(_ bookmarkId: String, duration: TimeInterval) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            bookmarks[index].listeningDuration = duration
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
        }
    }
    
    func getBookmarkById(_ id: String) -> Bookmark? {
        return bookmarks.first { $0.id == id }
    }
    
    func getBookmarksByCategory(_ category: BookmarkCategory) -> [Bookmark] {
        return bookmarks.filter { $0.category == category }
    }
    
    func getBookmarksByTag(_ tag: String) -> [Bookmark] {
        return bookmarks.filter { $0.tags.contains(tag) }
    }
    
    func getAllTags() -> [String] {
        var tags = Set<String>()
        for bookmark in bookmarks {
            tags.formUnion(bookmark.tags)
        }
        return Array(tags).sorted()
    }
    
    func addTag(_ tag: String, to bookmarkId: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            if !bookmarks[index].tags.contains(tag) {
                bookmarks[index].tags.append(tag)
                bookmarks[index].updatedTime = Date()
                saveBookmarks()
            }
        }
    }
    
    func removeTag(_ tag: String, from bookmarkId: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            bookmarks[index].tags.removeAll { $0 == tag }
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
        }
    }
    
    func setSortOption(_ option: BookmarkSortOption) {
        currentSortOption = option
        saveSortOption()
    }
    
    func setFilter(_ filter: BookmarkFilter) {
        currentFilter = filter
    }
    
    func resetFilter() {
        currentFilter = BookmarkFilter()
    }
    
    func duplicateBookmark(_ bookmark: Bookmark) {
        var newBookmark = bookmark
        newBookmark.id = UUID().uuidString
        newBookmark.name = "\(bookmark.name) (副本)"
        newBookmark.createdTime = Date()
        newBookmark.updatedTime = Date()
        newBookmark.visitCount = 0
        newBookmark.lastVisitTime = nil
        newBookmark.readingDuration = 0
        newBookmark.listeningDuration = 0
        newBookmark.customOrder = bookmarks.count
        bookmarks.append(newBookmark)
        saveBookmarks()
        logInfo("Duplicated bookmark: \(bookmark.name)")
    }
    
    func clearDuration(for bookmarkId: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            bookmarks[index].readingDuration = 0
            bookmarks[index].listeningDuration = 0
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
        }
    }
    
    func clearAllDuration() {
        for index in bookmarks.indices {
            bookmarks[index].readingDuration = 0
            bookmarks[index].listeningDuration = 0
        }
        saveBookmarks()
        logInfo("Cleared all reading/listening duration")
    }
    
    func resetVisitStats(for bookmarkId: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmarkId }) {
            bookmarks[index].visitCount = 0
            bookmarks[index].lastVisitTime = nil
            bookmarks[index].updatedTime = Date()
            saveBookmarks()
        }
    }
    
    func exportBookmarks() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let exportData = ExportBookmarkData(
            bookmarks: bookmarks,
            folders: folders,
            exportTime: Date()
        )
        
        return try? encoder.encode(exportData)
    }
    
    func importBookmarks(from data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let importData = try? decoder.decode(ExportBookmarkData.self, from: data) else {
            return false
        }
        
        for bookmark in importData.bookmarks {
            if !bookmarks.contains(where: { $0.id == bookmark.id }) {
                bookmarks.append(bookmark)
            }
        }
        
        for folder in importData.folders {
            if !folders.contains(where: { $0.id == folder.id }) {
                folders.append(folder)
            }
        }
        
        saveBookmarks()
        saveFolders()
        return true
    }
    
    func addFolder(name: String, icon: String = "folder.fill", parentId: String? = nil) {
        let folder = BookmarkFolder(name: name, icon: icon, parentId: parentId)
        folders.append(folder)
        saveFolders()
        logInfo("Added folder: \(name)")
    }
    
    func deleteFolder(_ folder: BookmarkFolder) {
        for bookmarkId in folder.bookmarkIds {
            removeFromAllFolders(bookmarkId)
        }
        folders.removeAll { $0.id == folder.id }
        saveFolders()
        logInfo("Deleted folder: \(folder.name)")
    }
    
    func updateFolder(_ folder: BookmarkFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
            folders[index].updatedTime = Date()
            saveFolders()
        }
    }
    
    func addBookmarkToFolder(_ bookmarkId: String, folderId: String) {
        if let folderIndex = folders.firstIndex(where: { $0.id == folderId }) {
            if !folders[folderIndex].bookmarkIds.contains(bookmarkId) {
                folders[folderIndex].bookmarkIds.append(bookmarkId)
                folders[folderIndex].updatedTime = Date()
                saveFolders()
            }
        }
    }
    
    func removeBookmarkFromFolder(_ bookmarkId: String, folderId: String) {
        if let folderIndex = folders.firstIndex(where: { $0.id == folderId }) {
            folders[folderIndex].bookmarkIds.removeAll { $0 == bookmarkId }
            folders[folderIndex].updatedTime = Date()
            saveFolders()
        }
    }
    
    func removeFromAllFolders(_ bookmarkId: String) {
        for index in folders.indices {
            folders[index].bookmarkIds.removeAll { $0 == bookmarkId }
        }
        saveFolders()
    }
    
    func getFoldersForBookmark(_ bookmarkId: String) -> [BookmarkFolder] {
        return folders.filter { $0.bookmarkIds.contains(bookmarkId) }
    }
    
    func getBookmarksInFolder(_ folderId: String) -> [Bookmark] {
        guard let folder = folders.first(where: { $0.id == folderId }) else {
            return []
        }
        return folder.bookmarkIds.compactMap { getBookmarkById($0) }
    }
    
    func getTopDurationBookmarks(limit: Int = 10) -> [Bookmark] {
        return bookmarks
            .sorted { $0.totalDuration > $1.totalDuration }
            .prefix(limit)
            .map { $0 }
    }
    
    func getTopReadingDurationBookmarks(limit: Int = 10) -> [Bookmark] {
        return bookmarks
            .sorted { $0.readingDuration > $1.readingDuration }
            .prefix(limit)
            .map { $0 }
    }
    
    func getTopListeningDurationBookmarks(limit: Int = 10) -> [Bookmark] {
        return bookmarks
            .sorted { $0.listeningDuration > $1.listeningDuration }
            .prefix(limit)
            .map { $0 }
    }
    
    func getTotalReadingDuration() -> TimeInterval {
        return bookmarks.reduce(0) { $0 + $1.readingDuration }
    }
    
    func getTotalListeningDuration() -> TimeInterval {
        return bookmarks.reduce(0) { $0 + $1.listeningDuration }
    }
    
    func getTotalDuration() -> TimeInterval {
        return getTotalReadingDuration() + getTotalListeningDuration()
    }
}

struct ExportBookmarkData: Codable {
    let bookmarks: [Bookmark]
    let folders: [BookmarkFolder]
    let exportTime: Date
}
