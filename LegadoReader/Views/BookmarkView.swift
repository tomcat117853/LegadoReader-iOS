import SwiftUI

struct BookmarkView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var showingSortSheet = false
    @State private var showingFilterSheet = false
    @State private var selectedBookmark: Bookmark?
    @State private var searchText = ""
    @State private var isEditingMode = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !searchText.isEmpty || !bookmarkManager.currentFilter.searchText.isEmpty {
                    searchBar
                }
                
                if bookmarkManager.filteredBookmarks.isEmpty {
                    emptyView
                } else {
                    bookmarkList
                }
            }
            .navigationTitle("收藏夹")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isEditingMode.toggle() }) {
                        Text(isEditingMode ? "完成" : "编辑")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingSortSheet = true }) {
                            Label("排序: \(bookmarkManager.currentSortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Button(action: { showingFilterSheet = true }) {
                            Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        Divider()
                        
                        Button(action: exportBookmarks) {
                            Label("导出收藏", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBookmarkSheet()
            }
            .sheet(item: $selectedBookmark) { bookmark in
                BookmarkEditSheet(bookmark: bookmark)
            }
            .sheet(isPresented: $showingSortSheet) {
                BookmarkSortSheet()
            }
            .sheet(isPresented: $showingFilterSheet) {
                BookmarkFilterSheet()
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索收藏", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, newValue in
                    bookmarkManager.setFilter(BookmarkFilter(searchText: newValue))
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    bookmarkManager.setFilter(BookmarkFilter())
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var bookmarkList: some View {
        List {
            if !bookmarkManager.pinnedBookmarks.isEmpty && searchText.isEmpty {
                Section("置顶") {
                    ForEach(bookmarkManager.pinnedBookmarks) { bookmark in
                        BookmarkRowView(bookmark: bookmark, isEditingMode: isEditingMode, onSelect: {
                            selectedBookmark = bookmark
                        })
                    }
                }
            }
            
            Section(searchText.isEmpty ? "所有收藏" : "搜索结果") {
                ForEach(filteredBookmarks) { bookmark in
                    BookmarkRowView(bookmark: bookmark, isEditingMode: isEditingMode, onSelect: {
                        selectedBookmark = bookmark
                    })
                }
                .onDelete(perform: deleteBookmarks)
                .onMove(perform: moveBookmarks)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty {
            return bookmarkManager.filteredBookmarks
        } else {
            return bookmarkManager.filteredBookmarks.filter { !$0.isPinned }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("暂无收藏")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("点击右上角按钮添加收藏")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: { showingAddSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加收藏")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            let bookmark = filteredBookmarks[index]
            bookmarkManager.deleteBookmark(bookmark)
        }
    }
    
    private func moveBookmarks(from source: IndexSet, to destination: Int) {
        bookmarkManager.moveBookmark(from: source, to: destination)
    }
    
    private func exportBookmarks() {
    }
}

struct BookmarkRowView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    let bookmark: Bookmark
    let isEditingMode: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: bookmark.icon)
                        .font(.system(size: 20))
                        .foregroundColor(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(bookmark.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if bookmark.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text(bookmark.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        if bookmark.readingDuration > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "book.fill")
                                    .font(.caption2)
                                Text(bookmark.readingDurationFormatted)
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                        
                        if bookmark.listeningDuration > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "headphones")
                                    .font(.caption2)
                                Text(bookmark.listeningDurationFormatted)
                                    .font(.caption2)
                            }
                            .foregroundColor(.purple)
                        }
                        
                        if bookmark.visitCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "eye")
                                    .font(.caption2)
                                Text("\(bookmark.visitCount)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if isEditingMode {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .leading) {
            Button(action: { bookmarkManager.togglePin(bookmark) }) {
                Label(bookmark.isPinned ? "取消置顶" : "置顶", systemImage: bookmark.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
            
            Button(action: { bookmarkManager.toggleFavorite(bookmark) }) {
                Label(bookmark.isFavorite ? "取消收藏" : "收藏", systemImage: bookmark.isFavorite ? "heart.slash" : "heart")
            }
            .tint(.red)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                bookmarkManager.deleteBookmark(bookmark)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private var categoryColor: Color {
        switch bookmark.category {
        case .general: return .gray
        case .reading: return .blue
        case .listening: return .purple
        case .learning: return .green
        case .work: return .orange
        case .entertainment: return .pink
        case .custom: return .indigo
        }
    }
}

struct AddBookmarkSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var name = ""
    @State private var url = ""
    @State private var selectedIcon = "link"
    @State private var selectedCategory: BookmarkCategory = .general
    @State private var showingIconPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("名称", text: $name)
                    
                    TextField("网址", text: $url)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    HStack {
                        Text("图标")
                        Spacer()
                        Button(action: { showingIconPicker = true }) {
                            HStack {
                                Image(systemName: selectedIcon)
                                    .foregroundColor(.blue)
                                Text("选择图标")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(BookmarkCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                } header: {
                    Text("设置")
                }
                
                Section {
                    Button(action: addBookmark) {
                        HStack {
                            Spacer()
                            Text("添加")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
            .navigationTitle("添加收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerSheet(selectedIcon: $selectedIcon)
            }
            .onAppear {
                if let clipboard = UIPasteboard.general.string,
                   clipboard.hasPrefix("http://") || clipboard.hasPrefix("https://") {
                    url = clipboard
                }
            }
        }
    }
    
    private func addBookmark() {
        var finalUrl = url
        if !finalUrl.hasPrefix("http://") && !finalUrl.hasPrefix("https://") {
            finalUrl = "https://" + finalUrl
        }
        
        bookmarkManager.addBookmark(name: name, url: finalUrl, icon: selectedIcon, category: selectedCategory)
        dismiss()
    }
}

struct BookmarkEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var bookmark: Bookmark
    @State private var editInfo: BookmarkEditInfo
    @State private var showingIconPicker = false
    @State private var showingDeleteAlert = false
    
    init(bookmark: Bookmark) {
        self._bookmark = State(initialValue: bookmark)
        self._editInfo = State(initialValue: BookmarkEditInfo(from: bookmark))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("名称", text: $editInfo.name)
                    
                    TextField("网址", text: $editInfo.url)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    HStack {
                        Text("图标")
                        Spacer()
                        Button(action: { showingIconPicker = true }) {
                            HStack {
                                Image(systemName: editInfo.icon)
                                    .foregroundColor(.blue)
                                Text("选择图标")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Picker("分类", selection: $editInfo.category) {
                        ForEach(BookmarkCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                } header: {
                    Text("设置")
                }
                
                Section {
                    Toggle("置顶", isOn: $bookmark.isPinned)
                        .tint(.orange)
                    
                    Toggle("收藏", isOn: $bookmark.isFavorite)
                        .tint(.red)
                } header: {
                    Text("状态")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("笔记")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("添加笔记（可选）", text: Binding(
                            get: { editInfo.note ?? "" },
                            set: { editInfo.note = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(3...6)
                    }
                }
                
                Section {
                    durationRow(title: "阅读时长", duration: bookmark.readingDuration, icon: "book.fill", color: .blue)
                    
                    durationRow(title: "听书时长", duration: bookmark.listeningDuration, icon: "headphones", color: .purple)
                    
                    durationRow(title: "总时长", duration: bookmark.totalDuration, icon: "clock", color: .green)
                    
                    HStack {
                        Text("访问次数")
                        Spacer()
                        Text("\(bookmark.visitCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastVisit = bookmark.lastVisitTime {
                        HStack {
                            Text("最近访问")
                            Spacer()
                            Text(lastVisit.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("统计")
                }
                
                Section {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        HStack {
                            Spacer()
                            Text("删除收藏")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("编辑收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerSheet(selectedIcon: $editInfo.icon)
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    bookmarkManager.deleteBookmark(bookmark)
                    dismiss()
                }
            } message: {
                Text("确定要删除 \"\(bookmark.name)\" 吗？")
            }
        }
    }
    
    private func durationRow(title: String, duration: TimeInterval, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
            Spacer()
            Text(formatDuration(duration))
                .foregroundColor(.secondary)
        }
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
    
    private func saveChanges() {
        editInfo.apply(to: &bookmark)
        bookmarkManager.updateBookmark(bookmark)
    }
}

struct BookmarkSortSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(BookmarkSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        bookmarkManager.setSortOption(option)
                        dismiss()
                    }) {
                        HStack {
                            Text(option.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if bookmarkManager.currentSortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("排序方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BookmarkFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("仅显示置顶", isOn: $bookmarkManager.currentFilter.showPinnedOnly)
                    
                    Toggle("仅显示收藏", isOn: $bookmarkManager.currentFilter.showFavoritesOnly)
                } header: {
                    Text("筛选")
                }
                
                Section {
                    Picker("分类", selection: Binding(
                        get: { bookmarkManager.currentFilter.category ?? .general },
                        set: { bookmarkManager.currentFilter.category = $0 }
                    )) {
                        Text("全部").tag(BookmarkCategory.general)
                        ForEach(BookmarkCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                } header: {
                    Text("按分类筛选")
                }
                
                if !bookmarkManager.getAllTags().isEmpty {
                    Section {
                        ForEach(bookmarkManager.getAllTags(), id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                if bookmarkManager.currentFilter.tags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if bookmarkManager.currentFilter.tags.contains(tag) {
                                    bookmarkManager.currentFilter.tags.removeAll { $0 == tag }
                                } else {
                                    bookmarkManager.currentFilter.tags.append(tag)
                                }
                            }
                        }
                    } header: {
                        Text("按标签筛选")
                    }
                }
                
                Section {
                    Button("重置筛选") {
                        bookmarkManager.resetFilter()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DurationStatisticsView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("总阅读时长")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDuration(bookmarkManager.getTotalReadingDuration()))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "book.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue.opacity(0.3))
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("总听书时长")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDuration(bookmarkManager.getTotalListeningDuration()))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "headphones")
                            .font(.system(size: 40))
                            .foregroundColor(.purple.opacity(0.3))
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("总使用时长")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDuration(bookmarkManager.getTotalDuration()))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "clock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green.opacity(0.3))
                    }
                } header: {
                    Text("时长统计")
                }
                
                Section {
                    ForEach(bookmarkManager.getTopReadingDurationBookmarks(limit: 5)) { bookmark in
                        DurationRankRow(bookmark: bookmark, type: "阅读")
                    }
                } header: {
                    Text("阅读时长排行")
                }
                
                Section {
                    ForEach(bookmarkManager.getTopListeningDurationBookmarks(limit: 5)) { bookmark in
                        DurationRankRow(bookmark: bookmark, type: "听书")
                    }
                } header: {
                    Text("听书时长排行")
                }
            }
            .navigationTitle("时长统计")
        }
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

struct DurationRankRow: View {
    let bookmark: Bookmark
    let type: String
    
    var body: some View {
        HStack {
            Image(systemName: bookmark.icon)
                .foregroundColor(type == "阅读" ? .blue : .purple)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(bookmark.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(type == "阅读" ? bookmark.readingDurationFormatted : bookmark.listeningDurationFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
