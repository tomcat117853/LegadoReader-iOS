import Foundation
import UIKit

protocol LazyBookProtocol: ObservableObject {
    var bookId: String { get }
    var bookTitle: String { get }
    var bookAuthor: String { get }
    var bookType: BookFormat { get }
    var chaptersCount: Int { get }
    var coverImage: Data? { get }
    
    func loadMetadata() async throws
    func loadChapter(at index: Int) async throws -> BookChapterContent
    func preloadChapters(around index: Int, range: Int) async
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics
    func cleanup()
}

enum BookFormat: String, CaseIterable {
    case txt = "TXT"
    case epub = "EPUB"
    case pdf = "PDF"
    case umd = "UMD"
    case azw = "AZW"
    case fb2 = "FB2"
    case chm = "CHM"
    case rtf = "RTF"
    case html = "HTML"
    case unknown = "未知"
    
    var fileExtensions: [String] {
        switch self {
        case .txt: return ["txt"]
        case .epub: return ["epub"]
        case .pdf: return ["pdf"]
        case .umd: return ["umd"]
        case .azw: return ["azw", "azw3", "mobi"]
        case .fb2: return ["fb2", "fbz", "fb2z"]
        case .chm: return ["chm"]
        case .rtf: return ["rtf"]
        case .html: return ["html", "htm", "xhtml", "xht"]
        case .unknown: return []
        }
    }
    
    var displayName: String {
        switch self {
        case .txt: return "纯文本"
        case .epub: return "EPUB电子书"
        case .pdf: return "PDF文档"
        case .umd: return "UMD电子书"
        case .azw: return "Kindle电子书"
        case .fb2: return "FictionBook"
        case .chm: return "CHM帮助文档"
        case .rtf: return "富文本"
        case .html: return "HTML网页"
        case .unknown: return "未知格式"
        }
    }
    
    var icon: String {
        switch self {
        case .txt: return "doc.text"
        case .epub: return "book"
        case .pdf: return "doc.richtext"
        case .umd: return "books.vertical"
        case .azw: return "books"
        case .fb2: return "book.circle"
        case .chm: return "questionmark.square"
        case .rtf: return "doc.plaintext"
        case .html: return "globe"
        case .unknown: return "questionmark.circle"
        }
    }
    
    static func from(extension ext: String) -> BookFormat {
        let lowercased = ext.lowercased()
        for format in BookFormat.allCases {
            if format.fileExtensions.contains(lowercased) {
                return format
            }
        }
        return .unknown
    }
}

struct BookChapterContent {
    var index: Int
    var title: String
    var content: String
    var rawContent: Data?
}

class LazyBookManager {
    static let shared = LazyBookManager()
    
    private var loadedBooks: [String: LazyBookProtocol] = [:]
    private var statisticsCache: [String: BookStatistics] = [:]
    private var chapterCache: [String: [Int: BookChapterContent]] = [:]
    
    private let lock = NSLock()
    private let maxLoadedBooks = 3
    private let maxChapterCachePerBook = 10
    
    private init() {}
    
    func loadBook(data: Data, id: String, format: BookFormat) async throws -> LazyBookProtocol {
        lock.lock()
        if let existingBook = loadedBooks[id] {
            lock.unlock()
            return existingBook
        }
        lock.unlock()
        
        let book: LazyBookProtocol
        
        switch format {
        case .txt:
            book = LazyTXTBook(id: id, data: data)
        case .epub:
            book = LazyEPUBBook(id: id, data: data)
        case .pdf:
            book = LazyPDFBook(id: id, data: data)
        case .umd:
            book = LazyUMDBook(id: id, data: data)
        case .azw:
            book = LazyAZWBook(id: id, data: data)
        case .fb2:
            book = LazyFB2Book(id: id, data: data)
        case .chm:
            book = LazyCHMBook(id: id, data: data)
        case .rtf:
            book = LazyRTFBook(id: id, data: data)
        case .html:
            book = LazyHTMLBook(id: id, data: data)
        case .unknown:
            book = LazyGenericBook(id: id, data: data)
        }
        
        try await book.loadMetadata()
        
        lock.lock()
        if loadedBooks.count >= maxLoadedBooks {
            let keysToRemove = Array(loadedBooks.keys.prefix(loadedBooks.count - maxLoadedBooks + 1))
            for key in keysToRemove {
                loadedBooks[key]?.cleanup()
                loadedBooks.removeValue(forKey: key)
            }
        }
        loadedBooks[id] = book
        lock.unlock()
        
        return book
    }
    
    func unloadBook(id: String) {
        lock.lock()
        loadedBooks[id]?.cleanup()
        loadedBooks.removeValue(forKey: id)
        chapterCache.removeValue(forKey: id)
        lock.unlock()
    }
    
    func getBook(id: String) -> LazyBookProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return loadedBooks[id]
    }
    
    func getStatistics(for bookId: String) -> BookStatistics? {
        lock.lock()
        defer { lock.unlock() }
        return statisticsCache[bookId]
    }
    
    func cacheStatistics(for bookId: String, statistics: BookStatistics) {
        lock.lock()
        statisticsCache[bookId] = statistics
        lock.unlock()
    }
}

class LazyTXTBook: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .txt
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 0
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    private var content: String?
    private var chapters: [TXTChapter] = []
    private let encoding: String.Encoding
    
    struct TXTChapter {
        var index: Int
        var title: String
        var startOffset: Int
        var endOffset: Int
    }
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
        self.encoding = Self.detectEncoding(data)
    }
    
    func loadMetadata() async throws {
        let contentString = try String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) ?? ""
        
        await MainActor.run {
            self.content = contentString
        }
        
        let parsedChapters = parseChapters(contentString)
        
        await MainActor.run {
            self.chapters = parsedChapters
            self.chaptersCount = parsedChapters.count
            self.bookTitle = extractTitle(from: contentString)
            self.bookAuthor = extractAuthor(from: contentString)
            self.metadataLoaded = true
        }
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        guard let content = content else {
            throw LazyBookError.contentNotLoaded
        }
        
        guard index >= 0 && index < chapters.count else {
            throw LazyBookError.invalidChapterIndex
        }
        
        let chapter = chapters[index]
        let startIndex = content.index(content.startIndex, offsetBy: min(chapter.startOffset, content.count))
        let endIndex = content.index(content.startIndex, offsetBy: min(chapter.endOffset, content.count))
        let chapterContent = String(content[startIndex..<endIndex])
        
        return BookChapterContent(
            index: index,
            title: chapter.title,
            content: chapterContent.trimmingCharacters(in: .whitespacesAndNewlines),
            rawContent: chapterContent.data(using: encoding)
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
        let startIndex = max(0, index - range)
        let endIndex = min(chapters.count - 1, index + range)
        
        for i in startIndex...endIndex {
            _ = try? await loadChapter(at: i)
        }
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chapters.count
        
        guard let content = content else {
            stats.isCalculated = true
            return stats
        }
        
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        stats.totalCharacters = text.count
        stats.totalWords = Self.countWords(in: text)
        
        for (index, chapter) in chapters.enumerated() {
            let startIndex = content.index(content.startIndex, offsetBy: min(chapter.startOffset, content.count))
            let endIndex = content.index(content.startIndex, offsetBy: min(chapter.endOffset, content.count))
            let chapterText = String(content[startIndex..<endIndex])
            stats.chapterWordCounts[index] = Self.countWords(in: chapterText)
            
            let progress = Double(index + 1) / Double(chapters.count)
            progressCallback?(progress)
        }
        
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
        content = nil
        chapters.removeAll()
    }
    
    private func parseChapters(_ content: String) -> [TXTChapter] {
        var chapters: [TXTChapter] = []
        
        let chapterPatterns = [
            #"^[\s*]*(第[零一二三四五六七八九十百千0-9]+[章节卷回部篇])[\s：:，,]*"#,
            #"^[\s*]*(Chapter\s*[0-9IVX]+)[\s：:]*"#,
            #"^[\s*]*#{1,6}\s+(.+)$"#,
            #"^[\s*]*【(.+?)】"#
        ]
        
        var currentChapterStart = 0
        
        for line in content.components(separatedBy: .newlines) {
            for pattern in chapterPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
                    let title = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let range = content.range(of: line) {
                        let startOffset = range.lowerBound.utf16Offset(in: content)
                        
                        if !chapters.isEmpty {
                            chapters[chapters.count - 1].endOffset = startOffset
                        }
                        
                        chapters.append(TXTChapter(
                            index: chapters.count,
                            title: title,
                            startOffset: startOffset,
                            endOffset: content.utf16.count
                        ))
                    }
                    break
                }
            }
        }
        
        if chapters.isEmpty {
            chapters.append(TXTChapter(
                index: 0,
                title: "全文",
                startOffset: 0,
                endOffset: content.utf16.count
            ))
        } else {
            chapters[chapters.count - 1].endOffset = content.utf16.count
        }
        
        return chapters
    }
    
    private func extractTitle(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 0 && trimmed.count < 100 {
                return trimmed
            }
        }
        
        return bookId
    }
    
    private func extractAuthor(from content: String) -> String {
        let authorPatterns = [
            #"作者[：:]\s*(.+)"#,
            #"^作者[：:]\s*(.+)$"#,
            #"著[者]?\s*[：:]\s*(.+)"#
        ]
        
        let lines = content.components(separatedBy: .newlines).prefix(20)
        
        for line in lines {
            for pattern in authorPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
                   let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
                   let range = Range(match.range(at: 1), in: line) {
                    return String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return "未知作者"
    }
    
    static func detectEncoding(_ data: Data) -> String.Encoding {
        let encodings: [String.Encoding] = [
            .utf8,
            .gbk,
            .gb18030,
            .big5,
            .utf16,
            .ascii
        ]
        
        for encoding in encodings {
            if let _ = try? String(data: data, encoding: encoding) {
                return encoding
            }
        }
        
        return .utf8
    }
    
    static func countWords(in text: String) -> Int {
        var count = 0
        
        let chinesePattern = "[\\u4e00-\\u9fa5]+"
        if let regex = try? NSRegularExpression(pattern: chinesePattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            count += regex.matches(in: text, options: [], range: range).reduce(0) { $0 + $1.range.length }
        }
        
        let englishPattern = "[a-zA-Z]+"
        if let regex = try? NSRegularExpression(pattern: englishPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            count += regex.matches(in: text, options: [], range: range).count
        }
        
        return count
    }
}

class LazyPDFBook: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .pdf
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 0
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    private var pageCache: [Int: String] = [:]
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
    }
    
    func loadMetadata() async throws {
        await MainActor.run {
            self.bookTitle = bookId
            self.bookAuthor = "未知作者"
            self.chaptersCount = 0
            self.metadataLoaded = true
        }
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        return BookChapterContent(
            index: index,
            title: "第\(index + 1)页",
            content: "PDF页面内容",
            rawContent: nil
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chaptersCount
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
        pageCache.removeAll()
    }
}

class LazyUMDBook: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .umd
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 0
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
    }
    
    func loadMetadata() async throws {
        await MainActor.run {
            self.bookTitle = bookId
            self.bookAuthor = "未知作者"
            self.chaptersCount = 1
            self.metadataLoaded = true
        }
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        return BookChapterContent(
            index: index,
            title: "内容",
            content: "UMD格式内容",
            rawContent: nil
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chaptersCount
        stats.totalCharacters = data.count
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
    }
}

class LazyAZWBook: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .azw
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 0
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
    }
    
    func loadMetadata() async throws {
        await MainActor.run {
            self.bookTitle = bookId
            self.bookAuthor = "未知作者"
            self.chaptersCount = 1
            self.metadataLoaded = true
        }
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        return BookChapterContent(
            index: index,
            title: "内容",
            content: "AZW格式内容",
            rawContent: nil
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chaptersCount
        stats.totalCharacters = data.count
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
    }
}

class LazyFB2Book: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .fb2
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 0
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    private var content: String?
    private var chapters: [FB2Chapter] = []
    
    struct FB2Chapter {
        var index: Int
        var title: String
        var content: String
    }
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
    }
    
    func loadMetadata() async throws {
        guard let contentString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .gbk) else {
            throw LazyBookError.parsingFailed
        }
        
        self.content = contentString
        parseFB2(contentString)
        bookTitle = extractTitle(from: contentString)
        bookAuthor = extractAuthor(from: contentString)
        chaptersCount = chapters.count
        
        metadataLoaded = true
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        guard index >= 0 && index < chapters.count else {
            throw LazyBookError.invalidChapterIndex
        }
        
        let chapter = chapters[index]
        return BookChapterContent(
            index: index,
            title: chapter.title,
            content: chapter.content,
            rawContent: chapter.content.data(using: .utf8)
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chapters.count
        
        for (index, chapter) in chapters.enumerated() {
            let wordCount = LazyTXTBook.countWords(in: chapter.content)
            stats.totalWords += wordCount
            stats.totalCharacters += chapter.content.count
            stats.chapterWordCounts[index] = wordCount
            
            let progress = Double(index + 1) / Double(chapters.count)
            progressCallback?(progress)
        }
        
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
        content = nil
        chapters.removeAll()
    }
    
    private func parseFB2(_ content: String) {
        var parsedChapters: [FB2Chapter] = []
        
        let sectionPattern = "<section[^>]*>([\\s\\S]*?)</section>"
        if let regex = try? NSRegularExpression(pattern: sectionPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for (index, match) in matches.enumerated() {
                if let range = Range(match.range(at: 1), in: content) {
                    let sectionContent = String(content[range])
                    let title = extractSectionTitle(from: sectionContent)
                    let text = stripXMLTags(sectionContent)
                    
                    parsedChapters.append(FB2Chapter(
                        index: index,
                        title: title.isEmpty ? "章节 \(index + 1)" : title,
                        content: text
                    ))
                }
            }
        }
        
        if parsedChapters.isEmpty {
            parsedChapters.append(FB2Chapter(
                index: 0,
                title: "全文",
                content: stripXMLTags(content)
            ))
        }
        
        chapters = parsedChapters
    }
    
    private func extractSectionTitle(from section: String) -> String {
        let titlePattern = "<title>([\\s\\S]*?)</title>"
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: section, range: NSRange(section.startIndex..., in: section)),
           let range = Range(match.range(at: 1), in: section) {
            return stripXMLTags(String(section[range])).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    
    private func extractTitle(from content: String) -> String {
        let titlePattern = "<book-title>([^<]*)</book-title>"
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return bookId
    }
    
    private func extractAuthor(from content: String) -> String {
        let authorPattern = "<author>.*?<first-name>([^<]*)</first-name>.*?<last-name>([^<]*)</last-name>"
        if let regex = try? NSRegularExpression(pattern: authorPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
            var author = ""
            if let firstRange = Range(match.range(at: 1), in: content) {
                author += String(content[firstRange])
            }
            if let lastRange = Range(match.range(at: 2), in: content) {
                author += " " + String(content[lastRange])
            }
            return author.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "未知作者"
    }
    
    private func stripXMLTags(_ xml: String) -> String {
        var text = xml
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

class LazyCHMBook: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .chm
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 1
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    private var content: String?
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
    }
    
    func loadMetadata() async throws {
        bookTitle = bookId
        bookAuthor = "未知作者"
        chaptersCount = 1
        metadataLoaded = true
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        return BookChapterContent(
            index: index,
            title: "CHM内容",
            content: "CHM格式内容需要专门解析器",
            rawContent: data
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chaptersCount
        stats.totalCharacters = data.count
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
        content = nil
    }
}

class LazyRTFBook: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .rtf
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 1
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    private var content: String?
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
    }
    
    func loadMetadata() async throws {
        if let contentString = String(data: data, encoding: .ascii) {
            self.content = contentString
            bookTitle = extractTitle(from: contentString)
            bookAuthor = extractAuthor(from: contentString)
        } else {
            bookTitle = bookId
            bookAuthor = "未知作者"
        }
        
        chaptersCount = 1
        metadataLoaded = true
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        guard let content = content else {
            throw LazyBookError.contentNotLoaded
        }
        
        return BookChapterContent(
            index: index,
            title: bookTitle,
            content: stripRTFTags(content),
            rawContent: data
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chaptersCount
        
        if let content = content {
            let text = stripRTFTags(content)
            stats.totalCharacters = text.count
            stats.totalWords = LazyTXTBook.countWords(in: text)
        }
        
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
        content = nil
    }
    
    private func extractTitle(from rtf: String) -> String {
        let titlePattern = "\\\\title\\s*([^\\\\{}]+)"
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: rtf, range: NSRange(rtf.startIndex..., in: rtf)),
           let range = Range(match.range(at: 1), in: rtf) {
            return String(rtf[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return bookId
    }
    
    private func extractAuthor(from rtf: String) -> String {
        let authorPattern = "\\\\author\\s*([^\\\\{}]+)"
        if let regex = try? NSRegularExpression(pattern: authorPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: rtf, range: NSRange(rtf.startIndex..., in: rtf)),
           let range = Range(match.range(at: 1), in: rtf) {
            return String(rtf[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "未知作者"
    }
    
    private func stripRTFTags(_ rtf: String) -> String {
        var text = rtf
        
        text = text.replacingOccurrences(of: "\\\\[a-z]+\\s*", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\{[^}]+\\}", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\\\par", with: "\n", options: .literal)
        text = text.replacingOccurrences(of: "\\\\rquote", with: "'", options: .literal)
        text = text.replacingOccurrences(of: "\\\\ldquote", with: "\"", options: .literal)
        text = text.replacingOccurrences(of: "\\}", with: "", options: .literal)
        text = text.replacingOccurrences(of: "\\{", with: "", options: .literal)
        
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

class LazyGenericBook: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .unknown
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 0
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
    }
    
    func loadMetadata() async throws {
        await MainActor.run {
            self.bookTitle = bookId
            self.bookAuthor = "未知作者"
            self.chaptersCount = 1
            self.metadataLoaded = true
        }
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        return BookChapterContent(
            index: index,
            title: "内容",
            content: "无法识别的格式",
            rawContent: nil
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chaptersCount
        stats.totalCharacters = data.count
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
    }
}

class LazyHTMLBook: LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .html
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 1
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    private let data: Data
    private var content: String?
    
    init(id: String, data: Data) {
        self.bookId = id
        self.data = data
    }
    
    func loadMetadata() async throws {
        guard let contentString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .gbk) else {
            throw LazyBookError.parsingFailed
        }
        
        self.content = contentString
        bookTitle = extractTitle(from: contentString)
        bookAuthor = extractAuthor(from: contentString)
        
        let parsedChapters = parseChapters(contentString)
        chaptersCount = max(1, parsedChapters.count)
        
        metadataLoaded = true
    }
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        guard let content = content else {
            throw LazyBookError.contentNotLoaded
        }
        
        return BookChapterContent(
            index: index,
            title: "HTML内容",
            content: stripHTML(content),
            rawContent: data
        )
    }
    
    func preloadChapters(around index: Int, range: Int) async {
    }
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chaptersCount
        
        if let content = content {
            let text = stripHTML(content)
            stats.totalCharacters = text.count
            stats.totalWords = LazyTXTBook.countWords(in: text)
        }
        
        stats.isCalculated = true
        return stats
    }
    
    func cleanup() {
        content = nil
    }
    
    private func extractTitle(from html: String) -> String {
        let titlePattern = "<title[^>]*>([^<]*)</title>"
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let h1Pattern = "<h1[^>]*>([^<]*)</h1>"
        if let regex = try? NSRegularExpression(pattern: h1Pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return bookId
    }
    
    private func extractAuthor(from html: String) -> String {
        let authorPatterns = [
            #"<meta[^>]+name=["']author["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']author["']"#,
            #"<author[^>]*>([^<]*)</author>"#
        ]
        
        for pattern in authorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return "未知作者"
    }
    
    private func parseChapters(_ content: String) -> [Int] {
        var chapterIndices: [Int] = []
        
        let hPattern = "<h[1-6][^>]*>"
        if let regex = try? NSRegularExpression(pattern: hPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            for match in matches {
                chapterIndices.append(match.range.location)
            }
        }
        
        return chapterIndices
    }
    
    private func stripHTML(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LazyBookError: Error {
    case contentNotLoaded
    case invalidChapterIndex
    case unsupportedFormat
    case parsingFailed
}
