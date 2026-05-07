import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    private init() {}
    
    func setup() {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法获取文档目录")
            return
        }
        
        let dbPath = documentsPath.appendingPathComponent("legado_reader.db").path
        
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("数据库打开成功: \(dbPath)")
            createTables()
        } else {
            print("数据库打开失败")
        }
    }
    
    private func createTables() {
        let createBookTable = """
            CREATE TABLE IF NOT EXISTS books (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                author TEXT NOT NULL,
                cover TEXT,
                intro TEXT,
                lastChapter TEXT,
                lastReadChapter TEXT,
                lastReadPosition INTEGER DEFAULT 0,
                totalChapters INTEGER DEFAULT 0,
                sourceUrl TEXT NOT NULL,
                sourceName TEXT NOT NULL,
                bookUrl TEXT NOT NULL,
                isFavorite INTEGER DEFAULT 1,
                lastReadTime TIMESTAMP,
                addedTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updatedTime TIMESTAMP
            );
        """
        
        let createChapterTable = """
            CREATE TABLE IF NOT EXISTS chapters (
                id TEXT PRIMARY KEY,
                bookId TEXT NOT NULL,
                title TEXT NOT NULL,
                url TEXT NOT NULL,
                index INTEGER NOT NULL,
                content TEXT,
                isLoaded INTEGER DEFAULT 0,
                FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
            );
        """
        
        let createBookSourceTable = """
            CREATE TABLE IF NOT EXISTS bookSources (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                url TEXT NOT NULL,
                type TEXT DEFAULT 'text',
                isEnabled INTEGER DEFAULT 1,
                weight INTEGER DEFAULT 1000,
                lastUpdateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                rule TEXT NOT NULL
            );
        """
        
        let createRSSSourceTable = """
            CREATE TABLE IF NOT EXISTS rssSources (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                url TEXT NOT NULL,
                icon TEXT,
                isEnabled INTEGER DEFAULT 1,
                lastUpdateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """
        
        let createRSSArticleTable = """
            CREATE TABLE IF NOT EXISTS rssArticles (
                id TEXT PRIMARY KEY,
                sourceId TEXT NOT NULL,
                title TEXT NOT NULL,
                link TEXT NOT NULL,
                description TEXT,
                content TEXT,
                author TEXT,
                pubDate TIMESTAMP,
                cover TEXT,
                isRead INTEGER DEFAULT 0,
                isFavorite INTEGER DEFAULT 0,
                FOREIGN KEY (sourceId) REFERENCES rssSources(id) ON DELETE CASCADE
            );
        """
        
        executeSQL(createBookTable)
        executeSQL(createChapterTable)
        executeSQL(createBookSourceTable)
        executeSQL(createRSSSourceTable)
        executeSQL(createRSSArticleTable)
    }
    
    private func executeSQL(_ sql: String) {
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = String(cString: errorMessage!)
            print("SQL执行错误: \(message)")
            sqlite3_free(errorMessage)
        }
    }
    
    // MARK: - Book Operations
    
    func saveBook(_ book: Book) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO books (
                id, name, author, cover, intro, lastChapter, lastReadChapter,
                lastReadPosition, totalChapters, sourceUrl, sourceName, bookUrl,
                isFavorite, lastReadTime, addedTime, updatedTime
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        sqlite3_bind_text(statement, 1, (book.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (book.name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (book.author as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (book.cover as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (book.intro as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_text(statement, 6, (book.lastChapter as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_text(statement, 7, (book.lastReadChapter as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_int(statement, 8, Int32(book.lastReadPosition))
        sqlite3_bind_int(statement, 9, Int32(book.totalChapters))
        sqlite3_bind_text(statement, 10, (book.sourceUrl as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 11, (book.sourceName as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 12, (book.bookUrl as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 13, book.isFavorite ? 1 : 0)
        sqlite3_bind_text(statement, 14, (book.lastReadTime?.ISO8601Format() as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_text(statement, 15, (book.addedTime.ISO8601Format() as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 16, (book.updatedTime?.ISO8601Format() as NSString?)?.utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        return result
    }
    
    func getAllBooks() -> [Book] {
        let sql = "SELECT * FROM books ORDER BY lastReadTime DESC;"
        var books: [Book] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return books
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let book = bookFromStatement(statement) {
                books.append(book)
            }
        }
        
        sqlite3_finalize(statement)
        return books
    }
    
    func deleteBook(id: String) -> Bool {
        let sql = "DELETE FROM books WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        return result
    }
    
    private func bookFromStatement(_ statement: OpaquePointer?) -> Book? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let name = String(cString: sqlite3_column_text(statement, 1))
        let author = String(cString: sqlite3_column_text(statement, 2))
        let cover = sqlite3_column_text(statement, 3).flatMap { String(cString: $0) }
        let intro = sqlite3_column_text(statement, 4).flatMap { String(cString: $0) }
        let lastChapter = sqlite3_column_text(statement, 5).flatMap { String(cString: $0) }
        let lastReadChapter = sqlite3_column_text(statement, 6).flatMap { String(cString: $0) }
        let lastReadPosition = Int(sqlite3_column_int(statement, 7))
        let totalChapters = Int(sqlite3_column_int(statement, 8))
        let sourceUrl = String(cString: sqlite3_column_text(statement, 9))
        let sourceName = String(cString: sqlite3_column_text(statement, 10))
        let bookUrl = String(cString: sqlite3_column_text(statement, 11))
        let isFavorite = sqlite3_column_int(statement, 12) == 1
        
        var book = Book(
            id: id,
            name: name,
            author: author,
            cover: cover,
            intro: intro,
            lastChapter: lastChapter,
            sourceUrl: sourceUrl,
            sourceName: sourceName,
            bookUrl: bookUrl
        )
        
        book.lastReadChapter = lastReadChapter
        book.lastReadPosition = lastReadPosition
        book.totalChapters = totalChapters
        book.isFavorite = isFavorite
        
        return book
    }
    
    // MARK: - BookSource Operations
    
    func saveBookSource(_ source: BookSource) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO bookSources (
                id, name, url, type, isEnabled, weight, lastUpdateTime, rule
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        let ruleData = try? JSONEncoder().encode(source.rule)
        let ruleString = ruleData.flatMap { String(data: $0, encoding: .utf8) }
        
        sqlite3_bind_text(statement, 1, (source.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (source.name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (source.url as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (source.type.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 5, source.isEnabled ? 1 : 0)
        sqlite3_bind_int(statement, 6, Int32(source.weight))
        sqlite3_bind_text(statement, 7, (source.lastUpdateTime.ISO8601Format() as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 8, (ruleString as NSString?)?.utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        return result
    }
    
    func getAllBookSources() -> [BookSource] {
        let sql = "SELECT * FROM bookSources ORDER BY weight DESC;"
        var sources: [BookSource] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return sources
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let source = bookSourceFromStatement(statement) {
                sources.append(source)
            }
        }
        
        sqlite3_finalize(statement)
        return sources
    }
    
    private func bookSourceFromStatement(_ statement: OpaquePointer?) -> BookSource? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let name = String(cString: sqlite3_column_text(statement, 1))
        let url = String(cString: sqlite3_column_text(statement, 2))
        let typeString = String(cString: sqlite3_column_text(statement, 3))
        let type = SourceType(rawValue: typeString) ?? .text
        let isEnabled = sqlite3_column_int(statement, 4) == 1
        let weight = Int(sqlite3_column_int(statement, 5))
        
        var rule = SourceRule()
        if let ruleData = sqlite3_column_text(statement, 7) {
            let ruleString = String(cString: ruleData)
            if let data = ruleString.data(using: .utf8) {
                rule = (try? JSONDecoder().decode(SourceRule.self, from: data)) ?? SourceRule()
            }
        }
        
        return BookSource(
            id: id,
            name: name,
            url: url,
            type: type,
            isEnabled: isEnabled,
            weight: weight,
            rule: rule
        )
    }
}
