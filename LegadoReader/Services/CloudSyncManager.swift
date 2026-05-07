import Foundation
import Combine

class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus: String {
        case idle = "空闲"
        case syncing = "同步中"
        case success = "同步成功"
        case failed = "同步失败"
        case conflict = "冲突"
    }
    
    struct SyncData: Codable {
        let version: String
        let timestamp: Date
        let books: [Book]
        let bookSources: [BookSource]
        let readingProgress: [ReadingProgressSync.ReadingProgress]
        let settings: [String: String]
        
        init(books: [Book], bookSources: [BookSource], readingProgress: [ReadingProgressSync.ReadingProgress], settings: [String: String]) {
            self.version = "1.0"
            self.timestamp = Date()
            self.books = books
            self.bookSources = bookSources
            self.readingProgress = readingProgress
            self.settings = settings
        }
    }
    
    struct SyncConflict: Identifiable {
        let id = UUID()
        let localData: SyncData
        let cloudData: SyncData
        let conflictType: ConflictType
        
        enum ConflictType: String {
            case bookConflict = "书籍冲突"
            case sourceConflict = "书源冲突"
            case progressConflict = "进度冲突"
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let syncKey = "CloudSync"
    private let lastSyncKey = "CloudSync_LastSync"
    private let syncEnabledKey = "CloudSync_Enabled"
    
    @Published var pendingConflicts: [SyncConflict] = []
    @Published var autoSyncEnabled = true
    
    private init() {
        loadSettings()
        setupiCloudObserver()
    }
    
    private var cloudContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    
    private var syncFileURL: URL? {
        cloudContainerURL?.appendingPathComponent("LegadoSync.json")
    }
    
    private var localSyncFileURL: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let localURL = urls[0].appendingPathComponent("LegadoSync_Local.json")
        
        if let parentDirectory = localURL.deletingLastPathComponent() as URL? {
            if !FileManager.default.fileExists(atPath: parentDirectory.path) {
                try? FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }
        }
        
        return localURL
    }
    
    private func loadSettings() {
        autoSyncEnabled = userDefaults.bool(forKey: syncEnabledKey)
        lastSyncTime = userDefaults.object(forKey: lastSyncKey) as? Date
    }
    
    private func setupiCloudObserver() {
        guard let syncFileURL = syncFileURL else { return }
        
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "LegadoSync.json")
        
        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            if FileManager.default.fileExists(atPath: syncFileURL.path) {
                if self?.autoSyncEnabled == true {
                    Task {
                        await self?.syncFromCloud()
                    }
                }
            }
        }
        
        query.start()
    }
    
    func isCloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    func syncToCloud() async {
        guard isCloudAvailable() else {
            await MainActor.run {
                syncStatus = .failed
                syncError = "iCloud 不可用"
            }
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
            syncError = nil
        }
        
        do {
            let syncData = createSyncData()
            try await saveSyncData(syncData, toCloud: true)
            
            await MainActor.run {
                lastSyncTime = Date()
                userDefaults.set(lastSyncTime, forKey: lastSyncKey)
                isSyncing = false
                syncStatus = .success
            }
        } catch {
            await MainActor.run {
                isSyncing = false
                syncStatus = .failed
                syncError = error.localizedDescription
            }
        }
    }
    
    func syncFromCloud() async {
        guard isCloudAvailable() else {
            await MainActor.run {
                syncStatus = .failed
                syncError = "iCloud 不可用"
            }
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
            syncError = nil
        }
        
        do {
            guard let cloudData = try await loadSyncData(fromCloud: true) else {
                await MainActor.run {
                    isSyncing = false
                    syncStatus = .success
                }
                return
            }
            
            if let localData = try? await loadSyncData(fromCloud: false) {
                let conflicts = detectConflicts(local: localData, cloud: cloudData)
                
                if !conflicts.isEmpty {
                    await MainActor.run {
                        pendingConflicts = conflicts
                        syncStatus = .conflict
                    }
                    await handleConflicts(conflicts)
                } else {
                    await mergeData(cloudData)
                }
            } else {
                await mergeData(cloudData)
            }
            
            await MainActor.run {
                lastSyncTime = Date()
                userDefaults.set(lastSyncTime, forKey: lastSyncKey)
                isSyncing = false
                syncStatus = .success
            }
        } catch {
            await MainActor.run {
                isSyncing = false
                syncStatus = .failed
                syncError = error.localizedDescription
            }
        }
    }
    
    func fullSync() async {
        await syncToCloud()
        await syncFromCloud()
    }
    
    private func createSyncData() -> SyncData {
        let books = DatabaseManager.shared.getAllBooks()
        let bookSources = DatabaseManager.shared.getAllBookSources()
        let progress = ReadingProgressSync.shared.getAllBooksProgress()
        
        var settings: [String: String] = [:]
        let readerDefaults = UserDefaults.standard
        settings["fontSize"] = String(readerDefaults.double(forKey: "ReaderSettings_fontSize"))
        settings["backgroundColor"] = readerDefaults.string(forKey: "ReaderSettings_backgroundColor") ?? "FFFFFF"
        
        return SyncData(
            books: books,
            bookSources: bookSources,
            readingProgress: progress,
            settings: settings
        )
    }
    
    private func saveSyncData(_ data: SyncData, toCloud: Bool) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(data)
        
        if toCloud {
            guard let cloudURL = syncFileURL else {
                throw CloudSyncError.cloudUnavailable
            }
            
            try jsonData.write(to: cloudURL)
            try FileManager.default.setUbiquitous(true, itemAt: cloudURL, destinationURL: cloudURL)
        }
        
        try jsonData.write(to: localSyncFileURL)
    }
    
    private func loadSyncData(fromCloud: Bool) async throws -> SyncData? {
        if fromCloud {
            guard let cloudURL = syncFileURL,
                  FileManager.default.fileExists(atPath: cloudURL.path) else {
                return nil
            }
            
            let data = try Data(contentsOf: cloudURL)
            return try JSONDecoder().decode(SyncData.self, from: data)
        } else {
            guard FileManager.default.fileExists(atPath: localSyncFileURL.path) else {
                return nil
            }
            
            let data = try Data(contentsOf: localSyncFileURL)
            return try JSONDecoder().decode(SyncData.self, from: data)
        }
    }
    
    private func detectConflicts(local: SyncData, cloud: SyncData) -> [SyncConflict] {
        var conflicts: [SyncConflict] = []
        
        let localBookIds = Set(local.books.map { $0.id })
        let cloudBookIds = Set(cloud.books.map { $0.id })
        
        let commonBookIds = localBookIds.intersection(cloudBookIds)
        
        for bookId in commonBookIds {
            if let localBook = local.books.first(where: { $0.id == bookId }),
               let cloudBook = cloud.books.first(where: { $0.id == bookId }) {
                
                if local.updatedTime != cloud.updatedTime || local.lastReadTime != cloud.lastReadTime {
                    if local.timestamp > cloud.timestamp {
                        conflicts.append(SyncConflict(
                            localData: local,
                            cloudData: cloud,
                            conflictType: .progressConflict
                        ))
                    }
                }
            }
        }
        
        return conflicts
    }
    
    private func handleConflicts(_ conflicts: [SyncConflict]) async {
        for conflict in conflicts {
            switch conflict.conflictType {
            case .progressConflict:
                if conflict.localData.timestamp > conflict.cloudData.timestamp {
                    await syncToCloud()
                } else {
                    await mergeData(conflict.cloudData)
                }
            default:
                await mergeData(conflict.cloudData)
            }
        }
    }
    
    private func mergeData(_ data: SyncData) async {
        for book in data.books {
            DatabaseManager.shared.saveBook(book)
        }
        
        for source in data.bookSources {
            DatabaseManager.shared.saveBookSource(source)
        }
        
        for progress in data.readingProgress {
            ReadingProgressSync.shared.saveProgress(progress)
        }
        
        for (key, value) in data.settings {
            if key == "fontSize", let fontSize = Double(value) {
                UserDefaults.standard.set(fontSize, forKey: "ReaderSettings_fontSize")
            } else if key == "backgroundColor" {
                UserDefaults.standard.set(value, forKey: "ReaderSettings_backgroundColor")
            }
        }
    }
    
    func resolveConflict(_ conflict: SyncConflict, useCloud: Bool) async {
        if useCloud {
            await mergeData(conflict.cloudData)
        }
        
        pendingConflicts.removeAll { $0.id == conflict.id }
        
        if pendingConflicts.isEmpty {
            await syncToCloud()
        }
    }
    
    func clearCloudData() async throws {
        guard let cloudURL = syncFileURL else { return }
        
        if FileManager.default.fileExists(atPath: cloudURL.path) {
            try FileManager.default.removeItem(at: cloudURL)
        }
        
        if FileManager.default.fileExists(atPath: localSyncFileURL.path) {
            try FileManager.default.removeItem(at: localSyncFileURL)
        }
        
        await MainActor.run {
            lastSyncTime = nil
            syncStatus = .idle
        }
    }
    
    func getSyncInfo() -> SyncInfo {
        return SyncInfo(
            isCloudAvailable: isCloudAvailable(),
            lastSyncTime: lastSyncTime,
            autoSyncEnabled: autoSyncEnabled,
            pendingConflicts: pendingConflicts.count,
            syncStatus: syncStatus
        )
    }
}

struct SyncInfo {
    let isCloudAvailable: Bool
    let lastSyncTime: Date?
    let autoSyncEnabled: Bool
    let pendingConflicts: Int
    let syncStatus: CloudSyncManager.SyncStatus
}

enum CloudSyncError: Error {
    case cloudUnavailable
    case networkError
    case dataCorrupted
    case saveFailed(String)
}
