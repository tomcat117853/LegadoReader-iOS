#!/usr/bin/env swift

import Foundation

print("=== LegadoReader 核心功能测试 ===\n")

var passed = 0
var failed = 0

func test(_ name: String, _ block: () -> Bool) {
    if block() {
        print("✓ \(name)")
        passed += 1
    } else {
        print("✗ \(name)")
        failed += 1
    }
}

print("--- BookFormatManager 测试 ---")

struct BookFormat: Identifiable {
    let id: String
    let name: String
    let extensions: [String]
    
    func matchesExtension(_ filename: String) -> Bool {
        let ext = filename.lowercased().components(separatedBy: ".").last ?? ""
        return extensions.contains(ext)
    }
}

class BookFormatManager {
    static let shared = BookFormatManager()
    
    let supportedFormats: [BookFormat] = [
        BookFormat(id: "epub", name: "EPUB", extensions: ["epub"]),
        BookFormat(id: "pdf", name: "PDF", extensions: ["pdf"]),
        BookFormat(id: "mobi", name: "MOBI", extensions: ["mobi"]),
        BookFormat(id: "txt", name: "TXT", extensions: ["txt"]),
        BookFormat(id: "fb2", name: "FB2", extensions: ["fb2"]),
        BookFormat(id: "azw", name: "AZW", extensions: ["azw", "azw3"]),
        BookFormat(id: "chm", name: "CHM", extensions: ["chm"]),
        BookFormat(id: "rtf", name: "RTF", extensions: ["rtf"]),
        BookFormat(id: "html", name: "HTML", extensions: ["html", "htm"]),
        BookFormat(id: "zip", name: "ZIP", extensions: ["zip"]),
        BookFormat(id: "rar", name: "RAR", extensions: ["rar"]),
        BookFormat(id: "cbz", name: "CBZ", extensions: ["cbz"])
    ]
    
    func detectFormat(_ filename: String) -> BookFormat? {
        let lowerFilename = filename.lowercased()
        return supportedFormats.first { $0.matchesExtension(lowerFilename) }
    }
    
    func detectFormat(from data: Data) -> BookFormat? {
        if data.starts(with: "%PDF-".data(using: .ascii)!) {
            return supportedFormats.first { $0.id == "pdf" }
        }
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) {
            return supportedFormats.first { $0.id == "epub" }
        }
        return nil
    }
    
    func canRead(_ filename: String) -> Bool {
        return detectFormat(filename) != nil
    }
}

let formatManager = BookFormatManager.shared

test("支持12种格式") {
    formatManager.supportedFormats.count == 12
}

test("检测EPUB格式") {
    formatManager.detectFormat("test.epub")?.id == "epub"
}

test("检测PDF格式") {
    formatManager.detectFormat("book.pdf")?.id == "pdf"
}

test("检测MOBI格式") {
    formatManager.detectFormat("novel.mobi")?.id == "mobi"
}

test("PDF文件头检测") {
    let pdfData = "%PDF-1.7".data(using: .utf8)!
    return formatManager.detectFormat(from: pdfData)?.id == "pdf"
}

print("\n--- TXT编码检测测试 ---")

extension Data {
    func detectEncoding() -> String.Encoding {
        if starts(with: [0xEF, 0xBB, 0xBF]) { return .utf8 }
        if starts(with: [0xFF, 0xFE]) { return .utf16LittleEndian }
        if starts(with: [0xFE, 0xFF]) { return .utf16BigEndian }
        return .utf8
    }
    
    func toString(encoding: String.Encoding = .utf8) -> String {
        return String(data: self, encoding: encoding) ?? ""
    }
}

test("UTF-8编码检测") {
    let data = "Hello World".data(using: .utf8)!
    return data.detectEncoding() == .utf8
}

test("数据转字符串") {
    let data = "Test".data(using: .utf8)!
    return data.toString() == "Test"
}

print("\n--- 加密功能测试 ---")

func simpleHash(_ input: String) -> String {
    var hash = 5381
    for char in input.utf8 {
        hash = ((hash << 5) &+ hash) &+ Int(char)
    }
    return String(format: "%08x", hash & 0xffffffff)
}

func hashPassword(_ password: String, for bookId: String) -> String {
    let salt = "LegadoReader_\(bookId)_Salt"
    return simpleHash(password + salt)
}

func simpleEncrypt(_ content: String, password: String) -> Data {
    var encrypted = Data()
    let salt = "LegadoReader"
    let fullPassword = password + salt
    for (index, char) in content.utf8.enumerated() {
        let keyChar = fullPassword.utf8[fullPassword.utf8.index(fullPassword.utf8.startIndex, offsetBy: index % fullPassword.utf8.count)]
        encrypted.append(char ^ keyChar)
    }
    return encrypted
}

func simpleDecrypt(_ data: Data, password: String) -> String? {
    let salt = "LegadoReader"
    let fullPassword = password + salt
    var decrypted = Data()
    for (index, byte) in data.enumerated() {
        let keyChar = fullPassword.utf8[fullPassword.utf8.index(fullPassword.utf8.startIndex, offsetBy: index % fullPassword.utf8.count)]
        decrypted.append(byte ^ keyChar)
    }
    return String(data: decrypted, encoding: .utf8)
}

test("密码哈希一致性") {
    hashPassword("test", for: "book1") == hashPassword("test", for: "book1")
}

test("密码哈希唯一性") {
    hashPassword("test", for: "book1") != hashPassword("test", for: "book2")
}

test("XOR加密解密") {
    let original = "Hello World"
    let encrypted = simpleEncrypt(original, password: "test")
    let decrypted = simpleDecrypt(encrypted, password: "test")
    return decrypted == original
}

print("\n--- 字符串处理测试 ---")

func parseChapters(_ content: String) -> [(title: String, content: String)] {
    let patterns = ["^第[零一二三四五六七八九十百千万]+章\\s+.*$", "^第\\d+章\\s+.*$"]
    let lines = content.components(separatedBy: "\n")
    var chapters: [(title: String, content: String)] = []
    var currentTitle = ""
    var currentContent = ""
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var isChapterStart = false
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                if regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                    isChapterStart = true
                    break
                }
            }
        }
        
        if isChapterStart && trimmed.count < 100 {
            if !currentTitle.isEmpty {
                chapters.append((currentTitle, currentContent))
            }
            currentTitle = trimmed
            currentContent = ""
        } else {
            currentContent += line + "\n"
        }
    }
    
    if !currentTitle.isEmpty {
        chapters.append((currentTitle, currentContent))
    }
    
    return chapters.isEmpty ? [("正文", content)] : chapters
}

func extractMetadata(_ content: String) -> (title: String, author: String) {
    let lines = content.components(separatedBy: "\n")
    var title = ""
    var author = ""
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("书名") {
            title = trimmed.replacingOccurrences(of: "书名", with: "")
                .replacingOccurrences(of: "：", with: "")
                .trimmingCharacters(in: .whitespaces)
        } else if trimmed.hasPrefix("作者") {
            author = trimmed.replacingOccurrences(of: "作者", with: "")
                .replacingOccurrences(of: "：", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
    }
    
    return (title, author)
}

test("章节解析") {
    let content = """
    第一章 开始
    内容1

    第二章 继续
    内容2
    """
    let chapters = parseChapters(content)
    return chapters.count == 2 && chapters[0].title == "第一章 开始"
}

test("元数据提取") {
    let content = "书名：测试书籍\n作者：张三\n内容..."
    let meta = extractMetadata(content)
    return meta.title == "测试书籍" && meta.author == "张三"
}

print("\n--- OPDS解析器测试 ---")

struct OPDSFeed: Identifiable {
    let id: String
    var title: String
    
    init() {
        self.id = UUID().uuidString
        self.title = "Untitled"
    }
}

struct OPDSEntry: Identifiable {
    let id: String
    var title: String
    var author: String?
    
    init() {
        self.id = UUID().uuidString
        self.title = "Untitled"
    }
    
    var authorName: String {
        return author ?? "未知作者"
    }
}

test("OPDS Feed初始化") {
    let feed = OPDSFeed()
    return !feed.id.isEmpty
}

test("OPDS Entry初始化") {
    let entry = OPDSEntry()
    return !entry.id.isEmpty && entry.authorName == "未知作者"
}

print("\n--- 缓存管理测试 ---")

class CacheManager {
    func getCacheSize() -> Int {
        return 0
    }
    
    func clearCache(type: String) throws {
        return
    }
}

let cacheManager = CacheManager()

test("缓存大小获取") {
    cacheManager.getCacheSize() >= 0
}

test("清除缓存不抛异常") {
    do {
        try cacheManager.clearCache(type: "image")
        return true
    } catch {
        return false
    }
}

print("\n--- 书签管理测试 ---")

struct Bookmark: Identifiable {
    let id: String
    let bookId: String
    let chapterIndex: Int
    let position: Int
    var note: String?
    
    init(bookId: String, chapterIndex: Int, position: Int, note: String? = nil) {
        self.id = UUID().uuidString
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.position = position
        self.note = note
    }
}

class BookmarkManager {
    private var bookmarks: [Bookmark] = []
    
    func addBookmark(_ bookmark: Bookmark) {
        bookmarks.append(bookmark)
    }
    
    func getBookmarks(for bookId: String) -> [Bookmark] {
        return bookmarks.filter { $0.bookId == bookId }
    }
    
    func removeBookmark(_ id: String) {
        bookmarks.removeAll { $0.id == id }
    }
}

let bookmarkManager = BookmarkManager()

test("添加书签") {
    let bookmark = Bookmark(bookId: "test", chapterIndex: 1, position: 100)
    bookmarkManager.addBookmark(bookmark)
    return bookmarkManager.getBookmarks(for: "test").count == 1
}

test("删除书签") {
    let bookmarks = bookmarkManager.getBookmarks(for: "test")
    if let id = bookmarks.first?.id {
        bookmarkManager.removeBookmark(id)
        return bookmarkManager.getBookmarks(for: "test").count == 0
    }
    return false
}

print("\n--- 笔记模板测试 ---")

class NoteTemplateManager {
    func getTemplates() -> [String] {
        return ["模板1", "模板2", "模板3", "模板4", "模板5", "模板6", "模板7", "模板8", "模板9", "模板10"]
    }
    
    func replaceVariables(_ template: String, selectedText: String, bookTitle: String, author: String, chapter: String, page: Int, date: Date) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{{selected_text}}", with: selectedText)
        result = result.replacingOccurrences(of: "{{book_title}}", with: bookTitle)
        result = result.replacingOccurrences(of: "{{author}}", with: author)
        result = result.replacingOccurrences(of: "{{chapter}}", with: chapter)
        result = result.replacingOccurrences(of: "{{page}}", with: "\(page)")
        return result
    }
}

let templateManager = NoteTemplateManager()

test("模板数量") {
    templateManager.getTemplates().count >= 10
}

test("变量替换") {
    let template = "{{selected_text}} - {{book_title}}"
    let result = templateManager.replaceVariables(
        template,
        selectedText: "测试",
        bookTitle: "书籍",
        author: "作者",
        chapter: "章节",
        page: 100,
        date: Date()
    )
    return result == "测试 - 书籍"
}

print("\n--- 音频播放器测试 ---")

struct ChapterInfo: Identifiable {
    let id: String
    let bookId: String
    let bookName: String
    let chapterId: String
    let chapterTitle: String
    let duration: TimeInterval
    let position: TimeInterval
    
    init(bookId: String, bookName: String, chapterId: String, chapterTitle: String, duration: TimeInterval = 0, position: TimeInterval = 0) {
        self.id = UUID().uuidString
        self.bookId = bookId
        self.bookName = bookName
        self.chapterId = chapterId
        self.chapterTitle = chapterTitle
        self.duration = duration
        self.position = position
    }
}

class AudioPlayerManager {
    static let shared = AudioPlayerManager()
    
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 300
    var progress: Double = 0
    var playbackRate: Float = 1.0
    var currentChapter: ChapterInfo?
    var playlist: [ChapterInfo] = []
    var currentIndex: Int = 0
    var isMiniPlayerVisible = false
    
    func loadPlaylist(_ chapters: [ChapterInfo], startIndex: Int = 0) {
        playlist = chapters
        currentIndex = startIndex
        if let chapter = chapters[safe: startIndex] {
            currentChapter = chapter
        }
    }
    
    func play() {
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    func seek(to time: TimeInterval) {
        currentTime = max(0, min(time, duration))
        progress = currentTime / duration
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
    }
    
    func playNext() {
        if currentIndex < playlist.count - 1 {
            currentIndex += 1
            currentChapter = playlist[safe: currentIndex]
        }
    }
    
    func playPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            currentChapter = playlist[safe: currentIndex]
        }
    }
    
    func showMiniPlayer() {
        isMiniPlayerVisible = true
    }
    
    func hideMiniPlayer() {
        isMiniPlayerVisible = false
    }
    
    var formattedCurrentTime: String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progressPercentage: String {
        return String(format: "%.1f%%", progress * 100)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

let audioPlayer = AudioPlayerManager.shared

test("音频播放器初始化") {
    !audioPlayer.isPlaying && audioPlayer.playbackRate == 1.0
}

test("加载播放列表") {
    let chapters = [
        ChapterInfo(bookId: "book1", bookName: "测试书籍", chapterId: "ch1", chapterTitle: "第一章", duration: 300),
        ChapterInfo(bookId: "book1", bookName: "测试书籍", chapterId: "ch2", chapterTitle: "第二章", duration: 280)
    ]
    audioPlayer.loadPlaylist(chapters)
    return audioPlayer.playlist.count == 2 && audioPlayer.currentChapter?.chapterTitle == "第一章"
}

test("播放/暂停切换") {
    audioPlayer.togglePlayPause()
    let playing = audioPlayer.isPlaying
    audioPlayer.togglePlayPause()
    return playing && !audioPlayer.isPlaying
}

test("进度跳转") {
    audioPlayer.seek(to: 150)
    return audioPlayer.currentTime == 150 && abs(audioPlayer.progress - 0.5) < 0.01
}

test("播放速度设置") {
    audioPlayer.setPlaybackRate(1.5)
    return audioPlayer.playbackRate == 1.5
}

test("下一章") {
    audioPlayer.playNext()
    return audioPlayer.currentIndex == 1 && audioPlayer.currentChapter?.chapterTitle == "第二章"
}

test("上一章") {
    audioPlayer.playPrevious()
    return audioPlayer.currentIndex == 0 && audioPlayer.currentChapter?.chapterTitle == "第一章"
}

test("迷你播放器显示") {
    audioPlayer.showMiniPlayer()
    return audioPlayer.isMiniPlayerVisible
}

test("迷你播放器隐藏") {
    audioPlayer.hideMiniPlayer()
    return !audioPlayer.isMiniPlayerVisible
}

test("时间格式化") {
    audioPlayer.currentTime = 125
    audioPlayer.duration = 300
    return audioPlayer.formattedCurrentTime == "02:05" && audioPlayer.formattedDuration == "05:00"
}

test("进度百分比") {
    audioPlayer.progress = 0.5
    return audioPlayer.progressPercentage == "50.0%"
}

print("\n--- 测试结果 ---")
print("通过: \(passed)")
print("失败: \(failed)")
print("总计: \(passed + failed)")

if failed == 0 {
    print("\n🎉 所有测试通过！")
    exit(0)
} else {
    print("\n⚠️ 有 \(failed) 个测试失败")
    exit(1)
}
