import Foundation
import PDFKit
import Combine

class PDFManager: ObservableObject {
    static let shared = PDFManager()
    
    @Published var currentDocument: PDFDocument?
    @Published var currentPageIndex: Int = 0
    @Published var totalPages: Int = 0
    @Published var isLoading = false
    @Published var loadProgress: Double = 0
    @Published var error: String?
    
    @Published var bookmarks: [PDFBookmark] = []
    @Published var recentFiles: [RecentPDFFile] = []
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let pdfDirectory: URL
    
    struct PDFBookmark: Identifiable, Codable {
        let id: String
        let fileName: String
        let pageIndex: Int
        let pageLabel: String
        let createdTime: Date
        var note: String
    }
    
    struct RecentPDFFile: Identifiable, Codable {
        let id: String
        let fileName: String
        let filePath: String
        let lastOpenTime: Date
        let pageCount: Int
        let lastPageIndex: Int
    }
    
    private let recentFilesKey = "PDFManager_recentFiles"
    private let bookmarksKey = "PDFManager_bookmarks"
    
    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        pdfDirectory = documentsDirectory.appendingPathComponent("PDFs")
        
        try? fileManager.createDirectory(at: pdfDirectory, withIntermediateDirectories: true)
        
        loadRecentFiles()
        loadBookmarks()
    }
    
    private func loadRecentFiles() {
        if let data = UserDefaults.standard.data(forKey: recentFilesKey),
           let files = try? JSONDecoder().decode([RecentPDFFile].self, from: data) {
            recentFiles = files
        }
    }
    
    private func saveRecentFiles() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(data, forKey: recentFilesKey)
        }
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let savedBookmarks = try? JSONDecoder().decode([PDFBookmark].self, from: data) {
            bookmarks = savedBookmarks
        }
    }
    
    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }
    
    func loadPDF(from url: URL) -> Bool {
        isLoading = true
        loadProgress = 0
        error = nil
        
        guard let document = PDFDocument(url: url) else {
            error = "无法加载PDF文件"
            isLoading = false
            return false
        }
        
        currentDocument = document
        totalPages = document.pageCount
        currentPageIndex = 0
        
        updateRecentFiles(fileName: url.lastPathComponent, filePath: url.path)
        
        isLoading = false
        loadProgress = 1.0
        return true
    }
    
    func loadPDF(from data: Data, fileName: String) -> Bool {
        isLoading = true
        loadProgress = 0
        error = nil
        
        guard let document = PDFDocument(data: data) else {
            error = "无法解析PDF数据"
            isLoading = false
            return false
        }
        
        currentDocument = document
        totalPages = document.pageCount
        currentPageIndex = 0
        
        isLoading = false
        loadProgress = 1.0
        return true
    }
    
    func getPage(at index: Int) -> PDFPage? {
        guard let document = currentDocument,
              index >= 0 && index < document.pageCount else {
            return nil
        }
        return document.page(at: index)
    }
    
    func goToPage(_ index: Int) {
        guard let document = currentDocument,
              index >= 0 && index < document.pageCount else {
            return
        }
        currentPageIndex = index
    }
    
    func nextPage() {
        goToPage(currentPageIndex + 1)
    }
    
    func previousPage() {
        goToPage(currentPageIndex - 1)
    }
    
    func firstPage() {
        goToPage(0)
    }
    
    func lastPage() {
        goToPage(totalPages - 1)
    }
    
    func closeDocument() {
        currentDocument = nil
        currentPageIndex = 0
        totalPages = 0
    }
    
    private func updateRecentFiles(fileName: String, filePath: String) {
        recentFiles.removeAll { $0.filePath == filePath }
        
        let recentFile = RecentPDFFile(
            id: UUID().uuidString,
            fileName: fileName,
            filePath: filePath,
            lastOpenTime: Date(),
            pageCount: totalPages,
            lastPageIndex: currentPageIndex
        )
        
        recentFiles.insert(recentFile, at: 0)
        
        if recentFiles.count > 20 {
            recentFiles = Array(recentFiles.prefix(20))
        }
        
        saveRecentFiles()
    }
    
    func updateLastPageIndex(_ index: Int, for filePath: String) {
        if let fileIndex = recentFiles.firstIndex(where: { $0.filePath == filePath }) {
            recentFiles[fileIndex] = RecentPDFFile(
                id: recentFiles[fileIndex].id,
                fileName: recentFiles[fileIndex].fileName,
                filePath: filePath,
                lastOpenTime: Date(),
                pageCount: recentFiles[fileIndex].pageCount,
                lastPageIndex: index
            )
            saveRecentFiles()
        }
    }
    
    func removeRecentFile(_ file: RecentPDFFile) {
        recentFiles.removeAll { $0.id == file.id }
        saveRecentFiles()
    }
    
    func clearRecentFiles() {
        recentFiles.removeAll()
        saveRecentFiles()
    }
    
    func addBookmark(pageIndex: Int, note: String = "") {
        guard let document = currentDocument,
              let page = document.page(at: pageIndex) else {
            return
        }
        
        let pageLabel = page.label ?? "第 \(pageIndex + 1) 页"
        
        let bookmark = PDFBookmark(
            id: UUID().uuidString,
            fileName: currentDocument?.documentURL?.lastPathComponent ?? "未知文件",
            pageIndex: pageIndex,
            pageLabel: pageLabel,
            createdTime: Date(),
            note: note
        )
        
        bookmarks.append(bookmark)
        saveBookmarks()
    }
    
    func removeBookmark(_ bookmark: PDFBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }
    
    func getBookmarks(for fileName: String) -> [PDFBookmark] {
        return bookmarks.filter { $0.fileName == fileName }
    }
    
    func updateBookmarkNote(_ bookmark: PDFBookmark, note: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = PDFBookmark(
                id: bookmark.id,
                fileName: bookmark.fileName,
                pageIndex: bookmark.pageIndex,
                pageLabel: bookmark.pageLabel,
                createdTime: bookmark.createdTime,
                note: note,
                note: note
            )
            saveBookmarks()
        }
    }
    
    func searchPDF(_ query: String) -> [PDFSearchResult] {
        guard let document = currentDocument else { return [] }
        
        var results: [PDFSearchResult] = []
        
        document.findString(query, withOptions: .caseInsensitive)
        
        if let selections = document.findString(query, withOptions: .caseInsensitive) as? [PDFSelection] {
            for selection in selections {
                if let page = selection.pages.first,
                   let pageIndex = document.index(for: page) {
                    let context = extractContext(from: selection, page: page)
                    
                    let result = PDFSearchResult(
                        pageIndex: pageIndex,
                        context: context,
                        selection: selection
                    )
                    results.append(result)
                }
            }
        }
        
        return results
    }
    
    struct PDFSearchResult {
        let pageIndex: Int
        let context: String
        let selection: PDFSelection
    }
    
    private func extractContext(from selection: PDFSelection, page: PDFPage) -> String {
        guard let selectionBounds = selection.bounds(for: page) as CGRect?,
              let pageBounds = page.bounds(for: .mediaBox) as CGRect? else {
            return selection.string ?? ""
        }
        
        let contextRange: CGFloat = 100
        
        let contextRect = CGRect(
            x: max(0, selectionBounds.minX - contextRange),
            y: selectionBounds.minY,
            width: selectionBounds.width + contextRange * 2,
            height: selectionBounds.height
        )
        
        return selection.string ?? ""
    }
    
    func extractText(from pageIndex: Int) -> String? {
        guard let page = getPage(at: pageIndex) else { return nil }
        return page.string
    }
    
    func extractAllText() -> String {
        guard let document = currentDocument else { return "" }
        
        var fullText = ""
        
        for i in 0..<document.pageCount {
            if let page = document.page(at: i),
               let text = page.string {
                fullText += text + "\n\n"
            }
        }
        
        return fullText
    }
    
    func getTableOfContents() -> [PDFOutlineItem] {
        guard let document = currentDocument,
              let outline = document.outlineRoot else {
            return []
        }
        
        return parseOutline(outline, level: 0)
    }
    
    struct PDFOutlineItem: Identifiable {
        let id: String
        let label: String
        let destination: PDFDestination?
        let level: Int
        let children: [PDFOutlineItem]
    }
    
    private func parseOutline(_ outline: PDFOutline, level: Int) -> [PDFOutlineItem] {
        var items: [PDFOutlineItem] = []
        
        for i in 0..<outline.numberOfChildren {
            if let child = outline.child(at: i) {
                let children = parseOutline(child, level: level + 1)
                
                let item = PDFOutlineItem(
                    id: UUID().uuidString,
                    label: child.label ?? "未命名",
                    destination: child.destination,
                    level: level,
                    children: children
                )
                items.append(item)
            }
        }
        
        return items
    }
    
    func exportCurrentPageAsImage(scale: CGFloat = 2.0) -> UIImage? {
        guard let page = getPage(at: currentPageIndex) else { return nil }
        
        let pageRect = page.bounds(for: .mediaBox)
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}

extension PDFManager {
    func getFileSize(at path: String) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            return (attributes[.size] as? Int64) ?? 0
        } catch {
            return 0
        }
    }
    
    func formatFileSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
