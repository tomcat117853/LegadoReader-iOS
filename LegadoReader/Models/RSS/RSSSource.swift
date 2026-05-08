import Foundation

struct RSSSource: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var url: String
    var icon: String?
    var isEnabled: Bool
    var lastUpdateTime: Date
    var articles: [RSSArticle]
    
    init(id: String = UUID().uuidString,
         name: String,
         url: String,
         icon: String? = nil,
         isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.icon = icon
        self.isEnabled = isEnabled
        self.lastUpdateTime = Date()
        self.articles = []
    }
}

struct RSSArticle: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var link: String
    var description: String?
    var content: String?
    var author: String?
    var pubDate: Date?
    var cover: String?
    var isRead: Bool
    var isFavorite: Bool
    
    init(id: String = UUID().uuidString,
         title: String,
         link: String,
         description: String? = nil,
         content: String? = nil,
         author: String? = nil,
         pubDate: Date? = nil,
         cover: String? = nil) {
        self.id = id
        self.title = title
        self.link = link
        self.description = description
        self.content = content
        self.author = author
        self.pubDate = pubDate
        self.cover = cover
        self.isRead = false
        self.isFavorite = false
    }
}
