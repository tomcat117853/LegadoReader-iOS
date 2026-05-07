import Foundation
import Combine

class BookGroupManager: BaseService, ObservableObject {
    static let shared = BookGroupManager()
    
    @Published var groups: [BookGroup] = []
    @Published var currentFilter: BookGroupFilter = BookGroupFilter()
    @Published var sortOption: GroupSortOption = .manual
    @Published var isEditing = false
    @Published var selectedGroup: BookGroup?
    
    private let storageKey = "BookGroupManager_groups"
    private let sortKey = "BookGroupManager_sortOption"
    
    private init() {
        super.init()
        loadGroups()
        loadSortOption()
        setupDefaultGroups()
    }
    
    private func setupDefaultGroups() {
        if groups.isEmpty {
            let defaultGroups = [
                BookGroup(name: "书架", icon: "books.vertical.fill", order: 0),
                BookGroup(name: "收藏", icon: "star.fill", order: 1),
                BookGroup(name: "阅读中", icon: "book.fill", order: 2),
                BookGroup(name: "已读完", icon: "checkmark.circle.fill", order: 3)
            ]
            groups = defaultGroups
            saveGroups()
        }
    }
    
    var filteredGroups: [BookGroup] {
        return groups.filter { currentFilter.matches($0) }
            .sorted { group1, group2 in
                switch sortOption {
                case .manual:
                    return group1.order < group2.order
                case .name:
                    return group1.name < group2.name
                case .createdTime:
                    return group1.createdTime > group2.createdTime
                case .bookCount:
                    return group1.bookCount > group2.bookCount
                case .updatedTime:
                    return group1.updatedTime > group2.updatedTime
                }
            }
    }
    
    func loadGroups() {
        if let saved = loadCodable([BookGroup].self, key: storageKey) {
            groups = saved
        }
    }
    
    func saveGroups() {
        saveCodable(groups, key: storageKey)
    }
    
    func loadSortOption() {
        if let saved = loadCodable(String.self, key: sortKey),
           let option = GroupSortOption(rawValue: saved) {
            sortOption = option
        }
    }
    
    func saveSortOption() {
        saveCodable(sortOption.rawValue, key: sortKey)
    }
    
    func addGroup(name: String, icon: String = "folder.fill") {
        let maxOrder = groups.map { $0.order }.max() ?? -1
        let group = BookGroup(name: name, icon: icon, order: maxOrder + 1)
        groups.append(group)
        saveGroups()
        logInfo("Added new group: \(name)")
    }
    
    func deleteGroup(_ group: BookGroup) {
        groups.removeAll { $0.id == group.id }
        reorderGroups()
        saveGroups()
        logInfo("Deleted group: \(group.name)")
    }
    
    func updateGroup(_ group: BookGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            var updated = group
            updated.updatedTime = Date()
            groups[index] = updated
            saveGroups()
            logInfo("Updated group: \(group.name)")
        }
    }
    
    func updateGroupInfo(_ groupId: String, editInfo: GroupEditInfo) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            editInfo.apply(to: &groups[index])
            saveGroups()
        }
    }
    
    func moveGroup(from source: IndexSet, to destination: Int) {
        groups.move(fromOffsets: source, toOffset: destination)
        reorderGroups()
        saveGroups()
    }
    
    private func reorderGroups() {
        for (index, _) in groups.enumerated() {
            groups[index].order = index
        }
    }
    
    func addBook(_ bookId: String, to groupId: String) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            if !groups[index].bookIds.contains(bookId) {
                groups[index].bookIds.append(bookId)
                groups[index].updatedTime = Date()
                saveGroups()
                logInfo("Added book \(bookId) to group \(groupId)")
            }
        }
    }
    
    func removeBook(_ bookId: String, from groupId: String) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].bookIds.removeAll { $0 == bookId }
            groups[index].updatedTime = Date()
            saveGroups()
            logInfo("Removed book \(bookId) from group \(groupId)")
        }
    }
    
    func removeBookFromAllGroups(_ bookId: String) {
        for index in groups.indices {
            groups[index].bookIds.removeAll { $0 == bookId }
        }
        saveGroups()
        logInfo("Removed book \(bookId) from all groups")
    }
    
    func getGroupsForBook(_ bookId: String) -> [BookGroup] {
        return groups.filter { $0.bookIds.contains(bookId) }
    }
    
    func getBooksInGroup(_ groupId: String) -> [String] {
        return groups.first { $0.id == groupId }?.bookIds ?? []
    }
    
    func isBookInGroup(_ bookId: String, groupId: String) -> Bool {
        return groups.first { $0.id == groupId }?.bookIds.contains(bookId) ?? false
    }
    
    func toggleLock(_ group: BookGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].isLocked.toggle()
            groups[index].updatedTime = Date()
            saveGroups()
            logInfo("Toggled lock for group: \(group.name) -> \(groups[index].isLocked)")
        }
    }
    
    func toggleHidden(_ group: BookGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].isHidden.toggle()
            groups[index].updatedTime = Date()
            saveGroups()
            logInfo("Toggled hidden for group: \(group.name) -> \(groups[index].isHidden)")
        }
    }
    
    func lockGroup(_ group: BookGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].isLocked = true
            groups[index].updatedTime = Date()
            saveGroups()
        }
    }
    
    func unlockGroup(_ group: BookGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].isLocked = false
            groups[index].updatedTime = Date()
            saveGroups()
        }
    }
    
    func hideGroup(_ group: BookGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].isHidden = true
            groups[index].updatedTime = Date()
            saveGroups()
        }
    }
    
    func unhideGroup(_ group: BookGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].isHidden = false
            groups[index].updatedTime = Date()
            saveGroups()
        }
    }
    
    func setSortOption(_ option: GroupSortOption) {
        sortOption = option
        saveSortOption()
    }
    
    func setFilter(showLocked: Bool? = nil, showHidden: Bool? = nil, searchText: String? = nil) {
        if let showLocked = showLocked {
            currentFilter.showLocked = showLocked
        }
        if let showHidden = showHidden {
            currentFilter.showHidden = showHidden
        }
        if let searchText = searchText {
            currentFilter.searchText = searchText
        }
    }
    
    func resetFilter() {
        currentFilter = BookGroupFilter()
    }
    
    func duplicateGroup(_ group: BookGroup) {
        var newGroup = group
        newGroup.id = UUID().uuidString
        newGroup.name = "\(group.name) (副本)"
        newGroup.order = groups.count
        newGroup.createdTime = Date()
        newGroup.updatedTime = Date()
        groups.append(newGroup)
        saveGroups()
        logInfo("Duplicated group: \(group.name)")
    }
    
    func mergeGroups(sourceId: String, targetId: String) {
        guard let sourceIndex = groups.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = groups.firstIndex(where: { $0.id == targetId }) else {
            return
        }
        
        let sourceBooks = groups[sourceIndex].bookIds
        for bookId in sourceBooks {
            if !groups[targetIndex].bookIds.contains(bookId) {
                groups[targetIndex].bookIds.append(bookId)
            }
        }
        
        groups[targetIndex].updatedTime = Date()
        deleteGroup(groups[sourceIndex])
        logInfo("Merged group \(sourceId) into \(targetId)")
    }
    
    func getGroupById(_ id: String) -> BookGroup? {
        return groups.first { $0.id == id }
    }
    
    func renameGroup(_ group: BookGroup, newName: String) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].name = newName
            groups[index].updatedTime = Date()
            saveGroups()
            logInfo("Renamed group: \(group.name) -> \(newName)")
        }
    }
    
    func setGroupIcon(_ group: BookGroup, icon: String) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].icon = icon
            groups[index].updatedTime = Date()
            saveGroups()
        }
    }
    
    func setGroupCover(_ group: BookGroup, cover: String?) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].coverImage = cover
            groups[index].updatedTime = Date()
            saveGroups()
        }
    }
    
    func setGroupDescription(_ group: BookGroup, description: String?) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].description = description
            groups[index].updatedTime = Date()
            saveGroups()
        }
    }
}
