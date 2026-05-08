import Foundation

class ReadingProgressSync: ObservableObject {
    static let shared = ReadingProgressSync()
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    private let userDefaults = UserDefaults.standard
    private let progressKey = "ReadingProgress"
    private let lastSyncKey = "ReadingProgressLastSync"
    
    struct ReadingProgress: Codable, Identifiable {
        var id: String { "\(bookId)_\(chapterId)" }
        let bookId: String
        let chapterId: String
        let bookName: String
        let chapterTitle: String
        let chapterIndex: Int
        var scrollPosition: Double
        var readPercentage: Double
        var lastReadTime: Date
        var totalChapters: Int
        var readChapters: Set<Int>
        
        init(bookId: String, chapterId: String, bookName: String, chapterTitle: String, chapterIndex: Int, scrollPosition: Double = 0, readPercentage: Double = 0, totalChapters: Int = 0) {
            self.bookId = bookId
            self.chapterId = chapterId
            self.bookName = bookName
            self.chapterTitle = chapterTitle
            self.chapterIndex = chapterIndex
            self.scrollPosition = scrollPosition
            self.readPercentage = readPercentage
            self.lastReadTime = Date()
            self.totalChapters = totalChapters
            self.readChapters = [chapterIndex]
        }
    }
    
    private init() {
        loadProgress()
        lastSyncTime = userDefaults.object(forKey: lastSyncKey) as? Date
    }
    
    private var progressDirectory: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let progressURL = urls[0].appendingPathComponent("ReadingProgress")
        
        if !FileManager.default.fileExists(atPath: progressURL.path) {
            try? FileManager.default.createDirectory(at: progressURL, withIntermediateDirectories: true)
        }
        
        return progressURL
    }
    
    private var progressFileURL: URL {
        return progressDirectory.appendingPathComponent("progress.json")
    }
    
    func loadProgress() {
        guard FileManager.default.fileExists(atPath: progressFileURL.path),
              let data = try? Data(contentsOf: progressFileURL),
              let progress = try? JSONDecoder().decode([ReadingProgress].self, from: data) else {
            return
        }
    }
    
    func saveProgress(_ progress: ReadingProgress) {
        var allProgress = loadAllProgress()
        
        if let index = allProgress.firstIndex(where: { $0.bookId == progress.bookId }) {
            var existingProgress = allProgress[index]
            existingProgress.scrollPosition = progress.scrollPosition
            existingProgress.readPercentage = progress.readPercentage
            existingProgress.chapterId = progress.chapterId
            existingProgress.chapterTitle = progress.chapterTitle
            existingProgress.chapterIndex = progress.chapterIndex
            existingProgress.lastReadTime = Date()
            existingProgress.readChapters.insert(progress.chapterIndex)
            allProgress[index] = existingProgress
        } else {
            allProgress.append(progress)
        }
        
        saveAllProgress(allProgress)
        syncToiCloud(progress: allProgress)
    }
    
    func getProgress(for bookId: String) -> ReadingProgress? {
        let allProgress = loadAllProgress()
        return allProgress.first { $0.bookId == bookId }
    }
    
    func getProgressForChapter(bookId: String, chapterId: String) -> ReadingProgress? {
        let allProgress = loadAllProgress()
        return allProgress.first { $0.bookId == bookId && $0.chapterId == chapterId }
    }
    
    func getAllBooksProgress() -> [ReadingProgress] {
        let allProgress = loadAllProgress()
        return allProgress.sorted { $0.lastReadTime > $1.lastReadTime }
    }
    
    func getRecentlyReadBooks(limit: Int = 10) -> [ReadingProgress] {
        let allProgress = loadAllProgress()
        return Array(allProgress.sorted { $0.lastReadTime > $1.lastReadTime }.prefix(limit))
    }
    
    func removeProgress(for bookId: String) {
        var allProgress = loadAllProgress()
        allProgress.removeAll { $0.bookId == bookId }
        saveAllProgress(allProgress)
        syncToiCloud(progress: allProgress)
    }
    
    private func loadAllProgress() -> [ReadingProgress] {
        guard FileManager.default.fileExists(atPath: progressFileURL.path),
              let data = try? Data(contentsOf: progressFileURL),
              let progress = try? JSONDecoder().decode([ReadingProgress].self, from: data) else {
            return []
        }
        return progress
    }
    
    private func saveAllProgress(_ progress: [ReadingProgress]) {
        do {
            let data = try JSONEncoder().encode(progress)
            try data.write(to: progressFileURL)
        } catch {
            print("Failed to save progress: \(error)")
        }
    }
    
    private func syncToiCloud(progress: [ReadingProgress]) {
        guard let ubiquitousContainerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return
        }
        
        let cloudURL = ubiquitousContainerURL.appendingPathComponent("Documents").appendingPathComponent("ReadingProgress.json")
        
        do {
            let data = try JSONEncoder().encode(progress)
            try data.write(to: cloudURL)
            lastSyncTime = Date()
            userDefaults.set(lastSyncTime, forKey: lastSyncKey)
        } catch {
            print("Failed to sync to iCloud: \(error)")
            syncError = error.localizedDescription
        }
    }
    
    func syncFromiCloud() {
        guard let ubiquitousContainerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return
        }
        
        let cloudURL = ubiquitousContainerURL.appendingPathComponent("Documents").appendingPathComponent("ReadingProgress.json")
        
        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            return
        }
        
        isSyncing = true
        
        do {
            let cloudData = try Data(contentsOf: cloudURL)
            let cloudProgress = try JSONDecoder().decode([ReadingProgress].self, from: cloudData)
            
            var localProgress = loadAllProgress()
            
            for cloudItem in cloudProgress {
                if let index = localProgress.firstIndex(where: { $0.bookId == cloudItem.bookId }) {
                    if cloudItem.lastReadTime > localProgress[index].lastReadTime {
                        localProgress[index] = cloudItem
                    }
                } else {
                    localProgress.append(cloudItem)
                }
            }
            
            saveAllProgress(localProgress)
            
            lastSyncTime = Date()
            userDefaults.set(lastSyncTime, forKey: lastSyncKey)
            isSyncing = false
        } catch {
            print("Failed to sync from iCloud: \(error)")
            syncError = error.localizedDescription
            isSyncing = false
        }
    }
    
    func getReadingStats() -> ReadingStats {
        let allProgress = loadAllProgress()
        
        var stats = ReadingStats()
        
        stats.totalBooks = allProgress.count
        stats.totalReadChapters = allProgress.reduce(0) { $0 + $1.readChapters.count }
        stats.lastReadTime = allProgress.map { $0.lastReadTime }.max()
        
        let calendar = Calendar.current
        let now = Date()
        
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
            stats.weeklyReadBooks = allProgress.filter { $0.lastReadTime >= weekAgo }.count
        }
        
        if let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) {
            stats.monthlyReadBooks = allProgress.filter { $0.lastReadTime >= monthAgo }.count
        }
        
        return stats
    }
    
    func exportProgress() -> Data? {
        let allProgress = loadAllProgress()
        
        struct ExportData: Codable {
            let version: Int = 1
            let exportDate: Date
            let progress: [ReadingProgress]
        }
        
        let exportData = ExportData(exportDate: Date(), progress: allProgress)
        
        return try? JSONEncoder().encode(exportData)
    }
    
    func importProgress(from data: Data, overwrite: Bool = false) throws -> Int {
        struct ImportData: Codable {
            let version: Int
            let exportDate: Date
            let progress: [ReadingProgress]
        }
        
        guard let importData = try? JSONDecoder().decode(ImportData.self, from: data) else {
            throw ProgressSyncError.invalidFormat
        }
        
        var allProgress = overwrite ? [] : loadAllProgress()
        
        for importedProgress in importData.progress {
            if let index = allProgress.firstIndex(where: { $0.bookId == importedProgress.bookId }) {
                if overwrite {
                    allProgress[index] = importedProgress
                } else if importedProgress.lastReadTime > allProgress[index].lastReadTime {
                    allProgress[index] = importedProgress
                }
            } else {
                allProgress.append(importedProgress)
            }
        }
        
        saveAllProgress(allProgress)
        syncToiCloud(progress: allProgress)
        
        return importData.progress.count
    }
    
    func exportProgressToFile(url: URL) throws {
        guard let data = exportProgress() else {
            throw ProgressSyncError.exportFailed
        }
        
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        try data.write(to: url)
    }
    
    func importProgressFromFile(url: URL, overwrite: Bool = false) throws -> Int {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let data = try? Data(contentsOf: url) else {
            throw ProgressSyncError.importFailed
        }
        
        return try importProgress(from: data, overwrite: overwrite)
    }
    
    func mergeProgress(from data: Data) throws -> Int {
        return try importProgress(from: data, overwrite: false)
    }
}

enum ProgressSyncError: Error, LocalizedError {
    case invalidFormat
    case exportFailed
    case importFailed
    case mergeConflict
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "无效的进度文件格式"
        case .exportFailed: return "导出进度失败"
        case .importFailed: return "导入进度失败"
        case .mergeConflict: return "合并进度时发生冲突"
        }
    }
}

struct ReadingStats {
    var totalBooks: Int = 0
    var totalReadChapters: Int = 0
    var weeklyReadBooks: Int = 0
    var monthlyReadBooks: Int = 0
    var lastReadTime: Date?
}
