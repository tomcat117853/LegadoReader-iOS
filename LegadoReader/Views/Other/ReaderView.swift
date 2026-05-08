import SwiftUI
import Combine

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
    @State private var showingAutoScroll = false
    @State private var autoScrollManager = AutoScrollManager()
    
    var body: some View {
        ZStack {
            readerSettings.currentBackground
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("加载中...")
            } else {
                ReaderContentView(
                    content: chapterContent,
                    chapterTitle: currentChapter?.title ?? "",
                    settings: readerSettings,
                    autoScrollManager: autoScrollManager
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if autoScrollManager.isScrolling {
                            autoScrollManager.stop()
                        } else {
                            autoScrollManager.start()
                        }
                    }
                }
                .onTapGesture {
                    withAnimation {
                        showingMenu.toggle()
                    }
                }
            }
            
            if autoScrollManager.isScrolling {
                AutoScrollIndicatorView(manager: autoScrollManager)
            }
            
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
                    
                    ReaderBottomBar(
                        currentChapter: currentChapter,
                        totalChapters: chapters.count,
                        onPrevious: loadPreviousChapter,
                        onNext: loadNextChapter,
                        onAudioBook: startAudioBook,
                        onAutoScroll: { showingAutoScroll = true }
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
        .sheet(isPresented: $showingAutoScroll) {
            AutoScrollSettingsView(manager: autoScrollManager)
        }
        .onAppear {
            loadInitialData()
        }
        .onDisappear {
            saveProgress()
            autoScrollManager.stop()
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
        autoScrollManager.stop()
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

class AutoScrollManager: ObservableObject {
    @Published var isScrolling = false
    @Published var speed: Double = 50.0
    @Published var progress: Double = 0.0
    
    private var timer: Timer?
    private var scrollOffset: CGFloat = 0
    
    enum SpeedLevel: String, CaseIterable {
        case verySlow = "极慢"
        case slow = "慢速"
        case normal = "正常"
        case fast = "快速"
        case veryFast = "极速"
        
        var pixelsPerSecond: Double {
            switch self {
            case .verySlow: return 20
            case .slow: return 40
            case .normal: return 60
            case .fast: return 80
            case .veryFast: return 120
            }
        }
    }
    
    func start() {
        isScrolling = true
        startTimer()
    }
    
    func stop() {
        isScrolling = false
        timer?.invalidate()
        timer = nil
    }
    
    func toggle() {
        if isScrolling {
            stop()
        } else {
            start()
        }
    }
    
    func setSpeed(_ speed: Double) {
        self.speed = speed
        if isScrolling {
            timer?.invalidate()
            startTimer()
        }
    }
    
    func setSpeedLevel(_ level: SpeedLevel) {
        setSpeed(level.pixelsPerSecond)
    }
    
    func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.progress = progress
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        let interval = 1.0 / 60.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scrollOffset += CGFloat(self.speed / 60.0)
            NotificationCenter.default.post(
                name: .autoScrollTick,
                object: nil,
                userInfo: ["offset": self.scrollOffset]
            )
        }
    }
    
    func resetOffset() {
        scrollOffset = 0
    }
    
    deinit {
        timer?.invalidate()
    }
}

extension Notification.Name {
    static let autoScrollTick = Notification.Name("autoScrollTick")
    static let autoScrollReset = Notification.Name("autoScrollReset")
}

struct ReaderContentView: View {
    let content: String
    let chapterTitle: String
    let settings: ReaderSettings
    @ObservedObject var autoScrollManager: AutoScrollManager
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(chapterTitle)
                            .font(.system(size: settings.fontSize + 4, weight: .bold))
                            .foregroundColor(settings.currentTextColor)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 30)
                            .id("top")
                        
                        Text(content)
                            .font(.custom(settings.fontFamily, size: settings.fontSize))
                            .lineSpacing(settings.lineSpacing * settings.fontSize)
                            .foregroundColor(settings.currentTextColor)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 50)
                            .background(
                                GeometryReader { contentGeometry in
                                    Color.clear.preference(
                                        key: ContentHeightPreferenceKey.self,
                                        value: contentGeometry.size.height
                                    )
                                }
                            )
                    }
                    .background(
                        GeometryReader { scrollGeometry in
                            Color.clear.preference(
                                key: ScrollViewHeightPreferenceKey.self,
                                value: scrollGeometry.size.height
                            )
                        }
                    )
                    .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                        contentHeight = height
                    }
                    .onPreferenceChange(ScrollViewHeightPreferenceKey.self) { height in
                        scrollViewHeight = height
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .autoScrollTick)) { notification in
                    if autoScrollManager.isScrolling,
                       let offset = notification.userInfo?["offset"] as? CGFloat {
                        withAnimation(.linear(duration: 0)) {
                            proxy.scrollProxy.scrollTo("bottom", anchor: .top)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .autoScrollReset)) { _ in
                    scrollOffset = 0
                }
            }
        }
        .onChange(of: autoScrollManager.isScrolling) { isScrolling in
            if isScrolling {
                autoScrollManager.resetOffset()
            }
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if autoScrollManager.isScrolling {
                        autoScrollManager.stop()
                    }
                }
        )
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AutoScrollIndicatorView: View {
    @ObservedObject var manager: AutoScrollManager
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(manager.isScrolling ? 0 : 180))
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: manager.isScrolling)
                    
                    Text("自动滚动中")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Text(manager.speedLevelText)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(12)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(.bottom, 100)
        }
        .onTapGesture {
            manager.stop()
        }
    }
}

struct AutoScrollSettingsView: View {
    @ObservedObject var manager: AutoScrollManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("滚动速度")
                        Spacer()
                        Text(manager.speedLevelText)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $manager.speed, in: 20...120, step: 10) {
                        Text("滚动速度")
                    } onEditingChanged: { editing in
                        if !editing {
                            manager.setSpeed(manager.speed)
                        }
                    }
                } header: {
                    Text("速度调节")
                }
                
                Section {
                    ForEach(AutoScrollManager.SpeedLevel.allCases, id: \.self) { level in
                        Button(action: {
                            manager.setSpeedLevel(level)
                        }) {
                            HStack {
                                Text(level.rawValue)
                                Spacer()
                                if manager.speed == level.pixelsPerSecond {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } header: {
                    Text("预设速度")
                }
                
                Section {
                    Button(action: {
                        if manager.isScrolling {
                            manager.stop()
                        } else {
                            manager.start()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: manager.isScrolling ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                            Text(manager.isScrolling ? "暂停滚动" : "开始滚动")
                                .font(.system(size: 17))
                            Spacer()
                        }
                    }
                    .foregroundColor(.blue)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("使用提示")
                            .font(.headline)
                        
                        Text("• 双击屏幕可快速开始/暂停自动滚动")
                        Text("• 拖动屏幕将停止自动滚动")
                        Text("• 从上方提示条点击可停止滚动")
                        Text("• 调节速度滑块可实时改变滚动速度")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                } header: {
                    Text("使用说明")
                }
            }
            .navigationTitle("自动滚动设置")
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

extension AutoScrollManager {
    var speedLevelText: String {
        switch speed {
        case ..<30: return "极慢"
        case 30..<50: return "慢速"
        case 50..<70: return "正常"
        case 70..<100: return "快速"
        default: return "极速"
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
    let onAutoScroll: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
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
                
                Button(action: onAutoScroll) {
                    HStack {
                        Image(systemName: "arrow.down.to.line")
                        Text("滚动")
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                }
                
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
                
                Section("行间距") {
                    Slider(value: $settings.lineSpacing, in: 1...3, step: 0.1)
                }
                
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
                
                Section {
                    Toggle("夜间模式", isOn: $settings.isNightMode)
                }
                
                Section("翻页模式") {
                    Picker("翻页模式", selection: $settings.pageTurnType) {
                        ForEach(ReaderSettings.PageTurnType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
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
