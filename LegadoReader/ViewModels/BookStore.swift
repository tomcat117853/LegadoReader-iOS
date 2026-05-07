import Foundation
import Combine

class BookStore: ObservableObject {
    @Published var books: [Book] = []
    @Published var currentBook: Book?
    @Published var chapters: [Chapter] = []
    @Published var currentChapter: Chapter?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadBooks()
    }
    
    // MARK: - Book Management
    
    func loadBooks() {
        books = DatabaseManager.shared.getAllBooks()
    }
    
    func addBook(_ book: Book) {
        if DatabaseManager.shared.saveBook(book) {
            loadBooks()
        }
    }
    
    func removeBook(_ book: Book) {
        if DatabaseManager.shared.deleteBook(id: book.id) {
            loadBooks()
        }
    }
    
    func updateBook(_ book: Book) {
        if DatabaseManager.shared.saveBook(book) {
            loadBooks()
        }
    }
    
    func updateReadingProgress(book: Book, chapter: Chapter?, position: Int) {
        var updatedBook = book
        updatedBook.lastReadChapter = chapter?.title
        updatedBook.lastReadPosition = position
        updatedBook.lastReadTime = Date()
        updateBook(updatedBook)
    }
    
    // MARK: - Search
    
    func searchBooks(keyword: String, sources: [BookSource]) async -> [Book] {
        guard !keyword.isEmpty else { return [] }
        
        var allBooks: [Book] = []
        
        await withTaskGroup(of: [Book].self) { group in
            for source in sources where source.isEnabled {
                group.addTask {
                    do {
                        return try await BookSourceParser.shared.searchBooks(keyword: keyword, source: source)
                    } catch {
                        print("搜索失败 \(source.name): \(error)")
                        return []
                    }
                }
            }
            
            for await books in group {
                allBooks.append(contentsOf: books)
            }
        }
        
        // 去重
        var uniqueBooks: [Book] = []
        var seen = Set<String>()
        for book in allBooks {
            let key = "\(book.name)_\(book.author)"
            if !seen.contains(key) {
                seen.insert(key)
                uniqueBooks.append(book)
            }
        }
        
        return uniqueBooks
    }
    
    // MARK: - Chapter Management
    
    func loadChapters(for book: Book, source: BookSource) async {
        do {
            let chapters = try await BookSourceParser.shared.getChapterList(book: book, source: source)
            await MainActor.run {
                self.chapters = chapters
                self.currentBook = book
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载章节失败: \(error.localizedDescription)"
            }
        }
    }
    
    func loadChapterContent(chapter: Chapter, source: BookSource) async -> String? {
        do {
            let content = try await BookSourceParser.shared.getChapterContent(chapter: chapter, source: source)
            await MainActor.run {
                self.currentChapter = chapter
            }
            return content
        } catch {
            await MainActor.run {
                self.errorMessage = "加载内容失败: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    func getNextChapter() -> Chapter? {
        guard let current = currentChapter,
              let index = chapters.firstIndex(where: { $0.id == current.id }),
              index + 1 < chapters.count else {
            return nil
        }
        return chapters[index + 1]
    }
    
    func getPreviousChapter() -> Chapter? {
        guard let current = currentChapter,
              let index = chapters.firstIndex(where: { $0.id == current.id }),
              index > 0 else {
            return nil
        }
        return chapters[index - 1]
    }
}
