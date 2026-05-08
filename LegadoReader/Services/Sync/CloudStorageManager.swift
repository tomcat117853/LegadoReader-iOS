import Foundation
import Combine

class CloudStorageManager: ObservableObject {
    static let shared = CloudStorageManager()
    
    @Published var isConnected = false
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var lastSyncTime: Date?
    @Published var connectedService: CloudService?
    
    enum CloudService: String, CaseIterable, Identifiable {
        case none = ""
        case baiduPan = "百度云盘"
        case aliDrive = "阿里云盘"
        case webdav = "WebDAV"
        case opds = "OPDS"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .none: return "questionmark.circle"
            case .baiduPan: return "cloud.fill"
            case .aliDrive: return "cloud.sun.fill"
            case .webdav: return "externaldrive.connected.to.line.below"
            case .opds: return "book.circle"
            }
        }
        
        var color: String {
            switch self {
            case .none: return "gray"
            case .baiduPan: return "blue"
            case .aliDrive: return "orange"
            case .webdav: return "purple"
            case .opds: return "green"
            }
        }
        
        var description: String {
            switch self {
            case .none: return "未选择"
            case .baiduPan: return "百度云盘"
            case .aliDrive: return "阿里云盘"
            case .webdav: return "通用WebDAV协议"
            case .opds: return "电子书订阅协议"
            }
        }
    }
    
    struct CloudStorageSettings: Codable {
        var selectedService: String = ""
        var baiduAccessToken: String = ""
        var baiduRefreshToken: String = ""
        var baiduUserId: String = ""
        var aliAccessToken: String = ""
        var aliRefreshToken: String = ""
        var aliDriveId: String = ""
        var webdavServerURL: String = ""
        var webdavUsername: String = ""
        var webdavPassword: String = ""
        var webdavPort: Int = 443
        var webdavUseSSL: Bool = true
        var webdavRemotePath: String = "/Legado"
        var opdsURL: String = ""
        var opdsUsername: String = ""
        var opdsPassword: String = ""
        var autoSync: Bool = false
        var syncInterval: Int = 60
    }
    
    struct CloudFile: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let isDirectory: Bool
        let size: Int64
        let modifiedDate: Date?
        let type: String
        
        var icon: String {
            if isDirectory { return "folder.fill" }
            let ext = (name as NSString).pathExtension.lowercased()
            switch ext {
            case "txt", "md": return "doc.text"
            case "epub": return "book"
            case "pdf": return "doc.fill"
            case "mobi", "azw", "azw3": return "ipad"
            case "cbz", "cbr": return "photo.stack"
            case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
            default: return "doc"
            }
        }
        
        var color: Color {
            if isDirectory { return .yellow }
            let ext = (name as NSString).pathExtension.lowercased()
            switch ext {
            case "txt", "md": return .gray
            case "epub": return .green
            case "pdf": return .red
            case "mobi", "azw", "azw3": return .purple
            case "cbz", "cbr": return .orange
            case "zip", "rar", "7z": return .blue
            default: return .gray
            }
        }
        
        var formattedSize: String {
            if isDirectory { return "" }
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    @Published var settings = CloudStorageSettings()
    @Published var files: [CloudFile] = []
    @Published var currentPath: String = ""
    @Published var pathHistory: [String] = []
    
    private let defaults = UserDefaults.standard
    private let settingsKey = "CloudStorageManager_settings"
    private let lastSyncKey = "CloudStorageManager_lastSync"
    
    var currentService: CloudService {
        CloudService(rawValue: settings.selectedService) ?? .none
    }
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        if let data = defaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(CloudStorageSettings.self, from: data) {
            settings = savedSettings
        }
        lastSyncTime = defaults.object(forKey: lastSyncKey) as? Date
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }
    
    func selectService(_ service: CloudService) {
        settings.selectedService = service.rawValue
        saveSettings()
    }
    
    func connect() async -> Bool {
        guard currentService != .none else {
            syncError = "请选择云服务"
            return false
        }
        
        switch currentService {
        case .baiduPan:
            return await connectBaidu()
        case .aliDrive:
            return await connectAliDrive()
        case .webdav:
            return await connectWebDAV()
        case .opds:
            return await connectOPDS()
        case .none:
            return false
        }
    }
    
    private func connectBaidu() async -> Bool {
        if settings.baiduAccessToken.isEmpty {
            syncError = "请先登录百度云盘"
            return false
        }
        
        do {
            let url = URL(string: "https://pan.baidu.com/rest/2.0/xpan/nas")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(settings.baiduAccessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                await MainActor.run {
                    isConnected = true
                    syncError = nil
                }
                return true
            }
            
            await MainActor.run {
                syncError = "百度云盘连接失败"
            }
            return false
        } catch {
            await MainActor.run {
                syncError = "百度云盘连接错误: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    private func connectAliDrive() async -> Bool {
        if settings.aliAccessToken.isEmpty {
            syncError = "请先登录阿里云盘"
            return false
        }
        
        do {
            let url = URL(string: "https://open.aliyundrive.com/adrive/v1.0/user/getDeviceInfo")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(settings.aliAccessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{}".data(using: .utf8)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                await MainActor.run {
                    isConnected = true
                    syncError = nil
                }
                return true
            }
            
            await MainActor.run {
                syncError = "阿里云盘连接失败"
            }
            return false
        } catch {
            await MainActor.run {
                syncError = "阿里云盘连接错误: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    private func connectWebDAV() async -> Bool {
        guard !settings.webdavServerURL.isEmpty else {
            syncError = "请输入WebDAV服务器地址"
            return false
        }
        
        do {
            let scheme = settings.webdavUseSSL ? "https" : "http"
            var serverURL = settings.webdavServerURL
            if !serverURL.hasPrefix("http") {
                let port = settings.webdavUseSSL && settings.webdavPort == 443 ? "" : ":\(settings.webdavPort)"
                serverURL = "\(scheme)://\(serverURL)\(port)"
            }
            
            let url = URL(string: serverURL + settings.webdavRemotePath)!
            var request = URLRequest(url: url)
            request.httpMethod = "PROPFIND"
            request.setValue("0,1", forHTTPHeaderField: "Depth")
            request.timeoutInterval = 15
            
            if let credentials = "\(settings.webdavUsername):\(settings.webdavPassword)".data(using: .utf8)?.base64EncodedString() {
                request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            }
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 207 {
                await MainActor.run {
                    isConnected = true
                    syncError = nil
                }
                return true
            }
            
            await MainActor.run {
                syncError = "WebDAV连接失败 (HTTP \(response as? HTTPURLResponse)?.statusCode ?? 0)"
            }
            return false
        } catch {
            await MainActor.run {
                syncError = "WebDAV连接错误: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    private func connectOPDS() async -> Bool {
        guard !settings.opdsURL.isEmpty else {
            syncError = "请输入OPDS地址"
            return false
        }
        
        guard URL(string: settings.opdsURL) != nil else {
            syncError = "无效的OPDS地址"
            return false
        }
        
        await MainActor.run {
            isConnected = true
            syncError = nil
        }
        return true
    }
    
    func loadFiles(path: String = "") async {
        guard isConnected else {
            let success = await connect()
            if !success { return }
        }
        
        await MainActor.run {
            isSyncing = true
            files = []
        }
        
        do {
            let fileList: [CloudFile]
            
            switch currentService {
            case .baiduPan:
                fileList = try await loadBaiduFiles(path: path)
            case .aliDrive:
                fileList = try await loadAliFiles(path: path)
            case .webdav:
                fileList = try await loadWebDAVFiles(path: path)
            case .opds:
                fileList = try await loadOPDSFiles(path: path)
            case .none:
                fileList = []
            }
            
            await MainActor.run {
                files = fileList
                currentPath = path
                isSyncing = false
            }
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
                isSyncing = false
            }
        }
    }
    
    private func loadBaiduFiles(path: String) async throws -> [CloudFile] {
        var files: [CloudFile] = []
        
        let url = URL(string: "https://pan.baidu.com/rest/2.0/xpan/file?method=list&dir=\(path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path)&access_token=\(settings.baiduAccessToken)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let list = json["list"] as? [[String: Any]] {
            for item in list {
                let name = item["server_filename"] as? String ?? item["filename"] as? String ?? ""
                let isDir = (item["isdir"] as? Int) == 1
                let size = Int64(item["size"] as? Int ?? 0)
                let path = item["path"] as? String ?? ""
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let modifiedDate = dateFormatter.date(from: item["mtime"] as? String ?? "")
                
                files.append(CloudFile(
                    name: name,
                    path: path,
                    isDirectory: isDir,
                    size: size,
                    modifiedDate: modifiedDate,
                    type: isDir ? "folder" : (name as NSString).pathExtension.lowercased()
                ))
            }
        }
        
        return files.sorted { f1, f2 in
            if f1.isDirectory != f2.isDirectory { return f1.isDirectory }
            return f1.name.localizedCaseInsensitiveCompare(f2.name) == .orderedAscending
        }
    }
    
    private func loadAliFiles(path: String) async throws -> [CloudFile] {
        var files: [CloudFile] = []
        
        let url = URL(string: "https://open.aliyundrive.com/adrive/v1.0/openFile/list")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.aliAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "drive_id": settings.aliDriveId,
            "parent_file_id": path.isEmpty ? "root" : path,
            "limit": 100,
            "order_by": "name",
            "order_direction": "ASC"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["items"] as? [[String: Any]] {
            for item in items {
                let name = item["name"] as? String ?? ""
                let isDir = (item["type"] as? String) == "folder"
                let size = Int64(item["size"] as? Int ?? 0)
                let fileId = item["file_id"] as? String ?? ""
                
                let modifiedDate: Date?
                if let updatedAt = item["updated_at"] as? String {
                    let formatter = ISO8601DateFormatter()
                    modifiedDate = formatter.date(from: updatedAt)
                } else {
                    modifiedDate = nil
                }
                
                files.append(CloudFile(
                    name: name,
                    path: fileId,
                    isDirectory: isDir,
                    size: size,
                    modifiedDate: modifiedDate,
                    type: isDir ? "folder" : (name as NSString).pathExtension.lowercased()
                ))
            }
        }
        
        return files.sorted { f1, f2 in
            if f1.isDirectory != f2.isDirectory { return f1.isDirectory }
            return f1.name.localizedCaseInsensitiveCompare(f2.name) == .orderedAscending
        }
    }
    
    private func loadWebDAVFiles(path: String) async throws -> [CloudFile] {
        let files: [CloudFile] = []
        
        let scheme = settings.webdavUseSSL ? "https" : "http"
        var serverURL = settings.webdavServerURL
        if !serverURL.hasPrefix("http") {
            let port = settings.webdavUseSSL && settings.webdavPort == 443 ? "" : ":\(settings.webdavPort)"
            serverURL = "\(scheme)://\(serverURL)\(port)"
        }
        
        let targetPath = path.isEmpty ? settings.webdavRemotePath : path
        let url = URL(string: serverURL + targetPath)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.timeoutInterval = 15
        
        if let credentials = "\(settings.webdavUsername):\(settings.webdavPassword)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) && httpResponse.statusCode != 207 {
            throw NSError(domain: "WebDAV", code: httpResponse.statusCode, userInfo: nil)
        }
        
        return parseWebDAVResponse(data, basePath: targetPath)
    }
    
    private func parseWebDAVResponse(_ data: Data, basePath: String) -> [CloudFile] {
        var files: [CloudFile] = []
        
        guard let xmlString = String(data: data, encoding: .utf8) else { return files }
        
        let hrefPattern = #"<d:href>([^<]+)</d:href>"#
        let propPattern = #"<d:prop>([\s\S]*?)</d:prop>"#
        
        guard let hrefRegex = try? NSRegularExpression(pattern: hrefPattern, options: []),
              let propRegex = try? NSRegularExpression(pattern: propPattern, options: []),
              let range = Range(xmlString.startIndex..., in: xmlString) else { return files }
        
        let hrefMatches = hrefRegex.matches(in: xmlString, range: range)
        let propMatches = propRegex.matches(in: xmlString, range: range)
        
        for (index, hrefMatch) in hrefMatches.enumerated() {
            guard let hrefRange = Range(hrefMatch.range(at: 1), in: xmlString) else { continue }
            var href = String(xmlString[hrefRange]).removingPercentEncoding ?? String(xmlString[hrefRange])
            
            var isDirectory = false
            var size: Int64 = 0
            
            if index < propMatches.count {
                let propMatch = propMatches[index]
                if let propRange = Range(propMatch.range(at: 1), in: xmlString) {
                    let propContent = String(xmlString[propRange])
                    if propContent.contains("<d:collection") {
                        isDirectory = true
                    }
                    
                    let sizePattern = #"<d:getcontentlength>([^<]*)</d:getcontentlength>"#
                    if let sizeRegex = try? NSRegularExpression(pattern: sizePattern, options: []),
                       let sizeMatch = sizeRegex.firstMatch(in: propContent, range: Range(propContent.startIndex..., in: propContent)!) {
                        if let sizeRange = Range(sizeMatch.range(at: 1), in: propContent) {
                            size = Int64(propContent[sizeRange]) ?? 0
                        }
                    }
                }
            }
            
            let displayName = URL(string: href)?.lastPathComponent ?? href
            if displayName.isEmpty || displayName == "/" || displayName.hasPrefix(".") {
                continue
            }
            
            if href == basePath || href == basePath + "/" {
                continue
            }
            
            let fullPath = (basePath as NSString).appendingPathComponent(displayName)
            
            files.append(CloudFile(
                name: displayName,
                path: fullPath,
                isDirectory: isDirectory,
                size: size,
                modifiedDate: nil,
                type: isDirectory ? "folder" : (displayName as NSString).pathExtension.lowercased()
            ))
        }
        
        return files.sorted { f1, f2 in
            if f1.isDirectory != f2.isDirectory { return f1.isDirectory }
            return f1.name.localizedCaseInsensitiveCompare(f2.name) == .orderedAscending
        }
    }
    
    private func loadOPDSFiles(path: String) async throws -> [CloudFile] {
        let urlString = path.isEmpty ? settings.opdsURL : path
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "OPDS", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("LegadoReader/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        if !settings.opdsUsername.isEmpty, !settings.opdsPassword.isEmpty {
            let credentials = "\(settings.opdsUsername):\(settings.opdsPassword)"
            if let credentialsData = credentials.data(using: .utf8) {
                request.setValue("Basic \(credentialsData.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return OPDSParser.shared.parseToCloudFiles(data)
    }
    
    func downloadFile(_ file: CloudFile, completion: @escaping (Result<URL, Error>) -> Void) {
        switch currentService {
        case .baiduPan:
            downloadBaiduFile(file, completion: completion)
        case .aliDrive:
            downloadAliFile(file, completion: completion)
        case .webdav:
            downloadWebDAVFile(file, completion: completion)
        case .opds:
            downloadOPDSFile(file, completion: completion)
        case .none:
            completion(.failure(NSError(domain: "CloudStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "未选择服务"])))
        }
    }
    
    private func downloadBaiduFile(_ file: CloudFile, completion: @escaping (Result<URL, Error>) -> Void) {
        let downloadURL = URL(string: "https://pan.baidu.com/rest/2.0/xpan/file?method=download&access_token=\(settings.baiduAccessToken)&path=\(file.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsPath = documentsPath.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
        let localURL = downloadsPath.appendingPathComponent(file.name)
        
        URLSession.shared.downloadTask(with: downloadURL) { tempURL, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let tempURL = tempURL else {
                completion(.failure(NSError(domain: "CloudStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                return
            }
            
            do {
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                completion(.success(localURL))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func downloadAliFile(_ file: CloudFile, completion: @escaping (Result<URL, Error>) -> Void) {
        let url = URL(string: "https://open.aliyundrive.com/adrive/v1.0/openFile/getDownloadUrl")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.aliAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "drive_id": settings.aliDriveId,
            "file_id": file.path
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let downloadURL = json["url"] as? String else {
                completion(.failure(NSError(domain: "CloudStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取下载链接失败"])))
                return
            }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let downloadsPath = documentsPath.appendingPathComponent("Downloads", isDirectory: true)
            try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
            let localURL = downloadsPath.appendingPathComponent(file.name)
            
            URLSession.shared.downloadTask(with: URL(string: downloadURL)!) { tempURL, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let tempURL = tempURL else {
                    completion(.failure(NSError(domain: "CloudStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                    return
                }
                
                do {
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        try FileManager.default.removeItem(at: localURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: localURL)
                    completion(.success(localURL))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }.resume()
    }
    
    private func downloadWebDAVFile(_ file: CloudFile, completion: @escaping (Result<URL, Error>) -> Void) {
        let scheme = settings.webdavUseSSL ? "https" : "http"
        var serverURL = settings.webdavServerURL
        if !serverURL.hasPrefix("http") {
            let port = settings.webdavUseSSL && settings.webdavPort == 443 ? "" : ":\(settings.webdavPort)"
            serverURL = "\(scheme)://\(serverURL)\(port)"
        }
        
        guard let url = URL(string: serverURL + file.path) else {
            completion(.failure(NSError(domain: "WebDAV", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        if let credentials = "\(settings.webdavUsername):\(settings.webdavPassword)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsPath = documentsPath.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
        let localURL = downloadsPath.appendingPathComponent(file.name)
        
        URLSession.shared.downloadTask(with: request) { tempURL, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let tempURL = tempURL else {
                completion(.failure(NSError(domain: "WebDAV", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                return
            }
            
            do {
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                completion(.success(localURL))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func downloadOPDSFile(_ file: CloudFile, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: file.path) else {
            completion(.failure(NSError(domain: "OPDS", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("LegadoReader/1.0", forHTTPHeaderField: "User-Agent")
        
        if !settings.opdsUsername.isEmpty, !settings.opdsPassword.isEmpty {
            let credentials = "\(settings.opdsUsername):\(settings.opdsPassword)"
            if let credentialsData = credentials.data(using: .utf8) {
                request.setValue("Basic \(credentialsData.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsPath = documentsPath.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
        let localURL = downloadsPath.appendingPathComponent(file.name)
        
        URLSession.shared.downloadTask(with: request) { tempURL, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let tempURL = tempURL else {
                completion(.failure(NSError(domain: "OPDS", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                return
            }
            
            do {
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                completion(.success(localURL))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func enterDirectory(_ directory: CloudFile) {
        pathHistory.append(currentPath)
        Task {
            await loadFiles(path: directory.path)
        }
    }
    
    func goBack() {
        if let previousPath = pathHistory.popLast() {
            Task {
                await loadFiles(path: previousPath)
            }
        }
    }
    
    func refresh() {
        Task {
            await loadFiles(path: currentPath)
        }
    }
}

struct CloudStorageSettingsView: View {
    @StateObject private var cloudManager = CloudStorageManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var testConnection = false
    @State private var connectionStatus = ""
    @State private var showingFileBrowser = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(CloudService.allCases) { service in
                        Button(action: {
                            cloudManager.selectService(service)
                        }) {
                            HStack {
                                Image(systemName: service.icon)
                                    .foregroundColor(colorForService(service))
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(service.rawValue.isEmpty ? "未选择" : service.rawValue)
                                        .foregroundColor(.primary)
                                    Text(service.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if cloudManager.currentService == service {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择云服务")
                }
                
                if cloudManager.currentService == .baiduPan {
                    Section("百度云盘设置") {
                        TextField("Access Token", text: $cloudManager.settings.baiduAccessToken)
                            .autocapitalization(.none)
                        TextField("Refresh Token", text: $cloudManager.settings.baiduRefreshToken)
                            .autocapitalization(.none)
                    }
                }
                
                if cloudManager.currentService == .aliDrive {
                    Section("阿里云盘设置") {
                        TextField("Access Token", text: $cloudManager.settings.aliAccessToken)
                            .autocapitalization(.none)
                        TextField("Refresh Token", text: $cloudManager.settings.aliRefreshToken)
                            .autocapitalization(.none)
                        TextField("Drive ID", text: $cloudManager.settings.aliDriveId)
                            .autocapitalization(.none)
                    }
                }
                
                if cloudManager.currentService == .webdav {
                    Section("WebDAV 设置") {
                        TextField("服务器地址", text: $cloudManager.settings.webdavServerURL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        
                        HStack {
                            TextField("端口", value: $cloudManager.settings.webdavPort, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                            Toggle("SSL", isOn: $cloudManager.settings.webdavUseSSL)
                        }
                        
                        TextField("用户名", text: $cloudManager.settings.webdavUsername)
                            .autocapitalization(.none)
                        
                        SecureField("密码", text: $cloudManager.settings.webdavPassword)
                        
                        TextField("远程路径", text: $cloudManager.settings.webdavRemotePath)
                            .autocapitalization(.none)
                    }
                }
                
                if cloudManager.currentService == .opds {
                    Section("OPDS 设置") {
                        TextField("OPDS 地址", text: $cloudManager.settings.opdsURL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        
                        TextField("用户名（可选）", text: $cloudManager.settings.opdsUsername)
                            .autocapitalization(.none)
                        
                        SecureField("密码（可选）", text: $cloudManager.settings.opdsPassword)
                    }
                }
                
                Section("同步设置") {
                    Toggle("自动同步", isOn: $cloudManager.settings.autoSync)
                    
                    if cloudManager.settings.autoSync {
                        Stepper("间隔: \(cloudManager.settings.syncInterval) 分钟", value: $cloudManager.settings.syncInterval, in: 5...1440, step: 5)
                    }
                }
                
                Section("连接状态") {
                    HStack {
                        Circle()
                            .fill(cloudManager.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(cloudManager.isConnected ? "已连接" : "未连接")
                            .foregroundColor(cloudManager.isConnected ? .green : .red)
                        
                        Spacer()
                        
                        if let lastSync = cloudManager.lastSyncTime {
                            Text("上次: \(lastSync, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        testConnection = true
                        connectionStatus = ""
                        Task {
                            let success = await cloudManager.connect()
                            await MainActor.run {
                                connectionStatus = success ? "连接成功 ✓" : "连接失败 ✗"
                                if let error = cloudManager.syncError {
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
                
                if cloudManager.isConnected {
                    Section("操作") {
                        Button(action: {
                            showingFileBrowser = true
                        }) {
                            HStack {
                                Image(systemName: "folder.badge.questionmark")
                                Text("浏览云端文件")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("云盘同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        cloudManager.saveSettings()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFileBrowser) {
                CloudFileBrowserView()
            }
        }
    }
    
    private func colorForService(_ service: CloudStorageManager.CloudService) -> Color {
        switch service {
        case .none: return .gray
        case .baiduPan: return .blue
        case .aliDrive: return .orange
        case .webdav: return .purple
        case .opds: return .green
        }
    }
}

struct CloudFileBrowserView: View {
    @StateObject private var cloudManager = CloudStorageManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var isDownloading = false
    @State private var downloadProgress = ""
    
    var body: some View {
        NavigationView {
            List {
                if !cloudManager.currentPath.isEmpty && !cloudManager.pathHistory.isEmpty {
                    Button(action: {
                        cloudManager.goBack()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.blue)
                            Text("返回上级目录")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section {
                    if cloudManager.isSyncing {
                        HStack {
                            ProgressView()
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }
                    } else if cloudManager.files.isEmpty {
                        Text("暂无文件")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(cloudManager.files) { file in
                            if file.isDirectory {
                                Button(action: {
                                    cloudManager.enterDirectory(file)
                                }) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.yellow)
                                        Text(file.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                HStack {
                                    Image(systemName: file.icon)
                                        .foregroundColor(file.color)
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
                                    Button(action: {
                                        downloadFile(file)
                                    }) {
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if !downloadProgress.isEmpty {
                    Section {
                        HStack {
                            ProgressView()
                            Text(downloadProgress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("云端文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        cloudManager.refresh()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(cloudManager.isSyncing)
                }
            }
            .onAppear {
                Task {
                    await cloudManager.loadFiles()
                }
            }
        }
    }
    
    private func downloadFile(_ file: CloudFile) {
        isDownloading = true
        downloadProgress = "正在下载: \(file.name)"
        
        cloudManager.downloadFile(file) { result in
            DispatchQueue.main.async {
                isDownloading = false
                switch result {
                case .success(let url):
                    downloadProgress = "已下载: \(url.lastPathComponent)"
                case .failure(let error):
                    downloadProgress = "下载失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
