import Foundation
import XMLCoder

class OPDSParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentContent = ""
    private var feeds: [OPDSFeed] = []
    private var currentFeed: OPDSFeed?
    private var entries: [OPDSEntry] = []
    private var currentEntry: OPDSEntry?
    private var isParsingEntry = false
    private var isParsingFeed = false
    
    func parse(data: Data) -> OPDSCatalog? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        return OPDSCatalog(feeds: feeds, entries: entries)
    }
    
    func parseFromString(_ xmlString: String) -> OPDSCatalog? {
        guard let data = xmlString.data(using: .utf8) else { return nil }
        return parse(data: data)
    }
    
    func parseToCloudFiles(_ data: Data) -> [CloudStorageManager.CloudFile] {
        guard let catalog = parse(data: data) else { return [] }
        
        var files: [CloudStorageManager.CloudFile] = []
        
        for feed in catalog.feeds {
            if let href = feed.href {
                files.append(CloudStorageManager.CloudFile(
                    name: feed.title.isEmpty ? "目录" : feed.title,
                    path: href,
                    isDirectory: true,
                    size: 0,
                    modifiedDate: feed.updated,
                    type: "folder"
                ))
            }
        }
        
        for entry in catalog.entries {
            let fileName = entry.title.isEmpty ? "未知书籍" : entry.title
            var downloadPath = ""
            var fileSize: Int64 = 0
            var fileType = "epub"
            
            if let link = entry.acquisitionLinks.first(where: { $0.type?.contains("epub") == true }) {
                downloadPath = link.href
                fileType = "epub"
            } else if let link = entry.acquisitionLinks.first(where: { $0.type?.contains("pdf") == true }) {
                downloadPath = link.href
                fileType = "pdf"
            } else if let link = entry.acquisitionLinks.first {
                downloadPath = link.href
                if let type = link.type {
                    if type.contains("pdf") { fileType = "pdf" }
                    else if type.contains("mobi") { fileType = "mobi" }
                    else if type.contains("zip") || type.contains("rar") { fileType = "zip" }
                }
            }
            
            files.append(CloudStorageManager.CloudFile(
                name: fileName + ".\(fileType)",
                path: downloadPath,
                isDirectory: false,
                size: fileSize,
                modifiedDate: entry.updated,
                type: fileType
            ))
        }
        
        return files
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentContent = ""
        
        switch elementName {
        case "feed":
            isParsingFeed = true
            currentFeed = OPDSFeed()
            if let title = attributeDict["title"] {
                currentFeed?.title = title
            }
            if let href = attributeDict["href"] {
                currentFeed?.href = href
            }
            
        case "entry":
            isParsingEntry = true
            currentEntry = OPDSEntry()
            
        case "link":
            if isParsingEntry {
                if let href = attributeDict["href"],
                   let rel = attributeDict["rel"] {
                    let link = OPDSLink(
                        href: href,
                        rel: rel,
                        type: attributeDict["type"],
                        title: attributeDict["title"]
                    )
                    currentEntry?.links.append(link)
                }
            } else if isParsingFeed {
                if let href = attributeDict["href"],
                   let rel = attributeDict["rel"] {
                    let link = OPDSLink(
                        href: href,
                        rel: rel,
                        type: attributeDict["type"],
                        title: attributeDict["title"]
                    )
                    currentFeed?.links.append(link)
                }
            }
            
        case "author":
            if isParsingEntry {
                currentEntry?.author = OPDSAuthor()
            }
            
        case "contributor":
            if isParsingEntry {
                currentEntry?.contributors.append(OPDSAuthor())
            }
            
        case "category":
            if isParsingEntry, let label = attributeDict["label"] {
                currentEntry?.categories.append(label)
            }
            
        case "price":
            if let currency = attributeDict["currency"],
               let valueStr = attributeDict["value"],
               let value = Double(valueStr) {
                currentEntry?.price = OPDSPrice(currency: currency, value: value)
            }
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentContent += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let content = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isParsingEntry {
            if let entry = currentEntry {
                switch elementName {
                case "title":
                    entry.title = content
                case "id":
                    entry.id = content
                case "updated", "published":
                    if let date = ISO8601DateFormatter().date(from: content) {
                        entry.updated = date
                    }
                case "summary", "content":
                    if entry.summary.isEmpty {
                        entry.summary = content
                    }
                case "author":
                    if let authorName = content.split(separator: ",").first {
                        entry.author?.name = String(authorName)
                    }
                case "name":
                    if !isParsingFeed {
                        entry.author?.name = content
                    }
                case "uri":
                    entry.author?.uri = content
                case "contributor":
                    if let last = entry.contributors.last {
                        last.name = content
                    }
                case "price":
                    if let price = entry.price {
                        entry.price = OPDSPrice(currency: price.currency, value: Double(content) ?? 0)
                    }
                case "entry":
                    if let entry = currentEntry {
                        entries.append(entry)
                    }
                    currentEntry = nil
                    isParsingEntry = false
                default:
                    break
                }
            }
        } else if isParsingFeed {
            if let feed = currentFeed {
                switch elementName {
                case "title":
                    feed.title = content
                case "id":
                    feed.id = content
                case "updated":
                    if let date = ISO8601DateFormatter().date(from: content) {
                        feed.updated = date
                    }
                case "subtitle":
                    feed.subtitle = content
                case "icon":
                    feed.icon = content
                case "name":
                    feed.author?.name = content
                case "uri":
                    feed.author?.uri = content
                case "feed":
                    if let feed = currentFeed {
                        feeds.append(feed)
                    }
                    currentFeed = nil
                    isParsingFeed = false
                default:
                    break
                }
            }
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("OPDS Parse Error: \(parseError.localizedDescription)")
    }
}

struct OPDSCatalog {
    let feeds: [OPDSFeed]
    let entries: [OPDSEntry]
    
    var isEmpty: Bool {
        return feeds.isEmpty && entries.isEmpty
    }
}

struct OPDSFeed: Identifiable, Codable {
    let id: String
    var title: String
    var href: String?
    var subtitle: String?
    var icon: String?
    var updated: Date?
    var author: OPDSAuthor?
    var links: [OPDSLink] = []
    var entries: [OPDSEntry] = []
    
    init() {
        self.id = UUID().uuidString
        self.title = ""
    }
}

struct OPDSEntry: Identifiable, Codable {
    let id: String
    var title: String
    var summary: String = ""
    var updated: Date?
    var author: OPDSAuthor?
    var contributors: [OPDSAuthor] = []
    var categories: [String] = []
    var links: [OPDSLink] = []
    var price: OPDSPrice?
    
    init() {
        self.id = UUID().uuidString
        self.title = ""
    }
    
    var coverImage: String? {
        return links.first { $0.rel == "http://opds-spec.org/cover" }?.href ??
               links.first { $0.rel.contains("cover") }?.href ??
               links.first { $0.type?.contains("image") }?.href
    }
    
    var thumbnailImage: String? {
        return links.first { $0.rel == "http://opds-spec.org/thumbnail" }?.href ??
               links.first { $0.rel.contains("thumbnail") }?.href
    }
    
    var acquisitionLinks: [OPDSLink] {
        return links.filter { $0.rel.contains("acquisition") || $0.rel == "alternate" }
    }
    
    var epubLink: OPDSLink? {
        return links.first { $0.type?.contains("epub") || $0.href?.contains(".epub") }
    }
    
    var pdfLink: OPDSLink? {
        return links.first { $0.type?.contains("pdf") || $0.href?.contains(".pdf") }
    }
    
    var authorName: String {
        return author?.name ?? contributors.first?.name ?? "未知作者"
    }
}

struct OPDSAuthor: Codable {
    var name: String = ""
    var uri: String?
}

struct OPDSLink: Codable {
    let href: String
    let rel: String
    let type: String?
    let title: String?
    
    var isAcquisitionLink: Bool {
        return rel.contains("acquisition")
    }
    
    var isImageLink: Bool {
        return type?.contains("image") ?? false
    }
}

struct OPDSPrice: Codable {
    let currency: String
    let value: Double
    
    var displayString: String {
        if value == 0 {
            return "免费"
        }
        return "\(currency) \(String(format: "%.2f", value))"
    }
}
