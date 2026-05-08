import SwiftUI

struct EnhancedBookDetailView: View {
    @StateObject private var bookStore = BookStore.shared
    @StateObject private var groupManager = BookGroupManager.shared
    @EnvironmentObject var sourceStore: SourceStore
    @Environment(\.dismiss) var dismiss
    
    @State private var book: Book
    @State private var chapters: [Chapter] = []
    @State private var isLoading = false
    @State private var showingReader = false
    @State private var showingChapterList = false
    @State private var showingGroupSelector = false
    @State private var showingEditSheet = false
    @State private var showingCoverPicker = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingGroupDetail: BookGroup?
    @State private var currentCover: UIImage?
    
    init(book: Book) {
        self._book = State(initialValue: book)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    bookHeaderSection
                    actionButtonsSection
                    bookInfoSection
                    groupsSection
                    chaptersSection
                }
                .padding()
            }
            .navigationTitle("书籍详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingEditSheet = true }) {
                            Label("编辑信息", systemImage: "pencil")
                        }
                        
                        Button(action: { showingCoverPicker = true }) {
                            Label("更换封面", systemImage: "photo")
                        }
                        
                        Button(action: { showingGroupSelector = true }) {
                            Label("分组管理", systemImage: "folder.badge.plus")
                        }
                        
                        Divider()
                        
                        Button(action: { showingShareSheet = true }) {
                            Label("分享书籍", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("删除书籍", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingReader) {
                if let source = sourceStore.bookSources.first(where: { $0.url == book.sourceUrl }) {
                    UniversalReaderView(readerMode: .networkBook(book: book, source: source))
                }
            }
            .sheet(isPresented: $showingChapterList) {
                ChapterListView(book: book, chapters: chapters)
            }
            .sheet(isPresented: $showingEditSheet) {
                BookEditSheet(book: $book)
            }
            .sheet(isPresented: $showingCoverPicker) {
                CoverManagementView(book: book)
            }
            .sheet(isPresented: $showingGroupSelector) {
                GroupSelectorSheet(bookId: book.id)
            }
            .sheet(item: $showingGroupDetail) { group in
                GroupDetailView(group: group)
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteBook()
                }
            } message: {
                Text("确定要删除《\(book.name)》吗？此操作不可撤销。")
            }
            .onAppear {
                loadChapters()
                loadCover()
            }
        }
    }
    
    private var bookHeaderSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 140)
                    
                    if let cover = currentCover {
                        Image(uiImage: cover)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if let cover = book.cover, let url = URL(string: cover) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            VStack {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 40))
                                Text(book.name.prefix(1))
                                    .font(.title2)
                            }
                            .foregroundColor(.gray)
                        }
                        .frame(width: 100, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        VStack {
                            Image(systemName: "book.fill")
                                .font(.system(size: 40))
                            Text(book.name.prefix(1))
                                .font(.title2)
                        }
                        .foregroundColor(.gray)
                    }
                }
                .shadow(radius: 4)
                .onTapGesture {
                    showingCoverPicker = true
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(book.name)
                        .font(.system(size: 20, weight: .bold))
                        .lineLimit(2)
                    
                    Text(book.author)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "globe")
                            .font(.caption)
                        Text(book.sourceName)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.blue)
                    
                    if let lastChapter = book.lastChapter {
                        HStack(alignment: .top) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                            Text(lastChapter)
                                .font(.system(size: 14))
                                .lineLimit(2)
                        }
                        .foregroundColor(.orange)
                    }
                    
                    if let lastRead = book.lastReadChapter {
                        HStack {
                            Image(systemName: "bookmark")
                                .font(.caption)
                            Text(lastRead)
                                .font(.system(size: 14))
                                .lineLimit(1)
                        }
                        .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("\(chapters.count) 章")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if book.progress > 0 {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text("\(Int(book.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
            }
            
            if book.progress > 0 {
                HStack {
                    Text("阅读进度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                    Text("\(Int(book.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { showingReader = true }) {
                    HStack {
                        Image(systemName: book.progress > 0 ? "book.open" : "book.fill")
                        Text(book.progress > 0 ? "继续阅读" : "开始阅读")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: { showingChapterList = true }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("目录")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { showingGroupSelector = true }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("分组")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: { showingEditSheet = true }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("编辑")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var bookInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("书籍信息")
                .font(.system(size: 18, weight: .bold))
            
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "名称", value: book.name)
                infoRow(label: "作者", value: book.author)
                infoRow(label: "来源", value: book.sourceName)
                
                if let intro = book.intro, !intro.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("简介")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(intro)
                            .font(.system(size: 14))
                            .lineLimit(4)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("所属分组")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Button("管理") {
                    showingGroupSelector = true
                }
                .font(.system(size: 14))
                .foregroundColor(.blue)
            }
            
            let bookGroups = groupManager.getGroupsForBook(book.id)
            
            if bookGroups.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text("暂未加入任何分组")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(bookGroups) { group in
                            Button(action: { showingGroupDetail = group }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: group.icon)
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                        
                                        if group.isLocked {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.orange)
                                                .offset(x: 15, y: -15)
                                        }
                                    }
                                    
                                    Text(group.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .frame(width: 80)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("章节预览")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text("\(chapters.count) 章")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 0) {
                ForEach(chapters.prefix(10)) { chapter in
                    Button(action: { showingReader = true }) {
                        HStack {
                            Text(chapter.title)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if chapter.isLoaded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                    }
                    
                    if chapter.id != chapters.prefix(10).last?.id {
                        Divider()
                    }
                }
                
                if chapters.count > 10 {
                    Button(action: { showingChapterList = true }) {
                        Text("查看全部 \(chapters.count) 章")
                            .font(.system(size: 15))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
    
    private func loadChapters() {
        guard let source = sourceStore.bookSources.first(where: { $0.url == book.sourceUrl }) else { return }
        
        isLoading = true
        Task {
            await bookStore.loadChapters(for: book, source: source)
            await MainActor.run {
                chapters = bookStore.chapters
                isLoading = false
            }
        }
    }
    
    private func loadCover() {
        Task {
            if let image = await CoverManager.shared.fetchCoverImage(for: book) {
                await MainActor.run {
                    currentCover = image
                }
            }
        }
    }
    
    private func deleteBook() {
        bookStore.removeBook(book)
        groupManager.removeBookFromAllGroups(book.id)
        dismiss()
    }
}

struct BookEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var book: Book
    @State private var editedBook: Book
    
    init(book: Binding<Book>) {
        self._book = book
        self._editedBook = State(initialValue: book.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("书名")
                        Spacer()
                        TextField("书名", text: $editedBook.name)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("作者")
                        Spacer()
                        TextField("作者", text: $editedBook.author)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("简介")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("简介", text: Binding(
                            get: { editedBook.intro ?? "" },
                            set: { editedBook.intro = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(3...6)
                    }
                } header: {
                    Text("简介")
                }
                
                Section {
                    Toggle("收藏", isOn: $editedBook.isFavorite)
                        .tint(.orange)
                } header: {
                    Text("状态")
                }
            }
            .navigationTitle("编辑书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        book = editedBook
                        BookStore.shared.updateBook(editedBook)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct GroupSelectorSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupManager = BookGroupManager.shared
    @StateObject private var bookStore = BookStore.shared
    @State private var selectedGroups: Set<String> = []
    @State private var showingNewGroupSheet = false
    
    let bookId: String
    
    init(bookId: String) {
        self.bookId = bookId
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupManager.groups) { group in
                    Button(action: { toggleGroup(group) }) {
                        HStack {
                            Image(systemName: group.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(group.name)
                                    .foregroundColor(.primary)
                                
                                if !group.description.isNilOrEmpty {
                                    Text(group.description ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedGroups.contains(group.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(group.isHidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("分组管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewGroupSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadSelectedGroups()
            }
            .sheet(isPresented: $showingNewGroupSheet) {
                NewGroupSheet()
            }
        }
    }
    
    private func loadSelectedGroups() {
        selectedGroups = Set(groupManager.getGroupsForBook(bookId).map { $0.id })
    }
    
    private func toggleGroup(_ group: BookGroup) {
        if selectedGroups.contains(group.id) {
            selectedGroups.remove(group.id)
            groupManager.removeBook(bookId, from: group.id)
        } else {
            selectedGroups.insert(group.id)
            groupManager.addBook(bookId, to: group.id)
        }
    }
}

struct NewGroupSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var groupName = ""
    @State private var selectedIcon = "folder.fill"
    @State private var showingIconPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("名称")
                        Spacer()
                        TextField("分组名称", text: $groupName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.primary)
                    }
                    
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
                }
            }
            .navigationTitle("新建分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        groupManager.addGroup(name: groupName, icon: selectedIcon)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(groupName.isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerSheet(selectedIcon: $selectedIcon)
            }
        }
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
