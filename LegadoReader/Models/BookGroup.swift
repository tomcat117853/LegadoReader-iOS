import Foundation

struct BookGroup: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var order: Int
    var isLocked: Bool
    var isHidden: Bool
    var bookIds: [String]
    var createdTime: Date
    var updatedTime: Date
    var coverImage: String?
    var description: String?
    
    init(id: String = UUID().uuidString,
         name: String,
         icon: String = "folder.fill",
         order: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.order = order
        self.isLocked = false
        self.isHidden = false
        self.bookIds = []
        self.createdTime = Date()
        self.updatedTime = Date()
        self.coverImage = nil
        self.description = nil
    }
    
    var bookCount: Int {
        return bookIds.count
    }
    
    var displayName: String {
        return name
    }
}

struct GroupEditInfo: Codable {
    var name: String
    var icon: String
    var description: String?
    var isLocked: Bool
    var isHidden: Bool
    var coverImage: String?
    
    init(from group: BookGroup) {
        self.name = group.name
        self.icon = group.icon
        self.description = group.description
        self.isLocked = group.isLocked
        self.isHidden = group.isHidden
        self.coverImage = group.coverImage
    }
    
    func apply(to group: inout BookGroup) {
        group.name = name
        group.icon = icon
        group.description = description
        group.isLocked = isLocked
        group.isHidden = isHidden
        group.coverImage = coverImage
        group.updatedTime = Date()
    }
}

struct BookGroupFilter {
    var showLocked: Bool = true
    var showHidden: Bool = false
    var searchText: String = ""
    
    func matches(_ group: BookGroup) -> Bool {
        if group.isHidden && !showHidden {
            return false
        }
        if !searchText.isEmpty && !group.name.localizedCaseInsensitiveContains(searchText) {
            return false
        }
        return true
    }
}

enum GroupSortOption: String, CaseIterable {
    case manual = "手动排序"
    case name = "名称"
    case createdTime = "创建时间"
    case bookCount = "书籍数量"
    case updatedTime = "更新时间"
}
