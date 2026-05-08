import Foundation
import Combine
import ZipArchive
import PDFKit

class ComicParserManager: BaseService, ObservableObject {
    static let shared = ComicParserManager()
    
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0
    @Published var currentComic: ComicBook?
    @Published var currentPage: Int = 0
    @Published var pageCount: Int = 0
    
    private var extractedImages: [UIImage] = []
    private var extractedPath: URL?
    
    struct ComicBook: Identifiable, Codable {
        let id: String
        let title: String
        let author: String?
        let pageCount: Int
        let format: ComicFormat
        let sourcePath: String
        let coverImage: Data?
        let extractedPath: String?
        let createdAt: Date
        var lastReadPage: Int
        var lastReadTime: Date?
        
        enum ComicFormat: String, Codable {
            case cbz = "cbz"
            case cbr = "cbr"
            case cb7 = "cb7"
            case pdf = "pdf"
            case folder = "folder"
            case tar = "tar"
            case tarGz = "tar.gz"
            case tarBz2 = "tar.bz2"
            case tarXz = "tar.xz"
            case xz = "xz"
            
            var displayName: String {
                switch self {
                case .cbz: return "CBZ (ZIP)"
                case .cbr: return "CBR (RAR)"
                case .cb7: return "CB7 (7z)"
                case .pdf: return "PDF"
                case .folder: return "文件夹"
                case .tar: return "TAR"
                case .tarGz: return "TAR.GZ"
                case .tarBz2: return "TAR.BZ2"
                case .tarXz: return "TAR.XZ"
                case .xz: return "XZ"
                }
            }
            
            var icon: String {
                switch self {
                case .cbz: return "doc.zipper"
                case .cbr: return "doc.fill"
                case .cb7: return "7.square"
                case .pdf: return "doc.richtext"
                case .folder: return "folder.fill"
                case .tar: return "doc.badge.gearshape"
                case .tarGz, .tarBz2, .tarXz: return "archivebox"
                case .xz: return "archivebox"
                }
            }
            
            var isSupported: Bool {
                return true
            }
        }
    }
    
    struct ComicPage: Identifiable {
        let id: Int
        let image: UIImage?
        let pageNumber: Int
        var isLoaded: Bool = false
    }
    
    private override init() {
        super.init()
    }
    
    func parseComic(at url: URL) async throws -> ComicBook {
        await MainActor.run {
            isLoading = true
            loadingProgress = 0
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let format = detectFormat(url: url)
        
        switch format {
        case .cbz:
            return try await parseCBZ(at: url)
        case .cbr:
            return try await parseCBR(at: url)
        case .cb7:
            return try await parse7Z(at: url)
        case .pdf:
            return try await parsePDF(at: url)
        case .folder:
            return try await parseFolder(at: url)
        case .tar:
            return try await parseTAR(at: url)
        case .tarGz:
            return try await parseTAR(at: url)
        case .tarBz2:
            return try await parseTAR(at: url)
        case .tarXz:
            return try await parseTAR(at: url)
        case .xz:
            return try await parseXZ(at: url)
        }
    }
    
    private func detectFormat(url: URL) -> ComicBook.ComicFormat {
        let filename = url.lastPathComponent.lowercased()
        
        if filename.hasSuffix(".tar.gz") || filename.hasSuffix(".tgz") {
            return .tarGz
        } else if filename.hasSuffix(".tar.bz2") || filename.hasSuffix(".tbz2") {
            return .tarBz2
        } else if filename.hasSuffix(".tar.xz") {
            return .tarXz
        } else if filename.hasSuffix(".xz") {
            return .xz
        } else if filename.hasSuffix(".tar") {
            return .tar
        } else if filename.hasSuffix(".cbz") || filename.hasSuffix(".zip") {
            return .cbz
        } else if filename.hasSuffix(".cbr") || filename.hasSuffix(".rar") {
            return .cbr
        } else if filename.hasSuffix(".cb7") || filename.hasSuffix(".7z") {
            return .cb7
        } else if filename.hasSuffix(".pdf") {
            return .pdf
        } else {
            return .folder
        }
    }
    
    private func parseCBZ(at url: URL) async throws -> ComicBook {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        SSZipArchive.unzipFile(atPath: url.path, toDestination: tempDir.path)
        
        let images = extractImages(from: tempDir)
        let coverData = images.first?.jpegData(compressionQuality: 0.8)
        
        let comic = ComicBook(
            id: UUID().uuidString,
            title: url.deletingPathExtension().lastPathComponent,
            author: nil,
            pageCount: images.count,
            format: .cbz,
            sourcePath: url.path,
            coverImage: coverData,
            extractedPath: tempDir.path,
            createdAt: Date(),
            lastReadPage: 0,
            lastReadTime: nil
        )
        
        extractedImages = images
        extractedPath = tempDir
        pageCount = images.count
        
        await MainActor.run {
            currentComic = comic
        }
        
        return comic
    }
    
    private func parseCBR(at url: URL) async throws -> ComicBook {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unrar")
        process.arguments = ["x", "-o+", url.path, tempDir.path]
        try process.run()
        process.waitUntilExit()
        
        let images = extractImages(from: tempDir)
        let coverData = images.first?.jpegData(compressionQuality: 0.8)
        
        let comic = ComicBook(
            id: UUID().uuidString,
            title: url.deletingPathExtension().lastPathComponent,
            author: nil,
            pageCount: images.count,
            format: .cbr,
            sourcePath: url.path,
            coverImage: coverData,
            extractedPath: tempDir.path,
            createdAt: Date(),
            lastReadPage: 0,
            lastReadTime: nil
        )
        
        extractedImages = images
        extractedPath = tempDir
        pageCount = images.count
        
        await MainActor.run {
            currentComic = comic
        }
        
        return comic
    }
    
    private func parse7Z(at url: URL) async throws -> ComicBook {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        do {
            let extractedFiles = try await ArchiveManager.shared.extractArchive(at: url, to: tempDir)
            
            let images = extractImages(from: tempDir)
            let coverData = images.first?.jpegData(compressionQuality: 0.8)
            
            let comic = ComicBook(
                id: UUID().uuidString,
                title: url.deletingPathExtension().lastPathComponent,
                author: nil,
                pageCount: images.count,
                format: .cb7,
                sourcePath: url.path,
                coverImage: coverData,
                extractedPath: tempDir.path,
                createdAt: Date(),
                lastReadPage: 0,
                lastReadTime: nil
            )
            
            extractedImages = images
            extractedPath = tempDir
            pageCount = images.count
            
            await MainActor.run {
                currentComic = comic
            }
            
            return comic
        } catch {
            try? fileManager.removeItem(at: tempDir)
            let images = extractImagesFromArchive(at: url) ?? []
            
            if images.isEmpty {
                throw ComicError.extractionFailed
            }
            
            let coverData = images.first?.jpegData(compressionQuality: 0.8)
            
            let comic = ComicBook(
                id: UUID().uuidString,
                title: url.deletingPathExtension().lastPathComponent,
                author: nil,
                pageCount: images.count,
                format: .cb7,
                sourcePath: url.path,
                coverImage: coverData,
                extractedPath: nil,
                createdAt: Date(),
                lastReadPage: 0,
                lastReadTime: nil
            )
            
            extractedImages = images
            pageCount = images.count
            
            await MainActor.run {
                currentComic = comic
            }
            
            return comic
        }
    }
    
    private func parseTAR(at url: URL) async throws -> ComicBook {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        do {
            let extractedFiles = try await ArchiveManager.shared.extractArchive(at: url, to: tempDir)
            
            let images = extractImages(from: tempDir)
            let coverData = images.first?.jpegData(compressionQuality: 0.8)
            
            let format = detectTARFormat(from: url)
            
            let comic = ComicBook(
                id: UUID().uuidString,
                title: url.deletingPathExtension().lastPathComponent,
                author: nil,
                pageCount: images.count,
                format: format,
                sourcePath: url.path,
                coverImage: coverData,
                extractedPath: tempDir.path,
                createdAt: Date(),
                lastReadPage: 0,
                lastReadTime: nil
            )
            
            extractedImages = images
            extractedPath = tempDir
            pageCount = images.count
            
            await MainActor.run {
                currentComic = comic
            }
            
            return comic
        } catch {
            try? fileManager.removeItem(at: tempDir)
            throw ComicError.extractionFailed
        }
    }
    
    private func parseXZ(at url: URL) async throws -> ComicBook {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        do {
            let extractedFiles = try await ArchiveManager.shared.extractArchive(at: url, to: tempDir)
            
            if let firstFile = extractedFiles.first {
                if extractedImages(from: firstFile).count > 0 {
                    extractedImages = extractedImages(from: firstFile)
                } else {
                    extractedImages = extractImages(from: firstFile.deletingLastPathComponent())
                }
            }
            
            if extractedImages.isEmpty {
                extractedImages = extractImages(from: tempDir)
            }
            
            let coverData = extractedImages.first?.jpegData(compressionQuality: 0.8)
            
            let comic = ComicBook(
                id: UUID().uuidString,
                title: url.deletingPathExtension().lastPathComponent,
                author: nil,
                pageCount: extractedImages.count,
                format: .xz,
                sourcePath: url.path,
                coverImage: coverData,
                extractedPath: tempDir.path,
                createdAt: Date(),
                lastReadPage: 0,
                lastReadTime: nil
            )
            
            pageCount = extractedImages.count
            
            await MainActor.run {
                currentComic = comic
            }
            
            return comic
        } catch {
            try? fileManager.removeItem(at: tempDir)
            throw ComicError.extractionFailed
        }
    }
    
    private func detectTARFormat(from url: URL) -> ComicBook.ComicFormat {
        let filename = url.lastPathComponent.lowercased()
        if filename.hasSuffix(".tar.gz") || filename.hasSuffix(".tgz") {
            return .tarGz
        } else if filename.hasSuffix(".tar.bz2") || filename.hasSuffix(".tbz2") {
            return .tarBz2
        } else if filename.hasSuffix(".tar.xz") {
            return .tarXz
        }
        return .tar
    }
    
    private func extractedImages(from url: URL) -> [UIImage] {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return []
        }
        return [image]
    }
    
    private func parsePDF(at url: URL) async throws -> ComicBook {
        guard let document = PDFDocument(url: url) else {
            throw ComicError.invalidFormat
        }
        
        var images: [UIImage] = []
        let pageCount = document.pageCount
        
        for i in 0..<pageCount {
            await MainActor.run {
                loadingProgress = Double(i) / Double(pageCount)
            }
            
            if let page = document.page(at: i) {
                let pageRect = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                let image = renderer.image { ctx in
                    UIColor.white.set()
                    ctx.fill(pageRect)
                    ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
                    ctx.cgContext.scaleBy(x: 1, y: -1)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                images.append(image)
            }
        }
        
        let coverData = images.first?.jpegData(compressionQuality: 0.8)
        
        let comic = ComicBook(
            id: UUID().uuidString,
            title: url.deletingPathExtension().lastPathComponent,
            author: nil,
            pageCount: images.count,
            format: .pdf,
            sourcePath: url.path,
            coverImage: coverData,
            extractedPath: nil,
            createdAt: Date(),
            lastReadPage: 0,
            lastReadTime: nil
        )
        
        self.extractedImages = images
        self.pageCount = images.count
        
        await MainActor.run {
            currentComic = comic
        }
        
        return comic
    }
    
    private func parseFolder(at url: URL) async throws -> ComicBook {
        let images = extractImages(from: url)
        let coverData = images.first?.jpegData(compressionQuality: 0.8)
        
        let comic = ComicBook(
            id: UUID().uuidString,
            title: url.lastPathComponent,
            author: nil,
            pageCount: images.count,
            format: .folder,
            sourcePath: url.path,
            coverImage: coverData,
            extractedPath: url.path,
            createdAt: Date(),
            lastReadPage: 0,
            lastReadTime: nil
        )
        
        extractedImages = images
        extractedPath = url
        self.pageCount = images.count
        
        await MainActor.run {
            currentComic = comic
        }
        
        return comic
    }
    
    private func extractImages(from directory: URL) -> [UIImage] {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        var imageFiles: [URL] = []
        
        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(ext) {
                imageFiles.append(fileURL)
            }
        }
        
        imageFiles.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        
        return imageFiles.compactMap { UIImage(contentsOfFile: $0.path) }
    }
    
    private func extractImagesFromArchive(at url: URL) -> [UIImage]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) {
            return extractImagesFromZIP(data: data)
        } else if data.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) {
            return extractImagesFrom7Z(data: data)
        } else if data.starts(with: [0x1F, 0x8B]) {
            if let decompressed = try? (data as NSData).decompressed(using: .zlib) {
                return extractImagesFromTAR(data: decompressed)
            }
        } else if data.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) {
            if let decompressed = try? (data as NSData).decompressed(using: .lzfse) {
                return extractImagesFromTAR(data: decompressed)
            }
        } else if data.starts(with: [0x42, 0x5A, 0x68]) {
            if let decompressed = try? (data as NSData).decompressed(using: .bzip2) {
                return extractImagesFromTAR(data: decompressed)
            }
        }
        
        return nil
    }
    
    private func extractImagesFromZIP(data: Data) -> [UIImage]? {
        var images: [UIImage] = []
        var imageDataArray: [(Int, Data)] = []
        var offset = 0
        
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
                
                let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
                
                if imageExtensions.contains(ext) && !name.hasSuffix("/") {
                    let dataStart = nameEnd + extraLength
                    let dataEnd = dataStart + compressedSize
                    
                    guard dataEnd <= data.count else { break }
                    
                    let compressedData = data[dataStart..<dataEnd]
                    
                    var decompressedData: Data?
                    if compressionMethod == 0 {
                        decompressedData = Data(compressedData)
                    } else if compressionMethod == 8 {
                        decompressedData = decompressDeflate(Data(compressedData))
                    }
                    
                    if let content = decompressedData {
                        imageDataArray.append((imageDataArray.count, content))
                    }
                }
                
                offset = dataEnd
            } else if signature == [0x50, 0x4B, 0x05, 0x06] || signature == [0x50, 0x4B, 0x06, 0x06] {
                break
            } else {
                offset += 1
            }
        }
        
        imageDataArray.sort { $0.0 < $1.0 }
        images = imageDataArray.compactMap { UIImage(data: $0.1) }
        
        return images.isEmpty ? nil : images
    }
    
    private func extractImagesFrom7Z(data: Data) -> [UIImage]? {
        return nil
    }
    
    private func extractImagesFromTAR(data: Data) -> [UIImage]? {
        var images: [UIImage] = []
        var imageDataArray: [(Int, Data)] = []
        var offset = 0
        
        while offset + 512 <= data.count {
            let header = data[offset..<offset+512]
            
            let typeFlag = header[156]
            
            if typeFlag == 0 || typeFlag == 0x30 {
                let nameData = header[0..<100]
                guard let name = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: .init(charactersIn: "\0")) else {
                    offset += 512
                    continue
                }
                
                if name.isEmpty { break }
                
                let sizeStr = String(data: header[124..<136], encoding: .ascii)?.trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? "0"
                let size = (Int(sizeStr, radix: 8) ?? 0)
                
                let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
                
                if imageExtensions.contains(ext) && size > 0 {
                    offset += 512
                    
                    if offset + size <= data.count {
                        let fileData = data[offset..<offset+size]
                        imageDataArray.append((imageDataArray.count, Data(fileData)))
                    }
                    
                    let padding = (512 - (size % 512)) % 512
                    offset += size + padding
                } else {
                    offset += 512 + ((size + 511) / 512) * 512
                }
            } else {
                let sizeStr = String(data: header[124..<136], encoding: .ascii)?.trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? "0"
                let size = (Int(sizeStr, radix: 8) ?? 0)
                offset += 512 + ((size + 511) / 512) * 512
            }
            
            if offset > data.count { break }
        }
        
        imageDataArray.sort { $0.0 < $1.0 }
        images = imageDataArray.compactMap { UIImage(data: $0.1) }
        
        return images.isEmpty ? nil : images
    }
    
    private func decompressDeflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        
        return try? (data as NSData).decompressed(using: .lzfse)
    }
    
    func getPage(at index: Int) -> UIImage? {
        guard index >= 0 && index < extractedImages.count else { return nil }
        return extractedImages[index]
    }
    
    func nextPage() {
        if currentPage < pageCount - 1 {
            currentPage += 1
            updateReadingProgress()
        }
    }
    
    func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
            updateReadingProgress()
        }
    }
    
    func goToPage(_ page: Int) {
        guard page >= 0 && page < pageCount else { return }
        currentPage = page
        updateReadingProgress()
    }
    
    private func updateReadingProgress() {
        guard var comic = currentComic else { return }
        comic.lastReadPage = currentPage
        comic.lastReadTime = Date()
        currentComic = comic
    }
    
    func closeComic() {
        if let path = extractedPath {
            try? fileManager.removeItem(at: path)
        }
        extractedImages.removeAll()
        currentComic = nil
        currentPage = 0
        pageCount = 0
        extractedPath = nil
    }
    
    enum ComicError: Error {
        case invalidFormat
        case extractionFailed
        case noImagesFound
        case fileNotFound
    }
}

class ComicReadingSettings: BaseService, ObservableObject {
    static let shared = ComicReadingSettings()
    
    @Published var readingMode: ReadingMode = .rightToLeft
    @Published var showPageNumber: Bool = true
    @Published var showPageSlider: Bool = true
    @Published var backgroundColor: ComicBackgroundColor = .black
    @Published var tapZoneEnabled: Bool = true
    @Published var doubleTapToZoom: Bool = true
    @Published var pinchToZoom: Bool = true
    @Published var magnifierEnabled: Bool = true
    @Published var magnifierSize: MagnifierSize = .medium
    @Published var keepScreenOn: Bool = true
    @Published var autoPlaySpeed: Double = 5.0
    
    enum ReadingMode: String, CaseIterable, Codable {
        case rightToLeft = "rightToLeft"
        case leftToRight = "leftToRight"
        case vertical = "vertical"
        case webtoon = "webtoon"
        case automatic = "automatic"
        
        var displayName: String {
            switch self {
            case .rightToLeft: return "从右到左"
            case .leftToRight: return "从左到右"
            case .vertical: return "垂直滚动"
            case .webtoon: return "条漫模式"
            case .automatic: return "自动切换"
            }
        }
        
        var icon: String {
            switch self {
            case .rightToLeft: return "arrow.left.and.right"
            case .leftToRight: return "arrow.right.and.arrow.left"
            case .vertical: return "arrow.up.arrow.down"
            case .webtoon: return "rectangle.stack"
            case .automatic: return "wand.and.stars"
            }
        }
    }
    
    enum ComicBackgroundColor: String, CaseIterable, Codable {
        case black = "black"
        case white = "white"
        case sepia = "sepia"
        
        var displayName: String {
            switch self {
            case .black: return "黑色"
            case .white: return "白色"
            case .sepia: return "护眼色"
            }
        }
        
        var color: UIColor {
            switch self {
            case .black: return .black
            case .white: return .white
            case .sepia: return UIColor(red: 0.96, green: 0.93, blue: 0.87, alpha: 1.0)
            }
        }
    }
    
    enum MagnifierSize: String, CaseIterable, Codable {
        case small = "small"
        case medium = "medium"
        case large = "large"
        
        var displayName: String {
            switch self {
            case .small: return "小"
            case .medium: return "中"
            case .large: return "大"
            }
        }
        
        var radius: CGFloat {
            switch self {
            case .small: return 60
            case .medium: return 80
            case .large: return 100
            }
        }
    }
    
    private let settingsKey = "ComicReadingSettings"
    
    private override init() {
        super.init()
        loadSettings()
    }
    
    private func loadSettings() {
        if let saved = loadCodable(SettingsData.self, key: settingsKey) {
            readingMode = saved.readingMode
            showPageNumber = saved.showPageNumber
            showPageSlider = saved.showPageSlider
            backgroundColor = saved.backgroundColor
            tapZoneEnabled = saved.tapZoneEnabled
            doubleTapToZoom = saved.doubleTapToZoom
            pinchToZoom = saved.pinchToZoom
            magnifierEnabled = saved.magnifierEnabled
            magnifierSize = saved.magnifierSize
            keepScreenOn = saved.keepScreenOn
        }
    }
    
    func saveSettings() {
        let data = SettingsData(
            readingMode: readingMode,
            showPageNumber: showPageNumber,
            showPageSlider: showPageSlider,
            backgroundColor: backgroundColor,
            tapZoneEnabled: tapZoneEnabled,
            doubleTapToZoom: doubleTapToZoom,
            pinchToZoom: pinchToZoom,
            magnifierEnabled: magnifierEnabled,
            magnifierSize: magnifierSize,
            keepScreenOn: keepScreenOn
        )
        saveCodable(data, key: settingsKey)
    }
    
    struct SettingsData: Codable {
        var readingMode: ReadingMode
        var showPageNumber: Bool
        var showPageSlider: Bool
        var backgroundColor: ComicBackgroundColor
        var tapZoneEnabled: Bool
        var doubleTapToZoom: Bool
        var pinchToZoom: Bool
        var magnifierEnabled: Bool
        var magnifierSize: MagnifierSize
        var keepScreenOn: Bool
    }
}
