import XCTest
@testable import LegadoReader

class BookFormatManagerTests: XCTestCase {
    var formatManager: BookFormatManager!
    
    override func setUp() {
        super.setUp()
        formatManager = BookFormatManager.shared
    }
    
    override func tearDown() {
        formatManager = nil
        super.tearDown()
    }
    
    func testSupportedFormatsCount() {
        let formats = formatManager.listSupportedFormats()
        XCTAssertGreaterThanOrEqual(formats.count, 10, "Should support at least 10 formats")
    }
    
    func testFormatDetectionByExtension() {
        let epubFormat = formatManager.detectFormat("test.epub")
        XCTAssertNotNil(epubFormat, "Should detect EPUB format")
        XCTAssertEqual(epubFormat?.id, "epub")
        
        let pdfFormat = formatManager.detectFormat("book.pdf")
        XCTAssertNotNil(pdfFormat, "Should detect PDF format")
        XCTAssertEqual(pdfFormat?.id, "pdf")
        
        let mobiFormat = formatManager.detectFormat("novel.mobi")
        XCTAssertNotNil(mobiFormat, "Should detect MOBI format")
        XCTAssertEqual(mobiFormat?.id, "mobi")
    }
    
    func testFormatDetectionByData() {
        let pdfData = "%PDF-1.7".data(using: .utf8)!
        let detected = formatManager.detectFormat(from: pdfData)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.id, "pdf")
    }
    
    func testCanReadSupportedFormats() {
        XCTAssertTrue(formatManager.canRead("test.epub"))
        XCTAssertTrue(formatManager.canRead("book.pdf"))
        XCTAssertTrue(formatManager.canRead("novel.mobi"))
        XCTAssertTrue(formatManager.canRead("story.txt"))
    }
    
    func testConvertibleFormats() {
        if let txtFormat = formatManager.getFormatById("txt") {
            let convertible = formatManager.getConvertibleFormats(from: txtFormat)
            XCTAssertGreaterThan(convertible.count, 0, "TXT should be convertible to at least one format")
        }
    }
    
    func testFormatById() {
        let epub = formatManager.getFormatById("epub")
        XCTAssertNotNil(epub)
        XCTAssertEqual(epub?.name, "EPUB")
        
        let unknown = formatManager.getFormatById("unknown")
        XCTAssertNil(unknown)
    }
}

class MOBIReaderTests: XCTestCase {
    func testMOBIHeaderParsing() {
        let reader = MOBIReader()
        XCTAssertNotNil(reader)
    }
    
    func testMOBIReaderConformsToProtocol() {
        let reader = MOBIReader()
        XCTAssertTrue(reader is BookReaderProtocol)
    }
}

class TXTReaderTests: XCTestCase {
    var txtReader: TXTReader!
    
    override func setUp() {
        super.setUp()
        txtReader = TXTReader()
    }
    
    override func tearDown() {
        txtReader = nil
        super.tearDown()
    }
    
    func testEncodingDetection() {
        let utf8Data = "Hello World".data(using: .utf8)!
        let encoding = utf8Data.detectEncoding()
        XCTAssertEqual(encoding, .utf8)
    }
    
    func testUTF16EncodingDetection() {
        let utf16Data = "Test".data(using: .utf16LittleEndian)!
        let encoding = utf16Data.detectEncoding()
        XCTAssertTrue(encoding == .utf16LittleEndian)
    }
    
    func testChapterParsing() {
        let content = """
        第一章 开始
        这是第一章的内容。
        
        第二章 继续
        这是第二章的内容。
        """
        let chapters = txtReader.parseChapters(content)
        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].title, "第一章 开始")
        XCTAssertEqual(chapters[1].title, "第二章 继续")
    }
    
    func testMetadataExtraction() {
        let content = """
        书名：测试书籍
        作者：张三
        
        这是书籍内容。
        """
        let metadata = txtReader.getMetadata(data: content.data(using: .utf8)!)
        XCTAssertEqual(metadata.title, "测试书籍")
        XCTAssertEqual(metadata.author, "张三")
    }
}

class OPDSParserTests: XCTestCase {
    func testOPDSParserInitialization() {
        let parser = OPDSParser()
        XCTAssertNotNil(parser)
    }
    
    func testOPDSFeedStructure() {
        let feed = OPDSFeed()
        XCTAssertNotNil(feed.id)
        XCTAssertFalse(feed.title.isEmpty)
    }
    
    func testOPDSEntryStructure() {
        let entry = OPDSEntry()
        XCTAssertNotNil(entry.id)
        XCTAssertFalse(entry.title.isEmpty)
    }
}

class BookEncryptionManagerTests: XCTestCase {
    var encryptionManager: BookEncryptionManager!
    
    override func setUp() {
        super.setUp()
        encryptionManager = BookEncryptionManager.shared
    }
    
    override func tearDown() {
        encryptionManager = nil
        super.tearDown()
    }
    
    func testEncryptionSettingsDefault() {
        let settings = encryptionManager.getSettings()
        XCTAssertFalse(settings.isEncryptionEnabled)
        XCTAssertEqual(settings.encryptionType, .standard)
        XCTAssertEqual(settings.autoLockTimeout, 5)
    }
    
    func testLockoutProtection() {
        for _ in 0..<6 {
            _ = encryptionManager.unlockWithPassword("wrongpassword")
        }
        XCTAssertTrue(encryptionManager.isLockedOut())
    }
    
    func testHashPassword() {
        let hash1 = encryptionManager.hashPassword("test", for: "book1")
        let hash2 = encryptionManager.hashPassword("test", for: "book1")
        XCTAssertEqual(hash1, hash2)
        
        let hash3 = encryptionManager.hashPassword("test", for: "book2")
        XCTAssertNotEqual(hash1, hash3)
    }
    
    func testEncryptDecryptContent() {
        let original = "Hello World"
        if let encrypted = encryptionManager.encryptContent(original, password: "test") {
            let decrypted = encryptionManager.decryptContent(encrypted, password: "test")
            XCTAssertEqual(decrypted, original)
        } else {
            XCTFail("Encryption failed")
        }
    }
}

class BookContentFilterTests: XCTestCase {
    func testFilterManagerInitialization() {
        let filterManager = ContentFilterManager.shared
        XCTAssertNotNil(filterManager)
    }
    
    func testFilterLoading() {
        let filterManager = ContentFilterManager.shared
        XCTAssertGreaterThan(filterManager.filters.count, 0, "Should have at least some filters")
    }
}

class TextLayoutManagerTests: XCTestCase {
    func testLayoutTypes() {
        let types = TextLayout.allCases
        XCTAssertEqual(types.count, 2)
    }
    
    func testVerticalDirections() {
        let directions = VerticalDirection.allCases
        XCTAssertEqual(directions.count, 2)
    }
}

class NoteTemplateManagerTests: XCTestCase {
    var templateManager: NoteTemplateManager!
    
    override func setUp() {
        super.setUp()
        templateManager = NoteTemplateManager.shared
    }
    
    override func tearDown() {
        templateManager = nil
        super.tearDown()
    }
    
    func testBuiltInTemplatesCount() {
        let templates = templateManager.getTemplates()
        XCTAssertGreaterThanOrEqual(templates.count, 10, "Should have at least 10 built-in templates")
    }
    
    func testTemplateCategories() {
        let categories = templateManager.getCategories()
        XCTAssertGreaterThan(categories.count, 0)
    }
    
    func testVariableReplacement() {
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
        XCTAssertTrue(result.contains("测试文本"))
        XCTAssertTrue(result.contains("测试书籍"))
    }
}

class UnderlineManagerTests: XCTestCase {
    var underlineManager: UnderlineManager!
    
    override func setUp() {
        super.setUp()
        underlineManager = UnderlineManager.shared
    }
    
    override func tearDown() {
        underlineManager = nil
        super.tearDown()
    }
    
    func testStyles() {
        let styles = UnderlineStyle.allCases
        XCTAssertEqual(styles.count, 5)
    }
    
    func testColors() {
        let colors = UnderlineColor.allCases
        XCTAssertEqual(colors.count, 7)
    }
}

class BookmarkManagerTests: XCTestCase {
    var bookmarkManager: BookmarkManager!
    
    override func setUp() {
        super.setUp()
        bookmarkManager = BookmarkManager.shared
    }
    
    override func tearDown() {
        bookmarkManager = nil
        super.tearDown()
    }
    
    func testAddAndGetBookmarks() {
        let bookId = "test_book"
        let bookmark = Bookmark(bookId: bookId, chapterIndex: 1, position: 100, note: "Test bookmark")
        
        bookmarkManager.addBookmark(bookmark)
        
        let bookmarks = bookmarkManager.getBookmarks(for: bookId)
        XCTAssertGreaterThan(bookmarks.count, 0)
    }
    
    func testRemoveBookmark() {
        let bookId = "test_book"
        let bookmark = Bookmark(bookId: bookId, chapterIndex: 1, position: 200)
        
        bookmarkManager.addBookmark(bookmark)
        
        let initialCount = bookmarkManager.getBookmarks(for: bookId).count
        
        bookmarkManager.removeBookmark(bookmark.id)
        
        let finalCount = bookmarkManager.getBookmarks(for: bookId).count
        XCTAssertEqual(finalCount, initialCount - 1)
    }
}

class CacheManagerTests: XCTestCase {
    var cacheManager: CacheManager!
    
    override func setUp() {
        super.setUp()
        cacheManager = CacheManager.shared
    }
    
    override func tearDown() {
        cacheManager = nil
        super.tearDown()
    }
    
    func testClearCache() {
        XCTAssertNoThrow(try cacheManager.clearCache(type: .image))
    }
    
    func testGetCacheSize() {
        let size = cacheManager.getCacheSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }
}

if CommandLine.arguments.contains("--run-tests") {
    XCTMain([
        testCase(BookFormatManagerTests.allTests),
        testCase(MOBIReaderTests.allTests),
        testCase(TXTReaderTests.allTests),
        testCase(OPDSParserTests.allTests),
        testCase(BookEncryptionManagerTests.allTests),
        testCase(BookContentFilterTests.allTests),
        testCase(TextLayoutManagerTests.allTests),
        testCase(NoteTemplateManagerTests.allTests),
        testCase(UnderlineManagerTests.allTests),
        testCase(BookmarkManagerTests.allTests),
        testCase(CacheManagerTests.allTests)
    ])
}
