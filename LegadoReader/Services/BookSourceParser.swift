import Foundation
import SwiftSoup

class BookSourceParser {
    static let shared = BookSourceParser()
    
    private init() {}
    
    // MARK: - Search Books
    
    func searchBooks(keyword: String, source: BookSource) async throws -> [Book] {
        guard let searchRule = source.rule.searchBook else {
            throw ParserError.noSearchRule
        }
        
        let url = searchRule.url
            .replacingOccurrences(of: "{{key}}", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)
        
        let html = try await fetchHTML(url: url, method: searchRule.method, body: searchRule.body, headers: searchRule.headers)
        let document = try SwiftSoup.parse(html)
        
        var books: [Book] = []
        let bookElements = try document.select(searchRule.bookList)
        
        for element in bookElements {
            if let book = try parseBookElement(element, searchRule: searchRule, source: source) {
                books.append(book)
            }
        }
        
        return books
    }
    
    private func parseBookElement(_ element: Element, searchRule: SearchRule, source: BookSource) throws -> Book? {
        let name = try element.select(searchRule.name).text()
        guard !name.isEmpty else { return nil }
        
        let author = searchRule.author != nil ? try element.select(searchRule.author!).text() : ""
        let cover = searchRule.cover != nil ? try element.select(searchRule.cover!).attr("src") : nil
        let intro = searchRule.intro != nil ? try element.select(searchRule.intro!).text() : nil
        let lastChapter = searchRule.lastChapter != nil ? try element.select(searchRule.lastChapter!).text() : nil
        let bookUrl = try element.select(searchRule.bookUrl).attr("href")
        
        return Book(
            name: name,
            author: author,
            cover: cover,
            intro: intro,
            lastChapter: lastChapter,
            sourceUrl: source.url,
            sourceName: source.name,
            bookUrl: bookUrl.hasPrefix("http") ? bookUrl : source.url + bookUrl
        )
    }
    
    // MARK: - Get Book Detail
    
    func getBookDetail(book: Book, source: BookSource) async throws -> Book {
        guard let detailRule = source.rule.bookDetail else {
            return book
        }
        
        let html = try await fetchHTML(url: book.bookUrl, method: "GET")
        let document = try SwiftSoup.parse(html)
        
        var updatedBook = book
        
        if let nameRule = detailRule.name {
            updatedBook.name = try document.select(nameRule).text()
        }
        if let authorRule = detailRule.author {
            updatedBook.author = try document.select(authorRule).text()
        }
        if let coverRule = detailRule.cover {
            updatedBook.cover = try document.select(coverRule).attr("src")
        }
        if let introRule = detailRule.intro {
            updatedBook.intro = try document.select(introRule).text()
        }
        if let lastChapterRule = detailRule.lastChapter {
            updatedBook.lastChapter = try document.select(lastChapterRule).text()
        }
        
        return updatedBook
    }
    
    // MARK: - Get Chapter List
    
    func getChapterList(book: Book, source: BookSource) async throws -> [Chapter] {
        guard let chapterListRule = source.rule.chapterList else {
            throw ParserError.noChapterListRule
        }
        
        var chapterListURL = book.bookUrl
        if let chapterListUrlRule = source.rule.bookDetail?.chapterListUrl {
            let html = try await fetchHTML(url: book.bookUrl, method: "GET")
            let document = try SwiftSoup.parse(html)
            chapterListURL = try document.select(chapterListUrlRule).attr("href")
            if !chapterListURL.hasPrefix("http") {
                chapterListURL = source.url + chapterListURL
            }
        }
        
        let html = try await fetchHTML(url: chapterListURL, method: "GET")
        let document = try SwiftSoup.parse(html)
        
        var chapters: [Chapter] = []
        let chapterElements = try document.select(chapterListRule.chapterList)
        
        for (index, element) in chapterElements.enumerated() {
            let title = try element.select(chapterListRule.chapterName).text()
            let url = try element.select(chapterListRule.chapterUrl).attr("href")
            
            let chapter = Chapter(
                title: title,
                url: url.hasPrefix("http") ? url : source.url + url,
                index: index
            )
            chapters.append(chapter)
        }
        
        return chapters
    }
    
    // MARK: - Get Chapter Content
    
    func getChapterContent(chapter: Chapter, source: BookSource) async throws -> String {
        guard let contentRule = source.rule.chapterContent else {
            throw ParserError.noContentRule
        }
        
        var content = ""
        var currentURL = chapter.url
        
        repeat {
            let html = try await fetchHTML(url: currentURL, method: "GET")
            let document = try SwiftSoup.parse(html)
            
            let pageContent = try document.select(contentRule.content).html()
            content += cleanContent(pageContent, replaceRules: contentRule.replaceRules)
            
            if let nextPageRule = contentRule.nextPage {
                let nextPageURL = try document.select(nextPageRule).attr("href")
                if !nextPageURL.isEmpty && nextPageURL != currentURL {
                    currentURL = nextPageURL.hasPrefix("http") ? nextPageURL : source.url + nextPageURL
                } else {
                    break
                }
            } else {
                break
            }
        } while true
        
        return content
    }
    
    private func cleanContent(_ html: String, replaceRules: [ReplaceRule]?) -> String {
        var content = html
        
        // 移除 script 和 style 标签
        content = content.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        content = content.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        
        // 应用替换规则
        if let rules = replaceRules {
            for rule in rules {
                if rule.isRegex {
                    content = content.replacingOccurrences(of: rule.pattern, with: rule.replacement, options: .regularExpression)
                } else {
                    content = content.replacingOccurrences(of: rule.pattern, with: rule.replacement)
                }
            }
        }
        
        // 移除 HTML 标签
        content = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 解码 HTML 实体
        content = content.htmlDecoded()
        
        // 规范化空白字符
        content = content.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Network Request
    
    private func fetchHTML(url: String, method: String, body: String? = nil, headers: [String: String]? = nil) async throws -> String {
        guard let url = URL(string: url) else {
            throw ParserError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body?.data(using: .utf8)
        
        // 设置默认请求头
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        
        // 应用自定义请求头
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ParserError.networkError
        }
        
        // 检测编码
        var encoding: String.Encoding = .utf8
        if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
            if contentType.contains("gb2312") || contentType.contains("gbk") {
                encoding = .gbk
            }
        }
        
        guard let html = String(data: data, encoding: encoding) else {
            throw ParserError.encodingError
        }
        
        return html
    }
    
    // MARK: - Import Book Source
    
    func importBookSource(from jsonString: String) throws -> [BookSource] {
        guard let data = jsonString.data(using: .utf8) else {
            throw ParserError.invalidJSON
        }
        
        // 尝试解析为数组
        if let sources = try? JSONDecoder().decode([LegadoBookSource].self, from: data) {
            return sources.map { $0.toBookSource() }
        }
        
        // 尝试解析为单个对象
        if let source = try? JSONDecoder().decode(LegadoBookSource.self, from: data) {
            return [source.toBookSource()]
        }
        
        throw ParserError.invalidJSON
    }
}

// MARK: - Legado Book Source Model

struct LegadoBookSource: Codable {
    let bookSourceName: String
    let bookSourceUrl: String
    let bookSourceType: String?
    let bookSourceGroup: String?
    let bookSourceComment: String?
    let loginUrl: String?
    let bookUrlPattern: String?
    let header: String?
    let searchUrl: String?
    let exploreUrl: String?
    let enabled: Bool?
    let enabledExplore: Bool?
    let weight: Int?
    let customOrder: Int?
    let lastUpdateTime: Int64?
    
    // 规则
    let ruleSearch: RuleSearch?
    let ruleBookInfo: RuleBookInfo?
    let ruleToc: RuleToc?
    let ruleContent: RuleContent?
    let ruleExplore: RuleExplore?
    
    struct RuleSearch: Codable {
        let bookList: String?
        let name: String?
        let author: String?
        let intro: String?
        let kind: String?
        let lastChapter: String?
        let updateTime: String?
        let bookUrl: String?
        let coverUrl: String?
        let wordCount: String?
    }
    
    struct RuleBookInfo: Codable {
        let name: String?
        let author: String?
        let intro: String?
        let kind: String?
        let lastChapter: String?
        let updateTime: String?
        let coverUrl: String?
        let tocUrl: String?
        let wordCount: String?
        let init: String?
    }
    
    struct RuleToc: Codable {
        let chapterList: String?
        let chapterName: String?
        let chapterUrl: String?
        let isVip: String?
        let updateTime: String?
        let nextTocUrl: String?
    }
    
    struct RuleContent: Codable {
        let content: String?
        let nextContentUrl: String?
        let webJs: String?
        let sourceRegex: String?
        let replaceRegex: String?
    }
    
    struct RuleExplore: Codable {
        let bookList: String?
        let name: String?
        let author: String?
        let intro: String?
        let kind: String?
        let lastChapter: String?
        let updateTime: String?
        let bookUrl: String?
        let coverUrl: String?
        let wordCount: String?
    }
    
    func toBookSource() -> BookSource {
        let type: SourceType
        switch bookSourceType {
        case "AUDIO": type = .audio
        case "CARTOON": type = .comic
        default: type = .text
        }
        
        var rule = SourceRule()
        
        // 搜索规则
        if let search = ruleSearch {
            rule.searchBook = SearchRule(
                url: searchUrl ?? "",
                method: "GET",
                body: nil,
                headers: nil,
                bookList: search.bookList ?? "",
                name: search.name ?? "",
                author: search.author,
                cover: search.coverUrl,
                intro: search.intro,
                lastChapter: search.lastChapter,
                bookUrl: search.bookUrl ?? ""
            )
        }
        
        // 详情规则
        if let bookInfo = ruleBookInfo {
            rule.bookDetail = DetailRule(
                name: bookInfo.name,
                author: bookInfo.author,
                cover: bookInfo.coverUrl,
                intro: bookInfo.intro,
                lastChapter: bookInfo.lastChapter,
                chapterListUrl: bookInfo.tocUrl
            )
        }
        
        // 目录规则
        if let toc = ruleToc {
            rule.chapterList = ChapterListRule(
                chapterList: toc.chapterList ?? "",
                chapterName: toc.chapterName ?? "",
                chapterUrl: toc.chapterUrl ?? "",
                isVip: toc.isVip,
                updateTime: toc.updateTime
            )
        }
        
        // 内容规则
        if let content = ruleContent {
            var replaceRules: [ReplaceRule]?
            if let replaceRegex = content.replaceRegex, !replaceRegex.isEmpty {
                replaceRules = [ReplaceRule(pattern: replaceRegex, replacement: "", isRegex: true)]
            }
            
            rule.chapterContent = ContentRule(
                content: content.content ?? "",
                nextPage: content.nextContentUrl,
                replaceRules: replaceRules
            )
        }
        
        return BookSource(
            name: bookSourceName,
            url: bookSourceUrl,
            type: type,
            isEnabled: enabled ?? true,
            weight: weight ?? 1000,
            rule: rule
        )
    }
}

// MARK: - Errors

enum ParserError: Error {
    case noSearchRule
    case noChapterListRule
    case noContentRule
    case invalidURL
    case networkError
    case encodingError
    case invalidJSON
    case parseError(String)
}

// MARK: - Extensions

extension String {
    func htmlDecoded() -> String {
        var result = self
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…"
        ]
        
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        
        return result
    }
}

extension String.Encoding {
    static let gbk = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}
