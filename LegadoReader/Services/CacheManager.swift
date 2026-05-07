import Foundation
import Combine

class CacheManager: BaseService {
    static let shared = CacheManager()
    
    @Published var cacheItems: [CacheItem] = []
    @Published var totalCacheSize: Int64 = 0
    @Published var isCalculating = false
    
    private let cacheDirectory: URL
    
    struct CacheItem: Identifiable, Codable {
        let id: String
        let type: CacheType
        let name: String
        let size: Int64
        let createdTime: Date
        let lastAccessTime: Date
        let filePath: String
        
        enum CacheType: String, Codable, CaseIterable {
            case book = "book"
            case chapter = "chapter"
            case cover = "cover"
            case image = "image"
            case audio = "audio"
            case temp = "temp"
            case database = "database"
            case other = "other"
            
            var displayName: String {
                switch self {
                case .book: return "书籍缓存"
                case .chapter: return "章节缓存"
                case .cover: return "封面缓存"
                case .image: return "图片缓存"
                case .audio: return "音频缓存"
                case .temp: return "临时文件"
                case .database: return "数据库"
                case .other: return "其他"
                }
            }
            
            var iconName: String {
                switch self {
                case .book: return "book.fill"
                case .chapter: return "doc.text.fill"
                case .cover: return "photo.fill"
                case .image: return "photo.stack.fill"
                case .audio: return "waveform"
                case .temp: return "folder.fill"
                case .database: return "cylinder.fill"
                case .other: return "doc.fill"
                }
            }
        }
        
        var sizeFormatted: String {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    private init() {
        cacheDirectory = fileManager.documentsDirectory().appendingPathComponent("Cache")
        super.init()
        
        createCacheDirectory()
        calculateCacheSize()
    }
    
    private func createCacheDirectory() {
        try? fileManager.createDirectory(at: cacheDirectory)
    }
    
    func calculateCacheSize() {
        isCalculating = true
        
        Task {
            var items: [CacheItem] = []
            var totalSize: Int64 = 0
            
            if let enumerator = fileManager.listFiles(at: cacheDirectory).enumerated() {
                for (_, fileURL) in enumerator {
                    do {
                        let attributes = try fileManager.fileManager.attributesOfItem(atPath: fileURL.path)
                        let size = (attributes[.size] as? Int64) ?? 0
                        let creationDate = (attributes[.creationDate] as? Date) ?? Date()
                        let modificationDate = (attributes[.modificationDate] as? Date) ?? Date()
                        
                        let type = determineCacheType(for: fileURL)
                        let name = fileURL.lastPathComponent
                        
                        let item = CacheItem(
                            id: UUID().uuidString,
                            type: type,
                            name: name,
                            size: size,
                            createdTime: creationDate,
                            lastAccessTime: modificationDate,
                            filePath: fileURL.path
                        )
                        
                        items.append(item)
                        totalSize += size
                    } catch {
                        continue
                    }
                }
            }
            
            let databaseSize = getDatabaseSize()
            if databaseSize > 0 {
                let dbItem = CacheItem(
                    id: "database_main",
                    type: .database,
                    name: "应用数据库",
                    size: databaseSize,
                    createdTime: Date(),
                    lastAccessTime: Date(),
                    filePath: ""
                )
                items.append(dbItem)
                totalSize += databaseSize
            }
            
            await MainActor.run {
                self.cacheItems = items.sorted { $0.size > $1.size }
                self.totalCacheSize = totalSize
                self.isCalculating = false
            }
        }
    }
    
    private func determineCacheType(for url: URL) -> CacheItem.CacheType {
        let path = url.path.lowercased()
        let fileName = url.lastPathComponent.lowercased()
        
        if path.contains("/books/") || fileName.hasPrefix("book_") {
            return .book
        } else if path.contains("/chapters/") || fileName.hasPrefix("chapter_") {
            return .chapter
        } else if path.contains("/covers/") || fileName.hasPrefix("cover_") {
            return .cover
        } else if path.contains("/images/") || path.contains("/img/") {
            return .image
        } else if path.contains("/audio/") || path.contains("/tts/") {
            return .audio
        } else if path.contains("/temp/") || path.contains("/tmp/") {
            return .temp
        } else if path.contains(".db") || path.contains(".sqlite") {
            return .database
        } else {
            return .other
        }
    }
    
    private func getDatabaseSize() -> Int64 {
        let dbPath = fileManager.documentsDirectory().appendingPathComponent("legado.db")
        return fileManager.fileSize(at: dbPath)
    }
    
    func clearCache(type: CacheItem.CacheType? = nil) {
        if let type = type {
            let itemsToDelete = cacheItems.filter { $0.type == type && !$0.filePath.isEmpty }
            for item in itemsToDelete {
                try? fileManager.removeFile(at: URL(fileURLWithPath: item.filePath))
            }
        } else {
            try? fileManager.clearDirectory(cacheDirectory)
        }
        
        calculateCacheSize()
    }
    
    func clearAllCache() {
        clearCache()
    }
    
    func clearTempCache() {
        clearCache(type: .temp)
    }
    
    func clearBookCache(bookId: String) {
        let bookCachePath = cacheDirectory.appendingPathComponent("books").appendingPathComponent(bookId)
        try? fileManager.removeFile(at: bookCachePath)
        calculateCacheSize()
    }
    
    func clearChapterCache(bookId: String, chapterId: String) {
        let chapterCachePath = cacheDirectory.appendingPathComponent("chapters").appendingPathComponent("\(bookId)_\(chapterId)")
        try? fileManager.removeFile(at: chapterCachePath)
        calculateCacheSize()
    }
    
    func clearCoverCache() {
        clearCache(type: .cover)
    }
    
    func clearImageCache() {
        clearCache(type: .image)
    }
    
    func clearAudioCache() {
        clearCache(type: .audio)
    }
    
    func clearOldCache(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let oldItems = cacheItems.filter { $0.lastAccessTime < cutoffDate && !$0.filePath.isEmpty }
        
        for item in oldItems {
            try? fileManager.removeFile(at: URL(fileURLWithPath: item.filePath))
        }
        
        calculateCacheSize()
    }
    
    func getCacheSize(for type: CacheItem.CacheType) -> Int64 {
        return cacheItems.filter { $0.type == type }.reduce(0) { $0 + $1.size }
    }
    
    func getCacheItems(for type: CacheItem.CacheType) -> [CacheItem] {
        return cacheItems.filter { $0.type == type }
    }
    
    func getCacheStatistics() -> CacheStatistics {
        let bookCache = getCacheSize(for: .book)
        let chapterCache = getCacheSize(for: .chapter)
        let coverCache = getCacheSize(for: .cover)
        let imageCache = getCacheSize(for: .image)
        let audioCache = getCacheSize(for: .audio)
        let tempCache = getCacheSize(for: .temp)
        let dbCache = getCacheSize(for: .database)
        let otherCache = getCacheSize(for: .other)
        
        return CacheStatistics(
            totalSize: totalCacheSize,
            bookCache: bookCache,
            chapterCache: chapterCache,
            coverCache: coverCache,
            imageCache: imageCache,
            audioCache: audioCache,
            tempCache: tempCache,
            databaseCache: dbCache,
            otherCache: otherCache
        )
    }
    
    struct CacheStatistics {
        let totalSize: Int64
        let bookCache: Int64
        let chapterCache: Int64
        let coverCache: Int64
        let imageCache: Int64
        let audioCache: Int64
        let tempCache: Int64
        let databaseCache: Int64
        let otherCache: Int64
        
        var totalSizeFormatted: String {
            return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
        
        var bookCacheFormatted: String {
            return ByteCountFormatter.string(fromByteCount: bookCache, countStyle: .file)
        }
        
        var chapterCacheFormatted: String {
            return ByteCountFormatter.string(fromByteCount: chapterCache, countStyle: .file)
        }
        
        var coverCacheFormatted: String {
            return ByteCountFormatter.string(fromByteCount: coverCache, countStyle: .file)
        }
        
        var imageCacheFormatted: String {
            return ByteCountFormatter.string(fromByteCount: imageCache, countStyle: .file)
        }
        
        var audioCacheFormatted: String {
            return ByteCountFormatter.string(fromByteCount: audioCache, countStyle: .file)
        }
        
        var tempCacheFormatted: String {
            return ByteCountFormatter.string(fromByteCount: tempCache, countStyle: .file)
        }
        
        var databaseCacheFormatted: String {
            return ByteCountFormatter.string(fromByteCount: databaseCache, countStyle: .file)
        }
        
        var otherCacheFormatted: String {
            return ByteCountFormatter.string(fromByteCount: otherCache, countStyle: .file)
        }
    }
    
    func saveChapterCache(bookId: String, chapterId: String, content: String) {
        let chaptersDir = cacheDirectory.appendingPathComponent("chapters")
        try? fileManager.createDirectory(at: chaptersDir)
        
        let fileName = "\(bookId)_\(chapterId).txt"
        let filePath = chaptersDir.appendingPathComponent(fileName)
        
        try? content.write(to: filePath, atomically: true, encoding: .utf8)
    }
    
    func getChapterCache(bookId: String, chapterId: String) -> String? {
        let fileName = "\(bookId)_\(chapterId).txt"
        let filePath = cacheDirectory.appendingPathComponent("chapters").appendingPathComponent(fileName)
        
        return try? String(contentsOf: filePath, encoding: .utf8)
    }
    
    func saveCoverCache(bookId: String, imageData: Data) {
        let coversDir = cacheDirectory.appendingPathComponent("covers")
        try? fileManager.createDirectory(at: coversDir)
        
        let fileName = "cover_\(bookId).jpg"
        let filePath = coversDir.appendingPathComponent(fileName)
        
        try? imageData.write(to: filePath)
    }
    
    func getCoverCache(bookId: String) -> Data? {
        let fileName = "cover_\(bookId).jpg"
        let filePath = cacheDirectory.appendingPathComponent("covers").appendingPathComponent(fileName)
        
        return try? Data(contentsOf: filePath)
    }
}

extension CacheManager {
    func preloadCache() {
        calculateCacheSize()
    }
    
    func scheduleAutoClean() {
        let interval = storageManager.integer(forKey: "AutoCleanInterval")
        if interval > 0 {
            clearOldCache(olderThan: interval)
        }
    }
}
