import SwiftUI

enum BookDetailSheet: Identifiable {
    case reader
    case chapterList
    case editInfo
    case coverPicker
    case groupSelector
    case groupDetail(BookGroup)
    case share
    
    var id: String {
        switch self {
        case .reader: return "reader"
        case .chapterList: return "chapterList"
        case .editInfo: return "editInfo"
        case .coverPicker: return "coverPicker"
        case .groupSelector: return "groupSelector"
        case .groupDetail(let group): return "groupDetail_\(group.id)"
        case .share: return "share"
        }
    }
}

struct EnhancedBookDetailView: View {
    @StateObject private var bookStore = BookStore.shared
    @StateObject private var groupManager = BookGroupManager.shared
    @EnvironmentObject var sourceStore: SourceStore
    @Environment(\.dismiss) var dismiss
    
    @State private var book: Book
    @State private var chapters: [Chapter] = []
    @State private var isLoading = false
    @State private var currentCover: UIImage?
    @State private var activeSheet: BookDetailSheet?
    @State private var showingDeleteAlert = false
    
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
                        Button(action: { activeSheet = .editInfo }) {
                            Label("编辑信息", systemImage: "pencil")
                        }
                        
                        Button(action: { activeSheet = .coverPicker }) {
                            Label("更换封面", systemImage: "photo")
                        }
                        
                        Button(action: { activeSheet = .groupSelector }) {
                            Label("分组管理", systemImage: "folder.badge.plus")
                        }
                        
                        Divider()
                        
                        Button(action: { activeSheet = .share }) {
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
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
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
    
    @ViewBuilder
    private func sheetContent(for sheet: BookDetailSheet) -> some View {
        switch sheet {
        case .reader:
            if let source = sourceStore.bookSources.first(where: { $0.url == book.sourceUrl }) {
                UniversalReaderView(readerMode: .networkBook(book: book, source: source))
            }
        case .chapterList:
            ChapterListView(book: book, chapters: chapters)
        case .editInfo:
            BookEditSheet(book: $book)
        case .coverPicker:
            CoverManagementView(book: book)
        case .groupSelector:
            GroupSelectorSheet(bookId: book.id)
        case .groupDetail(let group):
            GroupDetailView(group: group)
        case .share:
            ShareSheet(items: [book.name])
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
                    activeSheet = .coverPicker
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
                Button(action: { activeSheet = .reader }) {
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
                
                Button(action: { activeSheet = .chapterList }) {
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
                Button(action: { activeSheet = .groupSelector }) {
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
                
                Button(action: { activeSheet = .editInfo }) {
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
                    activeSheet = .groupSelector
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
                            Button(action: { activeSheet = .groupDetail(group) }) {
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
                
                Button("查看全部") {
                    activeSheet = .chapterList
                }
                .font(.system(size: 14))
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(chapters.prefix(5))) { chapter in
                    Button(action: {
                        bookStore.updateReadingProgress(
                            bookId: book.id,
                            chapterIndex: chapters.firstIndex(where: { $0.id == chapter.id }) ?? 0,
                            progress: 0
                        )
                        activeSheet = .reader
                    }) {
                        HStack {
                            Text(chapter.title)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if let readChapters = book.readChapters, readChapters.contains(chapter.id) {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                    
                    if chapter.id != chapters.prefix(5).last?.id {
                        Divider()
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
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
    
    private func loadChapters() {
        guard let source = sourceStore.bookSources.first(where: { $0.url == book.sourceUrl }) else {
            return
        }
        
        isLoading = true
        Task {
            do {
                let fetchedChapters = try await BookSourceParser.shared.fetchChapters(
                    bookUrl: book.url,
                    source: source
                )
                await MainActor.run {
                    self.chapters = fetchedChapters
                    self.isLoading = false
                }
            } catch {
                print("Failed to load chapters: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadCover() {
        if let coverUrl = book.cover, let url = URL(string: coverUrl) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.currentCover = image
                        }
                    }
                } catch {
                    print("Failed to load cover: \(error)")
                }
            }
        }
    }
    
    private func deleteBook() {
        bookStore.removeBook(book)
        dismiss()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
