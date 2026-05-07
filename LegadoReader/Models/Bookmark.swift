import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var url: String
    var icon: String
    var category: BookmarkCategory
    var tags: [String]
    var createdTime: Date
    var updatedTime: Date
    var visitCount: Int
    var lastVisitTime: Date?
    var readingDuration: TimeInterval
    var listeningDuration: TimeInterval
    var note: String?
    var isPinned: Bool
    var isFavorite: Bool
    var customOrder: Int
    
    init(id: String = UUID().uuidString,
         name: String,
         url: String,
         icon: String = "link",
         category: BookmarkCategory = .general) {
        self.id = id
        self.name = name
        self.url = url
        self.icon = icon
        self.category = category
        self.tags = []
        self.createdTime = Date()
        self.updatedTime = Date()
        self.visitCount = 0
        self.lastVisitTime = nil
        self.readingDuration = 0
        self.listeningDuration = 0
        self.note = nil
        self.isPinned = false
        self.isFavorite = false
        self.customOrder = 0
    }
    
    var totalDuration: TimeInterval {
        return readingDuration + listeningDuration
    }
    
    var totalDurationFormatted: String {
        return formatDuration(totalDuration)
    }
    
    var readingDurationFormatted: String {
        return formatDuration(readingDuration)
    }
    
    var listeningDurationFormatted: String {
        return formatDuration(listeningDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "< 1分钟"
        }
    }
}

enum BookmarkCategory: String, Codable, CaseIterable {
    case general = "通用"
    case reading = "阅读"
    case listening = "听书"
    case learning = "学习"
    case work = "工作"
    case entertainment = "娱乐"
    case custom = "自定义"
    
    var icon: String {
        switch self {
        case .general: return "link"
        case .reading: return "book.fill"
        case .listening: return "headphones"
        case .learning: return "graduationcap.fill"
        case .work: return "briefcase.fill"
        case .entertainment: return "gamecontroller.fill"
        case .custom: return "folder.fill"
        }
    }
}

struct BookmarkEditInfo: Codable {
    var name: String
    var url: String
    var icon: String
    var category: BookmarkCategory
    var tags: [String]
    var note: String?
    
    init(from bookmark: Bookmark) {
        self.name = bookmark.name
        self.url = bookmark.url
        self.icon = bookmark.icon
        self.category = bookmark.category
        self.tags = bookmark.tags
        self.note = bookmark.note
    }
    
    func apply(to bookmark: inout Bookmark) {
        bookmark.name = name
        bookmark.url = url
        bookmark.icon = icon
        bookmark.category = category
        bookmark.tags = tags
        bookmark.note = note
        bookmark.updatedTime = Date()
    }
}

struct BookmarkFolder: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var parentId: String?
    var bookmarkIds: [String]
    var createdTime: Date
    var updatedTime: Date
    var isExpanded: Bool
    
    init(id: String = UUID().uuidString,
         name: String,
         icon: String = "folder.fill",
         parentId: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.parentId = parentId
        self.bookmarkIds = []
        self.createdTime = Date()
        self.updatedTime = Date()
        self.isExpanded = true
    }
    
    var bookmarkCount: Int {
        return bookmarkIds.count
    }
}

enum BookmarkSortOption: String, CaseIterable {
    case custom = "自定义排序"
    case name = "名称"
    case createdTime = "创建时间"
    case lastVisit = "最近访问"
    case visitCount = "访问次数"
    case readingDuration = "阅读时长"
    case listeningDuration = "听书时长"
    case totalDuration = "总时长"
    
    func compare(_ b1: Bookmark, _ b2: Bookmark) -> Bool {
        switch self {
        case .custom:
            return b1.customOrder < b2.customOrder
        case .name:
            return b1.name.localizedCompare(b2.name) == .orderedAscending
        case .createdTime:
            return b1.createdTime > b2.createdTime
        case .lastVisit:
            guard let t1 = b1.lastVisitTime, let t2 = b2.lastVisitTime else {
                return b1.lastVisitTime != nil
            }
            return t1 > t2
        case .visitCount:
            return b1.visitCount > b2.visitCount
        case .readingDuration:
            return b1.readingDuration > b2.readingDuration
        case .listeningDuration:
            return b1.listeningDuration > b2.listeningDuration
        case .totalDuration:
            return b1.totalDuration > b2.totalDuration
        }
    }
}

struct BookmarkFilter {
    var searchText: String = ""
    var category: BookmarkCategory?
    var tags: [String] = []
    var showPinnedOnly: Bool = false
    var showFavoritesOnly: Bool = false
    
    func matches(_ bookmark: Bookmark) -> Bool {
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            let nameMatch = bookmark.name.lowercased().contains(lowercasedSearch)
            let urlMatch = bookmark.url.lowercased().contains(lowercasedSearch)
            let tagMatch = bookmark.tags.contains { $0.lowercased().contains(lowercasedSearch) }
            if !nameMatch && !urlMatch && !tagMatch {
                return false
            }
        }
        
        if let category = category, bookmark.category != category {
            return false
        }
        
        if !tags.isEmpty {
            let hasMatchingTag = bookmark.tags.contains { tags.contains($0) }
            if !hasMatchingTag {
                return false
            }
        }
        
        if showPinnedOnly && !bookmark.isPinned {
            return false
        }
        
        if showFavoritesOnly && !bookmark.isFavorite {
            return false
        }
        
        return true
    }
}
