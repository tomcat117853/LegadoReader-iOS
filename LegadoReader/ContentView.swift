import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var sourceStore: SourceStore
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BookshelfView()
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("书架")
                }
                .tag(0)
            
            ExploreView()
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text("探索")
                }
                .tag(1)
            
            LibraryView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("本地")
                }
                .tag(2)
            
            ReadingProgressView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("阅读")
                }
                .tag(3)
            
            ComicBookshelfView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("漫画")
                }
                .tag(4)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
                .tag(5)
        }
        .accentColor(.blue)
    }
}

// MARK: - Bookshelf View

struct BookshelfView: View {
    @EnvironmentObject var bookStore: BookStore
    @StateObject private var notificationManager = UpdateNotificationManager.shared
    @State private var isGridView = true
    @State private var showingNotifications = false
    @State private var showingBrowser = false
    @State private var selectedBook: Book?
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var sortOption: BookSortOption = .namePinyin
    @State private var showingSortOptions = false
    @State private var filterOption: FilterOption = .all
    @State private var showingFilterSheet = false
    @State private var selectedAuthor: String = ""
    @State private var selectedTag: String = ""
    @State private var showingGroupSelector = false
    @State private var bookToGroup: Book?
    
    enum BookSortOption: String, CaseIterable, Identifiable {
        case namePinyin = "按书名拼音"
        case authorPinyin = "按作者拼音"
        case lastRead = "最近阅读"
        case addedTime = "添加时间"
        case name = "书名排序"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .namePinyin: return "textformat.abc"
            case .authorPinyin: return "person"
            case .lastRead: return "clock"
            case .addedTime: return "calendar"
            case .name: return "textformat"
            }
        }
    }
    
    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "全部"
        case unread = "未读"
        case reading = "在读"
        case completed = "已读完"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .all: return "books.vertical"
            case .unread: return "book.closed"
            case .reading: return "book"
            case .completed: return "checkmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .blue
            case .unread: return .orange
            case .reading: return .green
            case .completed: return .purple
            }
        }
    }
    
    private var uniqueAuthors: [String] {
        Array(Set(bookStore.books.map { $0.author })).sorted()
    }
    
    private var uniqueTags: [String] {
        let allTags = bookStore.books.compactMap { $0.kind }
        return Array(Set(allTags)).sorted()
    }
    
    private func filterBooks(_ books: [Book]) -> [Book] {
        var filtered = books
        
        switch filterOption {
        case .all:
            break
        case .unread:
            filtered = filtered.filter { $0.lastReadTime == nil && $0.lastReadPosition == 0 }
        case .reading:
            filtered = filtered.filter { $0.lastReadTime != nil && $0.lastReadPosition > 0 }
        case .completed:
            filtered = filtered.filter { $0.lastReadPosition > 0 && $0.totalChapters > 0 && $0.lastReadPosition >= $0.totalChapters - 1 }
        }
        
        if !selectedAuthor.isEmpty {
            filtered = filtered.filter { $0.author == selectedAuthor }
        }
        
        if !selectedTag.isEmpty {
            filtered = filtered.filter { $0.kind == selectedTag }
        }
        
        return filtered
    }
    
    private func sortBooks(_ books: [Book]) -> [Book] {
        switch sortOption {
        case .namePinyin:
            return books.sorted { PinyinUtil.getPinyin(for: $0.name) < PinyinUtil.getPinyin(for: $1.name) }
        case .authorPinyin:
            return books.sorted { PinyinUtil.getPinyin(for: $0.author) < PinyinUtil.getPinyin(for: $1.author) }
        case .lastRead:
            return books.sorted { ($0.lastReadTime ?? .distantPast) > ($1.lastReadTime ?? .distantPast) }
        case .addedTime:
            return books.sorted { $0.addedTime > $1.addedTime }
        case .name:
            return books.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
    
    private var filteredBooks: [Book] {
        let baseBooks: [Book]
        if searchText.isEmpty {
            baseBooks = bookStore.books
        } else {
            let query = searchText.lowercased()
            baseBooks = bookStore.books.filter { book in
                book.name.lowercased().contains(query) ||
                book.author.lowercased().contains(query) ||
                (book.kind?.lowercased().contains(query) ?? false) ||
                (book.intro?.lowercased().contains(query) ?? false) ||
                (book.sourceName.lowercased().contains(query))
            }
        }
        let filtered = filterBooks(baseBooks)
        return sortBooks(filtered)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                PullToSearchView(
                    searchText: $searchText,
                    isSearchActive: $isSearchActive,
                    pullOffset: scrollOffset
                )
                .animation(.easeInOut(duration: 0.2), value: isSearchActive)
                
                filterBar
                
                ScrollView {
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                    }
                    LazyVStack(spacing: 0) {
                        if bookStore.books.isEmpty {
                            EmptyBookshelfView()
                        } else if filteredBooks.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("未找到匹配书籍")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("尝试其他关键词")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        } else if isGridView {
                            GridBookshelfView(books: filteredBooks, selectedBook: $selectedBook, showingGroupSelector: $showingGroupSelector, bookToGroup: $bookToGroup)
                        } else {
                            ListBookshelfView(books: filteredBooks, selectedBook: $selectedBook, showingGroupSelector: $showingGroupSelector, bookToGroup: $bookToGroup)
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    handleScrollOffset(value)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isGridView.toggle() }) {
                        Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(BookSortOption.allCases) { option in
                            Button(action: {
                                sortOption = option
                            }) {
                                HStack {
                                    Image(systemName: option.icon)
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingBrowser = true }) {
                        Image(systemName: "globe")
                    }
                    Button(action: { showingNotifications = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                            if notificationManager.getUnreadCount() > 0 {
                                Text("\(notificationManager.getUnreadCount())")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNotifications) {
                UpdateHistoryView()
            }
            .sheet(isPresented: $showingBrowser) {
                WebBrowserView()
            }
            .sheet(item: $selectedBook) { book in
                EnhancedBookDetailView(book: book)
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView(
                    filterOption: $filterOption,
                    selectedAuthor: $selectedAuthor,
                    selectedTag: $selectedTag,
                    uniqueAuthors: uniqueAuthors,
                    uniqueTags: uniqueTags
                )
            }
            .sheet(item: $bookToGroup) { book in
                GroupSelectorView(book: book)
            }
        }
    }
    
    private var filterBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterOption.allCases) { option in
                        FilterChip(
                            title: option.rawValue,
                            icon: option.icon,
                            color: option.color,
                            isSelected: filterOption == option && selectedAuthor.isEmpty && selectedTag.isEmpty,
                            count: countForFilter(option)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filterOption = option
                                selectedAuthor = ""
                                selectedTag = ""
                            }
                        }
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    FilterChip(
                        title: selectedAuthor.isEmpty ? "作者" : selectedAuthor,
                        icon: "person.fill",
                        color: .purple,
                        isSelected: !selectedAuthor.isEmpty
                    ) {
                        showingFilterSheet = true
                    }
                    
                    FilterChip(
                        title: selectedTag.isEmpty ? "标签" : selectedTag,
                        icon: "tag.fill",
                        color: .orange,
                        isSelected: !selectedTag.isEmpty
                    ) {
                        showingFilterSheet = true
                    }
                    
                    if !selectedAuthor.isEmpty || !selectedTag.isEmpty || filterOption != .all {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filterOption = .all
                                selectedAuthor = ""
                                selectedTag = ""
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("清除")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.systemBackground))
            
            Divider()
        }
    }
    
    private func countForFilter(_ option: FilterOption) -> Int {
        switch option {
        case .all:
            return bookStore.books.count
        case .unread:
            return bookStore.books.filter { $0.lastReadTime == nil && $0.lastReadPosition == 0 }.count
        case .reading:
            return bookStore.books.filter { $0.lastReadTime != nil && $0.lastReadPosition > 0 }.count
        case .completed:
            return bookStore.books.filter { $0.lastReadPosition > 0 && $0.totalChapters > 0 && $0.lastReadPosition >= $0.totalChapters - 1 }.count
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset
        
        if offset > 80 && !isSearchActive {
            isSearchActive = true
        } else if offset > 60 && isSearchActive && !searchText.isEmpty {
            isSearchActive = false
        }
    }
    
    private func refreshData() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PullToSearchView: View {
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    var pullOffset: CGFloat
    
    var body: some View {
        ZStack {
            if isSearchActive || pullOffset > 50 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("搜索书架", text: $searchText)
                        .textFieldStyle(.plain)
                        .onTapGesture {
                            isSearchActive = true
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button("取消") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                            isSearchActive = false
                        }
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(height: isSearchActive ? 60 : 0)
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    var isSelected: Bool = false
    var count: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FilterSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var filterOption: BookshelfView.FilterOption
    @Binding var selectedAuthor: String
    @Binding var selectedTag: String
    let uniqueAuthors: [String]
    let uniqueTags: [String]
    
    @State private var searchAuthor = ""
    @State private var searchTag = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("阅读状态") {
                    ForEach(BookshelfView.FilterOption.allCases) { option in
                        Button(action: {
                            filterOption = option
                        }) {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(option.color)
                                    .frame(width: 24)
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if filterOption == option && selectedAuthor.isEmpty && selectedTag.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.purple)
                        Text("按作者筛选")
                            .font(.headline)
                    }
                    
                    if !selectedAuthor.isEmpty {
                        Button(action: {
                            selectedAuthor = ""
                        }) {
                            HStack {
                                Text("当前: \(selectedAuthor)")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if uniqueAuthors.isEmpty {
                        Text("暂无作者数据")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(filteredAuthors, id: \.self) { author in
                            Button(action: {
                                selectedAuthor = author
                            }) {
                                HStack {
                                    Text(author)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedAuthor == author {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.orange)
                        Text("按标签筛选")
                            .font(.headline)
                    }
                    
                    if !selectedTag.isEmpty {
                        Button(action: {
                            selectedTag = ""
                        }) {
                            HStack {
                                Text("当前: \(selectedTag)")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if uniqueTags.isEmpty {
                        Text("暂无标签数据")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filteredTags, id: \.self) { tag in
                                    Button(action: {
                                        selectedTag = tag
                                    }) {
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedTag == tag ? Color.orange : Color.orange.opacity(0.1))
                                            .foregroundColor(selectedTag == tag ? .white : .orange)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.orange.opacity(0.3), lineWidth: selectedTag == tag ? 0 : 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        filterOption = .all
                        selectedAuthor = ""
                        selectedTag = ""
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchAuthor, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索作者")
            .searchable(text: $searchTag, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标签")
        }
    }
    
    private var filteredAuthors: [String] {
        if searchAuthor.isEmpty {
            return uniqueAuthors
        }
        return uniqueAuthors.filter { $0.lowercased().contains(searchAuthor.lowercased()) }
    }
    
    private var filteredTags: [String] {
        if searchTag.isEmpty {
            return uniqueTags
        }
        return uniqueTags.filter { $0.lowercased().contains(searchTag.lowercased()) }
    }
}

struct EmptyBookshelfView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            Text("书架空空如也")
                .font(.title2)
                .foregroundColor(.gray)
            Text("下拉或搜索添加书籍")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct BookContextMenu: View {
    let book: Book
    @EnvironmentObject var bookStore: BookStore
    
    var body: some View {
        Button(role: .destructive) {
            bookStore.removeBook(book)
        } label: {
            Label("删除", systemImage: "trash")
        }
        
        Button {
            // 置顶
        } label: {
            Label("置顶", systemImage: "arrow.up")
        }
        
        Button {
            // 缓存
        } label: {
            Label("缓存", systemImage: "arrow.down.circle")
        }
        
        Button {
            // 详情
        } label: {
            Label("详情", systemImage: "info.circle")
        }
    }
}
