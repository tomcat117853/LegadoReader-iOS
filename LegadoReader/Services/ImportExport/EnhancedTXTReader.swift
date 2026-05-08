import Foundation

class EnhancedTXTReader: BookReaderProtocol {
    private var detectedEncoding: String.Encoding = .utf8
    private var textContent: String = ""
    private let titleSegmentation = TitleSegmentationManager.shared
    
    struct EnhancedParseResult {
        var title: String
        var author: String?
        var intro: String?
        var volumes: [VolumeInfo]
        var chapters: [ChapterInfo]
        var rawContent: String
        var metadata: [String: String]
        var warnings: [String]
        
        struct VolumeInfo: Identifiable {
            var id: String
            var title: String
            var startLine: Int
            var endLine: Int
            var level: Int
            var chapterIndices: [Int]
        }
        
        struct ChapterInfo: Identifiable {
            var id: String
            var title: String
            var originalTitle: String
            var startLine: Int
            var endLine: Int
            var level: Int
            var formattedTitle: String
        }
    }
    
    private let chapterPatterns: [ChapterPattern] = [
        ChapterPattern(
            pattern: "^第([零一二三四五六七八九十百千万\\d]+)章\\s*[:：]?\\s*(.*)$",
            type: .chapter,
            priority: 100,
            description: "第X章格式"
        ),
        ChapterPattern(
            pattern: "^第([\\d]+)章\\s*[:：]?\\s*(.*)$",
            type: .chapter,
            priority: 95,
            description: "第数字章格式"
        ),
        ChapterPattern(
            pattern: "^【([^】]+)】\\s*(.*)$",
            type: .volume,
            priority: 90,
            description: "【卷名】格式"
        ),
        ChapterPattern(
            pattern: "^(卷|部|篇|集)\\s*([零一二三四五六七八九十百千万\\d]+)[:：]?\\s*(.*)$",
            type: .volume,
            priority: 85,
            description: "卷/部/篇/集格式"
        ),
        ChapterPattern(
            pattern: "^Chapter\\s*([\\d]+)[:：\\.\\s]*(.*)$",
            type: .chapter,
            priority: 80,
            description: "Chapter格式"
        ),
        ChapterPattern(
            pattern: "^CHAPTER\\s*([\\d]+)[:：\\.\\s]*(.*)$",
            type: .chapter,
            priority: 75,
            description: "CHAPTER格式"
        ),
        ChapterPattern(
            pattern: "^第([\\d]+)节\\s*[:：]?\\s*(.*)$",
            type: .section,
            priority: 70,
            description: "第X节格式"
        ),
        ChapterPattern(
            pattern: "^(\\d+)[:\\.\\s]+(.*)$",
            type: .chapter,
            priority: 60,
            description: "数字.标题格式"
        ),
        ChapterPattern(
            pattern: "^[【\\[【]([^】\\]]+)[】\\]]\\s*(.*)$",
            type: .section,
            priority: 55,
            description: "【标题】或[标题]格式"
        ),
        ChapterPattern(
            pattern: "^[零一二三四五六七八九十]+[、\\.]\\s*(.*)$",
            type: .section,
            priority: 50,
            description: "一、二、三格式"
        )
    ]
    
    struct ChapterPattern {
        let pattern: String
        let type: ChapterType
        let priority: Int
        let description: String
        
        enum ChapterType {
            case volume
            case chapter
            case section
        }
    }
    
    private let introPatterns: [String] = [
        "^简介\\s*$",
        "^内容简介\\s*$",
        "^小说简介\\s*$",
        "^故事简介\\s*$",
        "^书籍简介\\s*$",
        "^作品简介\\s*$",
        "^\\s*内容介绍\\s*$",
        "^\\s*介绍\\s*$",
        "^【简介】",
        "^【内容简介】",
        "^\\[简介\\]",
        "^文案\\s*$",
        "^作品文案\\s*$"
    ]
    
    private let authorPatterns: [String] = [
        "^作者\\s*[:：]\\s*(.+)$",
        "^Author\\s*[:：]\\s*(.+)$",
        "^\\s*作者[：:]\\s*(.+)$",
        "^\\s*\\[作者\\]\\s*(.+)$",
        "^(.+)◎著$",
        "^(.+)著$",
        "^(.+)\\s+著$"
    ]
    
    func read(data: Data) async throws -> BookContent {
        detectedEncoding = data.detectEncoding()
        textContent = data.toString(encoding: detectedEncoding)
        
        let result = parseEnhanced(textContent)
        
        let chapters = result.chapters.map { chapterInfo in
            BookChapter(
                title: chapterInfo.formattedTitle,
                content: extractChapterContent(from: textContent, startLine: chapterInfo.startLine, endLine: chapterInfo.endLine),
                startOffset: 0
            )
        }
        
        return BookContent(
            title: result.title,
            author: result.author,
            chapters: chapters,
            cover: nil,
            metadata: parseMetadata(result),
            rawContent: result.rawContent
        )
    }
    
    func extractCover(data: Data) -> Data? {
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        let text = data.toString(encoding: data.detectEncoding())
        let result = parseEnhanced(text)
        
        var metadata = BookMetadata()
        metadata.title = result.title
        metadata.author = result.author
        return metadata
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        let text = data.toString(encoding: data.detectEncoding())
        let result = parseEnhanced(text)
        
        return result.chapters.map { chapterInfo in
            BookChapter(
                title: chapterInfo.formattedTitle,
                content: "",
                startOffset: 0
            )
        }
    }
    
    func parseEnhanced(_ content: String) -> EnhancedParseResult {
        var warnings: [String] = []
        var lines = content.components(separatedBy: .newlines)
        
        let title = extractTitle(from: &lines, warnings: &warnings)
        let author = extractAuthor(from: lines)
        let intro = extractIntro(from: lines)
        
        let (chapters, volumes) = detectChaptersAndVolumes(from: lines, warnings: &warnings)
        
        return EnhancedParseResult(
            title: title,
            author: author,
            intro: intro,
            volumes: volumes,
            chapters: chapters,
            rawContent: lines.joined(separator: "\n"),
            metadata: [:],
            warnings: warnings
        )
    }
    
    private func extractTitle(from lines: inout [String], warnings: inout [String]) -> String {
        guard !lines.isEmpty else { return "未知标题" }
        
        var title = ""
        var skipLines = 0
        
        for (index, line) in lines.enumerated() {
            if index > 10 { break }
            
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty { continue }
            
            if trimmed.hasPrefix("书名") || trimmed.hasPrefix("书名：") || trimmed.hasPrefix("Title:") {
                title = trimmed.replacingOccurrences(of: "书名", with: "")
                    .replacingOccurrences(of: "Title:", with: "")
                    .replacingOccurrences(of: "：", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
                skipLines = index + 1
                break
            }
            
            if !trimmed.contains("作者") && !trimmed.contains("简介") && trimmed.count >= 2 && trimmed.count <= 50 {
                title = trimmed
                skipLines = index + 1
                break
            }
        }
        
        if skipLines > 0 {
            lines = Array(lines.dropFirst(skipLines))
        }
        
        if title.isEmpty {
            title = "未知标题"
            warnings.append("未能识别书籍标题")
        }
        
        return titleSegmentation.formatTitle(title)
    }
    
    private func extractAuthor(from lines: [String]) -> String? {
        for line in lines.prefix(30) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            for pattern in authorPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(trimmed.startIndex..., in: trimmed)
                    if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                        if match.numberOfRanges > 1,
                           let authorRange = Range(match.range(at: 1), in: trimmed) {
                            return String(trimmed[authorRange]).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func extractIntro(from lines: [String]) -> String? {
        var introLines: [String] = []
        var foundIntro = false
        
        for line in lines.prefix(50) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !foundIntro {
                for pattern in introPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                        let range = NSRange(trimmed.startIndex..., in: trimmed)
                        if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                            foundIntro = true
                            continue
                        }
                    }
                }
                continue
            }
            
            if trimmed.isEmpty {
                if introLines.count > 2 { break }
                introLines.append(trimmed)
                continue
            }
            
            if trimmed.count < 10 || trimmed.count > 500 { break }
            if isChapterTitle(trimmed) { break }
            
            introLines.append(trimmed)
            if introLines.count >= 10 { break }
        }
        
        return introLines.isEmpty ? nil : introLines.joined(separator: "\n")
    }
    
    private func detectChaptersAndVolumes(from lines: [String], warnings: inout [String]) -> ([EnhancedParseResult.ChapterInfo], [EnhancedParseResult.VolumeInfo]) {
        var chapters: [EnhancedParseResult.ChapterInfo] = []
        var volumes: [EnhancedParseResult.VolumeInfo] = []
        var currentVolumeStart = 0
        var currentVolumeTitle = "正文"
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty || trimmed.count < 3 || trimmed.count > 150 { continue }
            
            if let (pattern, chapterType) = matchChapterPattern(trimmed) {
                let segmentResult = titleSegmentation.segmentTitle(trimmed)
                let formattedTitle = segmentResult.formattedTitle.isEmpty ? trimmed : segmentResult.formattedTitle
                
                if chapterType == .volume || trimmed.hasPrefix("【") {
                    currentVolumeTitle = formattedTitle
                    currentVolumeStart = index
                }
                
                let chapter = EnhancedParseResult.ChapterInfo(
                    id: UUID().uuidString,
                    title: formattedTitle,
                    originalTitle: trimmed,
                    startLine: index,
                    endLine: min(index + 500, lines.count - 1),
                    level: chapterType == .volume ? 0 : (chapterType == .chapter ? 1 : 2),
                    formattedTitle: formattedTitle
                )
                chapters.append(chapter)
            }
        }
        
        for i in 0..<chapters.count {
            let startLine = chapters[i].startLine
            let endLine = i + 1 < chapters.count ? chapters[i + 1].startLine - 1 : lines.count - 1
            chapters[i] = EnhancedParseResult.ChapterInfo(
                id: chapters[i].id,
                title: chapters[i].title,
                originalTitle: chapters[i].originalTitle,
                startLine: startLine,
                endLine: endLine,
                level: chapters[i].level,
                formattedTitle: chapters[i].formattedTitle
            )
        }
        
        if chapters.count > 100 {
            warnings.append("检测到 \(chapters.count) 个章节，可能是误识别")
        }
        
        return (chapters, volumes)
    }
    
    private func matchChapterPattern(_ text: String) -> (ChapterPattern, ChapterPattern.ChapterType)? {
        var bestMatch: (ChapterPattern, ChapterPattern.ChapterType)?
        var bestPriority = 0
        
        for chapterPattern in chapterPatterns {
            if let regex = try? NSRegularExpression(pattern: chapterPattern.pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    if chapterPattern.priority > bestPriority {
                        bestPriority = chapterPattern.priority
                        bestMatch = (chapterPattern, chapterPattern.type)
                    }
                }
            }
        }
        
        return bestMatch
    }
    
    private func isChapterTitle(_ text: String) -> Bool {
        return matchChapterPattern(text) != nil
    }
    
    private func extractChapterContent(from lines: [String], startLine: Int, endLine: Int) -> String {
        guard startLine >= 0 && startLine < lines.count else { return "" }
        
        let actualEndLine = min(endLine, lines.count - 1)
        let chapterLines = Array(lines[startLine...actualEndLine])
        
        return chapterLines.joined(separator: "\n")
    }
    
    private func parseMetadata(_ result: EnhancedParseResult) -> [String: String] {
        var metadata: [String: String] = [:]
        metadata["title"] = result.title
        if let author = result.author {
            metadata["author"] = author
        }
        if let intro = result.intro {
            metadata["intro"] = intro
        }
        metadata["chapterCount"] = "\(result.chapters.count)"
        metadata["volumeCount"] = "\(result.volumes.count)"
        return metadata
    }
}
