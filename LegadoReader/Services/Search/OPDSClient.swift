import Foundation
import Combine

class OPDSClient: ObservableObject {
    static let shared = OPDSClient()
    
    @Published var subscriptions: [OPDSubscription] = []
    @Published var isLoading = false
    @Published var error: OPDSError?
    @Published var currentFeed: OPDSFeed?
    @Published var feedHistory: [String] = []
    
    private let defaults = UserDefaults.standard
    private let subscriptionsKey = "OPDS_subscriptions"
    private let historyKey = "OPDS_feedHistory"
    private var cancellables = Set<AnyCancellable>()
    
    struct OPDSSubscription: Identifiable, Codable {
        let id: String
        var title: String
        var url: String
        var iconURL: String?
        var lastUpdated: Date?
        var isEnabled: Bool
        var username: String?
        var password: String?
        
        init(title: String, url: String, iconURL: String? = nil) {
            self.id = UUID().uuidString
            self.title = title
            self.url = url
            self.iconURL = iconURL
            self.lastUpdated = nil
            self.isEnabled = true
        }
    }
    
    enum OPDSError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case parseError(String)
        case authenticationRequired
        case unsupportedFormat
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的URL地址"
            case .networkError(let error): return "网络错误: \(error.localizedDescription)"
            case .parseError(let message): return "解析错误: \(message)"
            case .authenticationRequired: return "需要身份验证"
            case .unsupportedFormat: return "不支持的文件格式"
            }
        }
    }
    
    private init() {
        loadSubscriptions()
        loadHistory()
    }
    
    private func loadSubscriptions() {
        if let data = defaults.data(forKey: subscriptionsKey),
           let subs = try? JSONDecoder().decode([OPDSubscription].self, from: data) {
            subscriptions = subs
        }
    }
    
    private func saveSubscriptions() {
        if let data = try? JSONEncoder().encode(subscriptions) {
            defaults.set(data, forKey: subscriptionsKey)
        }
    }
    
    private func loadHistory() {
        if let history = defaults.stringArray(forKey: historyKey) {
            feedHistory = history
        }
    }
    
    private func saveHistory() {
        defaults.set(feedHistory, forKey: historyKey)
    }
    
    func fetchFeed(url: String, completion: @escaping (Result<OPDSFeed, OPDSError>) -> Void) {
        guard let feedURL = URL(string: url) else {
            completion(.failure(.invalidURL))
            return
        }
        
        isLoading = true
        error = nil
        
        var request = URLRequest(url: feedURL)
        request.setValue("LegadoReader/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        if let subscription = subscriptions.first(where: { $0.url == url }) {
            if let username = subscription.username, let password = subscription.password {
                let credentials = "\(username):\(password)"
                if let credentialsData = credentials.data(using: .utf8) {
                    let base64Credentials = credentialsData.base64EncodedString()
                    request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
                }
            }
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.parseError("没有返回数据")))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        completion(.failure(.authenticationRequired))
                        return
                    }
                }
                
                let parser = OPDSParser()
                if let catalog = parser.parse(data: data), !catalog.isEmpty {
                    let feed = OPDSFeed()
                    feed.title = catalog.entries.first?.title ?? "Untitled"
                    feed.href = url
                    feed.entries = catalog.entries
                    
                    for link in catalog.feeds.first?.links ?? [] {
                        if link.rel.contains("alternate") || link.rel.contains("self") {
                            let subFeed = OPDSFeed()
                            subFeed.href = link.href
                            subFeed.title = link.title ?? "Sub Feed"
                            feed.entries.append(OPDSEntry())
                        }
                    }
                    
                    self?.currentFeed = feed
                    self?.addToHistory(url)
                    completion(.success(feed))
                } else {
                    completion(.failure(.parseError("无法解析OPDS源")))
                }
            }
        }.resume()
    }
    
    func discoverCatalogs(url: String, completion: @escaping (Result<[OPDSFeed], OPDSError>) -> Void) {
        fetchFeed(url: url) { result in
            switch result {
            case .success(let feed):
                let catalogs = feed.links.filter { $0.type?.contains("application/atom") == true || $0.type?.contains("application/xml") == true }
                var feeds: [OPDSFeed] = []
                for link in catalogs {
                    let newFeed = OPDSFeed()
                    newFeed.href = link.href
                    newFeed.title = link.title ?? "Catalog"
                    feeds.append(newFeed)
                }
                completion(.success(feeds))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func addSubscription(title: String, url: String, username: String? = nil, password: String? = nil) -> Bool {
        guard URL(string: url) != nil else { return false }
        
        if subscriptions.contains(where: { $0.url == url }) {
            return false
        }
        
        var subscription = OPDSSubscription(title: title, url: url)
        subscription.username = username
        subscription.password = password
        
        subscriptions.append(subscription)
        saveSubscriptions()
        
        return true
    }
    
    func removeSubscription(id: String) {
        subscriptions.removeAll { $0.id == id }
        saveSubscriptions()
    }
    
    func updateSubscription(_ subscription: OPDSSubscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            saveSubscriptions()
        }
    }
    
    func toggleSubscription(id: String) {
        if let index = subscriptions.firstIndex(where: { $0.id == id }) {
            subscriptions[index].isEnabled.toggle()
            saveSubscriptions()
        }
    }
    
    private func addToHistory(_ url: String) {
        feedHistory.removeAll { $0 == url }
        feedHistory.insert(url, at: 0)
        if feedHistory.count > 20 {
            feedHistory = Array(feedHistory.prefix(20))
        }
        saveHistory()
    }
    
    func clearHistory() {
        feedHistory.removeAll()
        saveHistory()
    }
    
    func downloadBook(url: String, bookTitle: String, completion: @escaping (Result<URL, OPDSError>) -> Void) {
        guard let downloadURL = URL(string: url) else {
            completion(.failure(.invalidURL))
            return
        }
        
        isLoading = true
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsPath = documentsPath.appendingPathComponent("Downloads", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
        } catch {
            completion(.failure(.networkError(error)))
            return
        }
        
        let fileExtension = URL(string: url)?.pathExtension ?? "epub"
        let localURL = downloadsPath.appendingPathComponent("\(bookTitle).\(fileExtension)")
        
        var request = URLRequest(url: downloadURL)
        request.setValue("LegadoReader/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.downloadTask(with: request) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let tempURL = tempURL else {
                    completion(.failure(.parseError("下载失败")))
                    return
                }
                
                do {
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        try FileManager.default.removeItem(at: localURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: localURL)
                    completion(.success(localURL))
                } catch {
                    completion(.failure(.networkError(error)))
                }
            }
        }.resume()
    }
    
    func searchInCatalog(url: String, query: String, completion: @escaping (Result<[OPDSEntry], OPDSError>) -> Void) {
        guard var urlComponents = URLComponents(string: url) else {
            completion(.failure(.invalidURL))
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "searchTerms", value: query)
        ]
        
        guard let searchURL = urlComponents.url?.absoluteString else {
            completion(.failure(.invalidURL))
            return
        }
        
        fetchFeed(url: searchURL) { result in
            switch result {
            case .success(let feed):
                completion(.success(feed.entries))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

extension OPDSClient {
    static let popularCatalogs: [OPDSClient.OPDSSubscription] = [
        OPDSClient.OPDSSubscription(
            title: "Project Gutenberg",
            url: "https://gutendownload.com/feed",
            iconURL: nil
        ),
        OPDSClient.OPDSSubscription(
            title: "Standard Ebooks",
            url: "https://standardebooks.org/opds",
            iconURL: nil
        ),
        OPDSClient.OPDSSubscription(
            title: "Feedbooks",
            url: "http://www.feedbooks.com/catalog.atom",
            iconURL: nil
        ),
        OPDSClient.OPDSSubscription(
            title: "Open Library",
            url: "https://openlibrary.org/developers/vanity/opds",
            iconURL: nil
        )
    ]
}
