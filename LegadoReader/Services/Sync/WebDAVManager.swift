import Foundation
import Combine

class WebDAVManager: ObservableObject {
    static let shared = WebDAVManager()
    
    @Published var isConnected = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var isSyncing = false
    @Published var serverFiles: [WebDAVFileItem] = []
    @Published var currentPath: String = ""
    
    enum PresetService: String, CaseIterable, Identifiable {
        case none = ""
        case jianguoyun = "坚果云"
        case infiniCloud = "InfiniCloud"
        case nutstore = "Nutstore"
        case nextcloud = "Nextcloud"
        case owncloud = "OwnCloud"
        case custom = "自定义"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .none, .custom: return "server.rack"
            case .jianguoyun, .nutstore: return "leaf.fill"
            case .infiniCloud: return "cloud.fill"
            case .nextcloud, .owncloud: return "cloud.sun.fill"
            }
        }
        
        var color: String {
            switch self {
            case .none, .custom: return "gray"
            case .jianguoyun, .nutstore: return "green"
            case .infiniCloud: return "blue"
            case .nextcloud, .owncloud: return "orange"
            }
        }
        
        var defaultPort: Int { 443 }
        var defaultSSL: Bool { true }
        
        var serverHint: String {
            switch self {
            case .none: return ""
            case .jianguoyun: return "dav.jianguoyun.com/dav"
            case .infiniCloud: return "infini.cloud"
            case .nutstore: return "dav.nutstore.net/dav"
            case .nextcloud: return "your-nextcloud.com/remote.php/dav/files/username"
            case .owncloud: return "your-owncloud.com/remote.php/dav/files/username"
            case .custom: return ""
            }
        }
    }
    
    struct WebDAVSettings: Codable {
        var presetService: String = ""
        var serverURL: String = ""
        var username: String = ""
        var password: String = ""
        var port: Int = 443
        var useSSL: Bool = true
        var syncInterval: Int = 60
        var autoSync: Bool = false
        var syncBooks: Bool = true
        var syncSources: Bool = true
        var syncProgress: Bool = true
        var remotePath: String = "/Legado"
    }
    
    struct WebDAVFileItem: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let isDirectory: Bool
        let size: Int64
        let modifiedDate: Date?
        
        var icon: String {
            isDirectory ? "folder.fill" : "doc.fill"
        }
        
        var formattedSize: String {
            if isDirectory { return "" }
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    @Published var settings = WebDAVSettings()
    
    private let defaults = UserDefaults.standard
    private let settingsKey = "WebDAVManager_settings"
    private let lastSyncKey = "WebDAVManager_lastSync"
    
    private init() {
        loadSettings()
    }
    
    var currentPreset: PresetService {
        get {
            PresetService(rawValue: settings.presetService) ?? .none
        }
        set {
            settings.presetService = newValue.rawValue
            if newValue != .none && newValue != .custom {
                settings.serverURL = newValue.serverHint
                settings.port = newValue.defaultPort
                settings.useSSL = newValue.defaultSSL
            }
        }
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
            request.timeoutInterval = 15
            
            if let credentials = "\(settings.username):\(settings.password)".data(using: .utf8)?.base64EncodedString() {
                request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            }
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 207 {
                isConnected = true
                syncError = nil
                return true
            } else {
                isConnected = false
                syncError = "连接失败 (HTTP \(httpResponse.statusCode))"
                return false
            }
        } catch {
            isConnected = false
            syncError = "连接失败: \(error.localizedDescription)"
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
        var baseURL = settings.serverURL
        
        if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
            let port = settings.useSSL && settings.port == 443 ? "" : ":\(settings.port)"
            baseURL = "\(scheme)://\(baseURL)\(port)"
        }
        
        let remotePath = settings.remotePath.isEmpty ? "" : settings.remotePath
        let cleanPath = path.isEmpty ? remotePath : path
        
        return URL(string: baseURL + cleanPath)!
    }
    
    func deleteFromServer(path: String) async throws {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        
        if let credentials = "\(settings.username):\(settings.password)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "WebDAV", code: httpResponse.statusCode, userInfo: nil)
        }
    }
    
    func getFileList(path: String = "") async throws -> [WebDAVFileItem] {
        let targetPath = path.isEmpty ? settings.remotePath : path
        let url = buildURL(path: targetPath)
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.timeoutInterval = 15
        
        if let credentials = "\(settings.username):\(settings.password)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) && httpResponse.statusCode != 207 {
            throw NSError(domain: "WebDAV", code: httpResponse.statusCode, userInfo: nil)
        }
        
        let xmlString = String(data: data, encoding: .utf8) ?? ""
        return parseFileList(xmlString, basePath: targetPath)
    }
    
    private func parseFileList(_ xml: String, basePath: String) -> [WebDAVFileItem] {
        var files: [WebDAVFileItem] = []
        
        let hrefPattern = #"<d:href>([^<]+)</d:href>"#
        let propPattern = #"<d:prop>([\s\S]*?)</d:prop>"#
        let displayNamePattern = #"<d:displayname>([^<]*)</d:displayname>"#
        let contentLengthPattern = #"<d:getcontentlength>([^<]*)</d:getcontentlength>"#
        let lastModifiedPattern = #"<d:getlastmodified>([^<]*)</d:getlastmodified>"#
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let hrefRegex = try? NSRegularExpression(pattern: hrefPattern, options: []),
              let propRegex = try? NSRegularExpression(pattern: propPattern, options: []),
              let range = Range(xml.startIndex..., in: xml) else {
            return files
        }
        
        let hrefMatches = hrefRegex.matches(in: xml, range: range)
        let propMatches = propRegex.matches(in: xml, range: range)
        
        for (index, hrefMatch) in hrefMatches.enumerated() {
            guard let hrefRange = Range(hrefMatch.range(at: 1), in: xml) else { continue }
            var href = String(xml[hrefRange]).removingPercentEncoding ?? String(xml[hrefRange])
            href = href.replacingOccurrences(of: " ", with: "%20")
            
            var isDirectory = false
            var displayName = ""
            var size: Int64 = 0
            var modifiedDate: Date? = nil
            
            if index < propMatches.count {
                let propMatch = propMatches[index]
                if let propRange = Range(propMatch.range(at: 1), in: xml) {
                    let propContent = String(xml[propRange])
                    
                    if propContent.contains("<d:collection/>") || propContent.contains("<d:collection") {
                        isDirectory = true
                    }
                    
                    if let nameRegex = try? NSRegularExpression(pattern: displayNamePattern, options: []),
                       let nameMatch = nameRegex.firstMatch(in: propContent, range: Range(propContent.startIndex..., in: propContent)!) {
                        if let nameRange = Range(nameMatch.range(at: 1), in: propContent) {
                            displayName = String(propContent[nameRange]).removingPercentEncoding ?? String(propContent[nameRange])
                        }
                    }
                    
                    if let sizeRegex = try? NSRegularExpression(pattern: contentLengthPattern, options: []),
                       let sizeMatch = sizeRegex.firstMatch(in: propContent, range: Range(propContent.startIndex..., in: propContent)!) {
                        if let sizeRange = Range(sizeMatch.range(at: 1), in: propContent) {
                            size = Int64(propContent[sizeRange]) ?? 0
                        }
                    }
                    
                    if let dateRegex = try? NSRegularExpression(pattern: lastModifiedPattern, options: []),
                       let dateMatch = dateRegex.firstMatch(in: propContent, range: Range(propContent.startIndex..., in: propContent)!) {
                        if let dateRange = Range(dateMatch.range(at: 1), in: propContent) {
                            let dateString = String(propContent[dateRange])
                            modifiedDate = dateFormatter.date(from: dateString)
                        }
                    }
                }
            }
            
            if displayName.isEmpty {
                displayName = URL(string: href)?.lastPathComponent ?? href
            }
            
            if displayName.hasPrefix(".") || displayName == "/" {
                continue
            }
            
            let decodedHref = href.removingPercentEncoding ?? href
            if decodedHref == basePath || (decodedHref.hasSuffix(basePath + "/") && decodedHref.count == basePath.count + 1) {
                continue
            }
            
            let fullPath = (basePath as NSString).appendingPathComponent(displayName)
            
            files.append(WebDAVFileItem(
                name: displayName,
                path: fullPath,
                isDirectory: isDirectory,
                size: size,
                modifiedDate: modifiedDate
            ))
        }
        
        return files.sorted { file1, file2 in
            if file1.isDirectory != file2.isDirectory {
                return file1.isDirectory
            }
            return file1.name.localizedCaseInsensitiveCompare(file2.name) == .orderedAscending
        }
    }
}

struct WebDAVSettingsView: View {
    @StateObject private var webDAVManager = WebDAVManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var testConnection = false
    @State private var connectionStatus = ""
    @State private var showingFileBrowser = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("服务", selection: Binding(
                        get: { webDAVManager.currentPreset },
                        set: { webDAVManager.currentPreset = $0 }
                    )) {
                        ForEach(PresetService.allCases) { service in
                            HStack {
                                Image(systemName: service.icon)
                                    .foregroundColor(colorForService(service))
                                Text(service.rawValue.isEmpty ? "自定义" : service.rawValue)
                            }
                            .tag(service)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("选择服务")
                } footer: {
                    Text("选择预设服务可自动填充服务器地址")
                }
                
                Section("服务器设置") {
                    TextField("服务器地址", text: $webDAVManager.settings.serverURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    HStack {
                        TextField("端口", value: $webDAVManager.settings.port, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                        Toggle("SSL", isOn: $webDAVManager.settings.useSSL)
                    }
                    
                    TextField("用户名", text: $webDAVManager.settings.username)
                        .autocapitalization(.none)
                    
                    SecureField("密码", text: $webDAVManager.settings.password)
                    
                    TextField("远程路径", text: $webDAVManager.settings.remotePath)
                        .autocapitalization(.none)
                }
                
                Section("同步设置") {
                    Toggle("自动同步", isOn: $webDAVManager.settings.autoSync)
                    
                    if webDAVManager.settings.autoSync {
                        HStack {
                            Text("同步间隔")
                            Spacer()
                            TextField("", value: $webDAVManager.settings.syncInterval, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                            Text("分钟")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("同步书籍", isOn: $webDAVManager.settings.syncBooks)
                    Toggle("同步书源", isOn: $webDAVManager.settings.syncSources)
                    Toggle("同步进度", isOn: $webDAVManager.settings.syncProgress)
                }
                
                Section("连接状态") {
                    HStack {
                        Circle()
                            .fill(webDAVManager.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(webDAVManager.isConnected ? "已连接" : "未连接")
                            .foregroundColor(webDAVManager.isConnected ? .green : .red)
                        
                        Spacer()
                        
                        if let lastSync = webDAVManager.lastSyncTime {
                            Text("上次同步: \(lastSync, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        testConnection = true
                        connectionStatus = ""
                        Task {
                            let success = await webDAVManager.connect()
                            await MainActor.run {
                                connectionStatus = success ? "连接成功 ✓" : "连接失败 ✗"
                                if let error = webDAVManager.syncError {
                                    connectionStatus += "\n\(error)"
                                }
                                testConnection = false
                            }
                        }
                    }) {
                        HStack {
                            if testConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "wifi")
                                Text("测试连接")
                            }
                        }
                    }
                    .disabled(testConnection)
                    
                    if !connectionStatus.isEmpty {
                        Text(connectionStatus)
                            .font(.caption)
                            .foregroundColor(connectionStatus.contains("成功") ? .green : .red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Section("操作") {
                    Button(action: {
                        webDAVManager.saveSettings()
                        Task {
                            await webDAVManager.fullSync()
                        }
                    }) {
                        HStack {
                            if webDAVManager.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("立即同步")
                        }
                    }
                    .disabled(webDAVManager.isSyncing)
                    
                    Button(action: {
                        showingFileBrowser = true
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.questionmark")
                            Text("浏览服务器文件")
                        }
                    }
                }
                
                if let error = webDAVManager.syncError, !error.isEmpty {
                    Section("错误信息") {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
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
            .sheet(isPresented: $showingFileBrowser) {
                WebDAVFileBrowserView()
            }
        }
    }
    
    private func colorForService(_ service: WebDAVManager.PresetService) -> Color {
        switch service {
        case .none, .custom: return .gray
        case .jianguoyun, .nutstore: return .green
        case .infiniCloud: return .blue
        case .nextcloud, .owncloud: return .orange
        }
    }
}

struct WebDAVFileBrowserView: View {
    @StateObject private var webDAVManager = WebDAVManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var files: [WebDAVManager.WebDAVFileItem] = []
    @State private var isLoading = false
    @State private var currentPath = ""
    @State private var errorMessage = ""
    @State private var pathHistory: [String] = []
    
    var body: some View {
        NavigationView {
            List {
                if !currentPath.isEmpty && currentPath != webDAVManager.settings.remotePath {
                    Section {
                        Button(action: {
                            goBack()
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.blue)
                                Text("返回上级目录")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }
                    } else if files.isEmpty {
                        Text("暂无文件")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(files) { file in
                            if file.isDirectory {
                                Button(action: {
                                    enterDirectory(file)
                                }) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.yellow)
                                        VStack(alignment: .leading) {
                                            Text(file.name)
                                                .foregroundColor(.primary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                HStack {
                                    Image(systemName: iconForFile(file.name))
                                        .foregroundColor(colorForFile(file.name))
                                    VStack(alignment: .leading) {
                                        Text(file.name)
                                            .foregroundColor(.primary)
                                        if !file.formattedSize.isEmpty {
                                            Text(file.formattedSize)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("文件浏览器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        loadFiles()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadFiles()
            }
        }
    }
    
    private func loadFiles() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let fileList = try await webDAVManager.getFileList(path: currentPath.isEmpty ? webDAVManager.settings.remotePath : currentPath)
                await MainActor.run {
                    files = fileList
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func enterDirectory(_ directory: WebDAVManager.WebDAVFileItem) {
        pathHistory.append(currentPath)
        currentPath = directory.path
        loadFiles()
    }
    
    private func goBack() {
        if let previousPath = pathHistory.popLast() {
            currentPath = previousPath
            loadFiles()
        } else {
            currentPath = ""
            loadFiles()
        }
    }
    
    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "md": return "doc.text"
        case "epub": return "book"
        case "pdf": return "doc.fill"
        case "mobi", "azw", "azw3": return "ipad"
        case "cbz", "cbr": return "photo.stack"
        case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
        case "json": return "curlybraces"
        default: return "doc"
        }
    }
    
    private func colorForFile(_ name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "md": return .gray
        case "epub": return .green
        case "pdf": return .red
        case "mobi", "azw", "azw3": return .purple
        case "cbz", "cbr": return .orange
        case "zip", "rar", "7z": return .blue
        case "json": return .yellow
        default: return .gray
        }
    }
}
