import Foundation
import UIKit
import ZIPFoundation

class EPUBParser: NSObject {
    static let shared = EPUBParser()
    
    struct EPUBBook {
        var metadata: EPUBMetadata
        var spine: [EPUBSpineItem]
        var manifest: [String: EPUBManifestItem]
        var chapters: [EPUBChapter]
        var stylesheets: [CSSParser.ParsedCSS]
        var coverImage: Data?
        var baseURL: URL?
    }
    
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
    
    struct EPUBChapter {
        var id: String
        var title: String
        var content: String
        var href: String
        var level: Int
        var rawHTML: String
    }
    
    func parse(data: Data) async throws -> EPUBBook {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.parseSync(data: data)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseSync(data: Data) throws -> EPUBBook {
        var book = EPUBBook(
            metadata: EPUBMetadata(),
            spine: [],
            manifest: [:],
            chapters: [],
            stylesheets: [],
            coverImage: nil
        )
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        try data.write(to: tempDir.appendingPathComponent("book.epub"))
        
        try FileManager.default.unzipItem(at: tempDir.appendingPathComponent("book.epub"), to: tempDir)
        
        book.baseURL = tempDir
        
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        if FileManager.default.fileExists(atPath: containerPath.path) {
            let containerData = try Data(contentsOf: containerPath)
            let rootfilePath = try parseContainerXML(containerData)
                
            let opfPath = tempDir.appendingPathComponent(rootfilePath)
            let opfData = try Data(contentsOf: opfPath)
            let opfBaseURL = opfPath.deletingLastPathComponent()
            
            try parseOPF(data: opfData, baseURL: opfBaseURL, into: &book)
        }
        
        for spineItem in book.spine {
            if let manifestItem = book.manifest[spineItem.idref] {
                let contentPath = tempDir.appendingPathComponent(manifestItem.href)
                if FileManager.default.fileExists(atPath: contentPath.path) {
                    let contentData = try Data(contentsOf: contentPath)
                    let chapter = try parseChapter(
                        data: contentData,
                        href: manifestItem.href,
                        stylesheets: book.stylesheets,
                        baseURL: tempDir
                    )
                    book.chapters.append(chapter)
                }
            }
        }
        
        return book
    }
    
    private func parseContainerXML(_ data: Data) throws -> String {
        guard let content = String(data: data, encoding: .utf8) else {
            throw EPUBParseError.invalidContainer
        }
        
        let pattern = "full-path=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            throw EPUBParseError.invalidContainer
        }
        
        let range = NSRange(content.startIndex..., in: content)
        if let match = regex.firstMatch(in: content, options: [], range: range),
           let pathRange = Range(match.range(at: 1), in: content) {
            return String(content[pathRange])
        }
        
        throw EPUBParseError.invalidContainer
    }
    
    private func parseOPF(data: Data, baseURL: URL, into book: inout EPUBBook) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw EPUBParseError.invalidOPF
        }
        
        let metadataPattern = "<dc:([^>]+)>([^<]*)</dc:\\1>"
        if let metadataRegex = try? NSRegularExpression(pattern: metadataPattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = metadataRegex.matches(in: content, options: [], range: range)
            
            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: content),
                   let valueRange = Range(match.range(at: 2), in: content) {
                    let name = String(content[nameRange]).lowercased()
                    let value = String(content[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    switch name {
                    case "title": book.metadata.title = value
                    case "creator": book.metadata.author = value
                    case "language": book.metadata.language = value
                    case "identifier": book.metadata.identifier = value
                    case "publisher": book.metadata.publisher = value
                    case "description": book.metadata.description = value
                    case "date": book.metadata.date = value
                    default: break
                    }
                }
            }
        }
        
        let coverMetaPattern = "<meta[^>]+name=\"cover\"[^>]+content=\"([^\"]+)\""
        if let coverRegex = try? NSRegularExpression(pattern: coverMetaPattern, options: .caseInsensitive) {
            let range = NSRange(content.startIndex..., in: content)
            if let match = coverRegex.firstMatch(in: content, options: [], range: range),
               let idRange = Range(match.range(at: 1), in: content) {
                book.metadata.coverImageId = String(content[idRange])
            }
        }
        
        let manifestItemPattern = "<item[^>]+id=\"([^\"]+)\"[^>]+href=\"([^\"]+)\"[^>]+media-type=\"([^\"]+)\""
        let manifestItemAltPattern = "<item[^>]+href=\"([^\"]+)\"[^>]+id=\"([^\"]+)\"[^>]+media-type=\"([^\"]+)\""
        
        if let regex = try? NSRegularExpression(pattern: manifestItemPattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: content),
                   let hrefRange = Range(match.range(at: 2), in: content),
                   let typeRange = Range(match.range(at: 3), in: content) {
                    let id = String(content[idRange])
                    let href = String(content[hrefRange])
                    let mediaType = String(content[typeRange])
                    
                    var properties: String? = nil
                    if let propMatch = content.range(of: "properties=\"([^\"]+)\"", range: Range(match.range, in: content)!) {
                        let propString = String(content[propMatch])
                        properties = propString.replacingOccurrences(of: "properties=\"", with: "")
                            .replacingOccurrences(of: "\"", with: "")
                    }
                    
                    let item = EPUBManifestItem(id: id, href: href, mediaType: mediaType, properties: properties)
                    book.manifest[id] = item
                    
                    if mediaType.starts(with: "text/css") || href.hasSuffix(".css") {
                        let cssPath = baseURL.appendingPathComponent(href)
                        if let cssData = try? Data(contentsOf: cssPath),
                           let cssString = String(data: cssData, encoding: .utf8) {
                            let parsedCSS = CSSParser.shared.parse(cssString)
                            book.stylesheets.append(parsedCSS)
                        }
                    }
                }
            }
        }
        
        let spineItemPattern = "<itemref[^>]+idref=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: spineItemPattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: content) {
                    let idref = String(content[idRange])
                    var linear = true
                    
                    if let linearMatch = content.range(of: "linear=\"no\"", range: Range(match.range, in: content)!) {
                        linear = false
                    }
                    
                    book.spine.append(EPUBSpineItem(idref: idref, linear: linear))
                }
            }
        }
    }
    
    private func parseChapter(data: Data, href: String, stylesheets: [CSSParser.ParsedCSS], baseURL: URL) throws -> EPUBChapter {
        guard let htmlContent = String(data: data, encoding: .utf8) else {
            throw EPUBParseError.invalidChapter
        }
        
        let title = extractTitle(from: htmlContent)
        let processedHTML = processHTML(htmlContent, baseURL: baseURL)
        
        return EPUBChapter(
            id: href,
            title: title,
            content: processedHTML,
            href: href,
            level: 1,
            rawHTML: htmlContent
        )
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
        
        return "Chapter"
    }
    
    private func processHTML(_ html: String, baseURL: URL) -> String {
        var processed = html
        
        processed = processed.replacingOccurrences(of: "<head>[\\s\\S]*?</head>", with: "", options: .regularExpression)
        
        processed = processed.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        
        processed = processed.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        
        return processed
    }
    
    func extractCover(from book: EPUBBook) -> Data? {
        if let coverId = book.metadata.coverImageId,
           let manifestItem = book.manifest[coverId],
           let baseURL = book.baseURL {
            let coverPath = baseURL.appendingPathComponent(manifestItem.href)
            return try? Data(contentsOf: coverPath)
        }
        
        for (_, item) in book.manifest {
            if item.properties?.contains("cover-image") == true,
               let baseURL = book.baseURL {
                let coverPath = baseURL.appendingPathComponent(item.href)
                return try? Data(contentsOf: coverPath)
            }
        }
        
        for (_, item) in book.manifest {
            if item.mediaType.starts(with: "image/") && item.id.lowercased().contains("cover") {
                if let baseURL = book.baseURL {
                    let coverPath = baseURL.appendingPathComponent(item.href)
                    return try? Data(contentsOf: coverPath)
                }
            }
        }
        
        return nil
    }
}

class EPUBParseError: Error, LocalizedError {
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
