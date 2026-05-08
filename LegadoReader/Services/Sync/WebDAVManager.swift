import Foundation
import Combine

class WebDAVManager: ObservableObject {
    static let shared = WebDAVManager()
    
    @Published var isConnected = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var isSyncing = false
    
    struct WebDAVSettings: Codable {
        var serverURL: String = ""
        var username: String = ""
        var password: String = ""
        var port: Int = 443
        var useSSL: Bool = true
        var syncInterval: Int = 60
        var autoSync: Bool = false
    }
    
    @Published var settings = WebDAVSettings()
    
    private let defaults = UserDefaults.standard
    private let settingsKey = "WebDAVManager_settings"
    private let lastSyncKey = "WebDAVManager_lastSync"
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        if let data = defaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(WebDAVSettings.self, from: data) {
            settings = savedSettings
        }
        lastSyncTime = defaults.object(forKey: lastSyncKey) as? Date
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }
    
    func connect() async -> Bool {
        guard !settings.serverURL.isEmpty else {
            syncError = "请输入服务器地址"
            return false
        }
        
        let url = buildURL(path: "")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "PROPFIND"
            request.setValue("0,1", forHTTPHeaderField: "Depth")
            
            if let credentials = "\(settings.username):\(settings.password)".data(using: .utf8)?.base64EncodedString() {
                request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            }
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                isConnected = true
                syncError = nil
                return true
            } else {
                isConnected = false
                syncError = "连接失败"
                return false
            }
        } catch {
            isConnected = false
            syncError = error.localizedDescription
            return false
        }
    }
    
    func syncBooks() async {
        await sync(type: .books)
    }
    
    func syncBookSources() async {
        await sync(type: .bookSources)
    }
    
    func syncProgress() async {
        await sync(type: .progress)
    }
    
    func fullSync() async {
        await syncBooks()
        await syncBookSources()
        await syncProgress()
    }
    
    private enum SyncType {
        case books
        case bookSources
        case progress
    }
    
    private func sync(type: SyncType) async {
        guard isConnected else {
            await connect()
            if !isConnected {
                return
            }
        }
        
        isSyncing = true
        
        do {
            switch type {
            case .books:
                try await syncBooksData()
            case .bookSources:
                try await syncBookSourcesData()
            case .progress:
                try await syncProgressData()
            }
            
            lastSyncTime = Date()
            defaults.set(lastSyncTime, forKey: lastSyncKey)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
    
    private func syncBooksData() async throws {
        let books = DatabaseManager.shared.getAllBooks()
        let data = try JSONEncoder().encode(books)
        let path = "/books.json"
        
        try await uploadData(data, to: path)
        try await downloadBooksFromServer()
    }
    
    private func syncBookSourcesData() async throws {
        let sources = DatabaseManager.shared.getAllBookSources()
        let data = try JSONEncoder().encode(sources)
        let path = "/bookSources.json"
        
        try await uploadData(data, to: path)
        try await downloadBookSourcesFromServer()
    }
    
    private func syncProgressData() async throws {
        let progress = ReadingProgressSync.shared.getAllBooksProgress()
        let data = try JSONEncoder().encode(progress)
        let path = "/progress.json"
        
        try await uploadData(data, to: path)
        try await downloadProgressFromServer()
    }
    
    private func uploadData(_ data: Data, to path: String) async throws {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let credentials = "\(settings.username):\(settings.password)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "WebDAV", code: httpResponse.statusCode, userInfo: nil)
        }
    }
    
    private func downloadData(from path: String) async throws -> Data {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        
        if let credentials = "\(settings.username):\(settings.password)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "WebDAV", code: httpResponse.statusCode, userInfo: nil)
        }
        
        return data
    }
    
    private func downloadBooksFromServer() async throws {
        do {
            let data = try await downloadData(from: "/books.json")
            let books = try JSONDecoder().decode([Book].self, from: data)
            
            for book in books {
                DatabaseManager.shared.saveBook(book)
            }
        } catch {
            print("下载书籍失败: \(error)")
        }
    }
    
    private func downloadBookSourcesFromServer() async throws {
        do {
            let data = try await downloadData(from: "/bookSources.json")
            let sources = try JSONDecoder().decode([BookSource].self, from: data)
            
            for source in sources {
                DatabaseManager.shared.saveBookSource(source)
            }
        } catch {
            print("下载书源失败: \(error)")
        }
    }
    
    private func downloadProgressFromServer() async throws {
        do {
            let data = try await downloadData(from: "/progress.json")
            let progressItems = try JSONDecoder().decode([ReadingProgressSync.ReadingProgress].self, from: data)
            
            for progress in progressItems {
                ReadingProgressSync.shared.saveProgress(progress)
            }
        } catch {
            print("下载进度失败: \(error)")
        }
    }
    
    private func buildURL(path: String) -> URL {
        let scheme = settings.useSSL ? "https" : "http"
        let port = settings.useSSL && settings.port == 443 ? "" : ":\(settings.port)"
        return URL(string: "\(scheme)://\(settings.serverURL)\(port)/legado\(path)")!
    }
    
    func deleteFromServer(path: String) async throws {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let credentials = "\(settings.username):\(settings.password)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "WebDAV", code: httpResponse.statusCode, userInfo: nil)
        }
    }
    
    func getFileList() async throws -> [String] {
        let url = buildURL(path: "")
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        
        if let credentials = "\(settings.username):\(settings.password)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "WebDAV", code: httpResponse.statusCode, userInfo: nil)
        }
        
        let xmlString = String(data: data, encoding: .utf8) ?? ""
        return parseFileList(xmlString)
    }
    
    private func parseFileList(_ xml: String) -> [String] {
        var files: [String] = []
        let pattern = #"<d:href>(.+?)</d:href>"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let range = NSRange(xml.startIndex..., in: xml) {
            let matches = regex.matches(in: xml, range: range)
            
            for match in matches {
                if let hrefRange = Range(match.range(at: 1), in: xml) {
                    let href = String(xml[hrefRange])
                    if let lastComponent = URL(string: href)?.lastPathComponent, !lastComponent.isEmpty {
                        files.append(lastComponent)
                    }
                }
            }
        }
        
        return files
    }
}

struct WebDAVSettingsView: View {
    @StateObject private var webDAVManager = WebDAVManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var testConnection = false
    @State private var connectionStatus = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("服务器设置") {
                    TextField("服务器地址", text: $webDAVManager.settings.serverURL)
                    
                    HStack {
                        TextField("端口", value: $webDAVManager.settings.port, formatter: NumberFormatter())
                        Toggle("SSL", isOn: $webDAVManager.settings.useSSL)
                    }
                    
                    TextField("用户名", text: $webDAVManager.settings.username)
                    
                    SecureField("密码", text: $webDAVManager.settings.password)
                }
                
                Section("同步设置") {
                    Toggle("自动同步", isOn: $webDAVManager.settings.autoSync)
                    
                    if webDAVManager.settings.autoSync {
                        HStack {
                            Text("同步间隔")
                            Spacer()
                            TextField("", value: $webDAVManager.settings.syncInterval, formatter: NumberFormatter())
                            Text("分钟")
                        }
                    }
                }
                
                Section("连接测试") {
                    Button(action: {
                        testConnection = true
                        Task {
                            let success = await webDAVManager.connect()
                            connectionStatus = success ? "连接成功" : "连接失败"
                            testConnection = false
                        }
                    }) {
                        HStack {
                            if testConnection {
                                ProgressView()
                            } else {
                                Text("测试连接")
                            }
                        }
                    }
                    
                    if !connectionStatus.isEmpty {
                        Text(connectionStatus)
                            .foregroundColor(connectionStatus == "连接成功" ? .green : .red)
                    }
                }
                
                Section("操作") {
                    Button(action: {
                        webDAVManager.saveSettings()
                        Task {
                            await webDAVManager.fullSync()
                        }
                    }) {
                        Text("立即同步")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        Task {
                            try? await webDAVManager.getFileList()
                        }
                    }) {
                        Text("查看服务器文件")
                            .foregroundColor(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("WebDAV 同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        webDAVManager.saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}
