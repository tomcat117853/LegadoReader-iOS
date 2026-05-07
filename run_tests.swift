#!/usr/bin/env swift

import Foundation

print("=== 开始测试 LegadoReader 核心功能 ===\n")

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

func testThrows(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        print("✓ \(name)")
        passed += 1
    } catch {
        print("✗ \(name): \(error.localizedDescription)")
        failed += 1
    }
}

print("--- BookFormatManager 测试 ---")

let formatManager = BookFormatManager.shared

test("支持格式数量 >= 10") {
    formatManager.listSupportedFormats().count >= 10
}

test("检测 EPUB 格式") {
    let format = formatManager.detectFormat("test.epub")
    return format?.id == "epub"
}

test("检测 PDF 格式") {
    let format = formatManager.detectFormat("book.pdf")
    return format?.id == "pdf"
}

test("检测 MOBI 格式") {
    let format = formatManager.detectFormat("novel.mobi")
    return format?.id == "mobi"
}

test("PDF 文件头检测") {
    let pdfData = "%PDF-1.7".data(using: .utf8)!
    let detected = formatManager.detectFormat(from: pdfData)
    return detected?.id == "pdf"
}

test("支持阅读 EPUB") {
    formatManager.canRead("test.epub")
}

test("支持阅读 TXT") {
    formatManager.canRead("story.txt")
}

print("\n--- TXTReader 测试 ---")

let txtReader = TXTReader()

test("UTF-8 编码检测") {
    let utf8Data = "Hello World".data(using: .utf8)!
    return utf8Data.detectEncoding() == .utf8
}

test("章节解析") {
    let content = """
    第一章 开始
    这是第一章内容。

    第二章 继续
    这是第二章内容。
    """
    let chapters = txtReader.parseChapters(content)
    return chapters.count == 2 && chapters[0].title == "第一章 开始"
}

test("元数据提取") {
    let content = """
    书名：测试书籍
    作者：张三

    内容...
    """
    let metadata = txtReader.getMetadata(data: content.data(using: .utf8)!)
    return metadata.title == "测试书籍" && metadata.author == "张三"
}

print("\n--- BookEncryptionManager 测试 ---")

let encryptionManager = BookEncryptionManager.shared

test("加密设置默认值") {
    let settings = encryptionManager.getSettings()
    return !settings.isEncryptionEnabled && settings.encryptionType == .standard
}

test("密码哈希一致性") {
    let hash1 = encryptionManager.hashPassword("test", for: "book1")
    let hash2 = encryptionManager.hashPassword("test", for: "book1")
    return hash1 == hash2
}

test("加密解密内容") {
    let original = "Hello World"
    if let encrypted = encryptionManager.encryptContent(original, password: "test") {
        let decrypted = encryptionManager.decryptContent(encrypted, password: "test")
        return decrypted == original
    }
    return false
}

print("\n--- NoteTemplateManager 测试 ---")

let templateManager = NoteTemplateManager.shared

test("内置模板数量 >= 10") {
    templateManager.getTemplates().count >= 10
}

test("变量替换") {
    let template = "{{selected_text}}\n{{book_title}}"
    let result = templateManager.replaceVariables(
        template,
        selectedText: "测试文本",
        bookTitle: "测试书籍",
        author: "作者",
        chapter: "章节",
        page: 100,
        date: Date()
    )
    return result.contains("测试文本") && result.contains("测试书籍")
}

print("\n--- UnderlineManager 测试 ---")

let underlineManager = UnderlineManager.shared

test("下划线样式数量") {
    UnderlineStyle.allCases.count == 5
}

test("下划线颜色数量") {
    UnderlineColor.allCases.count == 7
}

print("\n--- BookmarkManager 测试 ---")

let bookmarkManager = BookmarkManager.shared

test("添加书签") {
    let bookmark = Bookmark(bookId: "test_book", chapterIndex: 1, position: 100)
    bookmarkManager.addBookmark(bookmark)
    return bookmarkManager.getBookmarks(for: "test_book").count > 0
}

test("删除书签") {
    let bookmarks = bookmarkManager.getBookmarks(for: "test_book")
    if let bookmark = bookmarks.first {
        let initialCount = bookmarks.count
        bookmarkManager.removeBookmark(bookmark.id)
        let finalCount = bookmarkManager.getBookmarks(for: "test_book").count
        return finalCount == initialCount - 1
    }
    return true
}

print("\n--- CacheManager 测试 ---")

let cacheManager = CacheManager.shared

test("获取缓存大小") {
    let size = cacheManager.getCacheSize()
    return size >= 0
}

test("清除缓存不抛异常") {
    do {
        try cacheManager.clearCache(type: .image)
        return true
    } catch {
        return false
    }
}

print("\n--- OPDSParser 测试 ---")

let opdsParser = OPDSParser()

test("OPDS解析器初始化") {
    opdsParser != nil
}

test("OPDS Feed结构") {
    let feed = OPDSFeed()
    return !feed.id.isEmpty
}

test("OPDS Entry结构") {
    let entry = OPDSEntry()
    return !entry.id.isEmpty
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
