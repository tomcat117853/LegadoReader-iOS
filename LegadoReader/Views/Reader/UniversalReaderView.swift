import SwiftUI
import Combine

enum ReaderMode {
    case networkBook(book: Book, source: BookSource)
    case lazyBook(lazyBook: LazyBookProtocol, bookId: String)
}

struct UniversalReaderView: View {
    let readerMode: ReaderMode
    
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var readerSettings: ReaderSettings
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var annotationService = AnnotationService.shared
    @StateObject private var styleManager = AnnotationStyleManager.shared
    @StateObject private var eyeCareManager = EyeCareManager.shared
    
    @State private var chapters: [Chapter] = []
    @State private var currentChapter: Chapter?
    @State private var currentChapterIndex: Int = 0
    @State private var chapterContent: String = ""
    @State private var currentLazyChapter: BookChapterContent?
    @State private var isLoading = true
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var showingMenu = false
    @State private var showingAudioBook = false
    @State private var showingAutoScroll = false
    @State private var showingStatistics = false
    @State private var autoScrollManager = AutoScrollManager()
    @State private var readingStartTime = Date()
    @State private var readingDuration: TimeInterval = 0
    
    @State private var showingAnnotationMenu = false
    @State private var selectedText = ""
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var showingAnnotationEdit = false
    @State private var showingAnnotationPopup = false
    @State private var selectedAnnotation: AnnotationService.Annotation?
    @State private var isBrightnessAdjusting = false
    @State private var showingSourceSelector = false
    @State private var showingSettingsMenu = false
    
    private var isLazyBookMode: Bool {
        if case .lazyBook = readerMode { return true }
        return false
    }
    
    private var isEPUB: Bool {
        if case .lazyBook(let lazyBook) = readerMode {
            return lazyBook.bookType == .epub
        }
        return false
    }
    
    private var epubBaseURL: URL? {
        guard isEPUB, let lazyBook = readerMode.lazyBook as? LazyEPUBBook else { return nil }
        return lazyBook.baseURL
    }
    
    private var currentBookId: String {
        switch readerMode {
        case .networkBook(let book, _): return book.id
        case .lazyBook(_, let bookId): return bookId
        }
    }
    
    private var currentBookTitle: String {
        switch readerMode {
        case .networkBook(let book, _): return book.name
        case .lazyBook(let lazyBook, _): return lazyBook.bookTitle
        }
    }
    
    private var currentChapterTitle: String {
        switch readerMode {
        case .networkBook: return currentChapter?.title ?? ""
        case .lazyBook: return currentLazyChapter?.title ?? ""
        }
    }
    
    private var backgroundColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveBackgroundColor
        }
        return readerSettings.currentBackground
    }
    
    private var textColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveTextColor
        }
        return readerSettings.currentTextColor
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("加载中...")
            } else {
                readerContent
                    .onTapGesture {
                        withAnimation {
                            showingMenu.toggle()
                        }
                    }
            }
            
            TwoFingerBrightnessController(isActive: .constant(true)) { newBrightness in
            }
            
            BrightnessIndicatorOverlay()
            
            if showingMenu {
                VStack {
                    ReaderTopBar(
                        bookName: currentBookTitle,
                        chapterTitle: currentChapterTitle,
                        onBack: { dismiss() },
                        onShowChapters: { showingChapterList = true },
                        onShowSettings: { showingSettings = true },
                        onSelectSource: { showingSourceSelector = true }
                    )
                    .background(backgroundColor.opacity(0.95))
                    
                    Spacer()
                    
                    if isLazyBookMode {
                        ReaderBottomBar(
                            currentChapter: nil,
                            totalChapters: readerMode.lazyBook?.chaptersCount ?? 0,
                            currentIndex: currentChapterIndex,
                            onPrevious: loadPreviousChapter,
                            onNext: loadNextChapter,
                            onAudioBook: { showingAudioBook = true },
                            onAutoScroll: { showingAutoScroll = true },
                            onShowChapters: { showingChapterList = true },
                            onCache: {},
                            onPageTurn: {},
                            onSettings: { showingSettings = true },
                            progress: Double(currentChapterIndex) / Double(readerMode.lazyBook?.chaptersCount ?? 1)
                        )
                        .background(backgroundColor.opacity(0.95))
                    } else {
                        ReaderBottomBar(
                            currentChapter: currentChapter,
                            totalChapters: chapters.count,
                            currentIndex: currentChapterIndex,
                            onPrevious: loadPreviousChapter,
                            onNext: loadNextChapter,
                            onAudioBook: { showingAudioBook = true },
                            onAutoScroll: { showingAutoScroll = true },
                            onShowChapters: { showingChapterList = true },
                            onCache: {},
                            onPageTurn: {},
                            onSettings: { showingSettings = true },
                            progress: Double(currentChapterIndex) / Double(max(chapters.count, 1))
                        )
                        .background(backgroundColor.opacity(0.95))
                    }
                }
            }
            
            if showingAnnotationMenu {
                annotationMenuOverlay
            }
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsMenuView()
        }
        .sheet(isPresented: $showingChapterList) {
            chapterListView
        }
        .sheet(isPresented: $showingAudioBook) {
            AudioBookView()
        }
        .sheet(isPresented: $showingAutoScroll) {
            AutoScrollSettingsView(manager: autoScrollManager)
        }
        .sheet(isPresented: $showingSourceSelector) {
            BookSourceSelectorView(bookName: currentBookTitle)
        }
        .sheet(isPresented: $showingStatistics) {
            if let lazyBook = readerMode.lazyBook {
                UnifiedBookStatisticsView(bookId: currentBookId, book: lazyBook)
            }
        }
        .sheet(isPresented: $showingAnnotationEdit) {
            NavigationView {
                AnnotationEditView(
                    bookId: currentBookId,
                    chapterId: isLazyBookMode ? (currentLazyChapter?.id ?? "") : (currentChapter?.id ?? ""),
                    chapterIndex: currentChapterIndex,
                    chapterTitle: currentChapterTitle,
                    bookName: currentBookTitle,
                    selectedText: selectedText,
                    selectedRange: selectedRange,
                    existingAnnotation: selectedAnnotation,
                    onSave: { annotation in
                        if selectedAnnotation != nil {
                            annotationService.updateAnnotation(annotation)
                        } else {
                            annotationService.addAnnotation(annotation)
                        }
                        showingAnnotationEdit = false
                        selectedAnnotation = nil
                    }
                )
            }
        }
        .task {
            await loadInitialData()
            readingStartTime = Date()
        }
        .onDisappear {
            saveProgress()
            saveReadingHistory()
            autoScrollManager.stop()
        }
    }
    
    @ViewBuilder
    private var chapterListView: some View {
        if isLazyBookMode, let lazyBook = readerMode.lazyBook {
            LazyChapterListView(book: lazyBook, currentIndex: $currentChapterIndex)
        } else {
            ChapterSelectorView(
                chapters: chapters,
                currentChapter: currentChapter,
                onSelect: { chapter in
                    loadChapter(chapter)
                }
            )
        }
    }
    
    @ViewBuilder
    private var readerContent: some View {
        if isLazyBookMode, let chapter = currentLazyChapter {
            if isEPUB {
                EPUBCSSContentView(
                    chapter: chapter,
                    baseURL: epubBaseURL,
                    fontSize: readerSettings.fontSize,
                    fontFamily: readerSettings.fontFamily,
                    backgroundColor: backgroundColor,
                    textColor: textColor,
                    annotations: getCurrentAnnotations(),
                    onTextSelected: { text, range in
                        selectedText = text
                        selectedRange = range
                        showingAnnotationMenu = true
                    }
                )
            } else {
                ScrollView {
                    LazySelectableTextView(
                        chapterTitle: chapter.title,
                        content: chapter.content,
                        fontSize: readerSettings.fontSize,
                        fontFamily: readerSettings.fontFamily,
                        lineSpacing: readerSettings.lineSpacing,
                        horizontalPadding: readerSettings.horizontalPadding,
                        textColor: textColor,
                        annotations: getCurrentAnnotations(),
                        onTextSelected: { text, range in
                            selectedText = text
                            selectedRange = range
                            showingAnnotationMenu = true
                        }
                    )
                }
            }
        } else {
            SelectableReaderContentView(
                content: chapterContent,
                chapterTitle: currentChapter?.title ?? "",
                settings: readerSettings,
                annotations: getCurrentAnnotations(),
                onTextSelected: { text, range in
                    selectedText = text
                    selectedRange = range
                    showingAnnotationMenu = true
                },
                onAnnotationTapped: { annotation in
                    selectedAnnotation = annotation
                    showingAnnotationPopup = true
                }
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private var annotationMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture {
                    showingAnnotationMenu = false
                }
            
            AnnotationPopupMenuView(
                position: CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.4),
                selectedText: selectedText,
                onHighlight: addHighlight,
                onAddNote: { showingAnnotationEdit = true },
                onCopy: copySelectedText,
                onShare: shareSelectedText
            )
        }
    }
    
    private func loadInitialData() async {
        isLoading = true
        
        if isLazyBookMode, let lazyBook = readerMode.lazyBook {
            do {
                try await lazyBook.loadMetadata()
                await loadLazyChapter(0)
            } catch {
                print("加载失败: \(error)")
            }
        } else if case .networkBook(let book, let source) = readerMode {
            await loadNetworkBookChapters(book: book, source: source)
        }
        
        isLoading = false
    }
    
    private func loadNetworkBookChapters(book: Book, source: BookSource) async {
        await MainActor.run {
            isLoading = true
        }
        
        chapters = book.chapters ?? []
        
        if let firstChapter = chapters.first {
            currentChapter = firstChapter
            chapterContent = await loadChapterContent(firstChapter)
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func loadChapterContent(_ chapter: Chapter) async -> String {
        return chapter.content
    }
    
    private func loadChapter(_ chapter: Chapter) {
        currentChapter = chapter
        currentChapterIndex = chapters.firstIndex(where: { $0.id == chapter.id }) ?? 0
        Task {
            chapterContent = await loadChapterContent(chapter)
        }
    }
    
    private func loadLazyChapter(_ index: Int) async {
        guard let lazyBook = readerMode.lazyBook else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let chapter = try await lazyBook.loadChapter(at: index)
            await MainActor.run {
                self.currentLazyChapter = chapter
                self.currentChapterIndex = index
                self.isLoading = false
            }
            await lazyBook.preloadChapters(around: index, range: 2)
        } catch {
            print("加载章节失败: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadPreviousChapter() {
        if isLazyBookMode {
            if currentChapterIndex > 0 {
                Task {
                    await loadLazyChapter(currentChapterIndex - 1)
                }
            }
        } else {
            if let current = currentChapter,
               let currentIndex = chapters.firstIndex(where: { $0.id == current.id }),
               currentIndex > 0 {
                loadChapter(chapters[currentIndex - 1])
            }
        }
    }
    
    private func loadNextChapter() {
        if isLazyBookMode {
            if let lazyBook = readerMode.lazyBook,
               currentChapterIndex < lazyBook.chaptersCount - 1 {
                Task {
                    await loadLazyChapter(currentChapterIndex + 1)
                }
            }
        } else {
            if let current = currentChapter,
               let currentIndex = chapters.firstIndex(where: { $0.id == current.id }),
               currentIndex < chapters.count - 1 {
                loadChapter(chapters[currentIndex + 1])
            }
        }
    }
    
    private func saveProgress() {
        if isLazyBookMode {
            return
        }
        
        if let chapter = currentChapter, let book = readerMode.book {
            bookStore.updateReadingProgress(book: book, chapter: chapter, position: 0)
        }
    }
    
    private func getCurrentAnnotations() -> [AnnotationService.Annotation] {
        return annotationService.getAnnotations(for: currentBookId, chapterIndex: currentChapterIndex)
    }
    
    private func addHighlight() {
        guard !selectedText.isEmpty else { return }
        
        let annotation = AnnotationService.Annotation(
            bookId: currentBookId,
            chapterId: isLazyBookMode ? (currentLazyChapter?.id ?? "") : (currentChapter?.id ?? ""),
            chapterIndex: currentChapterIndex,
            chapterTitle: currentChapterTitle,
            bookName: currentBookTitle,
            startOffset: selectedRange.location,
            endOffset: selectedRange.location + selectedRange.length,
            text: selectedText,
            style: styleManager.currentStyle,
            colorHex: styleManager.currentColor.hex
        )
        
        annotationService.addAnnotation(annotation)
        showingAnnotationMenu = false
    }
    
    private func copySelectedText() {
        UIPasteboard.general.string = selectedText
        showingAnnotationMenu = false
    }
    
    private func shareSelectedText() {
        let activityVC = UIActivityViewController(
            activityItems: [selectedText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        showingAnnotationMenu = false
    }
    
    private func deleteAnnotation(_ annotation: AnnotationService.Annotation) {
        annotationService.removeAnnotation(annotation)
        showingAnnotationPopup = false
        selectedAnnotation = nil
    }
    
    private func saveReadingHistory() {
        readingDuration = Date().timeIntervalSince(readingStartTime)
        
        if readingDuration < 60 {
            return
        }
        
        if let book = readerMode.book {
            let record = ReadingRecord(book: book, duration: readingDuration)
            ReadingHistoryManager.shared.saveRecord(record)
        } else if let lazyBook = readerMode.lazyBook {
            let book = Book()
            book.id = currentBookId
            book.name = lazyBook.bookTitle
            book.cover = lazyBook.cover
            book.lastReadChapter = currentChapterTitle
            book.progress = Double(currentChapterIndex) / Double(lazyBook.chaptersCount)
            
            let record = ReadingRecord(book: book, duration: readingDuration)
            ReadingHistoryManager.shared.saveRecord(record)
        }
    }
}

extension ReaderMode {
    var book: Book? {
        if case .networkBook(let book, _) = self { return book }
        return nil
    }
    
    var lazyBook: LazyBookProtocol? {
        if case .lazyBook(let lazyBook, _) = self { return lazyBook }
        return nil
    }
}
