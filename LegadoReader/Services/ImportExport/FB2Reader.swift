import Foundation
import XMLCoder

class FB2Reader: BookReaderProtocol {
    private struct FictionBook: Codable {
        var description: Description?
        var body: Body?
        
        struct Description: Codable {
            var titleInfo: TitleInfo?
            var documentInfo: DocumentInfo?
            
            struct TitleInfo: Codable {
                var bookTitle: String?
                var author: [Author]?
                var annotation: String?
                var keywords: String?
                var lang: String?
                
                struct Author: Codable {
                    var firstName: String?
                    var lastName: String?
                    
                    var fullName: String {
                        return [firstName, lastName].compactMap { $0 }.joined(separator: " ")
                    }
                }
            }
            
            struct DocumentInfo: Codable {
                var author: [Author]?
                var programUsed: String?
                var date: String?
                var sourceURL: String?
                
                struct Author: Codable {
                    var firstName: String?
                    var lastName: String?
                }
            }
        }
        
        struct Body: Codable {
            var sections: [Section]?
            
            struct Section: Codable {
                var title: Title?
                var paragraphs: [Paragraph]?
                var sections: [Section]?
                
                struct Title: Codable {
                    var paragraphs: [Paragraph]?
                    
                    var text: String {
                        return paragraphs?.map { $0.text }.joined() ?? ""
                    }
                }
                
                struct Paragraph: Codable {
                    var text: String
                    
                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        text = try container.decode(String.self)
                    }
                }
            }
        }
    }
    
    private var fictionBook: FictionBook?
    
    func read(data: Data) async throws -> BookContent {
        fictionBook = try parseFB2(data: data)
        
        let metadata = getMetadata(data: data)
        let chapters = getTableOfContents(data: data)
        let content = chapters.map { $0.content }.joined("\n\n")
        
        return BookContent(
            title: metadata.title,
            author: metadata.author,
            chapters: chapters,
            cover: extractCover(data: data),
            metadata: metadata,
            rawContent: content
        )
    }
    
    func extractCover(data: Data) -> Data? {
        if let base64Image = extractBase64Image(from: data) {
            return Data(base64Encoded: base64Image)
        }
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        var metadata = BookMetadata()
        
        guard let book = fictionBook else {
            return parseMetadataFromXML(data: data)
        }
        
        if let titleInfo = book.description?.titleInfo {
            metadata.title = titleInfo.bookTitle ?? ""
            metadata.author = titleInfo.author?.first?.fullName ?? ""
            metadata.description = titleInfo.annotation ?? ""
            metadata.language = titleInfo.lang ?? ""
            if let keywords = titleInfo.keywords {
                metadata.tags = keywords.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        
        return metadata
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        guard let book = fictionBook else {
            return parseChaptersFromXML(data: data)
        }
        
        var chapters: [BookChapter] = []
        var offset = 0
        
        if let sections = book.body?.sections {
            for section in sections {
                chapters.append(contentsOf: extractChapters(from: section, level: 1, offset: &offset))
            }
        }
        
        if chapters.isEmpty {
            let content = extractTextContent(from: data)
            chapters.append(BookChapter(title: "正文", content: content))
        }
        
        return chapters
    }
    
    private func parseFB2(data: Data) throws -> FictionBook {
        let decoder = XMLDecoder()
        decoder.keyDecodingStrategy = .custom { codingPath in
            let lastComponent = codingPath.last?.stringValue ?? ""
            if lastComponent.hasPrefix("l:") {
                return CodingKey(stringValue: lastComponent.replacingOccurrences(of: "l:", with: ""))!
            }
            return CodingKey(stringValue: lastComponent)!
        }
        
        return try decoder.decode(FictionBook.self, from: data)
    }
    
    private func parseMetadataFromXML(data: Data) -> BookMetadata {
        var metadata = BookMetadata()
        
        guard let xmlString = String(data: data, encoding: .utf8) else { return metadata }
        
        if let match = xmlString.range(of: "<book-title>([^<]+)</book-title>", options: .regularExpression) {
            metadata.title = String(xmlString[match].dropFirst(12).dropLast(13))
        }
        
        if let match = xmlString.range(of: "<first-name>([^<]+)</first-name>", options: .regularExpression) {
            let firstName = String(xmlString[match].dropFirst(12).dropLast(14))
            if let match = xmlString.range(of: "<last-name>([^<]+)</last-name>", options: .regularExpression) {
                let lastName = String(xmlString[match].dropFirst(11).dropLast(12))
                metadata.author = firstName + " " + lastName
            } else {
                metadata.author = firstName
            }
        }
        
        if let match = xmlString.range(of: "<annotation>([^<]+)</annotation>", options: .regularExpression) {
            metadata.description = String(xmlString[match].dropFirst(12).dropLast(13))
        }
        
        return metadata
    }
    
    private func parseChaptersFromXML(data: Data) -> [BookChapter] {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            return [BookChapter(title: "正文", content: "")]
        }
        
        var chapters: [BookChapter] = []
        let pattern = "<section.*?>(.*?)</section>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let matches = regex?.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
        
        for match in matches ?? [] {
            let range = Range(match.range, in: xmlString)!
            let sectionContent = String(xmlString[range])
            
            var title = ""
            if let titleMatch = sectionContent.range(of: "<title>([^<]+)</title>", options: .regularExpression) {
                title = String(sectionContent[titleMatch].dropFirst(7).dropLast(8))
            }
            
            let content = sectionContent
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !content.isEmpty {
                chapters.append(BookChapter(title: title.isEmpty ? "章节" : title, content: content))
            }
        }
        
        if chapters.isEmpty {
            let content = xmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            chapters.append(BookChapter(title: "正文", content: content))
        }
        
        return chapters
    }
    
    private func extractChapters(from section: FictionBook.Body.Section, level: Int, offset: inout Int) -> [BookChapter] {
        var chapters: [BookChapter] = []
        
        let title = section.title?.text ?? ""
        let content = section.paragraphs?.map { $0.text }.joined("\n") ?? ""
        
        if !content.isEmpty || !title.isEmpty {
            chapters.append(BookChapter(
                title: title.isEmpty ? "章节" : title,
                content: content,
                level: level,
                startOffset: offset
            ))
            offset += content.count
        }
        
        if let subSections = section.sections {
            for subSection in subSections {
                chapters.append(contentsOf: extractChapters(from: subSection, level: level + 1, offset: &offset))
            }
        }
        
        return chapters
    }
    
    private func extractBase64Image(from data: Data) -> String? {
        guard let xmlString = String(data: data, encoding: .utf8) else { return nil }
        
        let pattern = "<binary.*?encoding=\"base64\">(.*?)</binary>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            if let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)) {
                let range = Range(match.range(at: 1), in: xmlString)!
                return String(xmlString[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    private func extractTextContent(from data: Data) -> String {
        guard let xmlString = String(data: data, encoding: .utf8) else { return "" }
        return xmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

class CHMReader: BookReaderProtocol {
    func read(data: Data) async throws -> BookContent {
        let content = extractHTMLContent(from: data)
        return BookContent(title: "", author: "", chapters: [BookChapter(title: "正文", content: content)])
    }
    
    func extractCover(data: Data) -> Data? {
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        return BookMetadata()
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        let content = extractHTMLContent(from: data)
        return parseChapters(content)
    }
    
    private func extractHTMLContent(from data: Data) -> String {
        if let xmlString = String(data: data, encoding: .utf8) {
            return xmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        return ""
    }
    
    private func parseChapters(_ content: String) -> [BookChapter] {
        let lines = content.components(separatedBy: .newlines)
        var chapters: [BookChapter] = []
        var currentChapter = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !currentChapter.isEmpty {
                    chapters.append(BookChapter(title: "章节", content: currentChapter))
                    currentChapter = ""
                }
            } else {
                currentChapter += trimmed + "\n"
            }
        }
        
        if !currentChapter.isEmpty {
            chapters.append(BookChapter(title: "章节", content: currentChapter))
        }
        
        return chapters.isEmpty ? [BookChapter(title: "正文", content: content)] : chapters
    }
}

class RTFReader: BookReaderProtocol {
    func read(data: Data) async throws -> BookContent {
        let text = convertRTFToText(data: data)
        return BookContent(title: "", author: "", chapters: [BookChapter(title: "正文", content: text)])
    }
    
    func extractCover(data: Data) -> Data? {
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        return BookMetadata()
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        let text = convertRTFToText(data: data)
        return parseChapters(text)
    }
    
    private func convertRTFToText(data: Data) -> String {
        guard let rtfString = String(data: data, encoding: .utf8) else { return "" }
        
        var text = rtfString
        text = text.replacingOccurrences(of: "\\\\[a-zA-Z]+[^}]*", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\{[^}]*\\}", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\\\", with: "")
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseChapters(_ content: String) -> [BookChapter] {
        let lines = content.components(separatedBy: "\n")
        var chapters: [BookChapter] = []
        var currentChapter = ""
        
        for line in lines {
            if line.hasPrefix("Chapter") || line.hasPrefix("CHAPTER") || line.hasPrefix("第") {
                if !currentChapter.isEmpty {
                    chapters.append(BookChapter(title: "章节", content: currentChapter))
                    currentChapter = ""
                }
            }
            currentChapter += line + "\n"
        }
        
        if !currentChapter.isEmpty {
            chapters.append(BookChapter(title: "章节", content: currentChapter))
        }
        
        return chapters.isEmpty ? [BookChapter(title: "正文", content: content)] : chapters
    }
}

class HTMLReader: BookReaderProtocol {
    func read(data: Data) async throws -> BookContent {
        let text = convertHTMLToText(data: data)
        return BookContent(title: "", author: "", chapters: [BookChapter(title: "正文", content: text)])
    }
    
    func extractCover(data: Data) -> Data? {
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        var metadata = BookMetadata()
        
        guard let htmlString = String(data: data, encoding: .utf8) else { return metadata }
        
        if let match = htmlString.range(of: "<title>([^<]+)</title>", options: .regularExpression) {
            metadata.title = String(htmlString[match].dropFirst(7).dropLast(8))
        }
        
        return metadata
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        let text = convertHTMLToText(data: data)
        return parseChapters(text)
    }
    
    private func convertHTMLToText(data: Data) -> String {
        guard let htmlString = String(data: data, encoding: .utf8) else { return "" }
        
        var text = htmlString
        text = text.replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: [.regularExpression, .dotMatchesLineSeparators])
        text = text.replacingOccurrences(of: "<style[^>]*>.*?</style>", with: "", options: [.regularExpression, .dotMatchesLineSeparators])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseChapters(_ content: String) -> [BookChapter] {
        let lines = content.components(separatedBy: "\n")
        var chapters: [BookChapter] = []
        var currentChapter = ""
        var currentTitle = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.count > 0 && trimmed.count < 50 && trimmed.uppercased() == trimmed {
                if !currentChapter.isEmpty {
                    chapters.append(BookChapter(title: currentTitle.isEmpty ? "章节" : currentTitle, content: currentChapter))
                    currentChapter = ""
                }
                currentTitle = trimmed
            } else {
                currentChapter += trimmed + "\n"
            }
        }
        
        if !currentChapter.isEmpty {
            chapters.append(BookChapter(title: currentTitle.isEmpty ? "正文" : currentTitle, content: currentChapter))
        }
        
        return chapters.isEmpty ? [BookChapter(title: "正文", content: content)] : chapters
    }
}
