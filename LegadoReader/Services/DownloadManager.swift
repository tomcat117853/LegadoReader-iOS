import Foundation

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloadingBooks: [String: DownloadProgress] = [:]
    @Published var cachedBooks: [String] = []
    
    private let fileManager = FileManager.default
    private var downloads: [String: Task<Void, Never>] = [:]
    
    struct DownloadProgress: Identifiable {
        let id: String
        let bookName: String
        let totalChapters: Int
        @Published var downloadedChapters: Int
        @Published var isComplete: Bool
        @Published var isPaused: Bool
        
        var progress: Double {
            Double(downloadedChapters) / Double(totalChapters)
        }
    }
    
    private init() {
        loadCachedBooks()
    }
    
    private var cacheDirectory: URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("BookCache")
        
        if !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        
        return cacheURL
    }
    
    private func loadCachedBooks() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            cachedBooks = contents.compactMap { $0.lastPathComponent }
        } catch {
            print("Failed to load cached books: \(error)")
        }
    }
    
    func isBookCached(bookId: String) -> Bool {
        return cachedBooks.contains(bookId)
    }
    
    func getCacheSize() -> String {
        let folderPath = cacheDirectory.path
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
    
    func startDownload(bookId: String, bookName: String, chapters: [Chapter], source: BookSource) {
        if downloads[bookId] != nil {
            return
        }
        
        downloadingBooks[bookId] = DownloadProgress(
            id: bookId,
            bookName: bookName,
            totalChapters: chapters.count,
            downloadedChapters: 0,
            isComplete: false,
            isPaused: false
        )
        
        downloads[bookId] = Task { [weak self] in
            for chapter in chapters {
                guard let progress = self?.downloadingBooks[bookId], !progress.isPaused else {
                    break
                }
                
                do {
                    let content = try await BookSourceParser.shared.getChapterContent(chapter: chapter, source: source)
                    try await self?.saveChapter(bookId: bookId, chapterId: chapter.id, content: content)
                    
                    await MainActor.run {
                        self?.downloadingBooks[bookId]?.downloadedChapters += 1
                    }
                } catch {
                    print("Failed to download chapter \(chapter.title): \(error)")
                }
            }
            
            await MainActor.run {
                if let progress = self?.downloadingBooks[bookId], !progress.isPaused {
                    self?.downloadingBooks[bookId]?.isComplete = true
                    if !self!.cachedBooks.contains(bookId) {
                        self?.cachedBooks.append(bookId)
                    }
                }
                self?.downloads[bookId] = nil
            }
        }
    }
    
    func pauseDownload(bookId: String) {
        downloadingBooks[bookId]?.isPaused = true
        downloads[bookId]?.cancel()
        downloads[bookId] = nil
    }
    
    func resumeDownload(bookId: String) {
        downloadingBooks[bookId]?.isPaused = false
    }
    
    func cancelDownload(bookId: String) {
        downloadingBooks[bookId]?.isPaused = true
        downloads[bookId]?.cancel()
        downloads[bookId] = nil
        
        Task {
            try? await removeBookCache(bookId: bookId)
        }
        
        downloadingBooks.removeValue(forKey: bookId)
    }
    
    func getCachedChapter(bookId: String, chapterId: String) -> String? {
        let chapterURL = cacheDirectory
            .appendingPathComponent(bookId)
            .appendingPathComponent("\(chapterId).txt")
        
        return try? String(contentsOf: chapterURL)
    }
    
    private func saveChapter(bookId: String, chapterId: String, content: String) async throws {
        let bookDir = cacheDirectory.appendingPathComponent(bookId)
        
        if !fileManager.fileExists(atPath: bookDir.path) {
            try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
        }
        
        let chapterURL = bookDir.appendingPathComponent("\(chapterId).txt")
        try content.write(to: chapterURL, atomically: true, encoding: .utf8)
    }
    
    func removeBookCache(bookId: String) async throws {
        let bookDir = cacheDirectory.appendingPathComponent(bookId)
        
        if fileManager.fileExists(atPath: bookDir.path) {
            try fileManager.removeItem(at: bookDir)
            
            if let index = cachedBooks.firstIndex(of: bookId) {
                cachedBooks.remove(at: index)
            }
        }
    }
    
    func clearAllCache() async throws {
        for bookId in cachedBooks {
            try await removeBookCache(bookId: bookId)
        }
        cachedBooks.removeAll()
    }
}
