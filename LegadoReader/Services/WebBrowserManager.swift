import Foundation
import WebKit
import Combine

class WebBrowserManager: NSObject, ObservableObject {
    static let shared = WebBrowserManager()
    
    @Published var currentURL: URL?
    @Published var currentTitle: String = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0
    @Published var pageHTML: String = ""
    @Published var favorites: [FavoriteSite] = []
    @Published var browsingHistory: [HistoryItem] = []
    @Published var searchEngine: SearchEngine = .baidu
    
    private let defaults = UserDefaults.standard
    private let favoritesKey = "WebBrowser_favorites"
    private let historyKey = "WebBrowser_history"
    private let searchEngineKey = "WebBrowser_searchEngine"
    
    enum SearchEngine: String, CaseIterable, Identifiable {
        case baidu = "baidu"
        case google = "google"
        case bing = "bing"
        case sogou = "sogou"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .baidu: return "百度"
            case .google: return "Google"
            case .bing: return "Bing"
            case .sogou: return "搜狗"
            }
        }
        
        var searchURL: String {
            switch self {
            case .baidu: return "https://www.baidu.com/s?wd="
            case .google: return "https://www.google.com/search?q="
            case .bing: return "https://www.bing.com/search?q="
            case .sogou: return "https://www.sogou.com/web?query="
            }
        }
        
        var icon: String {
            switch self {
            case .baidu: return "🔍"
            case .google: return "🌐"
            case .bing: return "🔎"
            case .sogou: return "🐹"
            }
        }
    }
    
    struct FavoriteSite: Identifiable, Codable {
        let id: String
        var title: String
        var url: String
        var icon: String
        var addedTime: Date
        
        init(title: String, url: String, icon: String = "🌐") {
            self.id = UUID().uuidString
            self.title = title
            self.url = url
            self.icon = icon
            self.addedTime = Date()
        }
    }
    
    struct HistoryItem: Identifiable, Codable {
        let id: String
        let title: String
        let url: String
        let visitTime: Date
    }
    
    private override init() {
        super.init()
        loadFavorites()
        loadHistory()
        loadSearchEngine()
    }
    
    private func loadFavorites() {
        if let data = defaults.data(forKey: favoritesKey),
           let saved = try? JSONDecoder().decode([FavoriteSite].self, from: data) {
            favorites = saved
        } else {
            favorites = defaultFavorites
        }
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: favoritesKey)
        }
    }
    
    private func loadHistory() {
        if let data = defaults.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            browsingHistory = saved
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(browsingHistory) {
            defaults.set(data, forKey: historyKey)
        }
    }
    
    private func loadSearchEngine() {
        if let saved = defaults.string(forKey: searchEngineKey),
           let engine = SearchEngine(rawValue: saved) {
            searchEngine = engine
        }
    }
    
    private var defaultFavorites: [FavoriteSite] {
        [
            FavoriteSite(title: "百度", url: "https://www.baidu.com", icon: "🔍"),
            FavoriteSite(title: "起点中文网", url: "https://www.qidian.com", icon: "📚"),
            FavoriteSite(title: "纵横中文网", url: "https://www.zongheng.com", icon: "📖"),
            FavoriteSite(title: "晋江文学城", url: "https://www.jjwxc.net", icon: "🏠")
        ]
    }
    
    func addToHistory(title: String, url: String) {
        browsingHistory.removeAll { $0.url == url }
        
        let item = HistoryItem(
            id: UUID().uuidString,
            title: title,
            url: url,
            visitTime: Date()
        )
        
        browsingHistory.insert(item, at: 0)
        
        if browsingHistory.count > 100 {
            browsingHistory = Array(browsingHistory.prefix(100))
        }
        
        saveHistory()
    }
    
    func removeHistoryItem(_ item: HistoryItem) {
        browsingHistory.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearHistory() {
        browsingHistory.removeAll()
        saveHistory()
    }
    
    func addToFavorites(title: String, url: String, icon: String = "🌐") {
        guard !favorites.contains(where: { $0.url == url }) else { return }
        
        let favorite = FavoriteSite(title: title, url: url, icon: icon)
        favorites.append(favorite)
        saveFavorites()
    }
    
    func removeFromFavorites(_ favorite: FavoriteSite) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }
    
    func isFavorite(url: String) -> Bool {
        return favorites.contains { $0.url == url }
    }
    
    func setSearchEngine(_ engine: SearchEngine) {
        searchEngine = engine
        defaults.set(engine.rawValue, forKey: searchEngineKey)
    }
    
    func searchURL(for query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: searchEngine.searchURL + encodedQuery)
    }
    
    func isValidURL(_ string: String) -> Bool {
        if let url = URL(string: string),
           let scheme = url.scheme,
           ["http", "https"].contains(scheme.lowercased()) {
            return true
        }
        return false
    }
    
    func parseURL(_ string: String) -> URL? {
        var urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isValidURL(urlString) {
            return URL(string: urlString)
        }
        
        if !urlString.contains(".") {
            return searchURL(for: urlString)
        }
        
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        if let url = URL(string: urlString) {
            return url
        }
        
        return searchURL(for: urlString)
    }
    
    func extractBookSources(from html: String) -> [BookSourceLink] {
        var sources: [BookSourceLink] = []
        
        let patterns = [
            ("bookSourceUrl.*?=.*?[\"']([^\"']+)[\"']", "书源URL"),
            ("source.*?url.*?=.*?[\"']([^\"']+)[\"']", "源地址"),
            ("json.*?=.*?[\"'](https?://[^\"']+\\.json)[\"']", "JSON书源")
        ]
        
        for (pattern, name) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)
                
                for match in matches {
                    if match.numberOfRanges >= 1,
                       let urlRange = Range(match.range(at: 1), in: html) {
                        let url = String(html[urlRange])
                        if isValidURL(url) {
                            sources.append(BookSourceLink(title: name, url: url))
                        }
                    }
                }
            }
        }
        
        return sources
    }
    
    struct BookSourceLink: Identifiable {
        let id = UUID().uuidString
        let title: String
        let url: String
    }
    
    func extractDownloadLinks(from html: String) -> [DownloadLink] {
        var links: [DownloadLink] = []
        
        let patterns = [
            "href=[\"']([^\"']+\\.(txt|epub|pdf|mobi|azw|azw3|cbz|cbr|zip|rar)[^\"']*)[\"']",
            "href=[\"']([^\"']*download[^\"']*)[\"']"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)
                
                for match in matches {
                    if match.numberOfRanges >= 1,
                       let urlRange = Range(match.range(at: 1), in: html) {
                        let url = String(html[urlRange])
                        let fileName = URL(string: url)?.lastPathComponent ?? "未知文件"
                        let fileExtension = (fileName as NSString).pathExtension.lowercased()
                        
                        links.append(DownloadLink(
                            fileName: fileName,
                            url: url,
                            fileType: fileExtension
                        ))
                    }
                }
            }
        }
        
        return links
    }
    
    struct DownloadLink: Identifiable {
        let id = UUID().uuidString
        let fileName: String
        let url: String
        let fileType: String
    }
}
