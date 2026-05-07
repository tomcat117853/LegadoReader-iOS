import Foundation

struct MultiLevelChapter: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var level: Int
    var parentId: String?
    var children: [MultiLevelChapter]
    var originalIndex: Int
    var isExpanded: Bool
    var isLocked: Bool
    
    init(id: String = UUID().uuidString,
         title: String,
         level: Int = 0,
         parentId: String? = nil,
         originalIndex: Int = 0) {
        self.id = id
        self.title = title
        self.level = level
        self.parentId = parentId
        self.children = []
        self.originalIndex = originalIndex
        self.isExpanded = true
        self.isLocked = false
    }
    
    var hasChildren: Bool {
        return !children.isEmpty
    }
    
    var displayTitle: String {
        if level > 0 {
            return String(repeating: "　", count: level * 2) + title
        }
        return title
    }
}

class MultiLevelChapterManager: BaseService, ObservableObject {
    static let shared = MultiLevelChapterManager()
    
    @Published var chapters: [MultiLevelChapter] = []
    @Published var expandedIds: Set<String> = []
    @Published var currentChapterId: String?
    
    private let storageKey = "MultiLevelChapterManager_chapters"
    
    private init() {
        super.init()
        loadExpandedState()
    }
    
    func parseChapters(from flatChapters: [Chapter]) -> [MultiLevelChapter] {
        var result: [MultiLevelChapter] = []
        var parentStack: [(id: String, level: Int)] = []
        
        for (index, chapter) in flatChapters.enumerated() {
            let level = detectChapterLevel(chapter.title)
            var chapterItem = MultiLevelChapter(
                title: cleanChapterTitle(chapter.title),
                level: level,
                originalIndex: index
            )
            
            while let last = parentStack.last, last.level >= level {
                parentStack.removeLast()
            }
            
            if let parent = parentStack.last {
                chapterItem.parentId = parent.id
            }
            
            if level > 0 && !parentStack.isEmpty {
                parentStack[parentStack.count - 1].id = chapterItem.id
            } else if level == 0 {
                parentStack.removeAll()
            }
            
            if level > 0 && !parentStack.isEmpty {
                chapterItem.parentId = parentStack[parentStack.count - 1].id
            }
            
            result.append(chapterItem)
            
            if level > 0 {
                parentStack.append((id: chapterItem.id, level: level))
            }
        }
        
        chapters = buildHierarchy(from: result)
        return flattenChapters()
    }
    
    func parseChaptersWithHeaderDetection(_ titles: [String]) -> [MultiLevelChapter] {
        var result: [MultiLevelChapter] = []
        var chapterStack: [(id: String, level: Int)] = []
        
        for (index, title) in titles.enumerated() {
            let level = detectChapterLevelByPattern(title)
            var chapterItem = MultiLevelChapter(
                title: cleanChapterTitle(title),
                level: level,
                originalIndex: index
            )
            
            while let last = chapterStack.last, last.level >= level {
                chapterStack.removeLast()
            }
            
            if let parent = chapterStack.last {
                chapterItem.parentId = parent.id
            }
            
            result.append(chapterItem)
            
            if level > 0 || chapterItem.title.hasPrefix("第") && chapterItem.title.contains("章") {
                chapterStack.append((id: chapterItem.id, level: level))
            }
        }
        
        chapters = buildHierarchy(from: result)
        return flattenChapters()
    }
    
    private func detectChapterLevel(_ title: String) -> Int {
        let patterns = [
            ("^第[一二三四五六七八九十百千万\\d]+[章节篇集卷部部]", 0),
            ("^[一二三四五六七八九十百千万\\d]+[\\.、\\:]", 1),
            ("^[0-9]+\\.[0-9]+", 2),
            ("^[A-Z]\\.[0-9]+", 2),
            ("^[0-9]+", 1)
        ]
        
        for (pattern, level) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) != nil {
                return level
            }
        }
        
        if title.contains("第") && title.contains("章") {
            return 0
        }
        
        return 0
    }
    
    private func detectChapterLevelByPattern(_ title: String) -> Int {
        if title.hasPrefix("第") && (title.contains("章") || title.contains("篇") || title.contains("卷")) {
            return 0
        }
        
        if title.range(of: "^第[一二三四五六七八九十百千]+", options: .regularExpression) != nil {
            return 0
        }
        
        if let regex = try? NSRegularExpression(pattern: "^\\d+[\\.、]", options: []),
           regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) != nil {
            return 1
        }
        
        if let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\d+", options: []),
           regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) != nil {
            return 2
        }
        
        return 0
    }
    
    private func cleanChapterTitle(_ title: String) -> String {
        var cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let patterns = [
            "^[第]?[一二三四五六七八九十百千万\\d]+[章节篇集卷部\\.、\\:\\s]+",
            "^[0-9]+[\\.、\\:]\\s*"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func buildHierarchy(from flatChapters: [MultiLevelChapter]) -> [MultiLevelChapter] {
        var rootChapters: [MultiLevelChapter] = []
        var chapterMap: [String: Int] = [:]
        
        for chapter in flatChapters {
            chapterMap[chapter.id] = rootChapters.count
            var newChapter = chapter
            rootChapters.append(newChapter)
        }
        
        for i in 0..<rootChapters.count {
            if let parentId = rootChapters[i].parentId,
               let parentIndex = chapterMap[parentId] {
                rootChapters[parentIndex].children.append(rootChapters[i])
                rootChapters[i].isExpanded = rootChapters[parentIndex].isExpanded
            }
        }
        
        for i in stride(from: rootChapters.count - 1, through: 0, by: -1) {
            if rootChapters[i].parentId != nil {
                rootChapters.remove(at: i)
            }
        }
        
        return rootChapters
    }
    
    func flattenChapters() -> [MultiLevelChapter] {
        var result: [MultiLevelChapter] = []
        
        func flatten(_ chapters: [MultiLevelChapter]) {
            for chapter in chapters {
                var mutableChapter = chapter
                mutableChapter.isExpanded = expandedIds.contains(chapter.id)
                result.append(mutableChapter)
                if mutableChapter.isExpanded {
                    flatten(chapter.children)
                }
            }
        }
        
        flatten(chapters)
        return result
    }
    
    func toggleExpand(_ chapterId: String) {
        if expandedIds.contains(chapterId) {
            expandedIds.remove(chapterId)
        } else {
            expandedIds.insert(chapterId)
        }
        saveExpandedState()
    }
    
    func expandAll() {
        func collectIds(_ chapters: [MultiLevelChapter]) {
            for chapter in chapters {
                expandedIds.insert(chapter.id)
                collectIds(chapter.children)
            }
        }
        collectIds(chapters)
        saveExpandedState()
    }
    
    func collapseAll() {
        expandedIds.removeAll()
        saveExpandedState()
    }
    
    func getChapterPath(_ chapterId: String) -> [MultiLevelChapter] {
        var path: [MultiLevelChapter] = []
        
        func findPath(_ chapters: [MultiLevelChapter], target: String) -> Bool {
            for chapter in chapters {
                if chapter.id == target {
                    path.append(chapter)
                    return true
                }
                
                path.append(chapter)
                if findPath(chapter.children, target: target) {
                    return true
                }
                path.removeLast()
            }
            return false
        }
        
        _ = findPath(chapters, target: chapterId)
        return path
    }
    
    func getRootChapter(_ chapterId: String) -> MultiLevelChapter? {
        let path = getChapterPath(chapterId)
        return path.first
    }
    
    func getParentChapter(_ chapterId: String) -> MultiLevelChapter? {
        let path = getChapterPath(chapterId)
        if path.count >= 2 {
            return path[path.count - 2]
        }
        return nil
    }
    
    func getChildChapters(_ chapterId: String) -> [MultiLevelChapter] {
        func findChildren(_ chapters: [MultiLevelChapter], parentId: String) -> [MultiLevelChapter]? {
            for chapter in chapters {
                if chapter.id == parentId {
                    return chapter.children
                }
                if let found = findChildren(chapter.children, parentId: parentId) {
                    return found
                }
            }
            return nil
        }
        return findChildren(chapters, parentId: chapterId) ?? []
    }
    
    func getSiblingChapters(_ chapterId: String) -> [MultiLevelChapter] {
        if let parent = getParentChapter(chapterId) {
            return parent.children
        }
        return chapters
    }
    
    func getNextChapter(_ chapterId: String) -> MultiLevelChapter? {
        let flat = flattenChapters()
        if let index = flat.firstIndex(where: { $0.id == chapterId }),
           index + 1 < flat.count {
            return flat[index + 1]
        }
        return nil
    }
    
    func getPreviousChapter(_ chapterId: String) -> MultiLevelChapter? {
        let flat = flattenChapters()
        if let index = flat.firstIndex(where: { $0.id == chapterId }),
           index > 0 {
            return flat[index - 1]
        }
        return nil
    }
    
    func setCurrentChapter(_ chapterId: String) {
        currentChapterId = chapterId
        
        var current: String? = chapterId
        while let cid = current {
            expandedIds.insert(cid)
            let parent = getParentChapter(cid)
            current = parent?.id
        }
        saveExpandedState()
    }
    
    private func saveExpandedState() {
        saveCodable(Array(expandedIds), key: storageKey + "_expanded")
    }
    
    private func loadExpandedState() {
        if let saved = loadCodable([String].self, key: storageKey + "_expanded") {
            expandedIds = Set(saved)
        }
    }
}

extension Chapter {
    var multiLevelTitle: String {
        return title
    }
}
