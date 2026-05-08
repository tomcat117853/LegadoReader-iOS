import Foundation
import Compression

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
    
    private func isPathTraversal(_ path: String, baseURL: URL) -> Bool {
        let normalizedPath = path
            .replacingOccurrences(of: "\\", with: "/")
        
        if normalizedPath.contains("..") {
            return true
        }
        
        if normalizedPath.hasPrefix("/") || normalizedPath.hasPrefix("./") {
            return true
        }
        
        return false
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return fileName.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    private func safeExtractPath(_ path: String, to destination: URL) -> URL {
        let sanitizedName = sanitizeFileName(path)
            .replacingOccurrences(of: "..", with: "_")
        
        let safePath = destination.appendingPathComponent(sanitizedName)
        
        let resolvedSafe = safePath.resolvingSymlinksInPath()
        let resolvedDest = destination.resolvingSymlinksInPath()
        
        if !resolvedSafe.path.hasPrefix(resolvedDest.path) {
            return destination.appendingPathComponent(UUID().uuidString + "_" + sanitizedName)
        }
        
        return safePath
    }
    
    private func registerFormats() {
        supportedArchiveFormats = [
            ArchiveFormat(id: "zip", name: "ZIP", extensions: ["zip", "cbz"], isNativeSupported: true),
            ArchiveFormat(id: "rar", name: "RAR", extensions: ["rar", "cbr"], isNativeSupported: true),
            ArchiveFormat(id: "7z", name: "7-Zip", extensions: ["7z"], isNativeSupported: true),
            ArchiveFormat(id: "tar", name: "TAR", extensions: ["tar", "tar.gz", "tgz", "tar.bz2", "tbz2"], isNativeSupported: true),
            ArchiveFormat(id: "gz", name: "GZIP", extensions: ["gz"], isNativeSupported: true),
            ArchiveFormat(id: "bz2", name: "BZIP2", extensions: ["bz2"], isNativeSupported: true),
            ArchiveFormat(id: "xz", name: "XZ", extensions: ["xz"], isNativeSupported: true)
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
        } else if filename.hasSuffix(".7z") {
            return try await analyze7ZArchive(at: url)
        } else if filename.hasSuffix(".tar.gz") || filename.hasSuffix(".tgz") {
            return try await analyzeTGZArchive(at: url)
        } else if filename.hasSuffix(".tar.bz2") || filename.hasSuffix(".tbz2") {
            return try await analyzeTBZ2Archive(at: url)
        } else if filename.hasSuffix(".tar.xz") {
            return try await analyzeTXZArchive(at: url)
        } else if filename.hasSuffix(".tar") {
            return try await analyzeTARArchive(at: url)
        } else if filename.hasSuffix(".gz") {
            return try await analyzeGZIPArchive(at: url)
        } else if filename.hasSuffix(".bz2") {
            return try await analyzeBZIP2Archive(at: url)
        } else if filename.hasSuffix(".xz") {
            return try await analyzeXZArchive(at: url)
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
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            
            if filename.hasSuffix(".zip") || filename.hasSuffix(".cbz") {
                extractedFiles = try await extractZIPArchive(at: url, to: destination, entries: entries)
            } else if filename.hasSuffix(".rar") || filename.hasSuffix(".cbr") {
                extractedFiles = try await extractRARArchive(at: url, to: destination, entries: entries)
            } else if filename.hasSuffix(".7z") {
                extractedFiles = try await extract7ZArchive(at: url, to: destination, entries: entries)
            } else if filename.hasSuffix(".tar.gz") || filename.hasSuffix(".tgz") {
                extractedFiles = try await extractTGZArchive(at: url, to: destination)
            } else if filename.hasSuffix(".tar.bz2") || filename.hasSuffix(".tbz2") {
                extractedFiles = try await extractTBZ2Archive(at: url, to: destination)
            } else if filename.hasSuffix(".tar.xz") {
                extractedFiles = try await extractTXZArchive(at: url, to: destination)
            } else if filename.hasSuffix(".tar") {
                extractedFiles = try await extractTARArchive(at: url, to: destination, entries: entries)
            } else if filename.hasSuffix(".gz") {
                extractedFiles = try await extractGZIPArchive(at: url, to: destination)
            } else if filename.hasSuffix(".bz2") {
                extractedFiles = try await extractBZIP2Archive(at: url, to: destination)
            } else if filename.hasSuffix(".xz") {
                extractedFiles = try await extractXZArchive(at: url, to: destination)
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
                do {
                    let data = try Data(contentsOf: url)
                    guard data.starts(with: [0x50, 0x4B, 0x03, 0x04]) || 
                          data.starts(with: [0x50, 0x4B, 0x05, 0x06]) ||
                          data.starts(with: [0x50, 0x4B, 0x07, 0x08]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    let entries = self.parseZIPHeaders(data: data)
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
            guard offset + 4 <= data.count else { break }
            let signature = [UInt8](data[offset..<offset+4])
            
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
                
                if !name.hasSuffix("/") && !name.isEmpty {
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
            } else if signature == [0x50, 0x4B, 0x05, 0x06] || signature == [0x50, 0x4B, 0x06, 0x06] {
                break
            } else {
                offset += 1
            }
        }
        
        return entries
    }
    
    private func analyzeRARArchive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    
                    guard data.starts(with: [0x52, 0x61, 0x72, 0x21]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    let entries = self.parseRARHeaders(data: data)
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
        
        guard data.count >= 7 else { return entries }
        
        if data[5] == 0x07 && (data[6] == 0x00 || data[6] == 0x01) {
            offset = 7
        } else if data[5] == 0x07 {
            offset = 7
        } else {
            offset = 7
        }
        
        while offset < data.count - 7 {
            guard offset + 7 <= data.count else { break }
            
            let blockType = data[offset]
            guard offset + 4 <= data.count else { break }
            let blockLength = Int(data[offset+2]) | (Int(data[offset+3]) << 8) |
                             (Int(data[offset+4]) << 16) | (Int(data[offset+5]) << 24)
            
            if blockType == 0x74 {
                guard offset + 15 <= data.count else { break }
                
                let nameLength = Int(data[offset+12]) | (Int(data[offset+13]) << 8)
                let packSize = Int(data[offset+8]) | (Int(data[offset+9]) << 8) |
                             (Int(data[offset+10]) << 16) | (Int(data[offset+11]) << 24)
                let unpackedSize = Int(data[offset+14]) | (Int(data[offset+15]) << 8) |
                                (Int(data[offset+16]) << 16) | (Int(data[offset+17]) << 24)
                
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
                
                if !name.hasSuffix("/") && !name.isEmpty && !name.hasPrefix("SFX") {
                    entries.append(ArchiveEntry(
                        id: UUID().uuidString,
                        name: URL(fileURLWithPath: name).lastPathComponent,
                        path: name,
                        size: Int64(unpackedSize),
                        isDirectory: false,
                        compressedSize: Int64(packSize),
                        modificationDate: nil
                    ))
                }
                
                offset += blockLength
            } else if blockType == 0x7B {
                break
            } else {
                let skipAmount = max(blockLength, 7)
                offset += skipAmount
            }
            
            if offset >= data.count { break }
        }
        
        return entries
    }
    
    private func analyze7ZArchive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    
                    guard data.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    let entries = self.parse7ZHeaders(data: data)
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func parse7ZHeaders(data: Data) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var offset = 0
        
        guard data.count >= 32 else { return entries }
        offset = 32
        
        guard offset + 20 <= data.count else { return entries }
        
        let nextHeaderOffset = Int(data[offset]) | (Int(data[offset+1]) << 8) |
                              (Int(data[offset+2]) << 16) | (Int(data[offset+3]) << 24) |
                              (Int(data[offset+4]) << 32) | (Int(data[offset+5]) << 40) |
                              (Int(data[offset+6]) << 48) | (Int(data[offset+7]) << 56)
        
        let nextHeaderSize = Int(data[offset+12]) | (Int(data[offset+13]) << 8) |
                            (Int(data[offset+14]) << 16) | (Int(data[offset+15]) << 24)
        
        offset += Int(nextHeaderOffset)
        
        guard offset + nextHeaderSize <= data.count else { return entries }
        
        guard offset + 1 <= data.count else { return entries }
        let nextHeaderType = data[offset]
        
        if nextHeaderType == 0x01 {
            offset += 1
            guard offset + 20 <= data.count else { return entries }
            
            let nameLen = Int(data[offset+2]) | (Int(data[offset+3]) << 8)
            offset += 4
            
            guard offset + nameLen <= data.count else { return entries }
            let nameData = data[offset..<offset+nameLen]
            
            if let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) {
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
        }
        
        return entries
    }
    
    private func analyzeTGZArchive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    guard data.starts(with: [0x1F, 0x8B]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    if let decompressed = self.decompressGZIP(data) {
                        let entries = self.parseTARHeaders(data: decompressed)
                        continuation.resume(returning: entries)
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func analyzeTBZ2Archive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    guard data.starts(with: [0x42, 0x5A, 0x68]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    if let decompressed = self.decompressBZIP2(data) {
                        let entries = self.parseTARHeaders(data: decompressed)
                        continuation.resume(returning: entries)
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func analyzeTXZArchive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    guard data.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    if let decompressed = self.decompressXZ(data) {
                        let entries = self.parseTARHeaders(data: decompressed)
                        continuation.resume(returning: entries)
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func analyzeTARArchive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    let entries = self.parseTARHeaders(data: data)
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func parseTARHeaders(data: Data) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var offset = 0
        
        while offset + 512 <= data.count {
            let header = data[offset..<offset+512]
            
            let typeFlag = header[156]
            
            if typeFlag == 0 || typeFlag == 0x30 || typeFlag == 0x35 {
                let nameData = header[0..<100]
                if let name = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: .init(charactersIn: "\0")) {
                    if !name.isEmpty && name != "" {
                        let sizeStr = String(data: header[124..<136], encoding: .ascii)?.trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? "0"
                        let size = Int(sizeStr, radix: 8) ?? 0
                        
                        entries.append(ArchiveEntry(
                            id: UUID().uuidString,
                            name: URL(fileURLWithPath: name).lastPathComponent,
                            path: name,
                            size: Int64(size),
                            isDirectory: typeFlag == 0x35,
                            compressedSize: 0,
                            modificationDate: nil
                        ))
                    }
                }
            }
            
            let sizeStr = String(data: header[124..<136], encoding: .ascii)?.trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? "0"
            let size = (Int(sizeStr, radix: 8) ?? 0)
            offset += 512 + ((size + 511) / 512) * 512
            
            if offset > data.count { break }
        }
        
        return entries
    }
    
    private func analyzeGZIPArchive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    guard data.starts(with: [0x1F, 0x8B]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    if let decompressed = self.decompressGZIP(data) {
                        let originalName = url.deletingPathExtension().lastPathComponent
                        let entry = ArchiveEntry(
                            id: UUID().uuidString,
                            name: originalName,
                            path: originalName,
                            size: Int64(decompressed.count),
                            isDirectory: false,
                            compressedSize: Int64(data.count),
                            modificationDate: nil
                        )
                        continuation.resume(returning: [entry])
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func analyzeBZIP2Archive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    guard data.starts(with: [0x42, 0x5A, 0x68]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    if let decompressed = self.decompressBZIP2(data) {
                        let originalName = url.deletingPathExtension().lastPathComponent
                        let entry = ArchiveEntry(
                            id: UUID().uuidString,
                            name: originalName,
                            path: originalName,
                            size: Int64(decompressed.count),
                            isDirectory: false,
                            compressedSize: Int64(data.count),
                            modificationDate: nil
                        )
                        continuation.resume(returning: [entry])
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func analyzeXZArchive(at url: URL) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    guard data.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) else {
                        throw ArchiveError.invalidArchive
                    }
                    
                    if let decompressed = self.decompressXZ(data) {
                        let originalName = url.deletingPathExtension().lastPathComponent
                        let entry = ArchiveEntry(
                            id: UUID().uuidString,
                            name: originalName,
                            path: originalName,
                            size: Int64(decompressed.count),
                            isDirectory: false,
                            compressedSize: Int64(data.count),
                            modificationDate: nil
                        )
                        continuation.resume(returning: [entry])
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToAnalyze(error.localizedDescription))
                }
            }
        }
    }
    
    private func extractZIPArchive(at url: URL, to destination: URL, entries: [ArchiveEntry]?) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    let extractedFiles = self.extractZIPManually(data: data, to: destination, entries: entries)
                    continuation.resume(returning: extractedFiles)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func extractZIPManually(data: Data, to destination: URL, entries: [ArchiveEntry]?) -> [URL] {
        var extractedFiles: [URL] = []
        var offset = 0
        
        let entriesToExtract: Set<String>?
        if let entries = entries {
            entriesToExtract = Set(entries.map { $0.path })
        } else {
            entriesToExtract = nil
        }
        
        while offset < data.count - 4 {
            guard offset + 4 <= data.count else { break }
            let signature = [UInt8](data[offset..<offset+4])
            
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
                guard let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1) else {
                    offset = nameEnd + extraLength + compressedSize
                    continue
                }
                
                if name.hasSuffix("/") || name.isEmpty {
                    offset = nameEnd + extraLength + compressedSize
                    continue
                }
                
                if let targetEntries = entriesToExtract, !targetEntries.contains(name) {
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
                    if self.isPathTraversal(name, baseURL: destination) {
                        self.logWarning("Blocked path traversal attempt: \(name)")
                        offset = dataEnd
                        continue
                    }
                    
                    let filePath = self.safeExtractPath(name, to: destination)
                    
                    do {
                        try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try content.write(to: filePath)
                        extractedFiles.append(filePath)
                    } catch {
                        self.logWarning("Failed to write file: \(name)")
                    }
                }
                
                offset = dataEnd
            } else if signature == [0x50, 0x4B, 0x05, 0x06] || signature == [0x50, 0x4B, 0x06, 0x06] {
                break
            } else {
                offset += 1
            }
        }
        
        return extractedFiles
    }
    
    private func decompressDeflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        
        let bufferSize = 65536
        var decompressed = Data()
        
        let result = data.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            guard let sourceBase = sourcePtr.baseAddress else { return nil }
            
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { destinationBuffer.deallocate() }
            
            let filter = try? makeZeroPressForkFilter(for: .zlib)
            
            var stream = z_stream()
            stream.next_in = UnsafeMutablePointer<UInt8>(mutating: sourceBase.assumingMemoryBound(to: UInt8.self))
            stream.avail_in = UInt32(data.count)
            stream.next_out = destinationBuffer
            stream.avail_out = UInt32(bufferSize)
            
            guard inflateInit2_(&stream, 47, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                inflateEnd(&stream)
                return decompressFallback(data)
            }
            
            defer { inflateEnd(&stream) }
            
            while true {
                let status = inflate(&stream, Z_NO_FLUSH)
                
                if status == Z_STREAM_END || stream.avail_out == 0 {
                    let bytesDecompressed = bufferSize - Int(stream.avail_out)
                    decompressed.append(destinationBuffer, count: bytesDecompressed)
                    
                    if status == Z_STREAM_END {
                        break
                    }
                    
                    stream.next_out = destinationBuffer
                    stream.avail_out = UInt32(bufferSize)
                }
                
                if status != Z_OK {
                    break
                }
            }
            
            return decompressed
        }
        
        return result ?? decompressFallback(data)
    }
    
    private func decompressFallback(_ data: Data) -> Data? {
        return try? (data as NSData).decompressed(using: .lzfse)
    }
    
    private func extractRARArchive(at url: URL, to destination: URL, entries: [ArchiveEntry]?) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    let extractedFiles = self.extractRARManually(data: data, to: destination, entries: entries)
                    continuation.resume(returning: extractedFiles)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func extractRARManually(data: Data, to destination: URL, entries: [ArchiveEntry]?) -> [URL] {
        var extractedFiles: [URL] = []
        var offset = 0
        
        let entriesToExtract: Set<String>?
        if let entries = entries {
            entriesToExtract = Set(entries.map { $0.path })
        } else {
            entriesToExtract = nil
        }
        
        guard data.count >= 7 else { return extractedFiles }
        
        if data[5] == 0x07 {
            offset = 7
        } else {
            offset = 7
        }
        
        while offset < data.count - 7 {
            guard offset + 7 <= data.count else { break }
            
            let blockType = data[offset]
            guard offset + 4 <= data.count else { break }
            let blockLength = Int(data[offset+2]) | (Int(data[offset+3]) << 8) |
                             (Int(data[offset+4]) << 16) | (Int(data[offset+5]) << 24)
            
            if blockType == 0x74 {
                guard offset + 15 <= data.count else { break }
                
                let packSize = Int(data[offset+8]) | (Int(data[offset+9]) << 8) |
                             (Int(data[offset+10]) << 16) | (Int(data[offset+11]) << 24)
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
                
                if name.hasSuffix("/") || name.isEmpty || name.hasPrefix("SFX") {
                    offset += blockLength
                    continue
                }
                
                if let targetEntries = entriesToExtract, !targetEntries.contains(name) {
                    offset += blockLength
                    continue
                }
                
                let dataStart = nameEnd
                let dataEnd = dataStart + packSize
                
                guard dataEnd <= data.count else {
                    offset += blockLength
                    continue
                }
                
                let compressedData = data[dataStart..<dataEnd]
                if let decompressed = self.decompressRARDATA(Data(compressedData)) {
                    if self.isPathTraversal(name, baseURL: destination) {
                        self.logWarning("Blocked path traversal attempt: \(name)")
                        offset += blockLength
                        continue
                    }
                    
                    let filePath = self.safeExtractPath(name, to: destination)
                    
                    do {
                        try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try decompressed.write(to: filePath)
                        extractedFiles.append(filePath)
                    } catch {
                        self.logWarning("Failed to write file: \(name)")
                    }
                }
                
                offset += blockLength
            } else if blockType == 0x7B {
                break
            } else {
                let skipAmount = max(blockLength, 7)
                offset += skipAmount
            }
            
            if offset >= data.count { break }
        }
        
        return extractedFiles
    }
    
    private func decompressRARDATA(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        
        return try? (data as NSData).decompressed(using: .lzfse)
    }
    
    private func extract7ZArchive(at url: URL, to destination: URL, entries: [ArchiveEntry]?) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    let extractedFiles = self.extract7ZManually(data: data, to: destination, entries: entries)
                    continuation.resume(returning: extractedFiles)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func extract7ZManually(data: Data, to destination: URL, entries: [ArchiveEntry]?) -> [URL] {
        var extractedFiles: [URL] = []
        
        guard data.count >= 32 else { return extractedFiles }
        guard data.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) else { return extractedFiles }
        
        let entriesToExtract: Set<String>?
        if let entries = entries {
            entriesToExtract = Set(entries.map { $0.path })
        } else {
            entriesToExtract = nil
        }
        
        var offset = 32
        
        guard offset + 20 <= data.count else { return extractedFiles }
        
        let nextHeaderOffset = Int(data[offset]) | (Int(data[offset+1]) << 8) |
                              (Int(data[offset+2]) << 16) | (Int(data[offset+3]) << 24) |
                              (Int(data[offset+4]) << 32) | (Int(data[offset+5]) << 40) |
                              (Int(data[offset+6]) << 48) | (Int(data[offset+7]) << 56)
        
        let nextHeaderSize = Int(data[offset+12]) | (Int(data[offset+13]) << 8) |
                            (Int(data[offset+14]) << 16) | (Int(data[offset+15]) << 24)
        
        offset += Int(nextHeaderOffset)
        
        guard offset + nextHeaderSize <= data.count else { return extractedFiles }
        
        if let files = self.parse7ZFileEntries(data: data, startOffset: offset, entries: entriesToExtract) {
            for (name, fileData) in files {
                let filePath = destination.appendingPathComponent(name)
                do {
                    try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fileData.write(to: filePath)
                    extractedFiles.append(filePath)
                } catch {
                    logWarning("Failed to write 7z file: \(name)")
                }
            }
        }
        
        return extractedFiles
    }
    
    private func parse7ZFileEntries(data: Data, startOffset: Int, entries: Set<String>?) -> [(String, Data)]? {
        return nil
    }
    
    private func extractTGZArchive(at url: URL, to destination: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    
                    guard let decompressed = self.decompressGZIP(data) else {
                        continuation.resume(throwing: ArchiveError.failedToExtract("GZIP decompression failed"))
                        return
                    }
                    
                    let extractedFiles = self.extractTARManually(data: decompressed, to: destination, entries: nil)
                    continuation.resume(returning: extractedFiles)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func extractTBZ2Archive(at url: URL, to destination: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    
                    guard let decompressed = self.decompressBZIP2(data) else {
                        continuation.resume(throwing: ArchiveError.failedToExtract("BZIP2 decompression failed"))
                        return
                    }
                    
                    let extractedFiles = self.extractTARManually(data: decompressed, to: destination, entries: nil)
                    continuation.resume(returning: extractedFiles)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func extractTXZArchive(at url: URL, to destination: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    
                    guard let decompressed = self.decompressXZ(data) else {
                        continuation.resume(throwing: ArchiveError.failedToExtract("XZ decompression failed"))
                        return
                    }
                    
                    let extractedFiles = self.extractTARManually(data: decompressed, to: destination, entries: nil)
                    continuation.resume(returning: extractedFiles)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func extractTARArchive(at url: URL, to destination: URL, entries: [ArchiveEntry]?) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    let extractedFiles = self.extractTARManually(data: data, to: destination, entries: entries)
                    continuation.resume(returning: extractedFiles)
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func extractTARManually(data: Data, to destination: URL, entries: [ArchiveEntry]?) -> [URL] {
        var extractedFiles: [URL] = []
        var offset = 0
        
        let entriesToExtract: Set<String>?
        if let entries = entries {
            entriesToExtract = Set(entries.map { $0.path })
        } else {
            entriesToExtract = nil
        }
        
        while offset + 512 <= data.count {
            let header = data[offset..<offset+512]
            
            let typeFlag = header[156]
            
            if typeFlag == 0 || typeFlag == 0x30 {
                let nameData = header[0..<100]
                guard let name = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: .init(charactersIn: "\0")) else {
                    offset += 512
                    continue
                }
                
                if name.isEmpty {
                    break
                }
                
                if let targetEntries = entriesToExtract, !targetEntries.contains(name) {
                    let sizeStr = String(data: header[124..<136], encoding: .ascii)?.trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? "0"
                    let size = (Int(sizeStr, radix: 8) ?? 0)
                    offset += 512 + ((size + 511) / 512) * 512
                    continue
                }
                
                let sizeStr = String(data: header[124..<136], encoding: .ascii)?.trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? "0"
                let size = (Int(sizeStr, radix: 8) ?? 0)
                
                offset += 512
                
                if size > 0 && offset + size <= data.count {
                    let fileData = data[offset..<offset+size]
                    
                    if self.isPathTraversal(name, baseURL: destination) {
                        self.logWarning("Blocked path traversal attempt: \(name)")
                        let padding = (512 - (size % 512)) % 512
                        offset += size + padding
                        continue
                    }
                    
                    let filePath = self.safeExtractPath(name, to: destination)
                    
                    do {
                        try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try Data(fileData).write(to: filePath)
                        extractedFiles.append(filePath)
                    } catch {
                        self.logWarning("Failed to write tar file: \(name)")
                    }
                    
                    let padding = (512 - (size % 512)) % 512
                    offset += size + padding
                } else {
                    break
                }
            } else {
                let sizeStr = String(data: header[124..<136], encoding: .ascii)?.trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? "0"
                let size = (Int(sizeStr, radix: 8) ?? 0)
                offset += 512 + ((size + 511) / 512) * 512
            }
            
            if offset > data.count { break }
        }
        
        return extractedFiles
    }
    
    private func extractGZIPArchive(at url: URL, to destination: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    
                    guard let decompressed = self.decompressGZIP(data) else {
                        continuation.resume(throwing: ArchiveError.failedToExtract("GZIP decompression failed"))
                        return
                    }
                    
                    let originalName = url.deletingPathExtension().lastPathComponent
                    
                    if self.isPathTraversal(originalName, baseURL: destination) {
                        self.logWarning("Blocked path traversal attempt: \(originalName)")
                        let safeName = UUID().uuidString + "_decompressed"
                        let filePath = destination.appendingPathComponent(safeName)
                        try decompressed.write(to: filePath)
                        continuation.resume(returning: [filePath])
                        return
                    }
                    
                    let filePath = self.safeExtractPath(originalName, to: destination)
                    try decompressed.write(to: filePath)
                    continuation.resume(returning: [filePath])
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func decompressGZIP(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        
        return try? (data as NSData).decompressed(using: .zlib)
    }
    
    private func extractBZIP2Archive(at url: URL, to destination: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    
                    guard let decompressed = self.decompressBZIP2(data) else {
                        continuation.resume(throwing: ArchiveError.failedToExtract("BZIP2 decompression failed"))
                        return
                    }
                    
                    let originalName = url.deletingPathExtension().lastPathComponent
                    let filePath = destination.appendingPathComponent(originalName)
                    
                    try decompressed.write(to: filePath)
                    continuation.resume(returning: [filePath])
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func decompressBZIP2(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        
        return try? (data as NSData).decompressed(using: .bzip2)
    }
    
    private func extractXZArchive(at url: URL, to destination: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    
                    let data = try Data(contentsOf: url)
                    
                    guard let decompressed = self.decompressXZ(data) else {
                        continuation.resume(throwing: ArchiveError.failedToExtract("XZ decompression failed"))
                        return
                    }
                    
                    let originalName = url.deletingPathExtension().lastPathComponent
                    let filePath = destination.appendingPathComponent(originalName)
                    
                    try decompressed.write(to: filePath)
                    continuation.resume(returning: [filePath])
                } catch {
                    continuation.resume(throwing: ArchiveError.failedToExtract(error.localizedDescription))
                }
            }
        }
    }
    
    private func decompressXZ(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        
        return try? (data as NSData).decompressed(using: .lzfse)
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
    case extractionCancelled
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支持的压缩格式"
        case .invalidArchive: return "无效的压缩文件"
        case .failedToAnalyze(let msg): return "分析失败: \(msg)"
        case .failedToExtract(let msg): return "解压失败: \(msg)"
        case .extractionCancelled: return "解压已取消"
        }
    }
}
