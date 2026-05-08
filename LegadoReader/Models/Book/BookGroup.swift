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
    var password: String?
    var passwordHint: String?
    
    enum LayoutStyle: String, Codable, CaseIterable {
        case grid = "grid"
        case list = "list"
        case cover = "cover"
        
        var displayName: String {
            switch self {
            case .grid: return "网格布局"
            case .list: return "列表布局"
            case .cover: return "封面布局"
            }
        }
        
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            case .cover: return "photo.stack"
            }
        }
    }
    
    var layoutStyle: LayoutStyle = .grid
    var sortOption: String = "namePinyin"
    var sortAscending: Bool = true
    var columnsCount: Int = 3
    
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
        self.password = nil
        self.passwordHint = nil
        self.layoutStyle = .grid
        self.sortOption = "namePinyin"
        self.sortAscending = true
        self.columnsCount = 3
    }
    
    var bookCount: Int {
        return bookIds.count
    }
    
    var displayName: String {
        return name
    }
    
    var hasPassword: Bool {
        return password != nil && !(password?.isEmpty ?? true)
    }
    
    func getSortIcon() -> String {
        switch sortOption {
        case "namePinyin": return "textformat.abc"
        case "authorPinyin": return "person"
        case "lastRead": return "clock"
        case "addedTime": return "calendar"
        case "name": return "textformat"
        default: return "arrow.up.arrow.down"
        }
    }
    
    func getSortName() -> String {
        switch sortOption {
        case "namePinyin": return "按书名拼音"
        case "authorPinyin": return "按作者拼音"
        case "lastRead": return "最近阅读"
        case "addedTime": return "添加时间"
        case "name": return "书名排序"
        default: return sortOption
        }
    }
}

struct GroupEditInfo: Codable {
    var name: String
    var icon: String
    var description: String?
    var isLocked: Bool
    var isHidden: Bool
    var coverImage: String?
    var password: String?
    var passwordHint: String?
    var layoutStyle: BookGroup.LayoutStyle
    var sortOption: String
    var sortAscending: Bool
    var columnsCount: Int
    
    init(from group: BookGroup) {
        self.name = group.name
        self.icon = group.icon
        self.description = group.description
        self.isLocked = group.isLocked
        self.isHidden = group.isHidden
        self.coverImage = group.coverImage
        self.password = group.password
        self.passwordHint = group.passwordHint
        self.layoutStyle = group.layoutStyle
        self.sortOption = group.sortOption
        self.sortAscending = group.sortAscending
        self.columnsCount = group.columnsCount
    }
    
    func apply(to group: inout BookGroup) {
        group.name = name
        group.icon = icon
        group.description = description
        group.isLocked = isLocked
        group.isHidden = isHidden
        group.coverImage = coverImage
        group.password = password
        group.passwordHint = passwordHint
        group.layoutStyle = layoutStyle
        group.sortOption = sortOption
        group.sortAscending = sortAscending
        group.columnsCount = columnsCount
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
