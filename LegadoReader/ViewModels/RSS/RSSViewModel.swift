import Foundation
import Combine

class RSSViewModel: ObservableObject {
    @Published var sources: [RSSSource] = []
    @Published var articles: [RSSArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let sourcesKey = "RSSViewModel_Sources"
    private let articlesKey = "RSSViewModel_Articles"
    
    init() {
        loadData()
    }
    
    private func loadData() {
        if let data = userDefaults.data(forKey: sourcesKey) {
            sources = (try? JSONDecoder().decode([RSSSource].self, from: data)) ?? []
        }
        
        if let data = userDefaults.data(forKey: articlesKey) {
            articles = (try? JSONDecoder().decode([RSSArticle].self, from: data)) ?? []
        }
    }
    
    private func saveData() {
        if let data = try? JSONEncoder().encode(sources) {
            userDefaults.set(data, forKey: sourcesKey)
        }
        
        if let data = try? JSONEncoder().encode(articles) {
            userDefaults.set(data, forKey: articlesKey)
        }
    }
    
    func addSource(_ source: RSSSource) {
        sources.append(source)
        saveData()
        
        Task {
            await refreshArticles(for: source)
        }
    }
    
    func removeSource(_ source: RSSSource) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources.remove(at: index)
        }
        
        articles.removeAll { $0.id.hasPrefix(source.id) }
        
        saveData()
    }
    
    func toggleSourceEnabled(_ source: RSSSource) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index].isEnabled.toggle()
            saveData()
        }
    }
    
    func refreshAll() async {
        for source in sources where source.isEnabled {
            await refreshArticles(for: source)
        }
    }
    
    func refreshArticles(for source: RSSSource) async {
        isLoading = true
        
        do {
            let newArticles = try await fetchRSSFeed(url: source.url)
            
            await MainActor.run {
                let existingArticleIDs = Set(articles.filter { $0.id.hasPrefix(source.id) }.map { $0.id })
                
                for article in newArticles {
                    let articleID = "\(source.id)_\(article.link)"
                    
                    if !existingArticleIDs.contains(articleID) {
                        var newArticle = article
                        newArticle.id = articleID
                        articles.insert(newArticle, at: 0)
                    }
                }
                
                if let index = sources.firstIndex(where: { $0.id == source.id }) {
                    sources[index].lastUpdateTime = Date()
                    sources[index].articles = newArticles
                }
                
                saveData()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "刷新失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func fetchRSSFeed(url: String) async throws -> [RSSArticle] {
        guard let url = URL(string: url) else {
            throw RSSError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RSSError.networkError
        }
        
        let parser = RSSParser(data: data)
        return try parser.parse()
    }
    
    func markAsRead(_ article: RSSArticle) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index].isRead = true
            saveData()
        }
    }
    
    func markAsUnread(_ article: RSSArticle) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index].isRead = false
            saveData()
        }
    }
    
    func toggleFavorite(_ article: RSSArticle) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index].isFavorite.toggle()
            saveData()
        }
    }
    
    func getArticles(for sourceId: String) -> [RSSArticle] {
        return articles.filter { $0.id.hasPrefix(sourceId) }
    }
    
    func getUnreadCount() -> Int {
        return articles.filter { !$0.isRead }.count
    }
    
    func getFavoriteArticles() -> [RSSArticle] {
        return articles.filter { $0.isFavorite }
    }
}

class RSSParser {
    private let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    func parse() throws -> [RSSArticle] {
        let parser = XMLParser(data: data)
        let delegate = RSSParserDelegate()
        parser.delegate = delegate
        
        if !parser.parse() {
            if let error = parser.parserError {
                throw error
            }
            throw RSSError.parseError
        }
        
        return delegate.articles
    }
}

class RSSParserDelegate: NSObject, XMLParserDelegate {
    var articles: [RSSArticle] = []
    private var currentElement = ""
    private var currentArticle: RSSArticle?
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentContent = ""
    private var currentAuthor = ""
    private var currentPubDate = ""
    private var currentCover = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "item" || elementName == "entry" {
            currentArticle = RSSArticle()
        }
        
        if elementName == "enclosure" {
            if let url = attributeDict["url"], let type = attributeDict["type"], type.hasPrefix("image") {
                currentCover = url
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        case "description":
            currentDescription += string
        case "content:encoded", "content":
            currentContent += string
        case "author":
            currentAuthor += string
        case "pubDate", "updated":
            currentPubDate += string
        case "media:content", "media:thumbnail":
            currentCover += string
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            if let article = currentArticle {
                article.title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                article.link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
                article.description = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                article.content = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                article.author = currentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
                article.pubDate = parseDate(currentPubDate)
                article.cover = currentCover.isEmpty ? nil : currentCover
                articles.append(article)
            }
            
            resetCurrent()
        }
    }
    
    private func resetCurrent() {
        currentArticle = nil
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentContent = ""
        currentAuthor = ""
        currentPubDate = ""
        currentCover = ""
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let dateFormats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}

enum RSSError: Error {
    case invalidURL
    case networkError
    case parseError
}
