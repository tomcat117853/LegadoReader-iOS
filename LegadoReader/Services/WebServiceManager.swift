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
    
    struct APIResponse<T: Codable>: Codable {
        let code: Int
        let message: String
        let data: T?
        let timestamp: String
        
        init(code: Int = 200, message: String = "success", data: T? = nil) {
            self.code = code
            self.message = message
            self.data = data
            self.timestamp = ISO8601DateFormatter().string(from: Date())
        }
    }
    
    struct PaginatedResponse<T: Codable>: Codable {
        let items: [T]
        let page: Int
        let pageSize: Int
        let total: Int
        let hasMore: Bool
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
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        ]
        
        if method == "OPTIONS" {
            return (200, headers, "")
        }
        
        var pathComponents = path.split(separator: "/").map { String($0) }
        if pathComponents.first == "" {
            pathComponents.removeFirst()
        }
        
        let apiPath = pathComponents.first ?? ""
        
        switch apiPath {
        case "api":
            return handleV2API(pathComponents: Array(pathComponents.dropFirst()), method: method, body: body)
        case "getBookshelf":
            return getBookshelf(query: path)
        case "getBookSource":
            return getBookSource(query: path)
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
        case "status":
            return getStatus()
        case "":
            return (200, headers, #"{"status":"ok","message":"LegadoReader Web Service is running","version":"1.0"}"#)
        default:
            return errorResponse(404, "Not Found: \(apiPath)")
        }
    }
    
    private func handleV2API(pathComponents: [String], method: String, body: String?) -> (Int, [String: String], String) {
        let headers = [
            "Content-Type": "application/json; charset=utf-8",
            "Access-Control-Allow-Origin": "*"
        ]
        
        guard !pathComponents.isEmpty else {
            return errorResponse(400, "Missing endpoint")
        }
        
        let endpoint = pathComponents[0]
        let remaining = Array(pathComponents.dropFirst())
        
        switch endpoint {
        case "books":
            return handleBooksAPI(method: method, path: remaining, body: body)
        case "sources":
            return handleSourcesAPI(method: method, path: remaining, body: body)
        case "progress":
            return handleProgressAPI(method: method, path: remaining, body: body)
        case "search":
            return handleSearchAPI(method: method, path: remaining, body: body)
        case "sync":
            return handleSyncAPI(method: method, path: remaining, body: body)
        default:
            return errorResponse(404, "Unknown endpoint: \(endpoint)")
        }
    }
    
    private func handleBooksAPI(method: String, path: [String], body: String?) -> (Int, [String: String], String) {
        switch method {
        case "GET":
            if path.isEmpty {
                return getBooksPaginated(query: "")
            } else if path.first == "search" {
                return getBooksPaginated(query: path.dropFirst().joined(separator: "&"))
            } else {
                let bookId = path.first ?? ""
                return getBookById(bookId)
            }
        case "POST":
            return addBook(body: body)
        case "DELETE":
            if let bookId = path.first {
                return deleteBook(bookId)
            }
            return errorResponse(400, "Missing book ID")
        default:
            return errorResponse(405, "Method not allowed")
        }
    }
    
    private func handleSourcesAPI(method: String, path: [String], body: String?) -> (Int, [String: String], String) {
        switch method {
        case "GET":
            if let sourceId = path.first {
                return getSourceById(sourceId)
            }
            return getSourcesList()
        case "POST":
            return saveSource(body: body)
        case "PUT":
            if let sourceId = path.first {
                return updateSource(sourceId: sourceId, body: body)
            }
            return errorResponse(400, "Missing source ID")
        case "DELETE":
            if let sourceId = path.first {
                return deleteSource(sourceId)
            }
            return errorResponse(400, "Missing source ID")
        default:
            return errorResponse(405, "Method not allowed")
        }
    }
    
    private func handleProgressAPI(method: String, path: [String], body: String?) -> (Int, [String: String], String) {
        switch method {
        case "GET":
            if let bookId = path.first {
                return getBookProgress(bookId)
            }
            return getAllProgress()
        case "POST", "PUT":
            if let bookId = path.first {
                return updateBookProgress(bookId: bookId, body: body)
            }
            return errorResponse(400, "Missing book ID")
        default:
            return errorResponse(405, "Method not allowed")
        }
    }
    
    private func handleSearchAPI(method: String, path: [String], body: String?) -> (Int, [String: String], String) {
        switch method {
        case "GET":
            let keyword = path.joined(separator: " ")
            return searchBooks(keyword: keyword)
        case "POST":
            return searchBooks(body: body)
        default:
            return errorResponse(405, "Method not allowed")
        }
    }
    
    private func handleSyncAPI(method: String, path: [String], body: String?) -> (Int, [String: String], String) {
        switch method {
        case "GET":
            return exportSyncData()
        case "POST":
            return importSyncData(body: body)
        default:
            return errorResponse(405, "Method not allowed")
        }
    }
    
    private func errorResponse(_ status: Int, _ message: String) -> (Int, [String: String], String) {
        let headers = ["Content-Type": "application/json; charset=utf-8"]
        let response: [String: Any] = [
            "code": status,
            "message": message,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try? JSONSerialization.data(withJSONObject: response)
        return (status, headers, String(data: data ?? Data(), encoding: .utf8) ?? "{}")
    }
    
    private func successResponse<T: Codable>(_ data: T, message: String = "success") -> (Int, [String: String], String) {
        let headers = ["Content-Type": "application/json; charset=utf-8"]
        let response: [String: Any] = [
            "code": 200,
            "message": message,
            "data": data,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: response)
        return (200, headers, String(data: jsonData ?? Data(), encoding: .utf8) ?? "{}")
    }
    
    private func getStatus() -> (Int, [String: String], String) {
        let headers = ["Content-Type": "application/json; charset=utf-8"]
        let books = DatabaseManager.shared.getAllBooks()
        let sources = DatabaseManager.shared.getAllBookSources()
        
        let status: [String: Any] = [
            "status": "running",
            "version": "1.0",
            "uptime": Date().timeIntervalSince1970,
            "stats": [
                "totalBooks": books.count,
                "totalSources": sources.count,
                "enabledSources": sources.filter { $0.isEnabled }.count
            ],
            "server": [
                "port": port,
                "url": serverURL
            ]
        ]
        
        let data = try? JSONSerialization.data(withJSONObject: status)
        return (200, headers, String(data: data ?? Data(), encoding: .utf8) ?? "{}")
    }
    
    private func getBooksPaginated(query: String) -> (Int, [String: String], String) {
        var page = 1
        var pageSize = 20
        var keyword = ""
        
        if !query.isEmpty {
            let params = query.split(separator: "&")
            for param in params {
                let parts = param.split(separator: "=")
                if parts.count == 2 {
                    let key = String(parts[0])
                    let value = String(parts[1])
                    switch key {
                    case "page": page = Int(value) ?? 1
                    case "pageSize": pageSize = min(Int(value) ?? 20, 100)
                    case "keyword": keyword = value
                    default: break
                    }
                }
            }
        }
        
        var books = DatabaseManager.shared.getAllBooks()
        
        if !keyword.isEmpty {
            books = books.filter {
                $0.name.lowercased().contains(keyword.lowercased()) ||
                $0.author.lowercased().contains(keyword.lowercased())
            }
        }
        
        let total = books.count
        let start = (page - 1) * pageSize
        let end = min(start + pageSize, total)
        
        let pagedBooks = start < total ? Array(books[start..<end]) : []
        let hasMore = end < total
        
        let response = PaginatedResponse(
            items: pagedBooks,
            page: page,
            pageSize: pageSize,
            total: total,
            hasMore: hasMore
        )
        
        return successResponse(response)
    }
    
    private func getBookById(_ bookId: String) -> (Int, [String: String], String) {
        let books = DatabaseManager.shared.getAllBooks()
        if let book = books.first(where: { $0.id == bookId }) {
            return successResponse(book)
        }
        return errorResponse(404, "Book not found")
    }
    
    private func addBook(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let book = try? JSONDecoder().decode(Book.self, from: data) else {
            return errorResponse(400, "Invalid book data")
        }
        
        DatabaseManager.shared.saveBook(book)
        return (201, ["Content-Type": "application/json"], "{\"code\":201,\"message\":\"Book added successfully\",\"data\":null}")
    }
    
    private func deleteBook(_ bookId: String) -> (Int, [String: String], String) {
        DatabaseManager.shared.deleteBook(id: bookId)
        DatabaseManager.shared.deleteChapters(bookId: bookId)
        return successResponse(["deleted": bookId] as [String: String])
    }
    
    private func getSourcesList() -> (Int, [String: String], String) {
        let sources = DatabaseManager.shared.getAllBookSources()
        return successResponse(sources)
    }
    
    private func getSourceById(_ sourceId: String) -> (Int, [String: String], String) {
        let sources = DatabaseManager.shared.getAllBookSources()
        if let source = sources.first(where: { $0.id == sourceId }) {
            return successResponse(source)
        }
        return errorResponse(404, "Source not found")
    }
    
    private func saveSource(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let source = try? JSONDecoder().decode(BookSource.self, from: data) else {
            return errorResponse(400, "Invalid source data")
        }
        
        DatabaseManager.shared.saveBookSource(source)
        return (201, ["Content-Type": "application/json"], "{\"code\":201,\"message\":\"Source saved successfully\"}")
    }
    
    private func updateSource(sourceId: String, body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              var source = try? JSONDecoder().decode(BookSource.self, from: data) else {
            return errorResponse(400, "Invalid source data")
        }
        
        source.id = sourceId
        DatabaseManager.shared.saveBookSource(source)
        return successResponse(source)
    }
    
    private func deleteSource(_ sourceId: String) -> (Int, [String: String], String) {
        return successResponse(["deleted": sourceId] as [String: String])
    }
    
    private func getBookProgress(_ bookId: String) -> (Int, [String: String], String) {
        let progress = ReadingProgressSync.shared.getProgress(for: bookId)
        return successResponse(progress)
    }
    
    private func getAllProgress() -> (Int, [String: String], String) {
        let allProgress = ReadingProgressSync.shared.getAllBooksProgress()
        return successResponse(allProgress)
    }
    
    private func updateBookProgress(bookId: String, body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return errorResponse(400, "Invalid progress data")
        }
        
        let chapterIndex = json["chapterIndex"] as? Int ?? 0
        let position = json["position"] as? Int ?? 0
        
        ReadingProgressSync.shared.saveProgress(
            for: bookId,
            chapterIndex: chapterIndex,
            position: position
        )
        
        return successResponse(["bookId": bookId, "chapterIndex": chapterIndex, "position": position])
    }
    
    private func searchBooks(keyword: String) -> (Int, [String: String], String) {
        let results = BookSourceParser.shared.searchBooks(keyword: keyword)
        return successResponse(results)
    }
    
    private func searchBooks(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keyword = json["keyword"] as? String else {
            return errorResponse(400, "Missing keyword")
        }
        
        let results = BookSourceParser.shared.searchBooks(keyword: keyword)
        return successResponse(results)
    }
    
    private func exportSyncData() -> (Int, [String: String], String) {
        let books = DatabaseManager.shared.getAllBooks()
        let sources = DatabaseManager.shared.getAllBookSources()
        let progress = ReadingProgressSync.shared.getAllBooksProgress()
        
        let syncData: [String: Any] = [
            "version": "1.0",
            "exportTime": ISO8601DateFormatter().string(from: Date()),
            "books": books,
            "sources": sources,
            "progress": progress
        ]
        
        let headers = ["Content-Type": "application/json; charset=utf-8"]
        let data = try? JSONSerialization.data(withJSONObject: syncData)
        return (200, headers, String(data: data ?? Data(), encoding: .utf8) ?? "{}")
    }
    
    private func importSyncData(body: String?) -> (Int, [String: String], String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return errorResponse(400, "Invalid sync data")
        }
        
        var importedBooks = 0
        var importedSources = 0
        var importedProgress = 0
        
        if let booksData = json["books"] as? [[String: Any]] {
            for bookDict in booksData {
                if let bookData = try? JSONSerialization.data(withJSONObject: bookDict),
                   let book = try? JSONDecoder().decode(Book.self, from: bookData) {
                    DatabaseManager.shared.saveBook(book)
                    importedBooks += 1
                }
            }
        }
        
        if let sourcesData = json["sources"] as? [[String: Any]] {
            for sourceDict in sourcesData {
                if let sourceData = try? JSONSerialization.data(withJSONObject: sourceDict),
                   let source = try? JSONDecoder().decode(BookSource.self, from: sourceData) {
                    DatabaseManager.shared.saveBookSource(source)
                    importedSources += 1
                }
            }
        }
        
        if let progressData = json["progress"] as? [[String: Any]] {
            for progressDict in progressData {
                if let progressJson = try? JSONSerialization.data(withJSONObject: progressDict),
                   let progress = try? JSONDecoder().decode(ReadingProgressSync.BookProgress.self, from: progressJson) {
                    ReadingProgressSync.shared.saveProgress(
                        for: progress.bookId,
                        chapterIndex: progress.chapterIndex,
                        position: progress.position
                    )
                    importedProgress += 1
                }
            }
        }
        
        let result: [String: Any] = [
            "importedBooks": importedBooks,
            "importedSources": importedSources,
            "importedProgress": importedProgress
        ]
        
        return successResponse(result, message: "Sync data imported successfully")
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
