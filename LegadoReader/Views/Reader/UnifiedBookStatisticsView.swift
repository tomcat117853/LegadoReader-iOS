import SwiftUI

struct UnifiedBookStatisticsView: View {
    let bookId: String
    @ObservedObject var book: LazyBookProtocol
    
    @State private var statistics: BookStatistics?
    @State private var isCalculating: Bool = false
    @State private var calculationProgress: Double = 0
    @State private var showingDetail: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let stats = statistics {
                statisticsSummary(stats)
            } else if isCalculating {
                calculatingView
            } else {
                startCalculationButton
            }
        }
        .padding()
    }
    
    private func statisticsSummary(_ stats: BookStatistics) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                statCard(
                    title: "总字数",
                    value: stats.formattedTotalCharacters,
                    icon: "character.cursor.ibeam"
                )
                
                statCard(
                    title: "总词数",
                    value: stats.formattedTotalWords,
                    icon: "text.word.spacing"
                )
            }
            
            HStack(spacing: 20) {
                statCard(
                    title: "章节数",
                    value: "\(stats.totalChapters)",
                    icon: "book.pages"
                )
                
                statCard(
                    title: "平均章节字数",
                    value: stats.totalChapters > 0 ? "\(stats.totalCharacters / stats.totalChapters)" : "0",
                    icon: "chart.bar"
                )
            }
            
            if book.chaptersCount > 1 {
                Button(action: {
                    showingDetail = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("查看各章节统计")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
            }
            
            Button(action: {
                Task {
                    await recalculateStatistics()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重新统计")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showingDetail) {
            ChapterStatisticsDetailView(
                statistics: statistics,
                chapterTitles: nil
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var calculatingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: calculationProgress) {
                Text("正在统计 \(book.bookType.rawValue) 格式...")
                    .font(.headline)
            }
            .progressViewStyle(.linear)
                
            Text("\(Int(calculationProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("取消") {
                isCalculating = false
            }
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var startCalculationButton: some View {
        Button(action: {
            Task {
                await recalculateStatistics()
            }
        }) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                Text("点击统计 \(book.bookType.rawValue) 总字数")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private func recalculateStatistics() async {
        isCalculating = true
        calculationProgress = 0
        
        let result = await book.calculateStatistics { progress in
            Task { @MainActor in
                self.calculationProgress = progress
            }
        }
        
        await MainActor.run {
            self.statistics = result
            self.isCalculating = false
        }
    }
}

struct UnifiedBookInfoCard: View {
    @ObservedObject var book: LazyBookProtocol
    let onRead: () -> Void
    let onStatistics: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let coverData = book.coverImage,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 80)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 80)
                        .overlay(
                            Image(systemName: bookTypeIcon)
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.bookTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(book.bookAuthor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 16) {
                        Label(book.bookType.rawValue, systemImage: bookTypeIcon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Label("\(book.chaptersCount)章", systemImage: "book.pages")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: onRead) {
                    HStack {
                        Image(systemName: "book")
                        Text("阅读")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: onStatistics) {
                    HStack {
                        Image(systemName: "chart.bar")
                        Text("统计")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var bookTypeIcon: String {
        switch book.bookType {
        case .txt: return "doc.text"
        case .epub: return "book"
        case .pdf: return "doc.richtext"
        case .umd: return "books.vertical"
        case .azw: return "books"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct UnifiedBookListItem: View {
    @ObservedObject var book: LazyBookProtocol
    let onRead: () -> Void
    let onStatistics: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let coverData = book.coverImage,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 80)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 80)
                    .overlay(
                        Image(systemName: bookTypeIcon)
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.bookTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(book.bookAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 16) {
                    Label(book.bookType.rawValue, systemImage: bookTypeIcon)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Label("\(book.chaptersCount)章", systemImage: "book.pages")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button(action: onRead) {
                    Image(systemName: "book")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                Button(action: onStatistics) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var bookTypeIcon: String {
        switch book.bookType {
        case .txt: return "doc.text"
        case .epub: return "book"
        case .pdf: return "doc.richtext"
        case .umd: return "books.vertical"
        case .azw: return "books"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct LazyBookReaderView: View {
    let book: LazyBookProtocol
    let bookId: String
    
    @State private var currentChapterIndex: Int = 0
    @State private var currentChapter: BookChapterContent?
    @State private var isLoading: Bool = true
    @State private var showingChapterList: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingStatistics: Bool = false
    
    @StateObject private var readerSettings = ReaderSettings.shared
    @StateObject private var eyeCareManager = EyeCareManager.shared
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("加载中...")
            } else if let chapter = currentChapter {
                readerContent(chapter)
            }
        }
        .task {
            await loadChapter(0)
        }
        .sheet(isPresented: $showingChapterList) {
            LazyChapterListView(book: book, currentIndex: $currentChapterIndex)
        }
        .sheet(isPresented: $showingStatistics) {
            UnifiedBookStatisticsView(bookId: bookId, book: book)
        }
    }
    
    private var backgroundColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveBackgroundColor
        }
        return readerSettings.backgroundColor.color
    }
    
    private var textColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveTextColor
        }
        return readerSettings.textColor
    }
    
    private func readerContent(_ chapter: BookChapterContent) -> some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(chapter.title)
                                .font(.system(size: readerSettings.fontSize + 4, weight: .bold))
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 16)
                            
                            Text(chapter.content)
                                .font(.custom(readerSettings.fontFamily, size: readerSettings.fontSize))
                                .foregroundColor(textColor)
                                .lineSpacing(readerSettings.lineSpacing)
                                .padding(.horizontal, readerSettings.horizontalPadding)
                                .textSelection(.enabled)
                        }
                    }
                    
                    chapterNavigation
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingButtons
                    }
                }
            }
        }
    }
    
    private var floatingButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showingSettings = true }) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Button(action: { showingChapterList = true }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Button(action: { showingStatistics = true }) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    private var chapterNavigation: some View {
        HStack {
            if currentChapterIndex > 0 {
                Button(action: {
                    currentChapterIndex -= 1
                    Task { await loadChapter(currentChapterIndex) }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            
            Spacer()
            
            Text("\(currentChapterIndex + 1) / \(book.chaptersCount)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            
            Spacer()
            
            if currentChapterIndex < book.chaptersCount - 1 {
                Button(action: {
                    currentChapterIndex += 1
                    Task { await loadChapter(currentChapterIndex) }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
        }
        .background(Color(.systemGray6))
    }
    
    private func loadChapter(_ index: Int) async {
        isLoading = true
        do {
            let chapter = try await book.loadChapter(at: index)
            await MainActor.run {
                self.currentChapter = chapter
                self.currentChapterIndex = index
                self.isLoading = false
            }
            await book.preloadChapters(around: index, range: 2)
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct LazyChapterListView: View {
    @ObservedObject var book: LazyBookProtocol
    @Binding var currentIndex: Int
    let onSelect: ((Int) -> Void)? = nil
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var chapters: [Int: String] = [:]
    @State private var isLoading: Bool = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载目录...")
                } else {
                    List {
                        ForEach(sortedChapterIndices, id: \.self) { index in
                            Button(action: {
                                currentIndex = index
                                onSelect?(index)
                                dismiss()
                            }) {
                                HStack {
                                    Text(chapters[index] ?? "第\(index + 1)章")
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    
                                    Spacer()
                                    
                                    if index == currentIndex {
                                        Image(systemName: "book.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索章节")
            .task {
                await loadAllChapters()
            }
        }
    }
    
    private var sortedChapterIndices: [Int] {
        chapters.keys.sorted()
    }
    
    private var filteredChapters: [(index: Int, title: String)] {
        let allChapters = chapters.map { (index: $0.key, title: $0.value) }
        if searchText.isEmpty {
            return allChapters.sorted { $0.index < $1.index }
        }
        return allChapters.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func loadAllChapters() async {
        isLoading = true
        for i in 0..<min(book.chaptersCount, 100) {
            if let chapter = try? await book.loadChapter(at: i) {
                await MainActor.run {
                    self.chapters[i] = chapter.title
                }
            }
        }
        await MainActor.run {
            self.isLoading = false
        }
    }
}
