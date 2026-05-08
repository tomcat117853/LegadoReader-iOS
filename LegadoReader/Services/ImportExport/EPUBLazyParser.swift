import Foundation
import UIKit
import ZIPFoundation

class LazyEPUBBook: ObservableObject {
    @Published var metadata: EPUBMetadata
    @Published var spine: [EPUBSpineItem]
    @Published var manifest: [String: EPUBManifestItem]
    @Published var chapters: [EPUBChapter]
    @Published var stylesheets: [CSSParser.ParsedCSS]
    @Published var coverImage: Data?
    @Published var isFullyLoaded: Bool = false
    
    let epubData: Data
    let baseURL: URL
    let parsingQueue = DispatchQueue(label: "com.legadoreader.epub.parsing", qos: .userInitiated)
    
    private var extractedDir: URL?
    private var loadedChapterCache: [Int: EPUBChapter] = [:]
    private let maxCacheCount = 5
    private let lock = NSLock()
    
    @Published var statistics: BookStatistics?
    @Published var isStatisticsCalculating: Bool = false
    
    init(data: Data) throws {
        self.epubData = data
        self.metadata = EPUBMetadata()
        self.spine = []
        self.manifest = [:]
        self.chapters = []
        self.stylesheets = []
        
        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent("epub_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        self.extractedDir = extractDir
        self.baseURL = extractDir
    }
    
    deinit {
        cleanup()
    }
    
    func cleanup() {
        lock.lock()
        defer { lock.unlock() }
        
        if let extractDir = extractedDir {
            try? FileManager.default.removeItem(at: extractDir)
            extractedDir = nil
        }
        loadedChapterCache.removeAll()
    }
    
    func loadMetadataAndSpine() async throws {
        guard let extractDir = extractedDir else {
            throw EPUBError.extractionFailed
        }
        
        let tempEpub = extractDir.appendingPathComponent("book.epub")
        try epubData.write(to: tempEpub)
        
        try FileManager.default.unzipItem(at: tempEpub, to: extractDir)
        try FileManager.default.removeItem(at: tempEpub)
        
        let containerPath = extractDir.appendingPathComponent("META-INF/container.xml")
        if FileManager.default.fileExists(atPath: containerPath.path) {
            let containerData = try Data(contentsOf: containerPath)
            let rootfilePath = try parseContainerXML(containerData)
            
            let opfPath = extractDir.appendingPathComponent(rootfilePath)
            let opfData = try Data(contentsOf: opfPath)
            let opfBaseURL = opfPath.deletingLastPathComponent()
            
            try await parseOPFMetadataOnly(data: opfData, baseURL: opfBaseURL)
        }
        
        let coverData = try? await loadCover()
        await MainActor.run {
            self.coverImage = coverData
        }
    }
    
    private func parseOPFMetadataOnly(data: Data, baseURL: URL) async throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw EPUBError.invalidOPF
        }
        
        await MainActor.run {
            parseMetadata(from: content)
        }
        
        let manifestItems = parseManifest(from: content)
        let spineItems = parseSpine(from: content)
        
        await MainActor.run {
            self.manifest = manifestItems
            self.spine = spineItems
            self.chapters = spineItems.enumerated().map { index, item in
                EPUBChapter(
                    id: item.idref,
                    title: "章节 \(index + 1)",
                    content: "",
                    href: manifestItems[item.idref]?.href ?? "",
                    level: 1,
                    rawHTML: ""
                )
            }
        }
        
        await parseStylesheets(content: content, baseURL: baseURL)
    }
    
    private func parseMetadata(from content: String) {
        let patterns: [(String, String)] = [
            ("<dc:title[^>]*>([^<]*)</dc:title>", "title"),
            ("<dc:creator[^>]*>([^<]*)</dc:creator>", "author"),
            ("<dc:language[^>]*>([^<]*)</dc:language>", "language"),
            ("<dc:identifier[^>]*>([^<]*)</dc:identifier>", "identifier"),
            ("<dc:publisher[^>]*>([^<]*)</dc:publisher>", "publisher"),
            ("<dc:description[^>]*>([^<]*)</dc:description>", "description"),
            ("<dc:date[^>]*>([^<]*)</dc:date>", "date")
        ]
        
        for (pattern, key) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                let value = String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                switch key {
                case "title": metadata.title = value
                case "author": metadata.author = value
                case "language": metadata.language = value
                case "identifier": metadata.identifier = value
                case "publisher": metadata.publisher = value
                case "description": metadata.description = value
                case "date": metadata.date = value
                default: break
                }
            }
        }
        
        let coverMetaPattern = "<meta[^>]+name=[\"']cover[\"'][^>]+content=[\"']([^\"']+)[\"']"
        if let regex = try? NSRegularExpression(pattern: coverMetaPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            metadata.coverImageId = String(content[range])
        }
    }
    
    private func parseManifest(from content: String) -> [String: EPUBManifestItem] {
        var manifest: [String: EPUBManifestItem] = [:]
        
        let patterns = [
            "<item[^>]+id=[\"']([^\"']+)[\"'][^>]+href=[\"']([^\"']+)[\"'][^>]+media-type=[\"']([^\"']+)[\"']",
            "<item[^>]+href=[\"']([^\"']+)[\"'][^>]+id=[\"']([^\"']+)[\"'][^>]+media-type=[\"']([^\"']+)[\"']"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
                
                for match in matches {
                    var id: String = ""
                    var href: String = ""
                    var mediaType: String = ""
                    
                    if let idRange = Range(match.range(at: 1), in: content) {
                        id = String(content[idRange])
                    }
                    if let hrefRange = Range(match.range(at: 2), in: content) {
                        href = String(content[hrefRange])
                    }
                    if let typeRange = Range(match.range(at: 3), in: content) {
                        mediaType = String(content[typeRange])
                    }
                    
                    if !id.isEmpty && !href.isEmpty {
                        let item = EPUBManifestItem(id: id, href: href, mediaType: mediaType)
                        manifest[id] = item
                    }
                }
            }
        }
        
        return manifest
    }
    
    private func parseSpine(from content: String) -> [EPUBSpineItem] {
        var spine: [EPUBSpineItem] = []
        
        let pattern = "<itemref[^>]+idref=[\"']([^\"']+)[\"'][^>]*>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: content) {
                    let idref = String(content[idRange])
                    var linear = true
                    
                    if let fullRange = Range(match.range, in: content) {
                        let itemrefStr = String(content[fullRange])
                        if itemrefStr.contains("linear=\"no\"") {
                            linear = false
                        }
                    }
                    
                    spine.append(EPUBSpineItem(idref: idref, linear: linear))
                }
            }
        }
        
        return spine
    }
    
    private func parseStylesheets(content: String, baseURL: URL) async {
        var stylesheets: [CSSParser.ParsedCSS] = []
        
        for (id, item) in manifest {
            if item.mediaType == "text/css" || item.href.hasSuffix(".css") {
                let cssPath = baseURL.appendingPathComponent(item.href)
                if let cssData = try? Data(contentsOf: cssPath),
                   let cssString = String(data: cssData, encoding: .utf8) {
                    let parsedCSS = CSSParser.shared.parse(cssString)
                    stylesheets.append(parsedCSS)
                }
            }
        }
        
        await MainActor.run {
            self.stylesheets = stylesheets
        }
    }
    
    func loadChapter(at index: Int) async throws -> EPUBChapter {
        lock.lock()
        
        if let cached = loadedChapterCache[index] {
            lock.unlock()
            return cached
        }
        
        guard index >= 0 && index < spine.count else {
            lock.unlock()
            throw EPUBError.invalidChapter
        }
        
        let spineItem = spine[index]
        guard let manifestItem = manifest[spineItem.idref] else {
            lock.unlock()
            throw EPUBError.invalidChapter
        }
        
        guard let extractDir = extractedDir else {
            lock.unlock()
            throw EPUBError.extractionFailed
        }
        
        lock.unlock()
        
        let contentPath = extractDir.appendingPathComponent(manifestItem.href)
        
        guard FileManager.default.fileExists(atPath: contentPath.path) else {
            throw EPUBError.invalidChapter
        }
        
        let contentData = try Data(contentsOf: contentPath)
        guard let htmlContent = String(data: contentData, encoding: .utf8) else {
            throw EPUBError.invalidChapter
        }
        
        let title = extractTitle(from: htmlContent)
        let processedHTML = processHTML(htmlContent)
        
        let chapter = EPUBChapter(
            id: spineItem.idref,
            title: title,
            content: processedHTML,
            href: manifestItem.href,
            level: 1,
            rawHTML: htmlContent
        )
        
        lock.lock()
        loadedChapterCache[index] = chapter
        
        if loadedChapterCache.count > maxCacheCount {
            let keysToRemove = Array(loadedChapterCache.keys.sorted().prefix(loadedChapterCache.count - maxCacheCount))
            for key in keysToRemove {
                loadedChapterCache.removeValue(forKey: key)
            }
        }
        lock.unlock()
        
        await MainActor.run {
            if index < self.chapters.count {
                self.chapters[index] = chapter
            }
        }
        
        return chapter
    }
    
    func preloadChapters(around index: Int, range: Int = 2) async {
        let startIndex = max(0, index - range)
        let endIndex = min(chapters.count - 1, index + range)
        
        for i in startIndex...endIndex {
            if loadedChapterCache[i] == nil {
                _ = try? await loadChapter(at: i)
            }
        }
    }
    
    private func loadCover() async throws -> Data? {
        if let coverId = metadata.coverImageId,
           let manifestItem = manifest[coverId] {
            let coverPath = baseURL.appendingPathComponent(manifestItem.href)
            if let data = try? Data(contentsOf: coverPath) {
                return data
            }
        }
        
        for (_, item) in manifest {
            if item.properties?.contains("cover-image") == true {
                let coverPath = baseURL.appendingPathComponent(item.href)
                if let data = try? Data(contentsOf: coverPath) {
                    return data
                }
            }
        }
        
        for (_, item) in manifest {
            if item.mediaType.starts(with: "image/") && item.id.lowercased().contains("cover") {
                let coverPath = baseURL.appendingPathComponent(item.href)
                if let data = try? Data(contentsOf: coverPath) {
                    return data
                }
            }
        }
        
        return nil
    }
    
    private func extractTitle(from html: String) -> String {
        let titlePattern = "<title>([^<]*)</title>"
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let h1Pattern = "<h1[^>]*>([^<]*)</h1>"
        if let regex = try? NSRegularExpression(pattern: h1Pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return "章节"
    }
    
    private func processHTML(_ html: String) -> String {
        var processed = html
        
        processed = processed.replacingOccurrences(of: "<head>[\\s\\S]*?</head>", with: "", options: .regularExpression)
        
        processed = processed.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        
        processed = processed.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        
        return processed
    }
}

struct BookStatistics {
    var totalCharacters: Int = 0
    var totalWords: Int = 0
    var totalChapters: Int = 0
    var chapterWordCounts: [Int: Int] = [:]
    var isCalculated: Bool = false
    
    var formattedTotalCharacters: String {
        if totalCharacters >= 10000 {
            return String(format: "%.1f万字", Double(totalCharacters) / 10000.0)
        }
        return "\(totalCharacters)字"
    }
    
    var formattedTotalWords: String {
        if totalWords >= 10000 {
            return String(format: "%.1f万词", Double(totalWords) / 10000.0)
        }
        return "\(totalWords)词"
    }
}

extension LazyEPUBBook {
    func calculateStatistics(progressCallback: ((Double) -> Void)? = nil) async {
        await MainActor.run {
            self.isStatisticsCalculating = true
            self.statistics = BookStatistics()
        }
        
        var totalChars = 0
        var totalWords = 0
        let total = chapters.count
        
        for (index, _) in chapters.enumerated() {
            do {
                let chapter = try await loadChapter(at: index)
                let text = extractPlainText(from: chapter.content)
                
                let charCount = text.count
                let wordCount = countWords(in: text)
                
                totalChars += charCount
                totalWords += wordCount
                
                await MainActor.run {
                    self.statistics?.chapterWordCounts[index] = wordCount
                    self.statistics?.totalCharacters = totalChars
                    self.statistics?.totalWords = totalWords
                }
                
                let progress = Double(index + 1) / Double(total)
                progressCallback?(progress)
                
            } catch {
                print("统计章节 \(index) 失败: \(error)")
            }
        }
        
        await MainActor.run {
            self.statistics?.totalChapters = total
            self.statistics?.isCalculated = true
            self.isStatisticsCalculating = false
        }
    }
    
    private func extractPlainText(from html: String) -> String {
        var text = html
        
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#\\d+;", with: "", options: .regularExpression)
        
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func countWords(in text: String) -> Int {
        let chinesePattern = "[\\u4e00-\\u9fa5]+"
        let englishPattern = "[a-zA-Z]+"
        
        var count = 0
        
        if let chineseRegex = try? NSRegularExpression(pattern: chinesePattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = chineseRegex.matches(in: text, options: [], range: range)
            count += matches.reduce(0) { $0 + $1.range.length }
        }
        
        if let englishRegex = try? NSRegularExpression(pattern: englishPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = englishRegex.matches(in: text, options: [], range: range)
            count += matches.count
        }
        
        return count
    }
}

class EPUBParsingManager {
    static let shared = EPUBParsingManager()
    
    private var loadedBooks: [String: LazyEPUBBook] = [:]
    private let lock = NSLock()
    private let maxLoadedBooks = 3
    
    private init() {}
    
    func loadBook(data: Data, id: String) async throws -> LazyEPUBBook {
        lock.lock()
        if let existingBook = loadedBooks[id] {
            lock.unlock()
            return existingBook
        }
        lock.unlock()
        
        let book = try LazyEPUBBook(data: data)
        try await book.loadMetadataAndSpine()
        
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
        lock.unlock()
    }
    
    func getLoadedBook(id: String) -> LazyEPUBBook? {
        lock.lock()
        defer { lock.unlock() }
        return loadedBooks[id]
    }
    
    func clearAllBooks() {
        lock.lock()
        for (_, book) in loadedBooks {
            book.cleanup()
        }
        loadedBooks.removeAll()
        lock.unlock()
    }
}

class EPUBLazyReader: BookReaderProtocol {
    private var currentBookId: String?
    private var cachedBook: LazyEPUBBook?
    
    func read(data: Data) async throws -> BookContent {
        let bookId = UUID().uuidString
        currentBookId = bookId
        
        let book = try await EPUBParsingManager.shared.loadBook(data: data, id: bookId)
        cachedBook = book
        
        var content = BookContent()
        content.title = book.metadata.title
        content.author = book.metadata.author
        content.cover = book.coverImage
        
        return content
    }
    
    func extractCover(data: Data) -> Data? {
        Task {
            let bookId = "cover_\(UUID().uuidString)"
            defer {
                EPUBParsingManager.shared.unloadBook(id: bookId)
            }
            
            let book = try? await EPUBParsingManager.shared.loadBook(data: data, id: bookId)
            return book?.coverImage
        }
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        var metadata = BookMetadata()
        
        Task {
            let bookId = "meta_\(UUID().uuidString)"
            defer {
                EPUBParsingManager.shared.unloadBook(id: bookId)
            }
            
            if let book = try? await EPUBParsingManager.shared.loadBook(data: data, id: bookId) {
                metadata = BookMetadata(
                    title: book.metadata.title,
                    author: book.metadata.author,
                    publisher: book.metadata.publisher,
                    description: book.metadata.description,
                    language: book.metadata.language
                )
            }
        }
        
        return metadata
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        var chapters: [BookChapter] = []
        
        Task {
            let bookId = "toc_\(UUID().uuidString)"
            defer {
                EPUBParsingManager.shared.unloadBook(id: bookId)
            }
            
            if let book = try? await EPUBParsingManager.shared.loadBook(data: data, id: bookId) {
                chapters = book.chapters.map { chapter in
                    BookChapter(
                        title: chapter.title,
                        content: "",
                        level: chapter.level
                    )
                }
            }
        }
        
        return chapters
    }
    
    func getBook(id: String) -> LazyEPUBBook? {
        return EPUBParsingManager.shared.getLoadedBook(id: id)
    }
    
    func unloadCurrentBook() {
        if let bookId = currentBookId {
            EPUBParsingManager.shared.unloadBook(id: bookId)
            currentBookId = nil
            cachedBook = nil
        }
    }
}

class EPUBLazyChapterLoader: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var chapter: EPUBChapter?
    
    private var currentTask: Task<Void, Never>?
    
    func loadChapter(from book: LazyEPUBBook, at index: Int) {
        currentTask?.cancel()
        
        isLoading = true
        error = nil
        
        currentTask = Task {
            do {
                let loadedChapter = try await book.loadChapter(at: index)
                
                await MainActor.run {
                    self.chapter = loadedChapter
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.error = error
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    func cancel() {
        currentTask?.cancel()
        isLoading = false
    }
}

class EPUBLazyStatisticsCalculator {
    static let shared = EPUBLazyStatisticsCalculator()
    
    private var calculationTasks: [String: Task<BookStatistics, Never>] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    func calculateStatistics(for bookId: String, book: LazyEPUBBook, progressCallback: ((Double) -> Void)? = nil) async -> BookStatistics {
        lock.lock()
        if let existingTask = calculationTasks[bookId] {
            lock.unlock()
            return await existingTask.value
        }
        lock.unlock()
        
        let task = Task {
            var stats = BookStatistics()
            var totalChars = 0
            var totalWords = 0
            let total = book.chapters.count
            
            for (index, _) in book.chapters.enumerated() {
                guard !Task.isCancelled else {
                    return BookStatistics()
                }
                
                do {
                    let chapter = try await book.loadChapter(at: index)
                    let text = extractPlainText(from: chapter.content)
                    
                    let charCount = text.count
                    let wordCount = countWords(in: text)
                    
                    totalChars += charCount
                    totalWords += wordCount
                    
                    stats.totalCharacters = totalChars
                    stats.totalWords = totalWords
                    stats.chapterWordCounts[index] = wordCount
                    
                    let progress = Double(index + 1) / Double(total)
                    progressCallback?(progress)
                    
                } catch {
                    print("统计章节 \(index) 失败")
                }
            }
            
            stats.totalChapters = total
            stats.isCalculated = true
            
            lock.lock()
            calculationTasks.removeValue(forKey: bookId)
            lock.unlock()
            
            return stats
        }
        
        lock.lock()
        calculationTasks[bookId] = task
        lock.unlock()
        
        let result = await task.value
        return result
    }
    
    func cancelCalculation(for bookId: String) {
        lock.lock()
        calculationTasks[bookId]?.cancel()
        calculationTasks.removeValue(forKey: bookId)
        lock.unlock()
    }
    
    func cancelAllCalculations() {
        lock.lock()
        for (_, task) in calculationTasks {
            task.cancel()
        }
        calculationTasks.removeAll()
        lock.unlock()
    }
    
    private func extractPlainText(from html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func countWords(in text: String) -> Int {
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
