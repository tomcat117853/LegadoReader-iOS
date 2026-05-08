import Foundation
import Combine

class BookSourceImportManager: ObservableObject {
    static let shared = BookSourceImportManager()
    
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var importedCount = 0
    @Published var totalCount = 0
    @Published var lastError: String?
    @Published var importHistory: [ImportRecord] = []
    @Published var isValidating = false
    @Published var validationResult: ValidationResult?
    
    private let defaults = UserDefaults.standard
    private let historyKey = "BookSourceImport_history"
    
    struct ImportRecord: Identifiable, Codable {
        let id: String
        let url: String
        let sourceName: String
        let importDate: Date
        let successCount: Int
        let failCount: Int
        let isSuccess: Bool
    }
    
    struct ValidationResult {
        let isValid: Bool
        let sourceCount: Int
        let sourceNames: [String]
        let errorMessage: String?
    }
    
    enum ImportFormat {
        case json
        case xml
        case txt
        case mixed
        
        var displayName: String {
            switch self {
            case .json: return "JSON"
            case .xml: return "XML"
            case .txt: return "TXT"
            case .mixed: return "混合格式"
            }
        }
    }
    
    private init() {
        loadHistory()
    }
    
    private func loadHistory() {
        if let data = defaults.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([ImportRecord].self, from: data) {
            importHistory = history
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(importHistory) {
            defaults.set(data, forKey: historyKey)
        }
    }
    
    func clearHistory() {
        importHistory.removeAll()
        saveHistory()
    }
    
    func validateSourceURL(_ urlString: String) async -> ValidationResult {
        await MainActor.run {
            isValidating = true
            validationResult = nil
        }
        
        guard let url = URL(string: urlString) else {
            let result = ValidationResult(isValid: false, sourceCount: 0, sourceNames: [], errorMessage: "无效的URL地址")
            await MainActor.run {
                isValidating = false
                validationResult = result
            }
            return result
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let result = ValidationResult(isValid: false, sourceCount: 0, sourceNames: [], errorMessage: "无法访问该URL")
                await MainActor.run {
                    isValidating = false
                    validationResult = result
                }
                return result
            }
            
            guard let content = String(data: data, encoding: .utf8) else {
                let result = ValidationResult(isValid: false, sourceCount: 0, sourceNames: [], errorMessage: "无法解析内容")
                await MainActor.run {
                    isValidating = false
                    validationResult = result
                }
                return result
            }
            
            let format = detectFormat(content)
            let sources = parseSources(from: content, format: format)
            
            let names = sources.compactMap { $0.bookSourceName }
            let result = ValidationResult(
                isValid: !sources.isEmpty,
                sourceCount: sources.count,
                sourceNames: names,
                errorMessage: sources.isEmpty ? "未找到有效的书源" : nil
            )
            
            await MainActor.run {
                isValidating = false
                validationResult = result
            }
            
            return result
            
        } catch {
            let result = ValidationResult(isValid: false, sourceCount: 0, sourceNames: [], errorMessage: error.localizedDescription)
            await MainActor.run {
                isValidating = false
                validationResult = result
            }
            return result
        }
    }
    
    func importFromURL(_ urlString: String) async -> [BookSource] {
        await MainActor.run {
            isImporting = true
            importProgress = 0
            importedCount = 0
            totalCount = 0
            lastError = nil
        }
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                isImporting = false
                lastError = "无效的URL地址"
            }
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let content = String(data: data, encoding: .utf8) else {
                await MainActor.run {
                    isImporting = false
                    lastError = "无法解析内容"
                }
                return []
            }
            
            let format = detectFormat(content)
            var sources = parseSources(from: content, format: format)
            
            await MainActor.run {
                totalCount = sources.count
            }
            
            var importedSources: [BookSource] = []
            var successCount = 0
            var failCount = 0
            
            for (index, source) in sources.enumerated() {
                await MainActor.run {
                    importProgress = Double(index) / Double(sources.count)
                }
                
                if validateSource(source) {
                    importedSources.append(source)
                    successCount += 1
                } else {
                    failCount += 1
                }
            }
            
            let record = ImportRecord(
                id: UUID().uuidString,
                url: urlString,
                sourceName: sources.map { $0.bookSourceName ?? "未知" }.joined(separator: ", "),
                importDate: Date(),
                successCount: successCount,
                failCount: failCount,
                isSuccess: !importedSources.isEmpty
            )
            
            await MainActor.run {
                importHistory.insert(record, at: 0)
                if importHistory.count > 50 {
                    importHistory = Array(importHistory.prefix(50))
                }
                saveHistory()
                
                isImporting = false
                importProgress = 1.0
                importedCount = successCount
            }
            
            return importedSources
            
        } catch {
            await MainActor.run {
                isImporting = false
                lastError = error.localizedDescription
            }
            return []
        }
    }
    
    func importFromText(_ text: String) async -> [BookSource] {
        await MainActor.run {
            isImporting = true
            importedCount = 0
            totalCount = 0
        }
        
        let format = detectFormat(text)
        var sources = parseSources(from: text, format: format)
        
        await MainActor.run {
            totalCount = sources.count
        }
        
        var importedSources: [BookSource] = []
        
        for (index, source) in sources.enumerated() {
            await MainActor.run {
                importProgress = Double(index) / Double(sources.count)
            }
            
            if validateSource(source) {
                importedSources.append(source)
            }
        }
        
        await MainActor.run {
            isImporting = false
            importProgress = 1.0
            importedCount = importedSources.count
        }
        
        return importedSources
    }
    
    private func detectFormat(_ content: String) -> ImportFormat {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            if trimmed.contains("\"bookSourceUrl\"") || trimmed.contains("\"bookSourceName\"") {
                return .json
            }
        }
        
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<sources>") || trimmed.hasPrefix("<bookSources>") {
            return .xml
        }
        
        if trimmed.contains("bookSourceUrl=") || trimmed.contains("BookSources") {
            return .txt
        }
        
        return .mixed
    }
    
    private func parseSources(from content: String, format: ImportFormat) -> [BookSource] {
        switch format {
        case .json:
            return parseJSONSources(content)
        case .xml:
            return parseXMLSources(content)
        case .txt:
            return parseTXTSources(content)
        case .mixed:
            return parseMixedSources(content)
        }
    }
    
    private func parseJSONSources(_ content: String) -> [BookSource] {
        var sources: [BookSource] = []
        
        let data = content.data(using: .utf8) ?? Data()
        
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in jsonArray {
                if let source = createSource(from: dict) {
                    sources.append(source)
                }
            }
        } else if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let source = createSource(from: jsonObject) {
                sources.append(source)
            }
        } else if let jsonString = try? JSONDecoder().decode([BookSource].self, from: data) {
            sources = jsonString
        } else if let singleSource = try? JSONDecoder().decode(BookSource.self, from: data) {
            sources.append(singleSource)
        }
        
        return sources
    }
    
    private func parseXMLSources(_ content: String) -> [BookSource] {
        var sources: [BookSource] = []
        
        let patterns = [
            "<source>([\\s\\S]*?)</source>",
            "<bookSource>([\\s\\S]*?)</bookSource>"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                let matches = regex.matches(in: content, options: [], range: range)
                
                for match in matches {
                    if let xmlRange = Range(match.range(at: 1), in: content) {
                        let xmlContent = String(content[xmlRange])
                        if let dict = parseXMLToDict(xmlContent),
                           let source = createSource(from: dict) {
                            sources.append(source)
                        }
                    }
                }
                
                if !sources.isEmpty {
                    break
                }
            }
        }
        
        return sources
    }
    
    private func parseXMLToDict(_ xml: String) -> [String: Any]? {
        var dict: [String: Any] = [:]
        
        let patterns = [
            "<bookSourceUrl>([\\s\\S]*?)</bookSourceUrl>",
            "<bookSourceName>([\\s\\S]*?)</bookSourceName>",
            "<bookSourceGroup>([\\s\\S]*?)</bookSourceGroup>",
            "<bookSourceComment>([\\s\\S]*?)</bookSourceComment>",
            "<bookSourceType>([\\s\\S]*?)</bookSourceType>",
            "<bookSourceUrlBase>([\\s\\S]*?)</bookSourceUrlBase>",
            "<customIndex>([\\s\\S]*?)</customIndex>",
            "<enabled>([\\s\\S]*?)</enabled>",
            "<weight>([\\s\\S]*?)</weight>"
        ]
        
        let keys = ["bookSourceUrl", "bookSourceName", "bookSourceGroup", "bookSourceComment",
                    "bookSourceType", "bookSourceUrlBase", "customIndex", "enabled", "weight"]
        
        for (index, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(xml.startIndex..., in: xml)
                if let match = regex.firstMatch(in: xml, options: [], range: range),
                   let valueRange = Range(match.range(at: 1), in: xml) {
                    dict[keys[index]] = String(xml[valueRange])
                }
            }
        }
        
        return dict.isEmpty ? nil : dict
    }
    
    private func parseTXTSources(_ content: String) -> [BookSource] {
        var sources: [BookSource] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentDict: [String: Any] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                continue
            }
            
            if trimmed.contains("bookSourceUrl=", to: "") {
                if !currentDict.isEmpty, let source = createSource(from: currentDict) {
                    sources.append(source)
                }
                currentDict = [:]
            }
            
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                currentDict[key] = value
            }
        }
        
        if !currentDict.isEmpty, let source = createSource(from: currentDict) {
            sources.append(source)
        }
        
        return sources
    }
    
    private func parseMixedSources(_ content: String) -> [BookSource] {
        var sources: [BookSource] = []
        
        let jsonPattern = "\\{[\\s\\S]*?\"bookSourceUrl\"[\\s\\S]*?\\}"
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            
            for match in matches {
                if let jsonRange = Range(match.range, in: content) {
                    let jsonString = String(content[jsonRange])
                    if let data = jsonString.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let source = createSource(from: dict) {
                        sources.append(source)
                    }
                }
            }
        }
        
        if sources.isEmpty {
            sources = parseTXTSources(content)
        }
        
        return sources
    }
    
    private func createSource(from dict: [String: Any]) -> BookSource? {
        var source = BookSource(
            url: "",
            name: "",
            type: .network,
            enabled: true,
            rule: BookSource.Rule()
        )
        
        if let url = dict["bookSourceUrl"] as? String ?? dict["bookSourceUrl"] as? String {
            source.url = url
        } else {
            return nil
        }
        
        source.name = dict["bookSourceName"] as? String ?? dict["bookSourceName"] as? String ?? "未命名书源"
        
        if let group = dict["bookSourceGroup"] as? String ?? dict["bookSourceGroup"] as? String {
            source.bookSourceGroup = group
        }
        
        if let comment = dict["bookSourceComment"] as? String ?? dict["bookSourceComment"] as? String {
            source.bookSourceComment = comment
        }
        
        if let type = dict["bookSourceType"] as? String ?? dict["bookSourceType"] as? Int {
            if let typeString = type as? String {
                source.type = typeString.lowercased().contains("audio") ? .audio : .network
            } else if let typeInt = type as? Int {
                source.type = typeInt == 1 ? .audio : .network
            }
        }
        
        if let urlBase = dict["bookSourceUrlBase"] as? String ?? dict["bookSourceUrlBase"] as? String {
            source.bookSourceUrlBase = urlBase
        }
        
        if let customIndex = dict["customIndex"] as? String ?? dict["customIndex"] as? String {
            source.customIndex = customIndex
        }
        
        source.enabled = (dict["enabled"] as? Bool) ?? true
        
        if let weight = dict["weight"] as? Int {
            source.weight = weight
        }
        
        if let ruleDict = dict["rule"] as? [String: Any] {
            source.rule = parseRule(from: ruleDict)
        } else if let searchRule = dict["searchRule"] as? [String: Any] {
            source.rule.searchKey = searchRule["key"] as? String
            source.rule.searchUrl = searchRule["url"] as? String
        }
        
        return source
    }
    
    private func parseRule(from dict: [String: Any]) -> BookSource.Rule {
        var rule = BookSource.Rule()
        
        if let searchDict = dict["search"] as? [String: Any] {
            rule.searchKey = searchDict["key"] as? String
            rule.searchUrl = searchDict["url"] as? String
        }
        
        if let bookInfoDict = dict["bookInfo"] as? [String: Any] {
            rule.bookInfoUrl = bookInfoDict["url"] as? String
        }
        
        if let catalogDict = dict["catalog"] as? [String: Any] {
            rule.catalogUrl = catalogDict["url"] as? String
        }
        
        if let chapterDict = dict["chapter"] as? [String: Any] {
            rule.chapterUrl = chapterDict["url"] as? String
        }
        
        return rule
    }
    
    private func validateSource(_ source: BookSource) -> Bool {
        guard !source.url.isEmpty else { return false }
        guard let url = URL(string: source.url) else { return false }
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        return true
    }
    
    func deleteHistoryRecord(_ record: ImportRecord) {
        importHistory.removeAll { $0.id == record.id }
        saveHistory()
    }
}

extension String {
    func contains(_ substring: String, to: String) -> Bool {
        return self.contains(substring)
    }
}
