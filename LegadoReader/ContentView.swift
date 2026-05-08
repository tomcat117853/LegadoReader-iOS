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
        var books = searchText.isEmpty ? bookStore.books : bookStore.books.filter { book in
            let query = searchText.lowercased()
            return book.name.lowercased().contains(query) ||
            book.author.lowercased().contains(query) ||
            (book.kind?.lowercased().contains(query) ?? false) ||
            (book.intro?.lowercased().contains(query) ?? false) ||
            (book.sourceName.lowercased().contains(query))
        }
        return sortBooks(books)
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
                            GridBookshelfView(books: filteredBooks, selectedBook: $selectedBook)
                        } else {
                            ListBookshelfView(books: filteredBooks, selectedBook: $selectedBook)
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

struct GridBookshelfView: View {
    let books: [Book]
    @Binding var selectedBook: Book?
    @EnvironmentObject var bookStore: BookStore
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(books) { book in
                    BookGridItem(book: book)
                        .onTapGesture {
                            selectedBook = book
                        }
                        .contextMenu {
                            BookContextMenu(book: book)
                        }
                }
            }
            .padding()
        }
    }
}

struct BookGridItem: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(3/4, contentMode: .fit)
                
                if let cover = book.cover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(book.name.prefix(1))
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            
            // 书名
            Text(book.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            // 作者或最新章节
            Text(book.lastChapter ?? book.author)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
    }
}

struct ListBookshelfView: View {
    let books: [Book]
    @Binding var selectedBook: Book?
    @EnvironmentObject var bookStore: BookStore
    
    var body: some View {
        List(books) { book in
            BookListItem(book: book)
                .onTapGesture {
                    selectedBook = book
                }
                .contextMenu {
                    BookContextMenu(book: book)
                }
        }
        .listStyle(.plain)
    }
}

struct BookListItem: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 80)
                
                if let cover = book.cover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(book.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let lastChapter = book.lastChapter {
                    Text("更新至: \(lastChapter)")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                if let lastRead = book.lastReadChapter {
                    Text("读至: \(lastRead)")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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
