import Foundation

class BookArchiveReader: BookReaderProtocol {
    private let archiveManager = ArchiveManager.shared
    private let txtReader = TXTReader()
    private let fb2Reader = FB2Reader()
    
    private let supportedTextExtensions = ["txt", "html", "htm", "xhtml", "fb2", "epub"]
    
    func read(data: Data) async throws -> BookContent {
        throw ArchiveBookError.unsupportedDirectRead
    }
    
    func read(from url: URL) async throws -> BookContent {
        let filename = url.lastPathComponent.lowercased()
        
        if filename.hasSuffix(".7z") {
            return try await read7Z(from: url)
        } else if filename.hasSuffix(".tar.gz") || filename.hasSuffix(".tgz") {
            return try await readTARGZ(from: url)
        } else if filename.hasSuffix(".tar.bz2") || filename.hasSuffix(".tbz2") {
            return try await readTARBZ2(from: url)
        } else if filename.hasSuffix(".tar.xz") {
            return try await readTARXZ(from: url)
        } else if filename.hasSuffix(".tar") {
            return try await readTAR(from: url)
        } else if filename.hasSuffix(".xz") {
            return try await readXZ(from: url)
        }
        
        throw ArchiveBookError.unsupportedFormat
    }
    
    private func read7Z(from url: URL) async throws -> BookContent {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedFiles = try await archiveManager.extractArchive(at: url, to: tempDir)
        return try await readExtractedContent(from: extractedFiles)
    }
    
    private func readTAR(from url: URL) async throws -> BookContent {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedFiles = try await archiveManager.extractArchive(at: url, to: tempDir)
        return try await readExtractedContent(from: extractedFiles)
    }
    
    private func readTARGZ(from url: URL) async throws -> BookContent {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedFiles = try await archiveManager.extractArchive(at: url, to: tempDir)
        return try await readExtractedContent(from: extractedFiles)
    }
    
    private func readTARBZ2(from url: URL) async throws -> BookContent {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedFiles = try await archiveManager.extractArchive(at: url, to: tempDir)
        return try await readExtractedContent(from: extractedFiles)
    }
    
    private func readTARXZ(from url: URL) async throws -> BookContent {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedFiles = try await archiveManager.extractArchive(at: url, to: tempDir)
        return try await readExtractedContent(from: extractedFiles)
    }
    
    private func readXZ(from url: URL) async throws -> BookContent {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedFiles = try await archiveManager.extractArchive(at: url, to: tempDir)
        return try await readExtractedContent(from: extractedFiles)
    }
    
    private func readExtractedContent(from files: [URL]) async throws -> BookContent {
        let bookFiles = files.filter { url in
            let ext = url.pathExtension.lowercased()
            return supportedTextExtensions.contains(ext)
        }
        
        if bookFiles.isEmpty {
            throw ArchiveBookError.noTextFileFound
        }
        
        let sortedFiles = bookFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        var allChapters: [BookChapter] = []
        var title = ""
        var author = ""
        
        for (index, fileURL) in sortedFiles.enumerated() {
            let fileData = try Data(contentsOf: fileURL)
            let ext = fileURL.pathExtension.lowercased()
            
            var content: BookContent
            
            if ext == "fb2" {
                content = try await fb2Reader.read(data: fileData)
            } else if ext == "epub" {
                content = try await EPUBReader().read(data: fileData)
            } else {
                content = try await txtReader.read(data: fileData)
            }
            
            if title.isEmpty && !content.title.isEmpty {
                title = content.title
            }
            
            if author.isEmpty && !content.author.isEmpty {
                author = content.author
            }
            
            if content.chapters.isEmpty && !content.rawContent.isEmpty {
                let chapterTitle = fileURL.deletingPathExtension().lastPathComponent
                allChapters.append(BookChapter(title: chapterTitle, content: content.rawContent))
            } else {
                for var chapter in content.chapters {
                    chapter = BookChapter(
                        title: chapter.title,
                        content: chapter.content,
                        level: chapter.level,
                        startOffset: chapter.startOffset
                    )
                    allChapters.append(chapter)
                }
            }
        }
        
        return BookContent(
            title: title.isEmpty ? "导入的书籍" : title,
            author: author,
            chapters: allChapters,
            cover: nil,
            metadata: BookMetadata(),
            rawContent: allChapters.map { $0.content }.joined(separator: "\n\n")
        )
    }
    
    func extractCover(data: Data) -> Data? {
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        return BookMetadata()
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        return []
    }
    
    func canRead(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let supportedExtensions = ["7z", "tar", "gz", "bz2", "xz"]
        
        if ext.hasSuffix(".tar.gz") || ext.hasSuffix(".tgz") ||
           ext.hasSuffix(".tar.bz2") || ext.hasSuffix(".tbz2") ||
           ext.hasSuffix(".tar.xz") || ext == "7z" || ext == "tar" || ext == "xz" {
            return true
        }
        
        return supportedExtensions.contains(ext)
    }
}

enum ArchiveBookError: Error, LocalizedError {
    case unsupportedFormat
    case unsupportedDirectRead
    case noTextFileFound
    case extractionFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "不支持的压缩格式"
        case .unsupportedDirectRead:
            return "不支持直接读取压缩数据"
        case .noTextFileFound:
            return "压缩包中未找到文本文件"
        case .extractionFailed:
            return "解压失败"
        }
    }
}
