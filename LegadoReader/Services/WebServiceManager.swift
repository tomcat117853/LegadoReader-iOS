import Foundation
import Network

class WebServiceManager: ObservableObject {
    static let shared = WebServiceManager()
    
    @Published var isRunning = false
    @Published var port: UInt16 = 1234
    @Published var serverURL: String = ""
    @Published var connectedClients: Int = 0
    @Published var requestLog: [RequestLog] = []
    
    struct RequestLog: Identifiable {
        let id = UUID()
        let timestamp: Date
        let method: String
        let path: String
        let status: Int
    }
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.legado.webservice")
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        port = UInt16(UserDefaults.standard.integer(forKey: "WebService_port"))
        if port == 0 {
            port = 1234
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(Int(port), forKey: "WebService_port")
    }
    
    func startServer() {
        guard !isRunning else { return }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.serverURL = "http://127.0.0.1:\(self?.port ?? 1234)"
                    case .failed(let error):
                        print("Server failed: \(error)")
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.start(queue: queue)
        } catch {
            print("Failed to start server: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        isRunning = false
        connectedClients = 0
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        DispatchQueue.main.async {
            self.connectedClients += 1
        }
        
        receiveRequest(connection)
    }
    
    private func receiveRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processRequest(data, connection: connection)
            }
            
            if isComplete || error != nil {
                connection.cancel()
                DispatchQueue.main.async {
                    self?.connectedClients = max(0, self?.connectedClients ?? 0 - 1)
                }
            } else {
                self?.receiveRequest(connection)
            }
        }
    }
    
    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection, status: 400, body: "Bad Request")
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection, status: 400, body: "Bad Request")
            return
        }
        
        let components = firstLine.split(separator: " ")
        guard components.count >= 2 else {
            sendResponse(connection, status: 400, body: "Bad Request")
            return
        }
        
        let method = String(components[0])
        let path = String(components[1])
        
        var body: String?
        if let bodyStart = requestString.range(of: "\r\n\r\n") {
            body = String(requestString[bodyStart.upperBound...])
        }
        
        let response = handleAPIRequest(method: method, path: path, body: body)
        
        DispatchQueue.main.async {
            self.requestLog.insert(RequestLog(
                timestamp: Date(),
                method: method,
                path: path,
                status: response.status
            ), at: 0)
            
            if self.requestLog.count > 100 {
                self.requestLog.removeLast()
            }
        }
        
        sendResponse(connection, status: response.status, headers: response.headers, body: response.body)
    }
    
    private func handleAPIRequest(method: String, path: String, body: String?) -> (status: Int, headers: [String: String], body: String) {
        let headers = [
            "Content-Type": "application/json; charset=utf-8",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type"
        ]
        
        if method == "OPTIONS" {
            return (200, headers, "")
        }
        
        let pathComponents = path.split(separator: "/")
        let apiPath = pathComponents.first.map(String.init) ?? ""
        
        switch apiPath {
        case "getBookshelf":
            return getBookshelf()
        case "getBookSource":
            return getBookSource()
        case "saveBookSource":
            return saveBookSource(body: body)
        case "saveBookSources":
            return saveBookSources(body: body)
        case "searchBook":
            return searchBook(body: body)
        case "getBookContent":
            return getBookContent(body: body)
        case "getChapterList":
            return getChapterList(body: body)
        case "addToBookshelf":
            return addToBookshelf(body: body)
        case "removeFromBookshelf":
            return removeFromBookshelf(body: body)
        case "getReadProgress":
            return getReadProgress()
        case "exportData":
            return exportData()
        case "importData":
            return importData(body: body)
        case "getRSSSources":
            return getRSSSources()
        case "saveRSSSource":
            return saveRSSSource(body: body)
        case "getRSSArticles":
            return getRSSArticles(body: body)
        case "":
            return (200, headers, #"{"status":"ok","message":"LegadoReader Web Service is running"}"#)
        default:
            return (404, headers, #"{"error":"Not Found"}"#)
        }
    }
    
    private func sendResponse(_ connection: NWConnection, status: Int, headers: [String: String] = [:], body: String = "") {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }
        
        var headerString = "HTTP/1.1 \(status) \(statusText)\r\n"
        headerString += "Content-Length: \(body.utf8.count)\r\n"
        
        for (key, value) in headers {
            headerString += "\(key): \(value)\r\n"
        }
        
        headerString += "\r\n"
        
        let response = headerString + body
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }
    
    // MARK: - API Handlers
    
    private func getBookshelf() -> (Int, [String: String], String) {
        let books = DatabaseManager.shared.getAllBooks()
        
        do {
            let data = try JSONEncoder().encode(books)
            return (200, ["Content-Type": "application/json"], String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return (500, [:], #"{"error":"Failed to encode books"}"#)
        }
    }
    
    private func getBookSource() -> (Int, [String: String], String) {
        let sources = DatabaseManager.shared.getAllBookSources()
        
        do {
            let data = try JSONEncoder().encode(sources)
            return (200, ["Content-Type": "application/json"], String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return (500, [:], #"{"error":"Failed to encode sources"}"#)
        }
    }
    
    private func saveBookSource(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let source = try? JSONDecoder().decode(BookSource.self, from: data) else {
            return (400, [:], #"{"error":"Invalid request body"}"#)
        }
        
        DatabaseManager.shared.saveBookSource(source)
        return (201, [:], #"{"status":"success"}"#)
    }
    
    private func saveBookSources(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let sources = try? JSONDecoder().decode([BookSource].self, from: data) else {
            return (400, [:], #"{"error":"Invalid request body"}"#)
        }
        
        for source in sources {
            DatabaseManager.shared.saveBookSource(source)
        }
        
        return (201, [:], #"{"status":"success","count":\#(sources.count)}"#)
    }
    
    private func searchBook(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = json["key"] as? String else {
            return (400, [:], #"{"error":"Missing search key"}"#)
        }
        
        let results = BookSourceParser.shared.searchBooks(keyword: key)
        
        do {
            let data = try JSONEncoder().encode(results)
            return (200, ["Content-Type": "application/json"], String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return (500, [:], #"{"error":"Failed to encode results"}"#)
        }
    }
    
    private func getBookContent(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bookUrl = json["bookUrl"] as? String,
              let chapterUrl = json["chapterUrl"] as? String else {
            return (400, [:], #"{"error":"Missing parameters"}"#)
        }
        
        let content = BookSourceParser.shared.getChapterContent(bookUrl: bookUrl, chapterUrl: chapterUrl)
        
        return (200, ["Content-Type": "application/json"], #"{"content":"\#(content.addingPercentEncoding(withAllowedCharacters: .jsonAllowed) ?? "")"}"#)
    }
    
    private func getChapterList(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bookUrl = json["bookUrl"] as? String else {
            return (400, [:], #"{"error":"Missing bookUrl"}"#)
        }
        
        let chapters = BookSourceParser.shared.getChapterList(bookUrl: bookUrl)
        
        do {
            let data = try JSONEncoder().encode(chapters)
            return (200, ["Content-Type": "application/json"], String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return (500, [:], #"{"error":"Failed to encode chapters"}"#)
        }
    }
    
    private func addToBookshelf(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let book = try? JSONDecoder().decode(Book.self, from: data) else {
            return (400, [:], #"{"error":"Invalid request body"}"#)
        }
        
        DatabaseManager.shared.saveBook(book)
        return (201, [:], #"{"status":"success"}"#)
    }
    
    private func removeFromBookshelf(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bookId = json["bookId"] as? String else {
            return (400, [:], #"{"error":"Missing bookId"}"#)
        }
        
        DatabaseManager.shared.deleteBook(id: bookId)
        return (200, [:], #"{"status":"success"}"#)
    }
    
    private func getReadProgress() -> (Int, [String: String], String) {
        let progress = ReadingProgressSync.shared.getAllBooksProgress()
        
        do {
            let data = try JSONEncoder().encode(progress)
            return (200, ["Content-Type": "application/json"], String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return (500, [:], #"{"error":"Failed to encode progress"}"#)
        }
    }
    
    private func exportData() -> (Int, [String: String], String) {
        let books = DatabaseManager.shared.getAllBooks()
        let sources = DatabaseManager.shared.getAllBookSources()
        let progress = ReadingProgressSync.shared.getAllBooksProgress()
        
        let exportData: [String: Any] = [
            "books": books,
            "sources": sources,
            "progress": progress
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: exportData)
            return (200, ["Content-Type": "application/json"], String(data: data, encoding: .utf8) ?? "{}")
        } catch {
            return (500, [:], #"{"error":"Failed to export data"}"#)
        }
    }
    
    private func importData(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (400, [:], #"{"error":"Invalid request body"}"#)
        }
        
        if let booksData = json["books"] as? [[String: Any]] {
            for bookDict in booksData {
                if let bookData = try? JSONSerialization.data(withJSONObject: bookDict),
                   let book = try? JSONDecoder().decode(Book.self, from: bookData) {
                    DatabaseManager.shared.saveBook(book)
                }
            }
        }
        
        if let sourcesData = json["sources"] as? [[String: Any]] {
            for sourceDict in sourcesData {
                if let sourceData = try? JSONSerialization.data(withJSONObject: sourceDict),
                   let source = try? JSONDecoder().decode(BookSource.self, from: sourceData) {
                    DatabaseManager.shared.saveBookSource(source)
                }
            }
        }
        
        return (201, [:], #"{"status":"success"}"#)
    }
    
    private func getRSSSources() -> (Int, [String: String], String) {
        let sources = DatabaseManager.shared.getAllRSSSources()
        
        do {
            let data = try JSONEncoder().encode(sources)
            return (200, ["Content-Type": "application/json"], String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return (500, [:], #"{"error":"Failed to encode RSS sources"}"#)
        }
    }
    
    private func saveRSSSource(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let source = try? JSONDecoder().decode(RSSSource.self, from: data) else {
            return (400, [:], #"{"error":"Invalid request body"}"#)
        }
        
        DatabaseManager.shared.saveRSSSource(source)
        return (201, [:], #"{"status":"success"}"#)
    }
    
    private func getRSSArticles(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sourceUrl = json["sourceUrl"] as? String else {
            return (400, [:], #"{"error":"Missing sourceUrl"}"#)
        }
        
        let articles = RSSViewModel().fetchArticles(from: sourceUrl)
        
        do {
            let data = try JSONEncoder().encode(articles)
            return (200, ["Content-Type": "application/json"], String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return (500, [:], #"{"error":"Failed to encode articles"}"#)
        }
    }
}

extension CharacterSet {
    static var jsonAllowed: CharacterSet {
        return CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    }
}
