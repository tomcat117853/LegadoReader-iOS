import Foundation

class ArchiveManager: BaseService {
    static let shared = ArchiveManager()
    
    @Published var supportedArchiveFormats: [ArchiveFormat] = []
    @Published var recentArchives: [ArchiveInfo] = []
    @Published var isExtracting = false
    @Published var extractionProgress: Double = 0
    
    struct ArchiveFormat: Identifiable {
        let id: String
        let name: String
        let extensions: [String]
        let isNativeSupported: Bool
        
        var displayName: String {
            return "\(name) (\(extensions.map { ".\($0)" }.joined(separator: ", ")))"
        }
    }
    
    struct ArchiveInfo: Identifiable, Codable {
        let id: String
        let name: String
        let path: String
        let size: Int64
        let format: String
        let entryCount: Int
        let createdTime: Date
        var lastAccessedTime: Date
        
        var sizeFormatted: String {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    struct ArchiveEntry: Identifiable {
        let id: String
        let name: String
        let path: String
        let size: Int64
        let isDirectory: Bool
        let compressedSize: Int64
        let modificationDate: Date?
        
        var sizeFormatted: String {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        
        var compressionRatio: Double {
            guard size > 0 else { return 0 }
            return 1.0 - (Double(compressedSize) / Double(size))
        }
    }
    
    private init() {
        super.init()
        registerFormats()
        loadRecentArchives()
    }
    
    private func registerFormats() {
        supportedArchiveFormats = [
            ArchiveFormat(id: "zip", name: "ZIP", extensions: ["zip", "cbz"], isNativeSupported: true),
            ArchiveFormat(id: "rar", name: "RAR", extensions: ["rar", "cbr"], isNativeSupported: false),
            ArchiveFormat(id: "7z", name: "7-Zip", extensions: ["7z"], isNativeSupported: false),
            ArchiveFormat(id: "tar", name: "TAR", extensions: ["tar", "tar.gz", "tgz", "tbz2"], isNativeSupported: false),
            ArchiveFormat(id: "bz2", name: "BZIP2", extensions: ["bz2"], isNativeSupported: false),
            ArchiveFormat(id: "xz", name: "XZ", extensions: ["xz"], isNativeSupported: false),
            ArchiveFormat(id: "lzma", name: "LZMA", extensions: ["lzma"], isNativeSupported: false)
        ]
    }
    
    private func loadRecentArchives() {
        if let saved = loadCodable([ArchiveInfo].self, key: "ArchiveManager_recent") {
            recentArchives = saved
        }
    }
    
    private func saveRecentArchives() {
        saveCodable(recentArchives, key: "ArchiveManager_recent")
    }
    
    func detectArchiveFormat(_ filename: String) -> ArchiveFormat? {
        let lowerFilename = filename.lowercased()
        
        for format in supportedArchiveFormats {
            for ext in format.extensions {
                if lowerFilename.hasSuffix(".\(ext)") {
                    return format
                }
            }
        }
        
        return nil
    }
    
    func isArchiveFile(_ filename: String) -> Bool {
        return detectArchiveFormat(filename) != nil
    }
    
    func getSupportedExtensions() -> [String] {
        return supportedArchiveFormats.flatMap { $0.extensions }
    }
    
    func analyzeArchive(at url: URL) async throws -> [ArchiveEntry] {
        let filename = url.lastPathComponent.lowercased()
        
        if filename.hasSuffix(".zip") || filename.hasSuffix(".cbz") {
            return try await analyzeZIPArchive(at: url)
        } else if filename.hasSuffix(".rar") || filename.hasSuffix(".cbr") {
            return try await analyzeRARArchive(at: url)
        }
        
        throw ArchiveError.unsupportedFormat
    }
    
    func extractArchive(at url: URL, to destination: URL, entries: [ArchiveEntry]? = nil) async throws -> [URL] {
        isExtracting = true
        extractionProgress = 0
        
        defer {
            isExtracting = false
            extractionProgress = 0
        }
        
        let filename = url.lastPathComponent.lowercased()
        var extractedFiles: [URL] = []
        
        do {
            if filename.hasSuffix(".zip") || filename.hasSuffix(".cbz") {
                extractedFiles = try await extractZIPArchive(at: url, to: destination, entries: entries)
            } else if filename.hasSuffix(".rar") || filename.hasSuffix(".cbr") {
                extractedFiles = try await extractRARArchive(at: url, to: destination, entries: entries)
            } else {
                throw ArchiveError.unsupportedFormat
            }
            
            let archiveInfo = ArchiveInfo(
                id: UUID().uuidString,
                name: url.lastPathComponent,
                path: url.path,
                size: fileManager.fileSize(at: url),
                format: filename.components(separatedBy: ".").last ?? "unknown",
                entryCount: extractedFiles.count,
                createdTime: Date(),
                lastAccessedTime: Date()
            )
            
            addToRecentArchives(archiveInfo)
            
            return extractedFiles
            
        } catch {
            logError("Failed to extract archive: \(error)")
            throw error
        }
    }
    
    private func analyzeZIPArchive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var entries: [ArchiveEntry] = []
                
                do {
                    let data = try Data(contentsOf: url)
                    guard data.starts(with: [0x50, 0x4B, 0x03, 0x04]) || 
                          data.starts(with: [0x50, 0x4B, 0x05, 0x06]) ||
                          data.starts(with: [0x50, 0x4B, 0x07, 0x08]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    let archiveURL = URL(fileURLWithPath: url.path)
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    
                    if ProcessInfo.processInfo.environment["IS_SIMULATOR"] == "1" {
                        entries = self.parseZIPHeaders(data: data)
                    } else {
                        try FileManager.default.unzipItem(at: archiveURL, to: tempDir)
                        entries = self.scanExtractedFiles(at: tempDir)
                    }
                    
                    try? FileManager.default.removeItem(at: tempDir)
                    
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func parseZIPHeaders(data: Data) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var offset = 0
        
        while offset < data.count - 4 {
            let signature = Array(data[offset..<offset+4])
            
            if signature == [0x50, 0x4B, 0x03, 0x04] {
                guard offset + 30 <= data.count else { break }
                
                let nameLength = Int(data[offset+26]) | (Int(data[offset+27]) << 8)
                let extraLength = Int(data[offset+28]) | (Int(data[offset+29]) << 8)
                let compressedSize = Int(data[offset+18]) | (Int(data[offset+19]) << 8) |
                                   (Int(data[offset+20]) << 16) | (Int(data[offset+21]) << 24)
                let uncompressedSize = Int(data[offset+22]) | (Int(data[offset+23]) << 8) |
                                     (Int(data[offset+24]) << 16) | (Int(data[offset+25]) << 24)
                
                let nameStart = offset + 30
                let nameEnd = nameStart + nameLength
                
                guard nameEnd <= data.count else { break }
                
                let nameData = data[nameStart..<nameEnd]
                guard let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1) else {
                    offset = nameEnd + extraLength + compressedSize
                    continue
                }
                
                if !name.hasSuffix("/") {
                    entries.append(ArchiveEntry(
                        id: UUID().uuidString,
                        name: URL(fileURLWithPath: name).lastPathComponent,
                        path: name,
                        size: Int64(uncompressedSize),
                        isDirectory: false,
                        compressedSize: Int64(compressedSize),
                        modificationDate: nil
                    ))
                }
                
                offset = nameEnd + extraLength + compressedSize
            } else if signature == [0x50, 0x4B, 0x05, 0x06] {
                break
            } else {
                offset += 1
            }
        }
        
        return entries
    }
    
    private func scanExtractedFiles(at directory: URL) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]) else {
            return entries
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                let isDirectory = resourceValues.isDirectory ?? false
                let size = Int64(resourceValues.fileSize ?? 0)
                
                let relativePath = fileURL.path.replacingOccurrences(of: directory.path, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                
                if !isDirectory {
                    entries.append(ArchiveEntry(
                        id: UUID().uuidString,
                        name: fileURL.lastPathComponent,
                        path: relativePath,
                        size: size,
                        isDirectory: false,
                        compressedSize: 0,
                        modificationDate: nil
                    ))
                }
            } catch {
                continue
            }
        }
        
        return entries
    }
    
    private func analyzeRARArchive(at url: URL) async throws -> [ArchiveEntry] {
        logWarning("RAR format requires third-party library for full support")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var entries: [ArchiveEntry] = []
                
                do {
                    let data = try Data(contentsOf: url)
                    
                    guard data.starts(with: [0x52, 0x61, 0x72, 0x21]) || 
                          data.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]) ||
                          data.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    entries = self.parseRARHeaders(data: data)
                    
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func parseRARHeaders(data: Data) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var offset = 0
        
        if data.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01]) {
            offset = 7
        } else if data.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]) {
            offset = 7
        } else {
            offset = 7
        }
        
        while offset < data.count - 7 {
            guard offset + 7 <= data.count else { break }
            
            let blockType = data[offset]
            let blockLength = Int(data[offset+2]) | (Int(data[offset+3]) << 8) |
                             (Int(data[offset+4]) << 16) | (Int(data[offset+5]) << 24)
            
            if blockType == 0x74 {
                guard offset + blockLength <= data.count else { break }
                
                let nameLength = Int(data[offset+12]) | (Int(data[offset+13]) << 8)
                let nameStart = offset + 15
                let nameEnd = nameStart + nameLength
                
                guard nameEnd <= data.count else {
                    offset += blockLength
                    continue
                }
                
                let nameData = data[nameStart..<nameEnd]
                guard let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1) else {
                    offset += blockLength
                    continue
                }
                
                if !name.hasSuffix("/") && !name.isEmpty {
                    entries.append(ArchiveEntry(
                        id: UUID().uuidString,
                        name: URL(fileURLWithPath: name).lastPathComponent,
                        path: name,
                        size: 0,
                        isDirectory: false,
                        compressedSize: 0,
                        modificationDate: nil
                    ))
                }
                
                offset += blockLength
            } else {
                offset += max(blockLength, 0)
            }
            
            if offset >= data.count { break }
        }
        
        return entries
    }
    
    private func extractZIPArchive(at url: URL, to destination: URL, entries: [ArchiveEntry]?) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    if ProcessInfo.processInfo.environment["IS_SIMULATOR"] == "1" {
                        let data = try Data(contentsOf: url)
                        let extractedFiles = self.extractZIPManually(data: data, to: destination, entries: entries)
                        continuation.resume(returning: extractedFiles)
                    } else {
                        try FileManager.default.unzipItem(at: url, to: destination)
                        
                        var extractedFiles: [URL] = []
                        let contents = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
                        
                        for file in contents {
                            extractedFiles.append(file)
                        }
                        
                        continuation.resume(returning: extractedFiles)
                    }
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func extractZIPManually(data: Data, to destination: URL, entries: [ArchiveEntry]?) -> [URL] {
        var extractedFiles: [URL] = []
        var offset = 0
        
        while offset < data.count - 4 {
            let signature = Array(data[offset..<min(offset+4, data.count)])
            
            if signature == [0x50, 0x4B, 0x03, 0x04] {
                guard offset + 30 <= data.count else { break }
                
                let compressionMethod = Int(data[offset+8]) | (Int(data[offset+9]) << 8)
                let nameLength = Int(data[offset+26]) | (Int(data[offset+27]) << 8)
                let extraLength = Int(data[offset+28]) | (Int(data[offset+29]) << 8)
                let compressedSize = Int(data[offset+18]) | (Int(data[offset+19]) << 8) |
                                   (Int(data[offset+20]) << 16) | (Int(data[offset+21]) << 24)
                
                let nameStart = offset + 30
                let nameEnd = nameStart + nameLength
                
                guard nameEnd <= data.count else { break }
                
                let nameData = data[nameStart..<nameEnd]
                guard var name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1) else {
                    offset = nameEnd + extraLength + compressedSize
                    continue
                }
                
                name = name.replacingOccurrences(of: "/", with: "_")
                
                if name.hasSuffix("/") || name.isEmpty {
                    offset = nameEnd + extraLength + compressedSize
                    continue
                }
                
                let dataStart = nameEnd + extraLength
                let dataEnd = dataStart + compressedSize
                
                guard dataEnd <= data.count else { break }
                
                let compressedData = data[dataStart..<dataEnd]
                
                var decompressedData: Data?
                
                if compressionMethod == 0 {
                    decompressedData = Data(compressedData)
                } else if compressionMethod == 8 {
                    decompressedData = self.decompressDeflate(Data(compressedData))
                }
                
                if let content = decompressedData {
                    let filePath = destination.appendingPathComponent(name)
                    
                    do {
                        try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try content.write(to: filePath)
                        extractedFiles.append(filePath)
                    } catch {
                        logWarning("Failed to write file: \(name)")
                    }
                }
                
                offset = dataEnd
            } else if signature == [0x50, 0x4B, 0x05, 0x06] {
                break
            } else {
                offset += 1
            }
        }
        
        return extractedFiles
    }
    
    private func decompressDeflate(_ data: Data) -> Data? {
        return try? (data as NSData).decompressed(using: .lzfse) ?? data
    }
    
    private func extractRARArchive(at url: URL, to destination: URL, entries: [ArchiveEntry]?) async throws -> [URL] {
        logWarning("RAR extraction requires third-party library (UnrarKit)")
        throw ArchiveError.rarRequiresLibrary
    }
    
    func addToRecentArchives(_ archive: ArchiveInfo) {
        recentArchives.removeAll { $0.path == archive.path }
        recentArchives.insert(archive, at: 0)
        
        if recentArchives.count > 20 {
            recentArchives = Array(recentArchives.prefix(20))
        }
        
        saveRecentArchives()
    }
    
    func clearRecentArchives() {
        recentArchives.removeAll()
        saveRecentArchives()
    }
    
    func getBookFiles(from entries: [ArchiveEntry]) -> [ArchiveEntry] {
        let bookExtensions = BookFormatManager.shared.getSupportedExtensions()
        
        return entries.filter { entry in
            let ext = URL(fileURLWithPath: entry.name).pathExtension.lowercased()
            return bookExtensions.contains(ext)
        }
    }
    
    func getImageFiles(from entries: [ArchiveEntry]) -> [ArchiveEntry] {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        
        return entries.filter { entry in
            let ext = URL(fileURLWithPath: entry.name).pathExtension.lowercased()
            return imageExtensions.contains(ext)
        }
    }
}

enum ArchiveError: Error, LocalizedError {
    case unsupportedFormat
    case invalidArchive
    case failedToAnalyze(String)
    case failedToExtract(String)
    case rarRequiresLibrary
    case extractionCancelled
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支持的压缩格式"
        case .invalidArchive: return "无效的压缩文件"
        case .failedToAnalyze(let msg): return "分析失败: \(msg)"
        case .failedToExtract(let msg): return "解压失败: \(msg)"
        case .rarRequiresLibrary: return "RAR格式需要第三方库支持（UnrarKit）"
        case .extractionCancelled: return "解压已取消"
        }
    }
}

extension FileManager {
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", sourceURL.path, "-d", destinationURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ArchiveError.failedToExtract("unzip command failed")
        }
    }
}
