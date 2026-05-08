import SwiftUI

enum PageTurnMode: String, Codable, CaseIterable {
    case horizontal = "水平滑动"
    case vertical = "垂直滑动"
    case curl = "仿真翻页"
    case none = "无效果"
    
    var icon: String {
        switch self {
        case .horizontal: return "arrow.left.and.right"
        case .vertical: return "arrow.up.and.down"
        case .curl: return "book"
        case .none: return "square"
        }
    }
    
    var description: String {
        switch self {
        case .horizontal: return "左右滑动翻页"
        case .vertical: return "上下滑动连续阅读"
        case .curl: return "仿真翻书效果"
        case .none: return "无翻页动画"
        }
    }
}

struct VerticalScrollReaderView: View {
    @StateObject private var readerSettings = ReaderSettings.shared
    @StateObject private var eyeCareManager = EyeCareManager.shared
    @StateObject private var annotationService = AnnotationService.shared
    @EnvironmentObject var sourceStore: SourceStore
    
    let book: Book
    let source: BookSource
    @Binding var chapters: [Chapter]
    @Binding var currentChapterIndex: Int
    @Binding var currentPosition: CGFloat
    
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var showingProgressIndicator = false
    @State private var currentProgress: Double = 0
    @State private var autoScrollSpeed: Double = 1.0
    @State private var isAutoScrolling = false
    @State private var autoScrollTimer: Timer?
    @State private var showingAnnotationPopup = false
    @State private var popupPosition: CGPoint = .zero
    @State private var selectedAnnotation: AnnotationService.Annotation?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                                ChapterContentView(
                                    book: book,
                                    chapter: chapter,
                                    fontSize: effectiveFontSize,
                                    textColor: effectiveTextColor,
                                    lineSpacing: effectiveLineSpacing,
                                    textAlignment: textAlignment,
                                    backgroundColor: backgroundColor,
                                    chapterIndex: index,
                                    isCurrentChapter: index == currentChapterIndex
                                )
                                .id(chapter.id)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: contentGeometry.frame(in: .named("scrollView")).minY
                                )
                            }
                        )
                    }
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        handleScrollOffset(value, viewHeight: geometry.size.height)
                    }
                    .onAppear {
                        scrollToCurrentPosition(proxy: proxy, height: geometry.size.height)
                    }
                }
                
                if showingProgressIndicator {
                    progressOverlay
                }
                
                if isAutoScrolling {
                    autoScrollIndicator
                }
                
                navigationOverlay
                
                eyeCareOverlay
            }
            .gesture(tapGesture)
            .onTapGesture(count: 2) {
                toggleAutoScroll()
            }
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsSheet()
        }
        .sheet(isPresented: $showingChapterList) {
            ChapterListView(book: book, chapters: chapters)
        }
    }
    
    private var backgroundColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveBackgroundColor
        }
        return readerSettings.backgroundColor
    }
    
    private var effectiveTextColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveTextColor
        }
        return readerSettings.textColor
    }
    
    private var effectiveFontSize: CGFloat {
        return readerSettings.fontSize * eyeCareManager.fontSizeMultiplier
    }
    
    private var effectiveLineSpacing: CGFloat {
        return readerSettings.lineSpacing * eyeCareManager.lineSpacingMultiplier
    }
    
    private var horizontalPadding: CGFloat {
        return readerSettings.horizontalPadding
    }
    
    private var verticalPadding: CGFloat {
        return readerSettings.verticalPadding
    }
    
    private var textAlignment: TextAlignment {
        switch readerSettings.textAlignment {
        case "left": return .leading
        case "center": return .center
        case "right": return .trailing
        case "justify": return .leading
        default: return .leading
        }
    }
    
    private var progressOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Text("\(Int(currentProgress * 100))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("第 \(currentChapterIndex + 1) / \(chapters.count) 章")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding()
            }
        }
    }
    
    private var autoScrollIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    Text("自动滚动")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .padding()
            }
        }
    }
    
    private var navigationOverlay: some View {
        VStack {
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
                    
                    Button(action: { toggleAutoScroll() }) {
                        Image(systemName: isAutoScrolling ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private var eyeCareOverlay: some View {
        if eyeCareManager.isEyeCareEnabled {
            Rectangle()
                .fill(eyeCareManager.overlayColor)
                .opacity(eyeCareManager.overlayOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
    
    private var tapGesture: some View {
        TapGesture()
            .onEnded { _ in
            }
    }
    
    private func handleScrollOffset(_ offset: CGFloat, viewHeight: CGFloat) {
        guard !isAutoScrolling else { return }
        
        let maxOffset = contentHeight - viewHeight
        if maxOffset > 0 {
            currentProgress = min(max(0, -offset / maxOffset), 1)
        }
        
        if -offset >= maxOffset - 50 && currentChapterIndex < chapters.count - 1 {
            let remainingHeight = contentHeight + offset
            if remainingHeight < viewHeight * 0.5 {
                moveToNextChapter()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !isAutoScrolling {
            }
        }
    }
    
    private func scrollToCurrentPosition(proxy: ScrollViewProxy, height: CGFloat) {
        guard currentChapterIndex < chapters.count else { return }
        
        let chapterId = chapters[currentChapterIndex].id
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(chapterId, anchor: .top)
        }
    }
    
    private func moveToNextChapter() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
        saveProgress()
    }
    
    private func moveToPreviousChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        saveProgress()
    }
    
    private func saveProgress() {
        BookStore.shared.updateReadingProgress(
            bookId: book.id,
            chapterIndex: currentChapterIndex,
            progress: currentProgress
        )
    }
    
    private func toggleAutoScroll() {
        isAutoScrolling.toggle()
        
        if isAutoScrolling {
            startAutoScroll()
        } else {
            stopAutoScroll()
        }
    }
    
    private func startAutoScroll() {
        autoScrollTimer?.invalidate()
        
        let interval = 0.05 / autoScrollSpeed
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

struct ChapterContentView: View {
    let book: Book
    let chapter: Chapter
    let fontSize: CGFloat
    let textColor: Color
    let lineSpacing: CGFloat
    let textAlignment: TextAlignment
    let backgroundColor: Color
    let chapterIndex: Int
    let isCurrentChapter: Bool
    
    @StateObject private var annotationService = AnnotationService.shared
    @State private var content: String = ""
    @State private var isLoading = false
    @State private var annotations: [AnnotationService.Annotation] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(chapter.title)
                .font(.system(size: fontSize + 4, weight: .bold))
                .foregroundColor(textColor)
                .padding(.bottom, 8)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else {
                AnnotationText(
                    content: content,
                    annotations: annotations,
                    fontSize: fontSize,
                    textColor: textColor,
                    lineSpacing: lineSpacing,
                    textAlignment: textAlignment,
                    onAnnotationTap: { annotation in
                        NotificationCenter.default.post(
                            name: .showAnnotationPopup,
                            object: annotation
                        )
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment(for: textAlignment))
        .padding(.vertical, 20)
        .background(backgroundColor)
        .onAppear {
            loadContent()
            loadAnnotations()
        }
    }
    
    private var alignment: Alignment {
        switch textAlignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        @unknown default: return .leading
        }
    }
    
    private func loadContent() {
        guard content.isEmpty else { return }
        
        isLoading = true
        
        Task {
            if let loadedContent = await BookStore.shared.loadChapterContent(for: chapter, book: book) {
                await MainActor.run {
                    content = loadedContent
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    content = chapter.content ?? ""
                    isLoading = false
                }
            }
        }
    }
    
    private func loadAnnotations() {
        annotations = annotationService.getAnnotations(for: book.id, chapterIndex: chapterIndex)
    }
}

struct AnnotationText: View {
    let content: String
    let annotations: [AnnotationService.Annotation]
    let fontSize: CGFloat
    let textColor: Color
    let lineSpacing: CGFloat
    let textAlignment: TextAlignment
    let onAnnotationTap: (AnnotationService.Annotation) -> Void
    
    var body: some View {
        let attributedText = NSAttributedString(string: content)
        Text(content)
            .font(.system(size: fontSize))
            .foregroundColor(textColor)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(textAlignment)
            .overlay(annotationHighlights)
    }
    
    private var annotationHighlights: some View {
        ZStack {
            ForEach(annotations) { annotation in
                if let range = annotation.range(in: content) {
                    Text(content[range])
                        .font(.system(size: fontSize))
                        .foregroundColor(.clear)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: annotation.colorHex) ?? .yellow)
                                .opacity(0.3)
                        )
                        .onTapGesture {
                            onAnnotationTap(annotation)
                        }
                }
            }
        }
    }
}

extension AnnotationService.Annotation {
    func range(in text: String) -> Range<String.Index>? {
        guard startOffset >= 0, endOffset <= text.count else { return nil }
        let startIndex = text.index(text.startIndex, offsetBy: startOffset)
        let endIndex = text.index(text.startIndex, offsetBy: endOffset)
        return startIndex..<endIndex
    }
}

extension Notification.Name {
    static let showAnnotationPopup = Notification.Name("showAnnotationPopup")
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContinuousScrollSettingsView: View {
    @StateObject private var readerSettings = ReaderSettings.shared
    @State private var autoScrollSpeed: Double = 1.0
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("翻页模式", selection: $readerSettings.pageTurnMode) {
                        ForEach(PageTurnMode.allCases, id: \.self) { mode in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(mode.rawValue)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: mode.icon)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("翻页模式")
                } footer: {
                    Text("选择阅读时的翻页方式")
                }
                
                if readerSettings.pageTurnMode == .vertical {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("滚动速度")
                                Spacer()
                                Text(String(format: "%.1fx", autoScrollSpeed))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $autoScrollSpeed, in: 0.5...3.0, step: 0.5)
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.green)
                                Text("开始自动滚动")
                            }
                        }
                    } header: {
                        Text("自动滚动设置")
                    }
                }
                
                Section {
                    Toggle("显示滚动指示器", isOn: $readerSettings.showScrollIndicator)
                    
                    Toggle("双击暂停自动滚动", isOn: $readerSettings.doubleTapToPause)
                } header: {
                    Text("显示设置")
                }
            }
            .navigationTitle("翻页设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
