import SwiftUI

struct ReaderView: View {
    let book: Book
    let source: BookSource
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var readerSettings: ReaderSettings
    @Environment(\.dismiss) var dismiss
    
    @State private var chapters: [Chapter] = []
    @State private var currentChapter: Chapter?
    @State private var chapterContent: String = ""
    @State private var isLoading = true
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var showingMenu = false
    @State private var showingAudioBook = false
    
    var body: some View {
        ZStack {
            // 背景
            readerSettings.currentBackground
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("加载中...")
            } else {
                // 阅读内容
                ReaderContentView(
                    content: chapterContent,
                    chapterTitle: currentChapter?.title ?? "",
                    settings: readerSettings
                )
                .onTapGesture {
                    withAnimation {
                        showingMenu.toggle()
                    }
                }
            }
            
            // 顶部菜单
            if showingMenu {
                VStack {
                    ReaderTopBar(
                        bookName: book.name,
                        chapterTitle: currentChapter?.title ?? "",
                        onBack: { dismiss() },
                        onShowChapters: { showingChapterList = true },
                        onShowSettings: { showingSettings = true }
                    )
                    .background(readerSettings.currentBackground.opacity(0.95))
                    
                    Spacer()
                    
                    // 底部菜单
                    ReaderBottomBar(
                        currentChapter: currentChapter,
                        totalChapters: chapters.count,
                        onPrevious: loadPreviousChapter,
                        onNext: loadNextChapter,
                        onAudioBook: startAudioBook
                    )
                    .background(readerSettings.currentBackground.opacity(0.95))
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsView(settings: readerSettings)
        }
        .sheet(isPresented: $showingChapterList) {
            ChapterSelectorView(
                chapters: chapters,
                currentChapter: currentChapter,
                onSelect: { chapter in
                    loadChapter(chapter)
                }
            )
        }
        .sheet(isPresented: $showingAudioBook) {
            AudioBookView()
        }
        .onAppear {
            loadInitialData()
        }
        .onDisappear {
            saveProgress()
        }
        .statusBar(hidden: !showingMenu)
    }
    
    private func startAudioBook() {
        AudioBookManager.shared.prepareForBook(
            bookId: book.id,
            bookName: book.name,
            chapters: chapters,
            startChapter: currentChapter?.index ?? 0
        )
        showingAudioBook = true
    }
    
    private func loadInitialData() {
        Task {
            await bookStore.loadChapters(for: book, source: source)
            await MainActor.run {
                chapters = bookStore.chapters
                
                // 找到上次阅读的章节
                if let lastReadChapter = book.lastReadChapter,
                   let chapter = chapters.first(where: { $0.title == lastReadChapter }) {
                    currentChapter = chapter
                } else {
                    currentChapter = chapters.first
                }
                
                if let chapter = currentChapter {
                    loadChapterContent(chapter)
                }
            }
        }
    }
    
    private func loadChapter(_ chapter: Chapter) {
        currentChapter = chapter
        loadChapterContent(chapter)
        showingChapterList = false
    }
    
    private func loadChapterContent(_ chapter: Chapter) {
        isLoading = true
        Task {
            if let content = await bookStore.loadChapterContent(chapter: chapter, source: source) {
                await MainActor.run {
                    chapterContent = content
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    chapterContent = "加载失败，请重试"
                    isLoading = false
                }
            }
        }
    }
    
    private func loadPreviousChapter() {
        guard let current = currentChapter,
              let index = chapters.firstIndex(where: { $0.id == current.id }),
              index > 0 else { return }
        
        loadChapter(chapters[index - 1])
    }
    
    private func loadNextChapter() {
        guard let current = currentChapter,
              let index = chapters.firstIndex(where: { $0.id == current.id }),
              index < chapters.count - 1 else { return }
        
        loadChapter(chapters[index + 1])
    }
    
    private func saveProgress() {
        if let chapter = currentChapter {
            bookStore.updateReadingProgress(book: book, chapter: chapter, position: 0)
        }
    }
}

struct ReaderContentView: View {
    let content: String
    let chapterTitle: String
    let settings: ReaderSettings
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 章节标题
                Text(chapterTitle)
                    .font(.system(size: settings.fontSize + 4, weight: .bold))
                    .foregroundColor(settings.currentTextColor)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                
                // 内容
                Text(content)
                    .font(.custom(settings.fontFamily, size: settings.fontSize))
                    .lineSpacing(settings.lineSpacing * settings.fontSize)
                    .foregroundColor(settings.currentTextColor)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
            }
        }
    }
}

struct ReaderTopBar: View {
    let bookName: String
    let chapterTitle: String
    let onBack: () -> Void
    let onShowChapters: () -> Void
    let onShowSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(bookName)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                Text(chapterTitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onShowChapters) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            
            Button(action: onShowSettings) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

struct ReaderBottomBar: View {
    let currentChapter: Chapter?
    let totalChapters: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onAudioBook: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 进度条
            if let chapter = currentChapter {
                HStack {
                    Text("\(chapter.index + 1)/\(totalChapters)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(Double(chapter.index + 1) / Double(totalChapters) * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // 导航按钮
            HStack(spacing: 40) {
                Button(action: onPrevious) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("上一章")
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                }
                .disabled(currentChapter?.index == 0)
                
                // 听书按钮
                Button(action: onAudioBook) {
                    HStack {
                        Image(systemName: "headphones")
                        Text("听书")
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                }
                
                Button(action: onNext) {
                    HStack {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                }
                .disabled(currentChapter?.index == totalChapters - 1)
            }
            .padding(.vertical, 16)
        }
    }
}

struct ReaderSettingsView: View {
    @ObservedObject var settings: ReaderSettings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // 字体大小
                Section("字体大小") {
                    HStack {
                        Button(action: { settings.fontSize = max(12, settings.fontSize - 2) }) {
                            Image(systemName: "textformat.size.smaller")
                        }
                        
                        Slider(value: $settings.fontSize, in: 12...32, step: 1)
                        
                        Button(action: { settings.fontSize = min(32, settings.fontSize + 2) }) {
                            Image(systemName: "textformat.size.larger")
                        }
                    }
                }
                
                // 行间距
                Section("行间距") {
                    Slider(value: $settings.lineSpacing, in: 1...3, step: 0.1)
                }
                
                // 背景颜色
                Section("背景颜色") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                        ForEach(ReaderSettings.ReaderBackground.allCases, id: \.self) { bg in
                            Button(action: { settings.backgroundColor = bg }) {
                                VStack {
                                    Circle()
                                        .fill(bg.color)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(settings.backgroundColor == bg ? Color.blue : Color.clear, lineWidth: 3)
                                        )
                                    Text(bg.displayName)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 夜间模式
                Section {
                    Toggle("夜间模式", isOn: $settings.isNightMode)
                }
                
                // 翻页模式
                Section("翻页模式") {
                    Picker("翻页模式", selection: $settings.pageTurnType) {
                        ForEach(ReaderSettings.PageTurnType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 屏幕常亮
                Section {
                    Toggle("屏幕常亮", isOn: $settings.keepScreenOn)
                }
            }
            .navigationTitle("阅读设置")
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

struct ChapterSelectorView: View {
    let chapters: [Chapter]
    let currentChapter: Chapter?
    let onSelect: (Chapter) -> Void
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
                Button(action: {
                    onSelect(chapter)
                    dismiss()
                }) {
                    HStack {
                        Text(chapter.title)
                            .font(.system(size: 15))
                            .foregroundColor(currentChapter?.id == chapter.id ? .blue : .primary)
                        
                        Spacer()
                        
                        if currentChapter?.id == chapter.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("选择章节")
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
