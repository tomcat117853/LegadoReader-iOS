import Foundation

class AudioConfigCloudSync: ObservableObject {
    static let shared = AudioConfigCloudSync()
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed
        case conflict
        
        var description: String {
            switch self {
            case .idle: return "等待同步"
            case .syncing: return "同步中..."
            case .success: return "同步成功"
            case .failed: return "同步失败"
            case .conflict: return "存在冲突"
            }
        }
    }
    
    private let cloudConfigKey = "AudioConfigCloudSync_config"
    private let lastSyncKey = "AudioConfigCloudSync_lastSync"
    
    struct CloudSyncData: Codable {
        let version: Int
        let lastModified: Date
        let audioConfigs: [String: BookAudioConfigManager.BookAudioConfig]
        let deviceId: String
        let deviceName: String
    }
    
    private init() {
        if let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            lastSyncTime = lastSync
        }
    }
    
    func syncToCloud() async throws {
        await MainActor.run {
            syncStatus = .syncing
            isSyncing = true
            syncError = nil
        }
        
        do {
            let configs = BookAudioConfigManager.shared.configs
            let syncData = CloudSyncData(
                version: 1,
                lastModified: Date(),
                audioConfigs: configs,
                deviceId: getDeviceId(),
                deviceName: getDeviceName()
            )
            
            let data = try JSONEncoder().encode(syncData)
            
            if let cloudData = try await uploadToCloud(data: data) {
                try await handleCloudResponse(cloudData)
            }
            
            await MainActor.run {
                syncStatus = .success
                isSyncing = false
                lastSyncTime = Date()
                UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            }
        } catch {
            await MainActor.run {
                syncStatus = .failed
                isSyncing = false
                syncError = error.localizedDescription
            }
            throw error
        }
    }
    
    func syncFromCloud() async throws {
        await MainActor.run {
            syncStatus = .syncing
            isSyncing = true
            syncError = nil
        }
        
        do {
            guard let cloudData = try await downloadFromCloud() else {
                await MainActor.run {
                    syncStatus = .success
                    isSyncing = false
                }
                return
            }
            
            try await mergeWithLocal(cloudData: cloudData)
            
            await MainActor.run {
                syncStatus = .success
                isSyncing = false
                lastSyncTime = Date()
                UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            }
        } catch {
            await MainActor.run {
                syncStatus = .failed
                isSyncing = false
                syncError = error.localizedDescription
            }
            throw error
        }
    }
    
    func syncBothDirections() async throws {
        await MainActor.run {
            syncStatus = .syncing
            isSyncing = true
            syncError = nil
        }
        
        do {
            let configs = BookAudioConfigManager.shared.configs
            let syncData = CloudSyncData(
                version: 1,
                lastModified: Date(),
                audioConfigs: configs,
                deviceId: getDeviceId(),
                deviceName: getDeviceName()
            )
            
            let localData = try JSONEncoder().encode(syncData)
            
            guard let cloudData = try await downloadFromCloud() else {
                _ = try await uploadToCloud(data: localData)
                
                await MainActor.run {
                    syncStatus = .success
                    isSyncing = false
                    lastSyncTime = Date()
                }
                return
            }
            
            let mergedData = try await mergeData(local: localData, cloud: cloudData)
            _ = try await uploadToCloud(data: mergedData)
            
            try await handleCloudResponse(mergedData)
            
            await MainActor.run {
                syncStatus = .success
                isSyncing = false
                lastSyncTime = Date()
                UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            }
        } catch {
            await MainActor.run {
                syncStatus = .failed
                isSyncing = false
                syncError = error.localizedDescription
            }
            throw error
        }
    }
    
    private func uploadToCloud(data: Data) async throws -> Data? {
        guard let url = URL(string: "https://api.example.com/audio-config/sync") else {
            throw CloudSyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: data)
            }.resume()
        }
    }
    
    private func downloadFromCloud() async throws -> Data? {
        guard let url = URL(string: "https://api.example.com/audio-config/sync") else {
            throw CloudSyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: data)
            }.resume()
        }
    }
    
    private func handleCloudResponse(_ data: Data) async throws {
        let cloudData = try JSONDecoder().decode(CloudSyncData.self, from: data)
        
        for (bookId, config) in cloudData.audioConfigs {
            var localConfig = BookAudioConfigManager.shared.getConfig(for: bookId)
            
            if config.updatedAt > localConfig.updatedAt {
                localConfig = config
                BookAudioConfigManager.shared.saveConfig(localConfig)
            }
        }
    }
    
    private func mergeData(local: Data, cloud: Data) async throws -> Data {
        let localSync = try JSONDecoder().decode(CloudSyncData.self, from: local)
        let cloudSync = try JSONDecoder().decode(CloudSyncData.self, from: cloud)
        
        var mergedConfigs = localSync.audioConfigs
        
        for (bookId, cloudConfig) in cloudSync.audioConfigs {
            if let localConfig = mergedConfigs[bookId] {
                if cloudConfig.updatedAt > localConfig.updatedAt {
                    mergedConfigs[bookId] = cloudConfig
                }
            } else {
                mergedConfigs[bookId] = cloudConfig
            }
        }
        
        let mergedSync = CloudSyncData(
            version: max(localSync.version, cloudSync.version) + 1,
            lastModified: Date(),
            audioConfigs: mergedConfigs,
            deviceId: getDeviceId(),
            deviceName: getDeviceName()
        )
        
        return try JSONEncoder().encode(mergedSync)
    }
    
    private func mergeWithLocal(cloudData: Data) async throws {
        let cloudSync = try JSONDecoder().decode(CloudSyncData.self, from: cloudData)
        
        let localConfigs = BookAudioConfigManager.shared.configs
        var hasConflict = false
        
        for (bookId, cloudConfig) in cloudSync.audioConfigs {
            if let localConfig = localConfigs[bookId] {
                let timeDiff = abs(cloudConfig.updatedAt.timeIntervalSince(localConfig.updatedAt))
                if timeDiff < 60 && cloudConfig != localConfig {
                    hasConflict = true
                    await MainActor.run {
                        syncStatus = .conflict
                    }
                }
                
                if cloudConfig.updatedAt > localConfig.updatedAt {
                    BookAudioConfigManager.shared.saveConfig(cloudConfig)
                }
            } else {
                BookAudioConfigManager.shared.saveConfig(cloudConfig)
            }
        }
        
        if !hasConflict {
            await MainActor.run {
                syncStatus = .success
            }
        }
    }
    
    private func getDeviceId() -> String {
        if let deviceId = UserDefaults.standard.string(forKey: "DeviceId") {
            return deviceId
        }
        
        let newDeviceId = UUID().uuidString
        UserDefaults.standard.set(newDeviceId, forKey: "DeviceId")
        return newDeviceId
    }
    
    private func getDeviceName() -> String {
        return UIDevice.current.name
    }
    
    private func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "CloudSyncAuthToken")
    }
    
    func setAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "CloudSyncAuthToken")
    }
    
    func exportToFile(url: URL) throws {
        let configs = BookAudioConfigManager.shared.configs
        let syncData = CloudSyncData(
            version: 1,
            lastModified: Date(),
            audioConfigs: configs,
            deviceId: getDeviceId(),
            deviceName: getDeviceName()
        )
        
        let data = try JSONEncoder().encode(syncData)
        
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        try data.write(to: url)
    }
    
    func importFromFile(url: URL) throws {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let data = try? Data(contentsOf: url) else {
            throw CloudSyncError.fileReadFailed
        }
        
        let syncData = try JSONDecoder().decode(CloudSyncData.self, from: data)
        
        for (bookId, config) in syncData.audioConfigs {
            BookAudioConfigManager.shared.saveConfig(config)
        }
    }
}

enum CloudSyncError: Error, LocalizedError {
    case invalidURL
    case networkError
    case authenticationFailed
    case fileReadFailed
    case fileWriteFailed
    case mergeConflict
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务器地址"
        case .networkError: return "网络错误"
        case .authenticationFailed: return "认证失败"
        case .fileReadFailed: return "读取文件失败"
        case .fileWriteFailed: return "写入文件失败"
        case .mergeConflict: return "数据合并冲突"
        case .serverError: return "服务器错误"
        }
    }
}

class ImportDefaultConfigManager: ObservableObject {
    static let shared = ImportDefaultConfigManager()
    
    @Published var defaultConfigs: [String: ImportDefaultConfig] = [:]
    
    private let configsKey = "ImportDefaultConfig_configs"
    
    struct ImportDefaultConfig: Codable, Identifiable {
        let id: String
        var format: String
        var source: Source
        
        enum Source: String, Codable, CaseIterable {
            case local = "local"
            case web = "web"
            case both = "both"
            
            var displayName: String {
                switch self {
                case .local: return "本地导入"
                case .web: return "Web导入"
                case .both: return "全部来源"
                }
            }
        }
        
        var voiceId: String
        var speechRate: Double
        var speechPitch: Double
        var speechStyle: String
        var chapterLevel: Int
        var autoPlayNext: Bool
        var paragraphInterval: Double
    }
    
    private init() {
        loadConfigs()
        
        if defaultConfigs.isEmpty {
            setupDefaultConfigs()
        }
    }
    
    private func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: configsKey),
           let saved = try? JSONDecoder().decode([String: ImportDefaultConfig].self, from: data) {
            defaultConfigs = saved
        }
    }
    
    private func saveConfigs() {
        if let data = try? JSONEncoder().encode(defaultConfigs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
    }
    
    private func setupDefaultConfigs() {
        let formats = ["txt", "epub", "pdf", "mobi", "fb2", "chm", "rtf", "html", "docx"]
        
        for format in formats {
            defaultConfigs[format] = ImportDefaultConfig(
                id: UUID().uuidString,
                format: format,
                source: .both,
                voiceId: "zh-CN-XiaoxiaoNeural",
                speechRate: 1.0,
                speechPitch: 1.0,
                speechStyle: "general",
                chapterLevel: 1,
                autoPlayNext: true,
                paragraphInterval: 0.5
            )
        }
        
        saveConfigs()
    }
    
    func getConfig(for format: String, source: ImportDefaultConfig.Source = .both) -> BookAudioConfigManager.BookAudioConfig {
        if let importConfig = defaultConfigs[format],
           (source == .both || importConfig.source == source || importConfig.source == .both) {
            return BookAudioConfigManager.BookAudioConfig(
                id: UUID().uuidString,
                bookId: nil,
                voiceId: importConfig.voiceId,
                voiceName: getVoiceName(importConfig.voiceId),
                speechRate: importConfig.speechRate,
                speechPitch: importConfig.speechPitch,
                speechVolume: 1.0,
                speechStyle: importConfig.speechStyle,
                chapterLevel: importConfig.chapterLevel,
                autoPlayNext: importConfig.autoPlayNext,
                paragraphInterval: importConfig.paragraphInterval,
                skipEmptyParagraphs: true,
                startPosition: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        return BookAudioConfigManager.BookAudioConfig.default
    }
    
    private func getVoiceName(_ voiceId: String) -> String {
        let voiceNames: [String: String] = [
            "zh-CN-XiaoxiaoNeural": "晓晓",
            "zh-CN-YunxiNeural": "云希",
            "zh-CN-XiaoyiNeural": "小艺",
            "zh-CN-YunyangNeural": "云扬",
            "zh-CN-XiaochenNeural": "晓辰",
            "zh-CN-YunfengNeural": "云枫"
        ]
        return voiceNames[voiceId] ?? "晓晓"
    }
    
    func setConfig(for format: String, config: ImportDefaultConfig) {
        defaultConfigs[format] = config
        saveConfigs()
    }
    
    func resetToDefaults() {
        defaultConfigs.removeAll()
        setupDefaultConfigs()
    }
    
    func applyToAllFormats(config: ImportDefaultConfig) {
        for format in defaultConfigs.keys {
            var newConfig = defaultConfigs[format]!
            newConfig.voiceId = config.voiceId
            newConfig.speechRate = config.speechRate
            newConfig.speechPitch = config.speechPitch
            newConfig.speechStyle = config.speechStyle
            newConfig.chapterLevel = config.chapterLevel
            newConfig.autoPlayNext = config.autoPlayNext
            newConfig.paragraphInterval = config.paragraphInterval
            defaultConfigs[format] = newConfig
        }
        saveConfigs()
    }
}
