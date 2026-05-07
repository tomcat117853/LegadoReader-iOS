import Foundation

class BackupManager {
    static let shared = BackupManager()
    
    private let fileManager = FileManager.default
    
    struct BackupData: Codable {
        let version: String = "1.0"
        let backupDate: Date
        let books: [Book]
        let bookSources: [BookSource]
        let rssSources: [RSSSource]
        let rssArticles: [RSSArticle]
        let readerSettings: ReaderSettingsData
        let cleanRules: CleanRulesData
        
        struct ReaderSettingsData: Codable {
            let fontSize: CGFloat
            let lineSpacing: CGFloat
            let paragraphSpacing: CGFloat
            let fontFamily: String
            let backgroundColor: String
            let isNightMode: Bool
            let autoReadSpeed: Double
        }
        
        struct CleanRulesData: Codable {
            let globalRules: [ReplaceRule]
            let bookRules: [String: [ReplaceRule]]
        }
    }
    
    private init() {}
    
    private var backupDirectory: URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let backupURL = urls[0].appendingPathComponent("Backups")
        
        if !fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        }
        
        return backupURL
    }
    
    func createBackup() -> String? {
        do {
            let books = DatabaseManager.shared.getAllBooks()
            let bookSources = DatabaseManager.shared.getAllBookSources()
            
            let userDefaults = UserDefaults.standard
            
            // 获取 RSS 数据
            var rssSources: [RSSSource] = []
            if let data = userDefaults.data(forKey: "RSSViewModel_Sources") {
                rssSources = (try? JSONDecoder().decode([RSSSource].self, from: data)) ?? []
            }
            
            var rssArticles: [RSSArticle] = []
            if let data = userDefaults.data(forKey: "RSSViewModel_Articles") {
                rssArticles = (try? JSONDecoder().decode([RSSArticle].self, from: data)) ?? []
            }
            
            // 获取阅读设置
            let settingsData = BackupData.ReaderSettingsData(
                fontSize: userDefaults.double(forKey: "ReaderSettings_fontSize"),
                lineSpacing: userDefaults.double(forKey: "ReaderSettings_lineSpacing"),
                paragraphSpacing: userDefaults.double(forKey: "ReaderSettings_paragraphSpacing"),
                fontFamily: userDefaults.string(forKey: "ReaderSettings_fontFamily") ?? "PingFang SC",
                backgroundColor: userDefaults.string(forKey: "ReaderSettings_backgroundColor") ?? "FFFFFF",
                isNightMode: userDefaults.bool(forKey: "ReaderSettings_isNightMode"),
                autoReadSpeed: userDefaults.double(forKey: "ReaderSettings_autoReadSpeed")
            )
            
            // 获取净化规则
            var globalRules: [ReplaceRule] = []
            if let data = userDefaults.data(forKey: "CleanRuleManager_GlobalRules") {
                globalRules = (try? JSONDecoder().decode([ReplaceRule].self, from: data)) ?? []
            }
            
            var bookRules: [String: [ReplaceRule]] = [:]
            if let data = userDefaults.data(forKey: "CleanRuleManager_BookRules") {
                bookRules = (try? JSONDecoder().decode([String: [ReplaceRule]].self, from: data)) ?? [:]
            }
            
            let cleanRulesData = BackupData.CleanRulesData(
                globalRules: globalRules,
                bookRules: bookRules
            )
            
            let backup = BackupData(
                backupDate: Date(),
                books: books,
                bookSources: bookSources,
                rssSources: rssSources,
                rssArticles: rssArticles,
                readerSettings: settingsData,
                cleanRules: cleanRulesData
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(backup)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "backup_\(formatter.string(from: Date())).json"
            let fileURL = backupDirectory.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            
            return fileURL.path
        } catch {
            print("Backup failed: \(error)")
            return nil
        }
    }
    
    func restoreBackup(from path: String) throws {
        let fileURL = URL(fileURLWithPath: path)
        
        guard fileManager.fileExists(atPath: path) else {
            throw BackupError.fileNotFound
        }
        
        let data = try Data(contentsOf: fileURL)
        let backup = try JSONDecoder().decode(BackupData.self, from: data)
        
        // 恢复书籍
        for book in backup.books {
            DatabaseManager.shared.saveBook(book)
        }
        
        // 恢复书源
        for source in backup.bookSources {
            DatabaseManager.shared.saveBookSource(source)
        }
        
        let userDefaults = UserDefaults.standard
        
        // 恢复 RSS 数据
        if let data = try? JSONEncoder().encode(backup.rssSources) {
            userDefaults.set(data, forKey: "RSSViewModel_Sources")
        }
        
        if let data = try? JSONEncoder().encode(backup.rssArticles) {
            userDefaults.set(data, forKey: "RSSViewModel_Articles")
        }
        
        // 恢复阅读设置
        userDefaults.set(backup.readerSettings.fontSize, forKey: "ReaderSettings_fontSize")
        userDefaults.set(backup.readerSettings.lineSpacing, forKey: "ReaderSettings_lineSpacing")
        userDefaults.set(backup.readerSettings.paragraphSpacing, forKey: "ReaderSettings_paragraphSpacing")
        userDefaults.set(backup.readerSettings.fontFamily, forKey: "ReaderSettings_fontFamily")
        userDefaults.set(backup.readerSettings.backgroundColor, forKey: "ReaderSettings_backgroundColor")
        userDefaults.set(backup.readerSettings.isNightMode, forKey: "ReaderSettings_isNightMode")
        userDefaults.set(backup.readerSettings.autoReadSpeed, forKey: "ReaderSettings_autoReadSpeed")
        
        // 恢复净化规则
        if let data = try? JSONEncoder().encode(backup.cleanRules.globalRules) {
            userDefaults.set(data, forKey: "CleanRuleManager_GlobalRules")
        }
        
        if let data = try? JSONEncoder().encode(backup.cleanRules.bookRules) {
            userDefaults.set(data, forKey: "CleanRuleManager_BookRules")
        }
        
        userDefaults.synchronize()
    }
    
    func getBackupFiles() -> [URL] {
        do {
            let contents = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
            return contents.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            return []
        }
    }
    
    func deleteBackup(at path: String) throws {
        let fileURL = URL(fileURLWithPath: path)
        
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    func getBackupSize() -> String {
        let folderPath = backupDirectory.path
        var totalSize: Int64 = 0
        
        let enumerator = fileManager.enumerator(atPath: folderPath)
        while let fileName = enumerator?.nextObject() as? String {
            let fileSize = try? fileManager.attributesOfItem(atPath: "\(folderPath)/\(fileName)")[.size] as? Int64
            totalSize += fileSize ?? 0
        }
        
        if totalSize < 1024 {
            return "\(totalSize) B"
        } else if totalSize < 1024 * 1024 {
            return String(format: "%.2f KB", Double(totalSize) / 1024)
        } else {
            return String(format: "%.2f MB", Double(totalSize) / (1024 * 1024))
        }
    }
}

enum BackupError: Error {
    case fileNotFound
    case invalidFormat
    case restoreFailed(String)
}
