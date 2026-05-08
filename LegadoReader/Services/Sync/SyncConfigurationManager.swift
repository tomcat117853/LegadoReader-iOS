import Foundation
import Combine

class SyncConfigurationManager: BaseService, ObservableObject {
    static let shared = SyncConfigurationManager()
    
    @Published var syncConfiguration: SyncConfiguration
    @Published var groupSyncSettings: [String: GroupSyncConfig] = [:]
    @Published var bookSyncSettings: [String: BookSyncConfig] = [:]
    @Published var fileSyncSettings: FileSyncConfig
    
    private let configKey = "SyncConfigurationManager_config"
    private let groupSettingsKey = "SyncConfigurationManager_groupSettings"
    private let bookSettingsKey = "SyncConfigurationManager_bookSettings"
    private let fileSettingsKey = "SyncConfigurationManager_fileSettings"
    
    struct SyncConfiguration: Codable {
        var enableAutoSync: Bool
        var syncOnWiFiOnly: Bool
        var syncOnCellular: Bool
        var syncInterval: SyncInterval
        var conflictResolution: ConflictResolution
        var syncDirection: DefaultSyncDirection
        var syncDeletedItems: Bool
        var syncMetadata: Bool
        var maxSyncSize: Int64
        
        enum SyncInterval: String, Codable, CaseIterable {
            case manual = "manual"
            case everyFiveMinutes = "everyFiveMinutes"
            case everyFifteenMinutes = "everyFifteenMinutes"
            case hourly = "hourly"
            case daily = "daily"
            case weekly = "weekly"
            
            var displayName: String {
                switch self {
                case .manual: return "手动"
                case .everyFiveMinutes: return "每5分钟"
                case .everyFifteenMinutes: return "每15分钟"
                case .hourly: return "每小时"
                case .daily: return "每天"
                case .weekly: return "每周"
                }
            }
            
            var intervalSeconds: TimeInterval {
                switch self {
                case .manual: return 0
                case .everyFiveMinutes: return 300
                case .everyFifteenMinutes: return 900
                case .hourly: return 3600
                case .daily: return 86400
                case .weekly: return 604800
                }
            }
        }
        
        enum ConflictResolution: String, Codable, CaseIterable {
            case keepLocal = "keepLocal"
            case keepCloud = "keepCloud"
            case keepNewer = "keepNewer"
            case ask = "ask"
            
            var displayName: String {
                switch self {
                case .keepLocal: return "保留本地"
                case .keepCloud: return "保留云端"
                case .keepNewer: return "保留较新"
                case .ask: return "每次询问"
                }
            }
        }
        
        enum DefaultSyncDirection: String, Codable, CaseIterable {
            case bidirectional = "bidirectional"
            case uploadOnly = "uploadOnly"
            case downloadOnly = "downloadOnly"
            
            var displayName: String {
                switch self {
                case .bidirectional: return "双向同步"
                case .uploadOnly: return "仅上传"
                case .downloadOnly: return "仅下载"
                }
            }
        }
        
        static var `default`: SyncConfiguration {
            SyncConfiguration(
                enableAutoSync: true,
                syncOnWiFiOnly: true,
                syncOnCellular: false,
                syncInterval: .daily,
                conflictResolution: .keepNewer,
                syncDirection: .bidirectional,
                syncDeletedItems: false,
                syncMetadata: true,
                maxSyncSize: 100 * 1024 * 1024
            )
        }
    }
    
    struct GroupSyncConfig: Identifiable, Codable {
        let id: String
        var groupId: String
        var groupName: String
        var syncEnabled: Bool
        var syncDirection: SyncConfiguration.DefaultSyncDirection
        var syncBooks: Bool
        var syncProgress: Bool
        var syncNotes: Bool
        var syncBookmarks: Bool
        
        init(groupId: String, groupName: String) {
            self.id = UUID().uuidString
            self.groupId = groupId
            self.groupName = groupName
            self.syncEnabled = true
            self.syncDirection = .bidirectional
            self.syncBooks = true
            self.syncProgress = true
            self.syncNotes = true
            self.syncBookmarks = true
        }
    }
    
    struct BookSyncConfig: Identifiable, Codable {
        let id: String
        var bookId: String
        var bookTitle: String
        var syncEnabled: Bool
        var syncDirection: SyncConfiguration.DefaultSyncDirection
        var syncProgress: Bool
        var syncNotes: Bool
        var syncBookmarks: Bool
        var syncOriginalFile: Bool
        var syncCover: Bool
        
        init(bookId: String, bookTitle: String) {
            self.id = UUID().uuidString
            self.bookId = bookId
            self.bookTitle = bookTitle
            self.syncEnabled = true
            self.syncDirection = .bidirectional
            self.syncProgress = true
            self.syncNotes = true
            self.syncBookmarks = true
            self.syncOriginalFile = false
            self.syncCover = true
        }
    }
    
    struct FileSyncConfig: Codable {
        var syncOriginalFiles: Bool
        var syncCovers: Bool
        var syncAnnotations: Bool
        var syncNotes: Bool
        var syncBookmarks: Bool
        var syncReadingProgress: Bool
        var syncBookSources: Bool
        var syncOPDSFeeds: Bool
        var syncReadHistory: Bool
        var syncCustomSources: Bool
        var maxCoverSize: Int64
        var maxBookFileSize: Int64
        var fileFormat: FileSyncFormat
        
        enum FileSyncFormat: String, Codable, CaseIterable {
            case json = "json"
            case both = "both"
            
            var displayName: String {
                switch self {
                case .json: return "JSON格式"
                case .both: return "JSON + 原文件"
                }
            }
        }
        
        static var `default`: FileSyncConfig {
            FileSyncConfig(
                syncOriginalFiles: false,
                syncCovers: true,
                syncAnnotations: true,
                syncNotes: true,
                syncBookmarks: true,
                syncReadingProgress: true,
                syncBookSources: true,
                syncOPDSFeeds: true,
                syncReadHistory: true,
                syncCustomSources: true,
                maxCoverSize: 5 * 1024 * 1024,
                maxBookFileSize: 50 * 1024 * 1024,
                fileFormat: .json
            )
        }
    }
    
    private override init() {
        self.syncConfiguration = SyncConfiguration.default
        self.fileSyncSettings = FileSyncConfig.default
        super.init()
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        if let saved = loadCodable(SyncConfiguration.self, key: configKey) {
            syncConfiguration = saved
        }
        
        if let saved = loadCodable([String: GroupSyncConfig].self, key: groupSettingsKey) {
            groupSyncSettings = saved
        }
        
        if let saved = loadCodable([String: BookSyncConfig].self, key: bookSettingsKey) {
            bookSyncSettings = saved
        }
        
        if let saved = loadCodable(FileSyncConfig.self, key: fileSettingsKey) {
            fileSyncSettings = saved
        }
    }
    
    func saveConfiguration() {
        saveCodable(syncConfiguration, key: configKey)
        saveCodable(groupSyncSettings, key: groupSettingsKey)
        saveCodable(bookSyncSettings, key: bookSettingsKey)
        saveCodable(fileSyncSettings, key: fileSettingsKey)
    }
    
    func updateConfiguration(_ config: SyncConfiguration) {
        syncConfiguration = config
        saveConfiguration()
    }
    
    func resetToDefaults() {
        syncConfiguration = .default
        fileSyncSettings = .default
        saveConfiguration()
    }
    
    func addGroupSyncConfig(_ groupId: String, groupName: String) {
        if groupSyncSettings[groupId] == nil {
            groupSyncSettings[groupId] = GroupSyncConfig(groupId: groupId, groupName: groupName)
            saveConfiguration()
        }
    }
    
    func updateGroupSyncConfig(_ config: GroupSyncConfig) {
        groupSyncSettings[config.groupId] = config
        saveConfiguration()
    }
    
    func removeGroupSyncConfig(_ groupId: String) {
        groupSyncSettings.removeValue(forKey: groupId)
        saveConfiguration()
    }
    
    func getGroupSyncConfig(_ groupId: String) -> GroupSyncConfig? {
        return groupSyncSettings[groupId]
    }
    
    func addBookSyncConfig(_ bookId: String, bookTitle: String) {
        if bookSyncSettings[bookId] == nil {
            bookSyncSettings[bookId] = BookSyncConfig(bookId: bookId, bookTitle: bookTitle)
            saveConfiguration()
        }
    }
    
    func updateBookSyncConfig(_ config: BookSyncConfig) {
        bookSyncSettings[config.bookId] = config
        saveConfiguration()
    }
    
    func removeBookSyncConfig(_ bookId: String) {
        bookSyncSettings.removeValue(forKey: bookId)
        saveConfiguration()
    }
    
    func getBookSyncConfig(_ bookId: String) -> BookSyncConfig? {
        return bookSyncSettings[bookId]
    }
    
    func updateFileSyncSettings(_ settings: FileSyncConfig) {
        fileSyncSettings = settings
        saveConfiguration()
    }
    
    func shouldSyncBook(_ bookId: String, groupId: String? = nil) -> Bool {
        if let bookConfig = bookSyncSettings[bookId] {
            return bookConfig.syncEnabled
        }
        
        if let groupId = groupId, let groupConfig = groupSyncSettings[groupId] {
            return groupConfig.syncEnabled
        }
        
        return syncConfiguration.enableAutoSync
    }
    
    func getSyncDirection(for bookId: String, groupId: String? = nil) -> SyncConfiguration.DefaultSyncDirection {
        if let bookConfig = bookSyncSettings[bookId] {
            return bookConfig.syncDirection
        }
        
        if let groupId = groupId, let groupConfig = groupSyncSettings[groupId] {
            return groupConfig.syncDirection
        }
        
        return syncConfiguration.syncDirection
    }
    
    func getSyncStatistics() -> SyncStatistics {
        var stats = SyncStatistics()
        
        stats.totalGroups = groupSyncSettings.count
        stats.totalBooks = bookSyncSettings.count
        stats.enabledGroups = groupSyncSettings.values.filter { $0.syncEnabled }.count
        stats.enabledBooks = bookSyncSettings.values.filter { $0.syncEnabled }.count
        
        stats.syncDirections = [
            "双向同步": bookSyncSettings.values.filter { $0.syncDirection == .bidirectional }.count,
            "仅上传": bookSyncSettings.values.filter { $0.syncDirection == .uploadOnly }.count,
            "仅下载": bookSyncSettings.values.filter { $0.syncDirection == .downloadOnly }.count
        ]
        
        stats.fileSettings = [
            "原文件": fileSyncSettings.syncOriginalFiles,
            "封面": fileSyncSettings.syncCovers,
            "标注": fileSyncSettings.syncAnnotations,
            "笔记": fileSyncSettings.syncNotes,
            "书签": fileSyncSettings.syncBookmarks,
            "进度": fileSyncSettings.syncReadingProgress,
            "书源": fileSyncSettings.syncBookSources
        ]
        
        return stats
    }
    
    struct SyncStatistics {
        var totalGroups: Int = 0
        var totalBooks: Int = 0
        var enabledGroups: Int = 0
        var enabledBooks: Int = 0
        var syncDirections: [String: Int] = [:]
        var fileSettings: [String: Bool] = [:]
    }
    
    func exportConfiguration() -> Data? {
        let exportData = ExportData(
            configuration: syncConfiguration,
            groupSettings: Array(groupSyncSettings.values),
            bookSettings: Array(bookSyncSettings.values),
            fileSettings: fileSyncSettings
        )
        return encodeJSON(exportData)
    }
    
    func importConfiguration(from data: Data) -> Bool {
        guard let imported = decodeJSON(ExportData.self, from: data) else {
            return false
        }
        
        syncConfiguration = imported.configuration
        fileSyncSettings = imported.fileSettings
        
        for group in imported.groupSettings {
            groupSyncSettings[group.groupId] = group
        }
        
        for book in imported.bookSettings {
            bookSyncSettings[book.bookId] = book
        }
        
        saveConfiguration()
        return true
    }
    
    struct ExportData: Codable {
        let configuration: SyncConfiguration
        let groupSettings: [GroupSyncConfig]
        let bookSettings: [BookSyncConfig]
        let fileSettings: FileSyncConfig
    }
}
