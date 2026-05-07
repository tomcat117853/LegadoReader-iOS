import SwiftUI

struct BookDetailView: View {
    let book: Book
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var sourceStore: SourceStore
    @Environment(\.dismiss) var dismiss
    
    @State private var chapters: [Chapter] = []
    @State private var isLoading = false
    @State private var showingReader = false
    @State private var showingChapterList = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 封面和基本信息
                    BookHeaderView(book: book)
                    
                    // 操作按钮
                    ActionButtonsView(
                        book: book,
                        isInBookshelf: bookStore.books.contains(where: { $0.id == book.id }),
                        onRead: { showingReader = true },
                        onAddToBookshelf: addToBookshelf,
                        onShowChapters: { showingChapterList = true }
                    )
                    
                    // 简介
                    if let intro = book.intro, !intro.isEmpty {
                        BookIntroView(intro: intro)
                    }
                    
                    // 章节预览
                    if !chapters.isEmpty {
                        ChapterPreviewView(chapters: Array(chapters.prefix(10)))
                    }
                }
                .padding()
            }
            .navigationTitle("书籍详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingReader) {
                if let source = sourceStore.bookSources.first(where: { $0.url == book.sourceUrl }) {
                    ReaderView(book: book, source: source)
                }
            }
            .sheet(isPresented: $showingChapterList) {
                ChapterListView(book: book, chapters: chapters)
            }
            .onAppear {
                loadChapters()
            }
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
    
    private func addToBookshelf() {
        bookStore.addBook(book)
    }
}

struct BookHeaderView: View {
    let book: Book
    @State private var showingCoverManagement = false
    @StateObject private var coverManager = CoverManager.shared
    @State private var currentCover: UIImage?
    
    var body: some View {
        VStack(spacing: 12) {
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
                            ProgressView()
                        }
                        .frame(width: 100, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        VStack {
                            Image(systemName: "book.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text(book.name.prefix(1))
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .shadow(radius: 4)
                .onTapGesture {
                    showingCoverManagement = true
                }
                
                Button(action: {
                    showingCoverManagement = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.caption)
                        Text("换封面")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(book.name)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Text("来源: \(book.sourceName)")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                if let lastChapter = book.lastChapter {
                    Text("最新: \(lastChapter)")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
                
                if let lastRead = book.lastReadChapter {
                    Text("读至: \(lastRead)")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
        }
        .sheet(isPresented: $showingCoverManagement) {
            CoverManagementView(book: book)
        }
        .onAppear {
            loadCurrentCover()
        }
    }
    
    private func loadCurrentCover() {
        Task {
            if let image = await coverManager.fetchCoverImage(for: book) {
                await MainActor.run {
                    currentCover = image
                }
            }
        }
    }
}

struct ActionButtonsView: View {
    let book: Book
    let isInBookshelf: Bool
    let onRead: () -> Void
    let onAddToBookshelf: () -> Void
    let onShowChapters: () -> Void
    
    @StateObject private var notificationManager = UpdateNotificationManager.shared
    @State private var showingNotificationSettings = false
    
    private var isSubscribed: Bool {
        notificationManager.isSubscribed(book.id)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onRead) {
                    HStack {
                        Image(systemName: "book.open")
                        Text("开始阅读")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: onAddToBookshelf) {
                    HStack {
                        Image(systemName: isInBookshelf ? "checkmark" : "plus")
                        Text(isInBookshelf ? "已在书架" : "加入书架")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isInBookshelf)
                
                Button(action: onShowChapters) {
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
                Button(action: {
                    if isSubscribed {
                        notificationManager.unsubscribeBook(book.id)
                    } else {
                        showingNotificationSettings = true
                    }
                }) {
                    HStack {
                        Image(systemName: isSubscribed ? "bell.fill" : "bell")
                        Text(isSubscribed ? "已订阅更新" : "订阅更新")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(isSubscribed ? .green : .orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background((isSubscribed ? Color.green : Color.orange).opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    showingNotificationSettings = true
                }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("提醒设置")
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
        .sheet(isPresented: $showingNotificationSettings) {
            SubscriptionSettingsSheet(book: book, isAlreadySubscribed: isSubscribed)
        }
    }
}

struct BookIntroView: View {
    let intro: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("简介")
                .font(.system(size: 18, weight: .bold))
            
            Text(intro)
                .font(.system(size: 15))
                .lineSpacing(4)
                .lineLimit(isExpanded ? nil : 4)
                .foregroundColor(.secondary)
            
            Button(action: { isExpanded.toggle() }) {
                Text(isExpanded ? "收起" : "展开")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ChapterPreviewView: View {
    let chapters: [Chapter]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("章节预览")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text("共 \(chapters.count) 章")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(chapters.prefix(5)) { chapter in
                    Text(chapter.title)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.vertical, 10)
                    
                    if chapter.id != chapters[min(4, chapters.count - 1)].id {
                        Divider()
                    }
                }
            }
            
            if chapters.count > 5 {
                Button(action: {}) {
                    Text("查看全部章节")
                        .font(.system(size: 15))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ChapterListView: View {
    let book: Book
    let chapters: [Chapter]
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredChapters: [Chapter] {
        if searchText.isEmpty {
            return chapters
        }
        return chapters.filter { $0.title.contains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            List(filteredChapters) { chapter in
                Text(chapter.title)
                    .font(.system(size: 15))
            }
            .listStyle(.plain)
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索章节")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}
