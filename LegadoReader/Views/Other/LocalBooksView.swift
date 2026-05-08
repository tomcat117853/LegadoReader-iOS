import SwiftUI

struct LocalBooksView: View {
    @StateObject private var bookManager = LocalBookManager.shared
    @StateObject private var groupManager = BookGroupManager.shared
    @StateObject private var bookStore = BookStore.shared
    @State private var showingImport = false
    @State private var showingGroupManager = false
    @State private var showingNewGroupSheet = false
    @State private var selectedBook: Book?
    @State private var selectedGroup: BookGroup?
    @State private var showingGroupDetail: BookGroup?
    @State private var showingLockedGroup: BookGroup?
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var currentFilter: BookFilter = BookFilter()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if showingSearch || currentFilter.hasActiveFilters {
                    filterBar
                }
                
                groupListView
            }
            .navigationTitle("本地书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showingSearch.toggle() }) {
                            Label(showingSearch ? "关闭搜索" : "搜索书籍", systemImage: "magnifyingglass")
                        }
                        
                        Button(action: { showingFilterSheet = true }) {
                            Label("筛选与排序", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        if currentFilter.hasActiveFilters {
                            Divider()
                            Button(role: .destructive, action: { currentFilter = BookFilter() }) {
                                Label("清除筛选", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: currentFilter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingGroupManager = true }) {
                        Image(systemName: "folder.badge.gearshape")
                    }
                    
                    Button(action: { showingNewGroupSheet = true }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    
                    Button(action: { showingImport = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImport) {
                // Import sheet
            }
            .sheet(isPresented: $showingGroupManager) {
                GroupManagementView()
            }
            .sheet(isPresented: $showingNewGroupSheet) {
                NewGroupSheet()
            }
            .sheet(isPresented: $showingGroupDetail) {
                GroupDetailView(group: $showingGroupDetail.wrappedValue!)
            }
            .sheet(isPresented: $showingLockedGroup) {
                LockUnlockView(groupId: $showingLockedGroup.wrappedValue!.id, onSuccess: {
                    showingLockedGroup = nil
                    selectedGroup = $showingLockedGroup.wrappedValue
                }, onCancel: {
                    showingLockedGroup = nil
                })
            }
            .sheet(item: $selectedBook) { book in
                EnhancedBookDetailView(book: book)
            }
            .sheet(isPresented: $showingFilterSheet) {
                BookFilterSheet(filter: $currentFilter)
            }
        }
    }
    
    private var filterBar: some View {
        VStack(spacing: 8) {
            if showingSearch {
                searchBar
            }
            
            if currentFilter.hasActiveFilters {
                activeFiltersView
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if currentFilter.hasFormatFilter {
                    FilterChip(title: "格式: \(currentFilter.selectedFormats.map { $0.uppercased() }.joined(separator: ", "))") {
                        currentFilter.selectedFormats.removeAll()
                    }
                }
                
                if currentFilter.hasStatusFilter {
                    FilterChip(title: "状态: \(formatFilterStatus(currentFilter.readStatus))") {
                        currentFilter.readStatus = nil
                    }
                }
                
                if currentFilter.hasProgressFilter {
                    FilterChip(title: "进度: \(formatProgressFilter(currentFilter.progressRange))") {
                        currentFilter.progressRange = nil
                    }
                }
                
                if currentFilter.hasSortFilter {
                    FilterChip(title: "排序: \(formatSortOption(currentFilter.sortOption))") {
                        currentFilter.sortOption = .name
                    }
                }
            }
        }
    }
    
    private func formatFilterStatus(_ status: BookFilter.ReadStatus?) -> String {
        guard let status = status else { return "" }
        switch status {
        case .unread: return "未读"
        case .reading: return "在读"
        case .completed: return "已读完"
        }
    }
    
    private func formatProgressFilter(_ range: ClosedRange<Double>?) -> String {
        guard let range = range else { return "" }
        return "\(Int(range.lowerBound * 100))%-\(Int(range.upperBound * 100))%"
    }
    
    private func formatSortOption(_ option: BookFilter.SortOption) -> String {
        switch option {
        case .name: return "名称"
        case .author: return "作者"
        case .recentlyRead: return "最近阅读"
        case .recentlyAdded: return "最近添加"
        case .progress: return "阅读进度"
        case .size: return "文件大小"
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索书籍", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var groupListView: some View {
        List {
            ForEach(filteredGroups) { group in
                GroupRowView(
                    group: group,
                    onTap: { handleGroupTap(group) },
                    onDelete: { handleDeleteGroup(group) }
                )
            }
        }
        .listStyle(.plain)
        .overlay {
            if groupManager.filteredGroups.isEmpty {
                emptyView
            }
        }
    }
    
    private var filteredGroups: [BookGroup] {
        var groups = groupManager.filteredGroups
        
        if !searchText.isEmpty {
            groups = groups.map { group in
                var filtered = group
                filtered.bookIds = group.bookIds.filter { bookId in
                    if let book = bookStore.books.first(where: { $0.id == bookId }) {
                        return book.name.localizedCaseInsensitiveContains(searchText) ||
                               book.author.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                }
                return filtered
            }.filter { !$0.bookIds.isEmpty }
        }
        
        return groups
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("暂无书籍")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("点击右上角按钮导入书籍或创建分组")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func handleGroupTap(_ group: BookGroup) {
        if group.isLocked {
            showingLockedGroup = group
        } else {
            selectedGroup = group
            showingGroupDetail = group
        }
    }
    
    private func handleDeleteGroup(_ group: BookGroup) {
        groupManager.deleteGroup(group)
    }
}

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.2))
        .foregroundColor(.accentColor)
        .cornerRadius(16)
    }
}

struct BookFilter {
    enum ReadStatus: String, CaseIterable {
        case unread = "未读"
        case reading = "在读"
        case completed = "已读完"
    }
    
    enum SortOption: String, CaseIterable {
        case name = "名称"
        case author = "作者"
        case recentlyRead = "最近阅读"
        case recentlyAdded = "最近添加"
        case progress = "阅读进度"
        case size = "文件大小"
    }
    
    var selectedFormats: [String] = []
    var readStatus: ReadStatus?
    var progressRange: ClosedRange<Double>?
    var sortOption: SortOption = .name
    var sortAscending: Bool = true
    
    var hasActiveFilters: Bool {
        return hasFormatFilter || hasStatusFilter || hasProgressFilter || hasSortFilter
    }
    
    var hasFormatFilter: Bool {
        return !selectedFormats.isEmpty
    }
    
    var hasStatusFilter: Bool {
        return readStatus != nil
    }
    
    var hasProgressFilter: Bool {
        return progressRange != nil
    }
    
    var hasSortFilter: Bool {
        return sortOption != .name || !sortAscending
    }
    
    func matches(book: Book, progress: ReadingProgress?) -> Bool {
        if hasFormatFilter && !selectedFormats.contains(book.format.lowercased()) {
            return false
        }
        
        if hasStatusFilter {
            let progressValue = progress?.progress ?? 0
            switch readStatus {
            case .unread:
                if progressValue > 0 { return false }
            case .reading:
                if progressValue == 0 || progressValue >= 0.95 { return false }
            case .completed:
                if progressValue < 0.95 { return false }
            case .none:
                break
            }
        }
        
        if hasProgressFilter, let range = progressRange {
            let progressValue = progress?.progress ?? 0
            if !range.contains(progressValue) { return false }
        }
        
        return true
    }
    
    func sort(_ books: [Book], by progressMap: [String: ReadingProgress]) -> [Book] {
        return books.sorted { book1, book2 in
            let progress1 = progressMap[book1.id]
            let progress2 = progressMap[book2.id]
            
            let result: Bool
            switch sortOption {
            case .name:
                result = book1.name < book2.name
            case .author:
                result = book1.author < book2.author
            case .recentlyRead:
                result = (progress1?.lastReadTime ?? .distantPast) > (progress2?.lastReadTime ?? .distantPast)
            case .recentlyAdded:
                result = book1.addedAt > book2.addedAt
            case .progress:
                result = (progress1?.progress ?? 0) > (progress2?.progress ?? 0)
            case .size:
                result = book1.fileSize > book2.fileSize
            }
            
            return sortAscending ? result : !result
        }
    }
}

struct BookFilterSheet: View {
    @Binding var filter: BookFilter
    @Environment(\.dismiss) private var dismiss
    
    let allFormats = ["txt", "epub", "pdf", "mobi", "azw", "fb2", "chm", "rtf", "html", "docx", "zip", "7z", "tar", "xz"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("按格式筛选") {
                    ForEach(allFormats, id: \.self) { format in
                        HStack {
                            Text(format.uppercased())
                            Spacer()
                            if filter.selectedFormats.contains(format) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if filter.selectedFormats.contains(format) {
                                filter.selectedFormats.removeAll { $0 == format }
                            } else {
                                filter.selectedFormats.append(format)
                            }
                        }
                    }
                }
                
                Section("按阅读状态筛选") {
                    ForEach(BookFilter.ReadStatus.allCases, id: \.self) { status in
                        HStack {
                            Text(status.rawValue)
                            Spacer()
                            if filter.readStatus == status {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if filter.readStatus == status {
                                filter.readStatus = nil
                            } else {
                                filter.readStatus = status
                            }
                        }
                    }
                    
                    if filter.readStatus != nil {
                        Button("清除状态筛选") {
                            filter.readStatus = nil
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("按阅读进度筛选") {
                    Picker("进度范围", selection: Binding(
                        get: { filter.progressRange ?? 0...1 },
                        set: { filter.progressRange = $0 }
                    )) {
                        Text("全部").tag(0.0...1.0)
                        Text("0-25%").tag(0.0...0.25)
                        Text("25-50%").tag(0.25...0.5)
                        Text("50-75%").tag(0.5...0.75)
                        Text("75-100%").tag(0.75...1.0)
                    }
                    .pickerStyle(.menu)
                }
                
                Section("排序方式") {
                    Picker("排序", selection: $filter.sortOption) {
                        ForEach(BookFilter.SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    Toggle("升序", isOn: $filter.sortAscending)
                }
            }
            .navigationTitle("筛选与排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        filter = BookFilter()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GroupRowView: View {
    let group: BookGroup
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var bookStore = BookStore.shared
    @State private var books: [Book] = []
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(groupColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: group.icon)
                            .font(.system(size: 28))
                            .foregroundColor(groupColor)
                        
                        if group.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .offset(x: 18, y: -18)
                        }
                        
                        if group.isHidden {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .offset(x: -18, y: -18)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(group.bookCount) 本书")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                if !books.isEmpty {
                    bookCoverRow
                }
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .onAppear {
            loadBooks()
        }
    }
    
    private var groupColor: Color {
        switch group.icon {
        case "star.fill": return .yellow
        case "heart.fill": return .red
        case "bookmark.fill": return .green
        case "flag.fill": return .orange
        case "crown.fill": return .purple
        default: return .blue
        }
    }
    
    private var bookCoverRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(books.prefix(6)) { book in
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 56)
                            
                            if let cover = book.cover, let url = URL(string: cover) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 40, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if book.progress > 0 {
                            ProgressView(value: book.progress)
                                .progressViewStyle(.linear)
                                .frame(width: 40)
                                .tint(.blue)
                        }
                    }
                }
            }
            .padding(.leading, 76)
        }
    }
    
    private func loadBooks() {
        books = group.bookIds.compactMap { bookId in
            bookStore.books.first { $0.id == bookId }
        }
    }
}

struct GroupManagementView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var showingNewGroup = false
    @State private var selectedGroup: BookGroup?
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupManager.groups) { group in
                    Button(action: {
                        selectedGroup = group
                        showingEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: group.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(group.name)
                                        .foregroundColor(.primary)
                                    
                                    if group.isLocked {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    if group.isHidden {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Text("\(group.bookCount) 本书")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            groupManager.deleteGroup(group)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: moveGroups)
            }
            .listStyle(.plain)
            .navigationTitle("分组管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewGroup = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewGroup) {
                NewGroupSheet()
            }
            .sheet(isPresented: $showingEditSheet) {
                if let group = selectedGroup {
                    GroupDetailView(group: group)
                }
            }
        }
    }
    
    private func moveGroups(from source: IndexSet, to destination: Int) {
        groupManager.moveGroup(from: source, to: destination)
    }
}
