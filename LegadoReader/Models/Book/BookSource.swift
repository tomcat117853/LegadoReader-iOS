import Foundation

struct BookSource: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var url: String
    var type: SourceType
    var isEnabled: Bool
    var weight: Int
    var lastUpdateTime: Date
    var rule: SourceRule
    
    init(id: String = UUID().uuidString,
         name: String,
         url: String,
         type: SourceType = .text,
         isEnabled: Bool = true,
         weight: Int = 1000,
         rule: SourceRule) {
        self.id = id
        self.name = name
        self.url = url
        self.type = type
        self.isEnabled = isEnabled
        self.weight = weight
        self.lastUpdateTime = Date()
        self.rule = rule
    }
}

enum SourceType: String, Codable, CaseIterable {
    case text = "text"
    case comic = "comic"
    case audio = "audio"
    case video = "video"
    
    var displayName: String {
        switch self {
        case .text: return "文本/小说"
        case .comic: return "图片/漫画"
        case .audio: return "音频/听书"
        case .video: return "视频/影视"
        }
    }
}

struct SourceRule: Codable, Equatable {
    var searchBook: SearchRule?
    var bookDetail: DetailRule?
    var chapterList: ChapterListRule?
    var chapterContent: ContentRule?
    var discover: DiscoverRule?
}

struct SearchRule: Codable, Equatable {
    var url: String
    var method: String
    var body: String?
    var headers: [String: String]?
    var bookList: String
    var name: String
    var author: String?
    var cover: String?
    var intro: String?
    var lastChapter: String?
    var bookUrl: String
}

struct DetailRule: Codable, Equatable {
    var name: String?
    var author: String?
    var cover: String?
    var intro: String?
    var lastChapter: String?
    var chapterListUrl: String?
}

struct ChapterListRule: Codable, Equatable {
    var chapterList: String
    var chapterName: String
    var chapterUrl: String
    var isVip: String?
    var updateTime: String?
}

struct ContentRule: Codable, Equatable {
    var content: String
    var nextPage: String?
    var replaceRules: [ReplaceRule]?
}

struct ReplaceRule: Codable, Equatable {
    var pattern: String
    var replacement: String
    var isRegex: Bool
    var isEnabled: Bool = true
    
    init(pattern: String, replacement: String, isRegex: Bool, isEnabled: Bool = true) {
        self.pattern = pattern
        self.replacement = replacement
        self.isRegex = isRegex
        self.isEnabled = isEnabled
    }
}

struct DiscoverRule: Codable, Equatable {
    var url: String
    var categories: [DiscoverCategory]
}

struct DiscoverCategory: Codable, Equatable {
    var name: String
    var url: String
}
