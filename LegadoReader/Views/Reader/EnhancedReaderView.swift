import SwiftUI

struct EnhancedReaderView: View {
    @StateObject private var readerSettings = ReaderSettings.shared
    @StateObject private var eyeCareManager = EyeCareManager.shared
    @StateObject private var noteManager = BookmarkNoteManager.shared
    @StateObject private var historyManager = ReadingHistoryManager.shared
    @EnvironmentObject var sourceStore: SourceStore
    
    let book: Book
    let source: BookSource
    
    @State private var chapters: [Chapter] = []
    @State private var currentChapterIndex: Int = 0
    @State private var currentPosition: CGFloat = 0
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var showingBookmarkSheet = false
    @State private var showingNoteSheet = false
    @State private var showingContextMenu = false
    @State private var contextMenuPosition: CGPoint = .zero
    @State private var selectedText: String = ""
    @State private var showingCopyMenu = false
    @State private var audioAutoFollowEnabled: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                if readerSettings.pageTurnMode == .vertical || readerSettings.pageTurnMode == .horizontal {
                    VerticalScrollReaderView(
                        book: book,
                        source: source,
                        chapters: $chapters,
                        currentChapterIndex: $currentChapterIndex,
                        currentPosition: $currentPosition
                    )
                } else {
                    PageBasedReaderView(
                        book: book,
                        source: source,
                        chapters: $chapters,
                        currentChapterIndex: $currentChapterIndex,
                        audioAutoFollowEnabled: $audioAutoFollowEnabled
                    )
                }
                
                if readerSettings.pageTurnMode == .vertical {
                    floatingHeader
                }
                
                navigationOverlay
                
                if readerSettings.pageTurnMode != .none && readerSettings.enablePageAnimation {
                    pageTurnGestureLayer
                }
                
                if showingContextMenu {
                    contextMenuOverlay
                }
            }
            .gesture(longPressGesture)
            .onTapGesture(count: 2) {
                toggleAutoScroll()
            }
            .onTapGesture {
                handleTap()
            }
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsSheet()
        }
        .sheet(isPresented: $showingChapterList) {
            ChapterListView(book: book, chapters: chapters)
        }
        .sheet(isPresented: $showingBookmarkSheet) {
            AddBookmarkSheet(book: book, chapterIndex: currentChapterIndex)
        }
        .sheet(isPresented: $showingNoteSheet) {
            NoteEditorView(book: book, chapterIndex: currentChapterIndex, selectedText: selectedText)
        }
        .onAppear {
            loadChapters()
            restoreReadingPosition()
        }
        .onDisappear {
            saveReadingPosition()
        }
        .onChange(of: currentChapterIndex) { _, _ in
            historyManager.savePosition(bookId: book.id, chapterIndex: currentChapterIndex)
        }
    }
    
    private var backgroundColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveBackgroundColor
        }
        return readerSettings.backgroundColor.color
    }
    
    private var floatingHeader: some View {
        VStack {
            if readerSettings.showChapterTitle {
                HStack {
                    Text(chapters[safe: currentChapterIndex]?.title ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
            }
            Spacer()
        }
    }
    
    private var navigationOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
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
                    
                    Button(action: { showingBookmarkSheet = true }) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var pageTurnGestureLayer: some View {
        if readerSettings.pageTurnMode == .horizontal && !readerSettings.tapZoneEnabled {
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        previousPage()
                    }
                
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        nextPage()
                    }
            }
        }
    }
    
    private var contextMenuOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                contextMenuButton(icon: "doc.on.doc", title: "复制") {
                    UIPasteboard.general.string = selectedText
                    showingContextMenu = false
                }
                
                Divider()
                
                contextMenuButton(icon: "bookmark", title: "添加书签") {
                    showingBookmarkSheet = true
                    showingContextMenu = false
                }
                
                Divider()
                
                contextMenuButton(icon: "note.text", title: "添加笔记") {
                    showingNoteSheet = true
                    showingContextMenu = false
                }
                
                Divider()
                
                contextMenuButton(icon: "square.and.arrow.up", title: "分享") {
                    shareText()
                    showingContextMenu = false
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func contextMenuButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                Spacer()
            }
            .padding()
        }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
            }
    }
    
    private func handleTap() {
        if showingContextMenu {
            withAnimation {
                showingContextMenu = false
            }
        }
    }
    
    private func toggleAutoScroll() {
    }
    
    private func previousPage() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        saveReadingPosition()
    }
    
    private func nextPage() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
        saveReadingPosition()
    }
    
    private func shareText() {
    }
    
    private func loadChapters() {
        Task {
        }
    }
    
    private func restoreReadingPosition() {
        if let position = historyManager.getPosition(for: book.id) {
            currentChapterIndex = position.chapterIndex
            currentPosition = position.scrollOffset
        }
    }
    
    private func saveReadingPosition() {
        historyManager.savePosition(
            bookId: book.id,
            chapterIndex: currentChapterIndex,
            scrollOffset: currentPosition
        )
    }
}

struct PageBasedReaderView: View {
    let book: Book
    let source: BookSource
    @Binding var chapters: [Chapter]
    @Binding var currentChapterIndex: Int
    @Binding var audioAutoFollowEnabled: Bool
    
    @StateObject private var readerSettings = ReaderSettings.shared
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 1
    
    var body: some View {
        TabView(selection: $currentChapterIndex) {
            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                PageContentView(
                    chapter: chapter,
                    currentPage: $currentPage,
                    totalPages: $totalPages,
                    audioAutoFollowEnabled: $audioAutoFollowEnabled
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}

struct PageContentView: View {
    let chapter: Chapter
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var audioAutoFollowEnabled: Bool
    
    @StateObject private var readerSettings = ReaderSettings.shared
    @StateObject private var eyeCareManager = EyeCareManager.shared
    @State private var content: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(chapter.title)
                        .font(.system(size: readerSettings.fontSize + 4, weight: .bold))
                        .foregroundColor(effectiveTextColor)
                        .padding(.bottom, 8)
                    
                    Text(content.isEmpty ? chapter.content ?? "" : content)
                        .font(.system(size: readerSettings.fontSize))
                        .foregroundColor(effectiveTextColor)
                        .lineSpacing(readerSettings.lineSpacing)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, readerSettings.horizontalPadding)
                .padding(.vertical, readerSettings.verticalPadding)
                .frame(minWidth: geometry.size.width)
            }
        }
        .background(effectiveBackgroundColor)
        .onAppear {
            loadContent()
        }
    }
    
    private var effectiveBackgroundColor: Color {
        eyeCareManager.isEyeCareEnabled ? eyeCareManager.effectiveBackgroundColor : readerSettings.backgroundColor.color
    }
    
    private var effectiveTextColor: Color {
        eyeCareManager.isEyeCareEnabled ? eyeCareManager.effectiveTextColor : readerSettings.currentTextColor
    }
    
    private func loadContent() {
        if content.isEmpty {
            content = chapter.content ?? ""
        }
    }
}

struct AddBookmarkSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    let book: Book
    let chapterIndex: Int
    
    @State private var bookmarkName = ""
    @State private var bookmarkNote = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("书签名称", text: $bookmarkName)
                    
                    TextField("备注（可选）", text: $bookmarkNote, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("书签信息")
                }
                
                Section {
                    HStack {
                        Text("书籍")
                        Spacer()
                        Text(book.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("章节")
                        Spacer()
                        Text("第\(chapterIndex + 1)章")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("当前位置")
                }
            }
            .navigationTitle("添加书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveBookmark()
                    }
                    .fontWeight(.semibold)
                    .disabled(bookmarkName.isEmpty)
                }
            }
        }
    }
    
    private func saveBookmark() {
        bookmarkManager.addBookmark(name: bookmarkName, url: "", icon: "bookmark.fill")
        dismiss()
    }
}

struct NoteEditorView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var noteManager = BookmarkNoteManager.shared
    
    let book: Book
    let chapterIndex: Int
    let selectedText: String
    
    @State private var noteContent: String
    @State private var selectedColor: HighlightColor = .yellow
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    init(book: Book, chapterIndex: Int, selectedText: String) {
        self.book = book
        self.chapterIndex = chapterIndex
        self.selectedText = selectedText
        self._noteContent = State(initialValue: selectedText)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(selectedText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                } header: {
                    Text("选中的内容")
                }
                
                Section {
                    TextField("笔记内容", text: $noteContent, axis: .vertical)
                        .lineLimit(5...10)
                } header: {
                    Text("笔记")
                }
                
                Section {
                    ForEach(HighlightColor.allCases, id: \.self) { color in
                        Button(action: { selectedColor = color }) {
                            HStack {
                                Circle()
                                    .fill(Color(hex: color.color) ?? .yellow)
                                    .frame(width: 24, height: 24)
                                Text(color.rawValue)
                                Spacer()
                                if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } header: {
                    Text("高亮颜色")
                }
                
                Section {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button(action: { tags.removeAll { $0 == tag } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("添加标签", text: $newTag)
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newTag.isEmpty)
                    }
                } header: {
                    Text("标签")
                }
            }
            .navigationTitle("添加笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveNote()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func addTag() {
        guard !newTag.isEmpty else { return }
        tags.append(newTag)
        newTag = ""
    }
    
    private func saveNote() {
        dismiss()
    }
}

struct AudioAutoFollowSettingsView: View {
    @Binding var isEnabled: Bool
    @State private var followMode: FollowMode = .chapter
    
    enum FollowMode: String, CaseIterable {
        case sentence = "句子跟随"
        case paragraph = "段落跟随"
        case chapter = "章节跟随"
        
        var description: String {
            switch self {
            case .sentence: return "每句话自动滚动"
            case .paragraph: return "每段自动滚动"
            case .chapter: return "每个章节滚动"
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("听书时自动翻页", isOn: $isEnabled)
                    .tint(.blue)
            } footer: {
                Text("听书时自动跟随朗读进度翻页")
            }
            
            if isEnabled {
                Section {
                    Picker("跟随模式", selection: $followMode) {
                        ForEach(FollowMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.rawValue)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("翻页模式")
                }
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
