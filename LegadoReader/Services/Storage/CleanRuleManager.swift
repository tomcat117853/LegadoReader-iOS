import Foundation

class CleanRuleManager {
    static let shared = CleanRuleManager()
    
    @Published var globalRules: [ReplaceRule] = []
    @Published var bookRules: [String: [ReplaceRule]] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let globalRulesKey = "CleanRuleManager_GlobalRules"
    private let bookRulesKey = "CleanRuleManager_BookRules"
    
    private init() {
        loadRules()
        loadDefaultRules()
    }
    
    private func loadRules() {
        if let data = userDefaults.data(forKey: globalRulesKey) {
            globalRules = (try? JSONDecoder().decode([ReplaceRule].self, from: data)) ?? []
        }
        
        if let data = userDefaults.data(forKey: bookRulesKey) {
            bookRules = (try? JSONDecoder().decode([String: [ReplaceRule]].self, from: data)) ?? [:]
        }
    }
    
    private func saveRules() {
        if let data = try? JSONEncoder().encode(globalRules) {
            userDefaults.set(data, forKey: globalRulesKey)
        }
        
        if let data = try? JSONEncoder().encode(bookRules) {
            userDefaults.set(data, forKey: bookRulesKey)
        }
    }
    
    private func loadDefaultRules() {
        if globalRules.isEmpty {
            globalRules = [
                ReplaceRule(pattern: "\\s*[第章节]\\s*[0-9零一二三四五六七八九十百千万]+\\s*[章节回卷集篇部].*", replacement: "", isRegex: true),
                ReplaceRule(pattern: "\\(本章完\\)", replacement: "", isRegex: true),
                ReplaceRule(pattern: "\\(未完待续\\)", replacement: "", isRegex: true),
                ReplaceRule(pattern: "请记住本书首发域名.*", replacement: "", isRegex: true),
                ReplaceRule(pattern: "最新网址.*", replacement: "", isRegex: true),
                ReplaceRule(pattern: "笔趣阁", replacement: "", isRegex: false),
                ReplaceRule(pattern: "顶点小说", replacement: "", isRegex: false),
                ReplaceRule(pattern: "\\s+", replacement: " ", isRegex: true),
                ReplaceRule(pattern: "^\\s+", replacement: "", isRegex: true),
                ReplaceRule(pattern: "\\s+$", replacement: "", isRegex: true)
            ]
            saveRules()
        }
    }
    
    func addGlobalRule(_ rule: ReplaceRule) {
        globalRules.append(rule)
        saveRules()
    }
    
    func removeGlobalRule(at index: Int) {
        globalRules.remove(at: index)
        saveRules()
    }
    
    func updateGlobalRule(at index: Int, with rule: ReplaceRule) {
        globalRules[index] = rule
        saveRules()
    }
    
    func addBookRule(bookId: String, rule: ReplaceRule) {
        if bookRules[bookId] == nil {
            bookRules[bookId] = []
        }
        bookRules[bookId]?.append(rule)
        saveRules()
    }
    
    func removeBookRule(bookId: String, at index: Int) {
        bookRules[bookId]?.remove(at: index)
        saveRules()
    }
    
    func getRules(for bookId: String?) -> [ReplaceRule] {
        var rules = globalRules
        
        if let bookId = bookId, let bookSpecificRules = bookRules[bookId] {
            rules.append(contentsOf: bookSpecificRules)
        }
        
        return rules
    }
    
    func cleanContent(_ content: String, bookId: String? = nil) -> String {
        var result = content
        
        for rule in getRules(for: bookId) {
            if rule.isRegex {
                result = result.replacingOccurrences(of: rule.pattern, with: rule.replacement, options: .regularExpression)
            } else {
                result = result.replacingOccurrences(of: rule.pattern, with: rule.replacement)
            }
        }
        
        return result
    }
    
    func cleanChapterContent(_ chapter: Chapter, bookId: String?) -> String {
        guard var content = chapter.content else {
            return ""
        }
        
        content = cleanContent(content, bookId: bookId)
        
        return content
    }
    
    func cleanSearchResults(_ books: [Book]) -> [Book] {
        return books.map { book in
            var cleanedBook = book
            cleanedBook.name = cleanContent(book.name)
            cleanedBook.author = cleanContent(book.author)
            cleanedBook.intro = book.intro.map { cleanContent($0) }
            cleanedBook.lastChapter = book.lastChapter.map { cleanContent($0) }
            return cleanedBook
        }
    }
    
    func exportRules() -> String {
        let data: [String: Any] = [
            "globalRules": globalRules,
            "bookRules": bookRules
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        }
        
        return "{}"
    }
    
    func importRules(from jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw CleanRuleError.invalidJSON
        }
        
        let decoded = try JSONDecoder().decode([String: [ReplaceRule]].self, from: data)
        
        if let global = decoded["globalRules"] {
            globalRules = global
        }
        
        if let book = decoded["bookRules"] {
            bookRules = book
        }
        
        saveRules()
    }
}

enum CleanRuleError: Error {
    case invalidJSON
    case parseError(String)
}

extension ReplaceRule {
    var displayPattern: String {
        if isRegex {
            return "正则: \(pattern)"
        }
        return pattern
    }
}
