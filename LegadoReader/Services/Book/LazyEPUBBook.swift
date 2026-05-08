import Foundation
import UIKit
import ZIPFoundation

struct EPUBMetadata {
    var title: String = ""
    var author: String = ""
    var language: String = "zh"
    var identifier: String = ""
    var publisher: String = ""
    var description: String = ""
    var date: String = ""
    var coverImageId: String?
}

struct EPUBSpineItem {
    var idref: String
    var linear: Bool = true
}

struct EPUBManifestItem {
    var id: String
    var href: String
    var mediaType: String
    var properties: String?
}

struct EPUBChapter: Identifiable {
    var id: String
    var title: String
    var content: String
    var href: String
    var level: Int
    var rawHTML: String
}

enum EPUBError: Error, LocalizedError {
    case invalidContainer
    case invalidOPF
    case invalidChapter
    case extractionFailed
    case coverNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidContainer: return "无效的EPUB容器"
        case .invalidOPF: return "无效的OPF文件"
        case .invalidChapter: return "无效的章节内容"
        case .extractionFailed: return "EPUB解压失败"
        case .coverNotFound: return "未找到封面图片"
        }
    }
}

class LazyEPUBBook: ObservableObject, LazyBookProtocol {
    let bookId: String
    let bookType: BookFormat = .epub
    
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var chaptersCount: Int = 0
    @Published var coverImage: Data? = nil
    @Published var metadataLoaded: Bool = false
    
    @Published var metadata: EPUBMetadata = EPUBMetadata()
    @Published var spine: [EPUBSpineItem] = []
    @Published var manifest: [String: EPUBManifestItem] = [:]
    @Published var chapters: [EPUBChapter] = []
    @Published var stylesheets: [CSSParser.ParsedCSS] = []
    
    let epubData: Data
    let baseURL: URL
    let parsingQueue = DispatchQueue(label: "com.legadoreader.epub.parsing", qos: .userInitiated)
    
    private var extractedDir: URL?
    private var loadedChapterCache: [Int: EPUBChapter] = [:]
    private let maxCacheCount = 5
    private let lock = NSLock()
    
    @Published var statistics: BookStatistics?
    @Published var isStatisticsCalculating: Bool = false
    
    init(data: Data) {
        let tempId = UUID().uuidString
        self.bookId = tempId
        self.epubData = data
        
        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent("epub_\(tempId)")
        try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        self.extractedDir = extractDir
        self.baseURL = extractDir
    }
    
    init(id: String, data: Data) {
        self.bookId = id
        self.epubData = data
        
        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent("epub_\(id)")
        try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
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
    
    func loadMetadata() async throws {
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
            self.bookTitle = self.metadata.title.isEmpty ? self.bookId : self.metadata.title
            self.bookAuthor = self.metadata.author.isEmpty ? "未知作者" : self.metadata.author
            self.chaptersCount = self.chapters.count
            self.metadataLoaded = true
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
    
    func loadChapter(at index: Int) async throws -> BookChapterContent {
        lock.lock()
        
        if let cached = loadedChapterCache[index] {
            lock.unlock()
            return BookChapterContent(
                index: index,
                title: cached.title,
                content: cached.content,
                rawContent: cached.rawHTML.data(using: .utf8)
            )
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
        
        return BookChapterContent(
            index: index,
            title: title,
            content: processedHTML,
            rawContent: htmlContent.data(using: .utf8)
        )
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
    
    func calculateStatistics(progressCallback: ((Double) -> Void)?) async -> BookStatistics {
        var stats = BookStatistics()
        stats.totalChapters = chapters.count
        
        for (index, _) in chapters.enumerated() {
            do {
                let chapter = try await loadChapter(at: index)
                let text = extractPlainText(from: chapter.content)
                
                let charCount = text.count
                let wordCount = Self.countWords(in: text)
                
                stats.totalCharacters += charCount
                stats.totalWords += wordCount
                stats.chapterWordCounts[index] = wordCount
                
                let progress = Double(index + 1) / Double(chapters.count)
                progressCallback?(progress)
                
            } catch {
                print("统计章节 \(index) 失败: \(error)")
            }
        }
        
        stats.isCalculated = true
        return stats
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
    
    private func parseContainerXML(_ data: Data) throws -> String {
        guard let content = String(data: data, encoding: .utf8) else {
            throw EPUBError.invalidContainer
        }
        
        let pattern = "full-path=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            throw EPUBError.invalidContainer
        }
        
        let range = NSRange(content.startIndex..., in: content)
        if let match = regex.firstMatch(in: content, options: [], range: range),
           let pathRange = Range(match.range(at: 1), in: content) {
            return String(content[pathRange])
        }
        
        throw EPUBError.invalidContainer
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
