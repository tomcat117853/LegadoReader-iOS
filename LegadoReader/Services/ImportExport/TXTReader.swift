import Foundation
import UIKit
import PDFKit

class TXTReader: BookReaderProtocol {
    private var detectedEncoding: String.Encoding = .utf8
    private var textContent: String = ""
    
    func read(data: Data) async throws -> BookContent {
        detectedEncoding = data.detectEncoding()
        textContent = data.toString(encoding: detectedEncoding)
        
        let metadata = BookMetadata()
        let chapters = parseChapters(textContent)
        
        return BookContent(
            title: extractTitle(),
            author: extractAuthor(),
            chapters: chapters,
            cover: nil,
            metadata: metadata,
            rawContent: textContent
        )
    }
    
    func extractCover(data: Data) -> Data? {
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        var metadata = BookMetadata()
        
        let text = data.toString(encoding: data.detectEncoding())
        metadata.title = extractTitle(from: text)
        metadata.author = extractAuthor(from: text)
        
        return metadata
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        let text = data.toString(encoding: data.detectEncoding())
        return parseChapters(text)
    }
    
    private func extractTitle() -> String {
        return extractTitle(from: textContent)
    }
    
    private func extractTitle(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        for (index, line) in lines.enumerated() {
            if index > 5 { break }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("书名") || trimmed.hasPrefix("书名：") || trimmed.hasPrefix("Title") {
                return trimmed.replacingOccurrences(of: "书名", with: "")
                    .replacingOccurrences(of: "：", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            
            if !trimmed.contains("作者") && !trimmed.contains("简介") && trimmed.count > 2 && trimmed.count < 50 {
                return trimmed
            }
        }
        
        return ""
    }
    
    private func extractAuthor() -> String {
        return extractAuthor(from: textContent)
    }
    
    private func extractAuthor(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("作者") || trimmed.hasPrefix("作者：") || trimmed.hasPrefix("Author") {
                return trimmed.replacingOccurrences(of: "作者", with: "")
                    .replacingOccurrences(of: "：", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            
            if trimmed.contains("著") && trimmed.count < 30 {
                return trimmed.replacingOccurrences(of: "著", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        
        return ""
    }
    
    private func parseChapters(_ content: String) -> [BookChapter] {
        let patterns = [
            "^第[零一二三四五六七八九十百千万]+章\\s+.*$",
            "^第\\d+章\\s+.*$",
            "^Chapter\\s+\\d+.*$",
            "^\\d+\\.\\s+.*$",
            "^【.*】$",
            "^《.*》$",
            "^\\s*[一二三四五六七八九十]+、.*$",
            "^\\s*[ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩ]+.*$"
        ]
        
        let lines = content.components(separatedBy: .newlines)
        var chapters: [BookChapter] = []
        var currentChapterTitle = ""
        var currentChapterContent = ""
        var offset = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            var isChapterStart = false
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    if regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                        isChapterStart = true
                        break
                    }
                }
            }
            
            if isChapterStart && trimmed.count < 100 {
                if !currentChapterTitle.isEmpty || !currentChapterContent.isEmpty {
                    chapters.append(BookChapter(
                        title: currentChapterTitle.isEmpty ? "章节" : currentChapterTitle,
                        content: currentChapterContent,
                        startOffset: offset
                    ))
                    offset += currentChapterContent.count
                }
                
                currentChapterTitle = trimmed
                currentChapterContent = ""
            } else {
                currentChapterContent += line + "\n"
            }
        }
        
        if !currentChapterTitle.isEmpty || !currentChapterContent.isEmpty {
            chapters.append(BookChapter(
                title: currentChapterTitle.isEmpty ? "正文" : currentChapterTitle,
                content: currentChapterContent,
                startOffset: offset
            ))
        }
        
        if chapters.isEmpty || (chapters.count == 1 && chapters[0].content.isEmpty) {
            chapters = [BookChapter(title: "正文", content: content)]
        }
        
        return chapters
    }
}

class EPUBReader: BookReaderProtocol {
    private var files: [String: Data] = [:]
    private var opfPath: String = ""
    private var contentBasePath: String = ""
    
    struct EPUBMetadata {
        var title: String = ""
        var author: String = ""
        var coverImagePath: String?
        var coverImageData: Data?
        var language: String = ""
        var publisher: String = ""
        var description: String = ""
        var identifier: String = ""
    }
    
    func read(data: Data) async throws -> BookContent {
        files = try await unzip(data: data)
        
        guard let containerData = files["META-INF/container.xml"] else {
            throw EPUBError.invalidFormat
        }
        
        opfPath = try parseContainer(data: containerData)
        
        guard !opfPath.isEmpty else {
            throw EPUBError.opfNotFound
        }
        
        let opfData = files[opfPath] ?? files["OEBPS/content.opf"] ?? files["OPS/content.opf"] ?? files.values.first { $0.count > 1000 }!
        contentBasePath = (opfPath as NSString).deletingLastPathComponent
        if contentBasePath.isEmpty { contentBasePath = "OEBPS" }
        
        let metadata = try parseOPF(data: opfData)
        let chapters = try await parseChapters(data: opfData)
        
        return BookContent(
            title: metadata.title,
            author: metadata.author,
            chapters: chapters,
            cover: metadata.coverImageData,
            metadata: BookMetadata(
                title: metadata.title,
                author: metadata.author,
                publisher: metadata.publisher,
                description: metadata.description,
                language: metadata.language
            ),
            rawContent: chapters.map { $0.content }.joined(separator: "\n\n")
        )
    }
    
    func extractCover(data: Data) -> Data? {
        Task {
            files = (try? await unzip(data: data)) ?? [:]
        }
        
        guard let containerData = files["META-INF/container.xml"] else { return nil }
        
        guard let path = try? parseContainer(data: containerData), !path.isEmpty else { return nil }
        
        let opfData = files[path] ?? files["OEBPS/content.opf"] ?? files["OPS/content.opf"]
        guard let opf = opfData else { return nil }
        
        return extractCoverFromOPF(data: opf)
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        var metadata = BookMetadata()
        
        Task {
            files = (try? await unzip(data: data)) ?? [:]
        }
        
        guard let containerData = files["META-INF/container.xml"] else { return metadata }
        
        guard let path = try? parseContainer(data: containerData), !path.isEmpty else { return metadata }
        
        let opfData = files[path] ?? files["OEBPS/content.opf"] ?? files["OPS/content.opf"]
        guard let opf = opfData else { return metadata }
        
        let epubMeta = extractMetadata(data: opf)
        metadata.title = epubMeta.title
        metadata.author = epubMeta.author
        metadata.publisher = epubMeta.publisher
        metadata.description = epubMeta.description
        metadata.language = epubMeta.language
        
        return metadata
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        return []
    }
    
    private func unzip(data: Data) async throws -> [String: Data] {
        var result: [String: Data] = [:]
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        guard let extractedFiles = try? await ArchiveManager.shared.extractArchive(at: data, to: tempDir) else {
            return try extractZIPManually(data: data)
        }
        
        for fileURL in extractedFiles {
            let relativePath = fileURL.path.replacingOccurrences(of: tempDir.path + "/", with: "")
            if let fileData = try? Data(contentsOf: fileURL) {
                result[relativePath] = fileData
            }
        }
        
        return result
    }
    
    private func extractZIPManually(data: Data) throws -> [String: Data] {
        var result: [String: Data] = [:]
        var offset = 0
        
        while offset < data.count - 4 {
            guard offset + 4 <= data.count else { break }
            let signature = [UInt8](data[offset..<offset+4])
            
            if signature == [0x50, 0x4B, 0x03, 0x04] {
                guard offset + 30 <= data.count else { break }
                
                let compressionMethod = Int(data[offset+8]) | (Int(data[offset+9]) << 8)
                let nameLength = Int(data[offset+26]) | (Int(data[offset+27]) << 8)
                let extraLength = Int(data[offset+28]) | (Int(data[offset+29]) << 8)
                let compressedSize = Int(data[offset+18]) | (Int(data[offset+19]) << 8) |
                                   (Int(data[offset+20]) << 16) | (Int(data[offset+21]) << 24)
                
                let nameStart = offset + 30
                let nameEnd = nameStart + nameLength
                
                guard nameEnd <= data.count else { break }
                
                let nameData = data[nameStart..<nameEnd]
                guard let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1) else {
                    offset = nameEnd + extraLength + compressedSize
                    continue
                }
                
                let dataStart = nameEnd + extraLength
                let dataEnd = dataStart + compressedSize
                
                guard dataEnd <= data.count else { break }
                
                let compressedData = data[dataStart..<dataEnd]
                
                var decompressedData: Data?
                if compressionMethod == 0 {
                    decompressedData = Data(compressedData)
                } else if compressionMethod == 8 {
                    decompressedData = decompressDeflate(Data(compressedData))
                }
                
                if let content = decompressedData {
                    result[name] = content
                }
                
                offset = dataEnd
            } else if signature == [0x50, 0x4B, 0x05, 0x06] || signature == [0x50, 0x4B, 0x06, 0x06] {
                break
            } else {
                offset += 1
            }
        }
        
        return result
    }
    
    private func decompressDeflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        return try? (data as NSData).decompressed(using: .lzfse)
    }
    
    private func parseContainer(data: Data) throws -> String {
        guard let content = String(data: data, encoding: .utf8) else {
            throw EPUBError.invalidXML
        }
        
        let pattern = #"full-path="([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            return String(content[range])
        }
        
        return "OEBPS/content.opf"
    }
    
    private func parseOPF(data: Data) throws -> EPUBMetadata {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw EPUBError.invalidXML
        }
        
        var metadata = EPUBMetadata()
        
        if let titleRange = content.range(of: #"<dc:title[^>]*>([^<]+)</dc:title>"#, options: .regularExpression) {
            let match = content[titleRange]
            if let colonIndex = match.lastIndex(of: '>') {
                metadata.title = String(match[match.index(after: colonIndex)...])
                    .replacingOccurrences(of: "</dc:title>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if let authorRange = content.range(of: #"<dc:creator[^>]*>([^<]+)</dc:creator>"#, options: .regularExpression) {
            let match = content[authorRange]
            if let colonIndex = match.lastIndex(of: '>') {
                metadata.author = String(match[match.index(after: colonIndex)...])
                    .replacingOccurrences(of: "</dc:creator>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if let descRange = content.range(of: #"<dc:description[^>]*>([^<]+)</dc:description>"#, options: .regularExpression) {
            let match = content[descRange]
            if let colonIndex = match.lastIndex(of: '>') {
                metadata.description = String(match[match.index(after: colonIndex)...])
                    .replacingOccurrences(of: "</dc:description>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if let langRange = content.range(of: #"<dc:language[^>]*>([^<]+)</dc:language>"#, options: .regularExpression) {
            let match = content[langRange]
            if let colonIndex = match.lastIndex(of: '>') {
                metadata.language = String(match[match.index(after: colonIndex)...])
                    .replacingOccurrences(of: "</dc:language>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if let pubRange = content.range(of: #"<dc:publisher[^>]*>([^<]+)</dc:publisher>"#, options: .regularExpression) {
            let match = content[pubRange]
            if let colonIndex = match.lastIndex(of: '>') {
                metadata.publisher = String(match[match.index(after: colonIndex)...])
                    .replacingOccurrences(of: "</dc:publisher>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        metadata.coverImagePath = extractCoverPath(from: content)
        
        return metadata
    }
    
    private func extractMetadata(data: Data) -> EPUBMetadata {
        return (try? parseOPF(data: data)) ?? EPUBMetadata()
    }
    
    private func extractCoverPath(from content: String) -> String? {
        let coverPatterns = [
            #"<item[^>]+properties=["']cover-image["'][^>]+href=["']([^"']+)["']"#,
            #"<item[^>]+href=["']([^"']+)["'][^>]+properties=["']cover-image["']"#,
            #"<meta[^>]+name=["']cover["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']cover["']"#
        ]
        
        for pattern in coverPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range])
            }
        }
        
        return nil
    }
    
    private func extractCoverFromOPF(data: Data) -> Data? {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }
        
        guard let coverPath = extractCoverPath(from: content) else { return nil }
        
        let fullPath = contentBasePath.isEmpty ? coverPath : "\(contentBasePath)/\(coverPath)"
        let normalizedPath = fullPath.replacingOccurrences(of: "//", with: "/")
        
        if let coverData = files[normalizedPath] {
            return coverData
        }
        
        let components = normalizedPath.components(separatedBy: "/")
        for i in 0..<components.count {
            let path = components[i...].joined(separator: "/")
            if let data = files[path] {
                return data
            }
        }
        
        return nil
    }
    
    private func parseChapters(data: Data) async throws -> [BookChapter] {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw EPUBError.invalidXML
        }
        
        var chapters: [BookChapter] = []
        
        let spinePattern = #"<itemref[^>]+idref=["']([^"']+)["']"#
        let manifestPattern = #"<item[^>]+id=["']([^"']+)["'][^>]+href=["']([^"']+)["'][^>]*/?"#
        let manifestPattern2 = #"<item[^>]+href=["']([^"']+)["'][^>]+id=["']([^"']+)["'][^>]*/?"#
        
        var itemIdToHref: [String: String] = [:]
        
        if let regex = try? NSRegularExpression(pattern: manifestPattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: content),
                   let hrefRange = Range(match.range(at: 2), in: content) {
                    let id = String(content[idRange])
                    let href = String(content[hrefRange])
                    itemIdToHref[id] = href
                }
            }
        }
        
        if let regex = try? NSRegularExpression(pattern: manifestPattern2) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            for match in matches {
                if let hrefRange = Range(match.range(at: 1), in: content),
                   let idRange = Range(match.range(at: 2), in: content) {
                    let href = String(content[hrefRange])
                    let id = String(content[idRange])
                    itemIdToHref[id] = href
                }
            }
        }
        
        var orderedHrefs: [String] = []
        if let regex = try? NSRegularExpression(pattern: spinePattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: content) {
                    let id = String(content[idRange])
                    if let href = itemIdToHref[id] {
                        orderedHrefs.append(href)
                    }
                }
            }
        }
        
        var offset = 0
        for href in orderedHrefs {
            let fullPath = contentBasePath.isEmpty ? href : "\(contentBasePath)/\(href)"
            let normalizedPath = fullPath.replacingOccurrences(of: "//", with: "/")
            
            if let chapterData = files[normalizedPath] ?? files[href] {
                let chapterContent = processChapterContent(data: chapterData, basePath: (normalizedPath as NSString).deletingLastPathComponent)
                if !chapterContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let title = extractChapterTitle(from: chapterContent) ?? "第 \(chapters.count + 1) 章"
                    chapters.append(BookChapter(title: title, content: chapterContent, level: 1, startOffset: offset))
                    offset += chapterContent.count
                }
            }
        }
        
        if chapters.isEmpty {
            chapters.append(BookChapter(title: "内容", content: "无法解析章节内容", level: 1, startOffset: 0))
        }
        
        return chapters
    }
    
    private func processChapterContent(data: Data, basePath: String) -> String {
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return ""
        }
        
        var content = html
        
        let bodyPattern = #"<body[^>]*>([\s\S]*?)</body>"#
        if let regex = try? NSRegularExpression(pattern: bodyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            content = String(content[range])
        }
        
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            content = regex.stringByReplacingMatches(in: content, range: NSRange(content.startIndex..., in: content), withTemplate: "")
        }
        
        content = content.replacingOccurrences(of: "&nbsp;", with: " ")
        content = content.replacingOccurrences(of: "&amp;", with: "&")
        content = content.replacingOccurrences(of: "&lt;", with: "<")
        content = content.replacingOccurrences(of: "&gt;", with: ">")
        content = content.replacingOccurrences(of: "&quot;", with: "\"")
        content = content.replacingOccurrences(of: "&#39;", with: "'")
        
        let lines = content.components(separatedBy: .newlines)
        content = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
        
        return content
    }
    
    private func extractChapterTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 2 && trimmed.count <= 50 && !trimmed.contains("。") {
                let chineseCount = trimmed.filter { $0 >= "\u{4E00}" && $0 <= "\u{9FFF}" }.count
                if chineseCount >= trimmed.count / 2 {
                    return trimmed
                }
            }
        }
        return nil
    }
    
    func getCoverImage(data: Data) -> Data? {
        return extractCover(data: data)
    }
}

enum EPUBError: Error, LocalizedError {
    case invalidFormat
    case invalidXML
    case opfNotFound
    case noContent
    case coverNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "无效的 EPUB 格式"
        case .invalidXML: return "无效的 XML 内容"
        case .opfNotFound: return "未找到 OPF 文件"
        case .noContent: return "未找到内容"
        case .coverNotFound: return "未找到封面图片"
        }
    }
}

class PDFReader: BookReaderProtocol {
    func read(data: Data) async throws -> BookContent {
        guard let document = PDFDocument(data: data) else {
            throw PDFError.invalidDocument
        }
        
        let metadata = extractMetadata(from: document)
        var chapters: [BookChapter] = []
        var offset = 0
        
        let pageCount = document.pageCount
        
        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let content = pageText.replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !content.isEmpty {
                    chapters.append(BookChapter(
                        title: "第 \(i + 1) 页",
                        content: content,
                        level: 1,
                        startOffset: offset
                    ))
                    offset += content.count
                }
            }
        }
        
        return BookContent(
            title: metadata.title,
            author: metadata.author,
            chapters: chapters.isEmpty ? [BookChapter(title: "PDF内容", content: "此PDF为扫描版，无法提取文本", level: 1, startOffset: 0)] : chapters,
            cover: nil,
            metadata: BookMetadata(
                title: metadata.title,
                author: metadata.author,
                publisher: metadata.publisher,
                description: metadata.description
            ),
            rawContent: chapters.map { $0.content }.joined(separator: "\n\n")
        )
    }
    
    func extractCover(data: Data) -> Data? {
        guard let document = PDFDocument(data: data),
              let firstPage = document.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            firstPage.draw(with: .mediaBox, to: ctx.cgContext)
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        guard let document = PDFDocument(data: data) else {
            return BookMetadata()
        }
        
        return extractMetadata(from: document)
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        return []
    }
    
    private func extractMetadata(from document: PDFDocument) -> BookMetadata {
        var metadata = BookMetadata()
        
        if let attributes = document.documentAttributes {
            if let title = attributes[PDFDocumentAttribute.titleAttribute] as? String {
                metadata.title = title
            }
            if let author = attributes[PDFDocumentAttribute.authorAttribute] as? String {
                metadata.author = author
            }
            if let creator = attributes[PDFDocumentAttribute.creatorAttribute] as? String {
                if metadata.author.isEmpty {
                    metadata.author = creator
                }
            }
            if let subject = attributes[PDFDocumentAttribute.subjectAttribute] as? String {
                metadata.description = subject
            }
            if let producer = attributes[PDFDocumentAttribute.producerAttribute] as? String {
                metadata.publisher = producer
            }
        }
        
        if metadata.title.isEmpty {
            metadata.title = "未命名 PDF"
        }
        
        return metadata
    }
}

enum PDFError: Error, LocalizedError {
    case invalidDocument
    case extractionFailed
    case pageNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidDocument: return "无效的 PDF 文档"
        case .extractionFailed: return "PDF 内容提取失败"
        case .pageNotFound: return "未找到 PDF 页面"
        }
    }
}

class DOCXReader: BookReaderProtocol {
    private var files: [String: Data] = [:]
    
    func read(data: Data) async throws -> BookContent {
        files = try await unzipDOCX(data: data)
        
        guard let documentXML = files["word/document.xml"] else {
            throw DOCXError.invalidFormat
        }
        
        let metadata = extractMetadata()
        let content = try extractContent(from: documentXML)
        let chapters = parseChapters(from: content)
        
        return BookContent(
            title: metadata.title,
            author: metadata.author,
            chapters: chapters,
            cover: nil,
            metadata: BookMetadata(
                title: metadata.title,
                author: metadata.author
            ),
            rawContent: content
        )
    }
    
    func extractCover(data: Data) -> Data? {
        Task {
            files = (try? await unzipDOCX(data: data)) ?? [:]
        }
        
        if let mediaFiles = try? FileManager.default.contentsOfDirectory(atPath: ""),
           let coverPath = mediaFiles.first(where: { $0.contains("image") && ($0.hasSuffix(".jpg") || $0.hasSuffix(".png")) }) {
            return files[coverPath]
        }
        
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        Task {
            files = (try? await unzipDOCX(data: data)) ?? [:]
        }
        return extractMetadata()
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        return []
    }
    
    private func unzipDOCX(data: Data) async throws -> [String: Data] {
        var result: [String: Data] = [:]
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        guard let extractedFiles = try? await ArchiveManager.shared.extractArchive(at: data, to: tempDir) else {
            return try extractZIPManually(data: data)
        }
        
        for fileURL in extractedFiles {
            let relativePath = fileURL.path.replacingOccurrences(of: tempDir.path + "/", with: "")
            if let fileData = try? Data(contentsOf: fileURL) {
                result[relativePath] = fileData
            }
        }
        
        return result
    }
    
    private func extractZIPManually(data: Data) throws -> [String: Data] {
        var result: [String: Data] = [:]
        var offset = 0
        
        while offset < data.count - 4 {
            guard offset + 4 <= data.count else { break }
            let signature = [UInt8](data[offset..<offset+4])
            
            if signature == [0x50, 0x4B, 0x03, 0x04] {
                guard offset + 30 <= data.count else { break }
                
                let compressionMethod = Int(data[offset+8]) | (Int(data[offset+9]) << 8)
                let nameLength = Int(data[offset+26]) | (Int(data[offset+27]) << 8)
                let extraLength = Int(data[offset+28]) | (Int(data[offset+29]) << 8)
                let compressedSize = Int(data[offset+18]) | (Int(data[offset+19]) << 8) |
                                   (Int(data[offset+20]) << 16) | (Int(data[offset+21]) << 24)
                
                let nameStart = offset + 30
                let nameEnd = nameStart + nameLength
                
                guard nameEnd <= data.count else { break }
                
                let nameData = data[nameStart..<nameEnd]
                guard let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1) else {
                    offset = nameEnd + extraLength + compressedSize
                    continue
                }
                
                let dataStart = nameEnd + extraLength
                let dataEnd = dataStart + compressedSize
                
                guard dataEnd <= data.count else { break }
                
                let compressedData = data[dataStart..<dataEnd]
                
                var decompressedData: Data?
                if compressionMethod == 0 {
                    decompressedData = Data(compressedData)
                } else if compressionMethod == 8 {
                    decompressedData = decompressDeflate(Data(compressedData))
                }
                
                if let content = decompressedData {
                    result[name] = content
                }
                
                offset = dataEnd
            } else if signature == [0x50, 0x4B, 0x05, 0x06] || signature == [0x50, 0x4B, 0x06, 0x06] {
                break
            } else {
                offset += 1
            }
        }
        
        return result
    }
    
    private func decompressDeflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        return try? (data as NSData).decompressed(using: .lzfse)
    }
    
    private func extractMetadata() -> (title: String, author: String) {
        var title = ""
        var author = ""
        
        if let appXML = files["docProps/app.xml"],
           let content = String(data: appXML, encoding: .utf8) {
            
            if let titleRange = content.range(of: #"<dc:title[^>]*>([^<]+)</dc:title>"#, options: .regularExpression) {
                let match = content[titleRange]
                if let colonIndex = match.lastIndex(of: '>') {
                    title = String(match[match.index(after: colonIndex)...])
                        .replacingOccurrences(of: "</dc:title>", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            if let authorRange = content.range(of: #"<dc:creator[^>]*>([^<]+)</dc:creator>"#, options: .regularExpression) {
                let match = content[authorRange]
                if let colonIndex = match.lastIndex(of: '>') {
                    author = String(match[match.index(after: colonIndex)...])
                        .replacingOccurrences(of: "</dc:creator>", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        if title.isEmpty {
            title = "未命名文档"
        }
        
        return (title, author)
    }
    
    private func extractContent(from xmlData: Data) throws -> String {
        guard let xml = String(data: xmlData, encoding: .utf8) ?? String(data: xmlData, encoding: .isoLatin1) else {
            throw DOCXError.invalidXML
        }
        
        var content = ""
        
        let paraPattern = #"<w:p[\s\S]*?</w:p>"#
        if let regex = try? NSRegularExpression(pattern: paraPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            
            for match in matches {
                if let range = Range(match.range, in: xml) {
                    let paraXML = String(xml[range])
                    let text = extractTextFromParagraph(paraXML)
                    if !text.isEmpty {
                        content += text + "\n"
                    }
                }
            }
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractTextFromParagraph(_ paraXML: String) -> String {
        var text = ""
        
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: paraXML, range: NSRange(paraXML.startIndex..., in: paraXML))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: paraXML) {
                    text += String(paraXML[range])
                }
            }
        }
        
        return text.trimmingCharacters(in: .whitespaces)
    }
    
    private func parseChapters(from content: String) -> [BookChapter] {
        var chapters: [BookChapter] = []
        let lines = content.components(separatedBy: "\n")
        
        var currentChapter = ""
        var currentContent = ""
        var offset = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.count >= 2 && trimmed.count <= 100 {
                let chineseCount = trimmed.filter { $0 >= "\u{4E00}" && $0 <= "\u{9FFF}" }.count
                let headingChars = trimmed.filter { "一二三四五六七八九十百千".contains($0) }
                
                if (chineseCount >= trimmed.count * 0.5 && (trimmed.hasPrefix("第") || trimmed.hasPrefix("第") || headingChars.count >= 2)) ||
                   trimmed.range(of: #"^[0-9零一二三四五六七八九十]+[.、\s]"#, options: .regularExpression) != nil {
                    
                    if !currentContent.isEmpty {
                        chapters.append(BookChapter(
                            title: currentChapter.isEmpty ? "第一章" : currentChapter,
                            content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                            level: 1,
                            startOffset: offset
                        ))
                        offset += currentContent.count
                    }
                    
                    currentChapter = trimmed
                    currentContent = ""
                    continue
                }
            }
            
            currentContent += trimmed + "\n"
        }
        
        if !currentContent.isEmpty {
            chapters.append(BookChapter(
                title: currentChapter.isEmpty ? "内容" : currentChapter,
                content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                level: 1,
                startOffset: offset
            ))
        }
        
        if chapters.isEmpty && !content.isEmpty {
            chapters.append(BookChapter(
                title: "正文",
                content: content,
                level: 1,
                startOffset: 0
            ))
        }
        
        return chapters
    }
}

enum DOCXError: Error, LocalizedError {
    case invalidFormat
    case invalidXML
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "无效的 DOCX 格式"
        case .invalidXML: return "无效的 XML 内容"
        case .noContent: return "未找到文档内容"
        }
    }
}

extension Data {
    func detectEncoding() -> String.Encoding {
        if starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8
        }
        if starts(with: [0xFF, 0xFE]) {
            return .utf16LittleEndian
        }
        if starts(with: [0xFE, 0xFF]) {
            return .utf16BigEndian
        }
        if starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            return .utf32BigEndian
        }
        if starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return .utf32LittleEndian
        }
        
        let windows1252Count = filter {
            ($0 >= 0x20 && $0 <= 0x7E) || 
            ($0 >= 0x80 && $0 <= 0x9F) || 
            ($0 >= 0xA0 && $0 <= 0xFF)
        }.count
        
        let gb2312Count = filter {
            ($0 >= 0xB0 && $0 <= 0xF7) || 
            (($0 >= 0xA1 && $0 <= 0xFE) && count > 1)
        }.count
        
        let utf8ValidCount = validateUTF8()
        
        let windows1252Ratio = Double(windows1252Count) / Double(count)
        let utf8Ratio = Double(utf8ValidCount) / Double(count)
        let gb2312Ratio = Double(gb2312Count) / Double(count)
        
        if utf8Ratio > 0.95 {
            return .utf8
        }
        
        if gb2312Ratio > 0.5 {
            return .gbk
        }
        
        if windows1252Ratio > 0.9 {
            return .windowsCP1252
        }
        
        return .utf8
    }
    
    private func validateUTF8() -> Int {
        var validCount = 0
        var index = 0
        
        while index < count {
            let byte = self[index]
            
            if (byte & 0x80) == 0 {
                validCount += 1
                index += 1
            } else if (byte & 0xE0) == 0xC0 {
                if index + 1 < count {
                    validCount += 2
                }
                index += 2
            } else if (byte & 0xF0) == 0xE0 {
                if index + 2 < count {
                    validCount += 3
                }
                index += 3
            } else if (byte & 0xF8) == 0xF0 {
                if index + 3 < count {
                    validCount += 4
                }
                index += 4
            } else {
                index += 1
            }
        }
        
        return validCount
    }
    
    func toString(encoding: String.Encoding = .utf8) -> String {
        if let string = String(data: self, encoding: encoding) {
            return string
        }
        
        if encoding != .windowsCP1252, let string = String(data: self, encoding: .windowsCP1252) {
            return string
        }
        
        if encoding != .gbk, let string = String(data: self, encoding: .gbk) {
            return string
        }
        
        return String(data: self, encoding: .utf8) ?? ""
    }
}

extension String.Encoding {
    static let gbk = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    static let big5 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
    static let shiftJIS = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.ShiftJIS.rawValue)))
}

class BookEncodingDetector {
    static func detectEncoding(data: Data) -> String.Encoding {
        return data.detectEncoding()
    }
    
    static func detectCharsetName(data: Data) -> String {
        let encoding = data.detectEncoding()
        
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16LittleEndian: return "UTF-16LE"
        case .utf16BigEndian: return "UTF-16BE"
        case .utf32LittleEndian: return "UTF-32LE"
        case .utf32BigEndian: return "UTF-32BE"
        case .windowsCP1252: return "Windows-1252"
        case .gbk: return "GBK/GB2312"
        case .big5: return "Big5"
        default: return "UTF-8"
        }
    }
    
    static func convertToUTF8(data: Data) -> Data? {
        let encoding = detectEncoding(data: data)
        guard let string = String(data: data, encoding: encoding) else { return nil }
        return string.data(using: .utf8)
    }
}
