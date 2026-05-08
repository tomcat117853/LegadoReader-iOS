import Foundation
import UIKit

class LocalBookManager: ObservableObject {
    static let shared = LocalBookManager()
    
    @Published var localBooks: [LocalBook] = []
    
    struct LocalBook: Identifiable, Codable {
        let id: String
        let name: String
        let author: String
        let path: String
        let type: BookType
        let cover: String?
        let size: Int64
        let lastReadTime: Date
        let progress: Double
        let currentChapter: Int
        let totalChapters: Int
        
        enum BookType: String, Codable {
            case txt = "TXT"
            case epub = "EPUB"
            case unknown = "未知"
        }
    }
    
    private let defaults = UserDefaults.standard
    private let localBooksKey = "LocalBookManager_localBooks"
    
    private init() {
        loadLocalBooks()
    }
    
    func loadLocalBooks() {
        if let data = defaults.data(forKey: localBooksKey),
           let books = try? JSONDecoder().decode([LocalBook].self, from: data) {
            localBooks = books
        } else {
            scanForBooks()
        }
    }
    
    func saveLocalBooks() {
        if let data = try? JSONEncoder().encode(localBooks) {
            defaults.set(data, forKey: localBooksKey)
        }
    }
    
    func scanForBooks() {
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let bookExtensions = ["txt", "epub"]
        localBooks.removeAll()
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
            
            for file in files {
                let ext = file.pathExtension.lowercased()
                if bookExtensions.contains(ext) {
                    let book = createBook(from: file)
                    localBooks.append(book)
                }
            }
            
            saveLocalBooks()
        } catch {
            print("扫描书籍失败: \(error)")
        }
    }
    
    private func createBook(from fileURL: URL) -> LocalBook {
        let fileManager = FileManager.default
        let ext = fileURL.pathExtension.lowercased()
        let bookName = fileURL.deletingPathExtension().lastPathComponent
        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        
        let size = attributes?[.size] as? Int64 ?? 0
        
        let book = LocalBook(
            id: fileURL.lastPathComponent,
            name: bookName,
            author: extractAuthor(from: bookName),
            path: fileURL.path,
            type: ext == "txt" ? .txt : ext == "epub" ? .epub : .unknown,
            cover: nil,
            size: size,
            lastReadTime: Date(),
            progress: 0,
            currentChapter: 0,
            totalChapters: countChapters(in: fileURL)
        )
        
        return book
    }
    
    private func extractAuthor(from filename: String) -> String {
        let patterns = [
            #"\[(.+?)\]"#,
            #"\((.+?)\)"#,
            #"-(.+?)-"#,
            #"【(.+?)】"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: filename, range: NSRange(location: 0, length: filename.utf16.count)) {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: filename) {
                    return String(filename[swiftRange])
                }
            }
        }
        
        return "未知作者"
    }
    
    private func countChapters(in fileURL: URL) -> Int {
        guard let content = try? String(contentsOf: fileURL) else {
            return 1
        }
        
        let chapterPatterns = [
            #"第[零一二三四五六七八九十百千\d]+[章节卷回]"#,
            #"chapter\s*\d+"#,
            #"第\d+章"#
        ]
        
        var chapterCount = 0
        
        for pattern in chapterPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                chapterCount += regex.numberOfMatches(in: content, range: NSRange(location: 0, length: content.utf16.count))
            }
        }
        
        return max(chapterCount, 1)
    }
    
    func importBook(from fileURL: URL) {
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentDirectory.appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: fileURL, to: destinationURL)
            scanForBooks()
        } catch {
            print("导入书籍失败: \(error)")
        }
    }
    
    func deleteBook(_ book: LocalBook) {
        let fileManager = FileManager.default
        
        do {
            try fileManager.removeItem(atPath: book.path)
            localBooks.removeAll { $0.id == book.id }
            saveLocalBooks()
        } catch {
            print("删除书籍失败: \(error)")
        }
    }
    
    func readBook(_ book: LocalBook) -> (chapters: [String], content: String) {
        switch book.type {
        case .txt:
            return readTXTBook(book)
        case .epub:
            return readEPUBBook(book)
        case .unknown:
            return ([book.name], "无法识别的文件格式")
        }
    }
    
    private func readTXTBook(_ book: LocalBook) -> (chapters: [String], content: String) {
        guard let content = try? String(contentsOfFile: book.path, encoding: detectEncoding(book.path)) else {
            return ([book.name], "无法读取文件")
        }
        
        let chapters = parseChapters(content)
        return (chapters, content)
    }
    
    private func readEPUBBook(_ book: LocalBook) -> (chapters: [String], content: String) {
        do {
            let epubData = try Data(contentsOf: URL(fileURLWithPath: book.path))
            let epub = LocalEPUBParser(data: epubData)
            return try epub.parse()
        } catch {
            print("EPUB解析失败: \(error)")
            return ([book.name], "EPUB解析失败")
        }
    }
    
    private func detectEncoding(_ path: String) -> String.Encoding {
        let encodings: [String.Encoding] = [
            .utf8,
            .gbk,
            .gb18030,
            .big5,
            .utf16,
            .ascii
        ]
        
        for encoding in encodings {
            if let _ = try? String(contentsOfFile: path, encoding: encoding) {
                return encoding
            }
        }
        
        return .utf8
    }
    
    private func parseChapters(_ content: String) -> [String] {
        var chapters: [String] = []
        let lines = content.components(separatedBy: .newlines)
        
        let chapterPattern = #"^[\s*]*(第[零一二三四五六七八九十百千\d]+[章节卷回])[\s：:]?"#
        
        for (index, line) in lines.enumerated() {
            if let regex = try? NSRegularExpression(pattern: chapterPattern, options: .caseInsensitive),
               regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
                let chapterTitle = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !chapterTitle.isEmpty {
                    chapters.append(chapterTitle)
                }
            }
        }
        
        if chapters.isEmpty {
            chapters = ["全文"]
        }
        
        return chapters
    }
    
    func getChapterContent(content: String, chapterIndex: Int, chapters: [String]) -> String {
        if chapters.count == 1 {
            return content
        }
        
        let chapterTitle = chapters[chapterIndex]
        var startIndex: String.Index?
        var endIndex: String.Index?
        
        for (idx, title) in chapters.enumerated() {
            if let range = content.range(of: title) {
                if idx == chapterIndex {
                    startIndex = range.lowerBound
                } else if idx > chapterIndex && endIndex == nil {
                    endIndex = range.lowerBound
                }
            }
        }
        
        if let start = startIndex {
            if let end = endIndex {
                return String(content[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return String(content[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return content
    }
    
    func updateProgress(bookId: String, progress: Double, chapter: Int) {
        if let index = localBooks.firstIndex(where: { $0.id == bookId }) {
            localBooks[index] = LocalBook(
                id: localBooks[index].id,
                name: localBooks[index].name,
                author: localBooks[index].author,
                path: localBooks[index].path,
                type: localBooks[index].type,
                cover: localBooks[index].cover,
                size: localBooks[index].size,
                lastReadTime: Date(),
                progress: progress,
                currentChapter: chapter,
                totalChapters: localBooks[index].totalChapters
            )
            saveLocalBooks()
        }
    }
}

class LocalEPUBParser {
    private let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    func parse() throws -> (chapters: [String], content: String) {
        let archive = try Archive(data: data, options: .none)
        
        var chapters: [String] = []
        var content: String = ""
        
        for entry in archive.entries {
            let path = entry.path.lowercased()
            
            if path.hasSuffix(".xhtml") || path.hasSuffix(".html") {
                let entryData = try entry.extract()
                if let htmlString = String(data: entryData, encoding: .utf8) {
                    let chapterContent = parseHTML(htmlString)
                    content += chapterContent + "\n\n"
                    
                    if let title = extractTitle(htmlString) {
                        chapters.append(title)
                    }
                }
            }
        }
        
        if chapters.isEmpty {
            chapters = ["全文"]
        }
        
        return (chapters, content)
    }
    
    private func parseHTML(_ html: String) -> String {
        var cleaned = html
        
        cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: "\n", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractTitle(_ html: String) -> String? {
        let patterns = [
            #"<title>(.+?)</title>"#,
            #"<h1[^>]*>(.+?)</h1>"#,
            #"<h2[^>]*>(.+?)</h2>"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: html.utf16.count)) {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: html) {
                    return parseHTML(String(html[swiftRange]))
                }
            }
        }
        
        return nil
    }
}

import ZIPFoundation

extension Archive {
    func extractEntry(named name: String) throws -> Data {
        guard let entry = self[name] else {
            throw NSError(domain: "EPUBParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Entry not found"])
        }
        return try entry.extract()
    }
}
