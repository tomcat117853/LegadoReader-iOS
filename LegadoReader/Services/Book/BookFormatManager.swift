import Foundation

class BookFormatManager: ObservableObject {
    static let shared = BookFormatManager()
    
    @Published var supportedFormats: [BookFormat] = []
    @Published var detectedFormat: BookFormat?
    @Published var isConverting = false
    @Published var conversionProgress: Double = 0
    
    struct BookFormat: Identifiable, Codable {
        let id: String
        let name: String
        let extensions: [String]
        let mimeType: String
        let description: String
        let supportsMetadata: Bool
        let supportsImages: Bool
        let isBinary: Bool
        
        var displayName: String {
            return "\(name) (\(extensions.map { ".\($0)" }.joined(", ")))"
        }
        
        func matchesExtension(_ filename: String) -> Bool {
            let ext = filename.lowercased().pathExtension
            return extensions.contains(ext)
        }
    }
    
    private init() {
        registerFormats()
    }
    
    private func registerFormats() {
        supportedFormats = [
            BookFormat(
                id: "epub",
                name: "EPUB",
                extensions: ["epub"],
                mimeType: "application/epub+zip",
                description: "标准电子书格式，支持丰富格式和多媒体",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: true
            ),
            BookFormat(
                id: "pdf",
                name: "PDF",
                extensions: ["pdf"],
                mimeType: "application/pdf",
                description: "便携式文档格式，保留原始排版",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: true
            ),
            BookFormat(
                id: "mobi",
                name: "MOBI",
                extensions: ["mobi"],
                mimeType: "application/x-mobipocket-ebook",
                description: "Kindle原生格式，支持DRM",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: true
            ),
            BookFormat(
                id: "azw",
                name: "AZW",
                extensions: ["azw", "azw3", "azw4"],
                mimeType: "application/vnd.amazon.mobi8-ebook",
                description: "Amazon Kindle专有格式",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: true
            ),
            BookFormat(
                id: "fb2",
                name: "FictionBook",
                extensions: ["fb2", "fb2.zip"],
                mimeType: "application/x-fictionbook+xml",
                description: "俄罗斯流行的XML格式电子书",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: false
            ),
            BookFormat(
                id: "txt",
                name: "纯文本",
                extensions: ["txt"],
                mimeType: "text/plain",
                description: "纯文本文件，编码自动检测",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: false
            ),
            BookFormat(
                id: "chm",
                name: "CHM",
                extensions: ["chm"],
                mimeType: "application/vnd.ms-htmlhelp",
                description: "Microsoft帮助文档格式",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: true
            ),
            BookFormat(
                id: "rtf",
                name: "RTF",
                extensions: ["rtf"],
                mimeType: "application/rtf",
                description: "富文本格式，保留基本格式",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: false
            ),
            BookFormat(
                id: "html",
                name: "HTML",
                extensions: ["html", "htm", "xhtml"],
                mimeType: "text/html",
                description: "网页格式，支持复杂排版",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: false
            ),
            BookFormat(
                id: "docx",
                name: "Word文档",
                extensions: ["docx"],
                mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                description: "Microsoft Word 2007+ 文档格式",
                supportsMetadata: true,
                supportsImages: true,
                isBinary: true
            ),
            BookFormat(
                id: "zip",
                name: "ZIP压缩",
                extensions: ["zip"],
                mimeType: "application/zip",
                description: "压缩包格式，可包含多种文件",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: true
            ),
            BookFormat(
                id: "rar",
                name: "RAR压缩",
                extensions: ["rar"],
                mimeType: "application/vnd.rar",
                description: "RAR压缩格式",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: true
            ),
            BookFormat(
                id: "cbz",
                name: "CBZ漫画",
                extensions: ["cbz"],
                mimeType: "application/x-cbz",
                description: "漫画压缩包格式",
                supportsMetadata: false,
                supportsImages: true,
                isBinary: true
            ),
            BookFormat(
                id: "7z",
                name: "7Z压缩",
                extensions: ["7z"],
                mimeType: "application/x-7z-compressed",
                description: "7-Zip高压缩比格式",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: true
            ),
            BookFormat(
                id: "tar",
                name: "TAR归档",
                extensions: ["tar"],
                mimeType: "application/x-tar",
                description: "Unix磁带归档格式",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: true
            ),
            BookFormat(
                id: "targz",
                name: "TAR.GZ压缩",
                extensions: ["tar.gz", "tgz"],
                mimeType: "application/gzip",
                description: "Gzip压缩的TAR归档",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: true
            ),
            BookFormat(
                id: "tarbz2",
                name: "TAR.BZ2压缩",
                extensions: ["tar.bz2", "tbz2"],
                mimeType: "application/x-bzip2",
                description: "Bzip2压缩的TAR归档",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: true
            ),
            BookFormat(
                id: "tarxz",
                name: "TAR.XZ压缩",
                extensions: ["tar.xz"],
                mimeType: "application/x-xz",
                description: "XZ压缩的TAR归档",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: true
            ),
            BookFormat(
                id: "xz",
                name: "XZ压缩",
                extensions: ["xz"],
                mimeType: "application/x-xz",
                description: "XZ压缩格式",
                supportsMetadata: false,
                supportsImages: false,
                isBinary: true
            )
        ]
    }
    
    func detectFormat(_ filename: String) -> BookFormat? {
        let lowerFilename = filename.lowercased()
        
        if lowerFilename.hasSuffix(".tar.gz") || lowerFilename.hasSuffix(".tgz") {
            return supportedFormats.first { $0.id == "targz" }
        } else if lowerFilename.hasSuffix(".tar.bz2") || lowerFilename.hasSuffix(".tbz2") {
            return supportedFormats.first { $0.id == "tarbz2" }
        } else if lowerFilename.hasSuffix(".tar.xz") {
            return supportedFormats.first { $0.id == "tarxz" }
        } else if lowerFilename.hasSuffix(".tar") {
            return supportedFormats.first { $0.id == "tar" }
        } else if lowerFilename.hasSuffix(".7z") {
            return supportedFormats.first { $0.id == "7z" }
        } else if lowerFilename.hasSuffix(".xz") {
            return supportedFormats.first { $0.id == "xz" }
        }
        
        for format in supportedFormats {
            if format.matchesExtension(lowerFilename) {
                detectedFormat = format
                return format
            }
        }
        
        return nil
    }
    
    func detectFormat(from data: Data) -> BookFormat? {
        if data.hasPDFHeader {
            return supportedFormats.first { $0.id == "pdf" }
        }
        
        if data.hasEPUBHeader {
            return supportedFormats.first { $0.id == "epub" }
        }
        
        if data.hasMOBIHeader {
            return supportedFormats.first { $0.id == "mobi" }
        }
        
        if data.hasAZWHeader {
            return supportedFormats.first { $0.id == "azw" }
        }
        
        if data.hasFB2Header {
            return supportedFormats.first { $0.id == "fb2" }
        }
        
        if data.hasCHMHeader {
            return supportedFormats.first { $0.id == "chm" }
        }
        
        if data.hasZIPHeader {
            return supportedFormats.first { $0.id == "zip" }
        }
        
        if data.has7ZHeader {
            return supportedFormats.first { $0.id == "7z" }
        }
        
        if data.hasXZHeader {
            return supportedFormats.first { $0.id == "xz" }
        }
        
        if data.hasBZIP2Header {
            return supportedFormats.first { $0.id == "tarbz2" }
        }
        
        if data.hasGZIPHeader {
            return supportedFormats.first { $0.id == "targz" }
        }
        
        if data.hasTARHeader {
            return supportedFormats.first { $0.id == "tar" }
        }
        
        if data.isPlainText {
            return supportedFormats.first { $0.id == "txt" }
        }
        
        return nil
    }
    
    func canRead(_ filename: String) -> Bool {
        return detectFormat(filename) != nil
    }
    
    func canRead(_ data: Data) -> Bool {
        return detectFormat(from: data) != nil
    }
    
    func getReader(for format: BookFormat) -> BookReaderProtocol? {
        switch format.id {
        case "epub":
            return EPUBReader()
        case "pdf":
            return PDFReader()
        case "mobi", "azw":
            return MOBIReader()
        case "fb2":
            return FB2Reader()
        case "txt":
            return TXTReader()
        case "chm":
            return CHMReader()
        case "rtf":
            return RTFReader()
        case "html":
            return HTMLReader()
        case "docx":
            return DOCXReader()
        case "7z", "tar", "targz", "tarbz2", "tarxz", "xz":
            return BookArchiveReader()
        default:
            return nil
        }
    }
    
    func convert(_ data: Data, from sourceFormat: BookFormat, to targetFormat: BookFormat) async throws -> Data {
        let reader = getReader(for: sourceFormat)
        let content = try await reader?.read(data: data) ?? BookContent()
        
        let converter = BookConverter()
        return try await converter.convert(content, to: targetFormat)
    }
    
    func extractCover(data: Data, format: BookFormat) -> Data? {
        let reader = getReader(for: format)
        return reader?.extractCover(data: data)
    }
    
    func getMetadata(data: Data, format: BookFormat) -> BookMetadata {
        let reader = getReader(for: format)
        return reader?.getMetadata(data: data) ?? BookMetadata()
    }
    
    func listSupportedFormats() -> [BookFormat] {
        return supportedFormats
    }
    
    func getConvertibleFormats(from format: BookFormat) -> [BookFormat] {
        let convertible: [String]
        switch format.id {
        case "txt", "html", "rtf", "fb2":
            convertible = ["epub", "txt", "html"]
        case "epub":
            convertible = ["epub", "txt", "html"]
        case "mobi", "azw":
            convertible = ["epub", "txt"]
        case "pdf":
            convertible = ["txt"]
        case "chm":
            convertible = ["html", "txt"]
        default:
            convertible = []
        }
        return supportedFormats.filter { convertible.contains($0.id) }
    }
}

protocol BookReaderProtocol {
    func read(data: Data) async throws -> BookContent
    func extractCover(data: Data) -> Data?
    func getMetadata(data: Data) -> BookMetadata
    func getTableOfContents(data: Data) -> [BookChapter]
}

struct BookContent {
    var title: String = ""
    var author: String = ""
    var chapters: [BookChapter] = []
    var cover: Data?
    var metadata: BookMetadata = BookMetadata()
    var rawContent: String = ""
}

struct BookChapter {
    let id: String
    let title: String
    let content: String
    let level: Int
    let startOffset: Int
    
    init(title: String, content: String, level: Int = 1, startOffset: Int = 0) {
        self.id = UUID().uuidString
        self.title = title
        self.content = content
        self.level = level
        self.startOffset = startOffset
    }
}

struct BookMetadata {
    var title: String = ""
    var author: String = ""
    var publisher: String = ""
    var publicationDate: Date?
    var isbn: String = ""
    var description: String = ""
    var language: String = ""
    var tags: [String] = []
    var series: String = ""
    var seriesIndex: Int = 0
}

class BookConverter {
    func convert(_ content: BookContent, to format: BookFormatManager.BookFormat) async throws -> Data {
        switch format.id {
        case "epub":
            return try await convertToEPUB(content)
        case "txt":
            return try convertToTXT(content)
        case "html":
            return try convertToHTML(content)
        default:
            throw ConversionError.unsupportedFormat
        }
    }
    
    private func convertToEPUB(_ content: BookContent) async throws -> Data {
        let epub = EPUBGenerator()
        return try epub.generate(content)
    }
    
    private func convertToTXT(_ content: BookContent) throws -> Data {
        var text = ""
        
        if !content.title.isEmpty {
            text += content.title + "\n\n"
        }
        
        if !content.author.isEmpty {
            text += "作者: \(content.author)\n\n"
        }
        
        for chapter in content.chapters {
            text += chapter.title + "\n"
            text += "=" * chapter.title.count + "\n\n"
            text += chapter.content + "\n\n"
        }
        
        return text.data(using: .utf8) ?? Data()
    }
    
    private func convertToHTML(_ content: BookContent) throws -> Data {
        var html = """
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
            <meta charset="UTF-8" />
            <title>\(content.title)</title>
            <style>
                body { font-family: serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
                h1 { text-align: center; color: #333; }
                h2 { color: #444; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
                h3 { color: #555; }
                p { margin: 1em 0; }
            </style>
        </head>
        <body>
        """
        
        html += "<h1>\(content.title)</h1>\n"
        
        if !content.author.isEmpty {
            html += "<p style='text-align:center; color:#666;'>作者: \(content.author)</p>\n"
        }
        
        for chapter in content.chapters {
            let tag = chapter.level == 1 ? "h2" : chapter.level == 2 ? "h3" : "h4"
            html += "<\(tag)>\(chapter.title)</\(tag)>\n"
            html += "<div>\(formatTextToHTML(chapter.content))</div>\n"
        }
        
        html += "</body></html>"
        
        return html.data(using: .utf8) ?? Data()
    }
    
    private func formatTextToHTML(_ text: String) -> String {
        var html = text
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = html.replacingOccurrences(of: "\n", with: "<br/>")
        return "<p>" + html + "</p>"
    }
}

enum ConversionError: Error, LocalizedError {
    case unsupportedFormat
    case conversionFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支持的格式转换"
        case .conversionFailed: return "转换失败"
        case .invalidData: return "无效的数据"
        }
    }
}

extension Data {
    var hasPDFHeader: Bool {
        return starts(with: "%PDF-".data(using: .ascii)!)
    }
    
    var hasEPUBHeader: Bool {
        if count < 4 { return false }
        let signature = [UInt8](prefix(4))
        return signature == [0x50, 0x4B, 0x03, 0x04]
    }
    
    var hasMOBIHeader: Bool {
        if count < 4 { return false }
        let signature = [UInt8](prefix(4))
        return signature == [0x4D, 0x4F, 0x42, 0x49] || 
               signature == [0x52, 0x49, 0x46, 0x46]
    }
    
    var hasAZWHeader: Bool {
        if count < 8 { return false }
        let signature = [UInt8](prefix(8))
        return signature.starts(with: [0x50, 0x4B, 0x03, 0x04])
    }
    
    var hasFB2Header: Bool {
        if count < 50 { return false }
        if let string = String(data: prefix(50), encoding: .utf8) {
            return string.contains("<FictionBook") || string.contains("<?xml")
        }
        return false
    }
    
    var hasCHMHeader: Bool {
        if count < 8 { return false }
        let signature = [UInt8](prefix(8))
        return signature == [0x49, 0x54, 0x53, 0x46, 0x03, 0x00, 0x00, 0x00]
    }
    
    var hasZIPHeader: Bool {
        if count < 4 { return false }
        let signature = [UInt8](prefix(4))
        return signature == [0x50, 0x4B, 0x03, 0x04]
    }
    
    var has7ZHeader: Bool {
        if count < 6 { return false }
        let signature = [UInt8](prefix(6))
        return signature == [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
    }
    
    var hasTARHeader: Bool {
        if count < 262 { return false }
        let data = self[257..<262]
        return data == "ustar".data(using: .ascii)!
    }
    
    var hasGZIPHeader: Bool {
        if count < 2 { return false }
        let signature = [UInt8](prefix(2))
        return signature == [0x1F, 0x8B]
    }
    
    var hasBZIP2Header: Bool {
        if count < 3 { return false }
        let signature = [UInt8](prefix(3))
        return signature == [0x42, 0x5A, 0x68]
    }
    
    var hasXZHeader: Bool {
        if count < 6 { return false }
        let signature = [UInt8](prefix(6))
        return signature == [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]
    }
    
    var isPlainText: Bool {
        if count == 0 { return false }
        
        let textPercentage = Double(filter { 
            $0 == 0x0A || $0 == 0x0D || ($0 >= 0x20 && $0 <= 0x7E) || 
            ($0 >= 0xC0 && $0 <= 0xFF)
        }.count) / Double(count)
        
        return textPercentage > 0.8
    }
    
    func detectEncoding() -> String.Encoding {
        if starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8
        }
        if starts(with: [0xFF, 0xFE]) {
            return .utf16LittleEndian
        }
        if starts(with: [0xFE, 0xFF]) {
            return .utf16BigEndian
        }
        
        let windows1252Percentage = Double(filter {
            ($0 >= 0x20 && $0 <= 0x7E) || ($0 >= 0xA0 && $0 <= 0xFF)
        }.count) / Double(count)
        
        if windows1252Percentage > 0.95 {
            return .windowsCP1252
        }
        
        return .utf8
    }
}

extension BookFormatManager {
    func getFormatById(_ id: String) -> BookFormat? {
        return supportedFormats.first { $0.id == id }
    }
    
    func getSupportedExtensions() -> [String] {
        return supportedFormats.flatMap { $0.extensions }
    }
    
    func getExtensionForFormat(_ formatId: String) -> String {
        return supportedFormats.first { $0.id == formatId }?.extensions.first ?? "txt"
    }
}
