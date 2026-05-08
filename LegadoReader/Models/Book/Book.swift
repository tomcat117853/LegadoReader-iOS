import Foundation

struct Book: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var author: String
    var cover: String?
    var intro: String?
    var lastChapter: String?
    var lastReadChapter: String?
    var lastReadPosition: Int
    var totalChapters: Int
    var sourceUrl: String
    var sourceName: String
    var bookUrl: String
    var isFavorite: Bool
    var lastReadTime: Date?
    var addedTime: Date
    var updatedTime: Date?
    
    init(id: String = UUID().uuidString,
         name: String,
         author: String,
         cover: String? = nil,
         intro: String? = nil,
         lastChapter: String? = nil,
         sourceUrl: String,
         sourceName: String,
         bookUrl: String) {
        self.id = id
        self.name = name
        self.author = author
        self.cover = cover
        self.intro = intro
        self.lastChapter = lastChapter
        self.lastReadChapter = nil
        self.lastReadPosition = 0
        self.totalChapters = 0
        self.sourceUrl = sourceUrl
        self.sourceName = sourceName
        self.bookUrl = bookUrl
        self.isFavorite = true
        self.lastReadTime = nil
        self.addedTime = Date()
        self.updatedTime = nil
    }
}

struct Chapter: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var url: String
    var index: Int
    var content: String?
    var isLoaded: Bool
    
    init(id: String = UUID().uuidString,
         title: String,
         url: String,
         index: Int,
         content: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.index = index
        self.content = content
        self.isLoaded = content != nil
    }
}

struct BookShelf: Codable {
    var books: [Book]
    var sortType: SortType
    
    enum SortType: String, Codable {
        case lastRead
        case addedTime
        case name
        case updated
    }
}
