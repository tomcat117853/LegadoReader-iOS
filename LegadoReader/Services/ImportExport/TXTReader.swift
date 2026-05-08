import Foundation

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
    func read(data: Data) async throws -> BookContent {
        let unzipped = try await unzip(data: data)
        let content = try extractContent(from: unzipped)
        
        return BookContent(title: "", author: "", chapters: [BookChapter(title: "正文", content: content)])
    }
    
    func extractCover(data: Data) -> Data? {
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        return BookMetadata()
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        return []
    }
    
    private func unzip(data: Data) async throws -> [String: Data] {
        return [:]
    }
    
    private func extractContent(from files: [String: Data]) throws -> String {
        return ""
    }
}

class PDFReader: BookReaderProtocol {
    func read(data: Data) async throws -> BookContent {
        return BookContent(title: "", author: "", chapters: [BookChapter(title: "正文", content: "")])
    }
    
    func extractCover(data: Data) -> Data? {
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        return BookMetadata()
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        return []
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
