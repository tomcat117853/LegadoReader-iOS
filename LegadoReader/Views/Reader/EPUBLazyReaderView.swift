import SwiftUI
import Combine

struct EPUBLazyReaderView: View {
    let bookData: Data
    let bookId: String
    
    @StateObject private var chapterLoader = EPUBLazyChapterLoader()
    @StateObject private var readerSettings = ReaderSettings.shared
    @StateObject private var eyeCareManager = EyeCareManager.shared
    
    @State private var book: LazyEPUBBook?
    @State private var currentChapterIndex: Int = 0
    @State private var isLoadingBook: Bool = true
    @State private var bookError: Error?
    @State private var showingChapterList: Bool = false
    @State private var showingSettings: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                if isLoadingBook {
                    loadingView
                } else if let book = book {
                    readerContent(book: book, geometry: geometry)
                } else if let error = bookError {
                    errorView(error: error)
                }
            }
        }
        .task {
            await loadBook()
        }
        .sheet(isPresented: $showingChapterList) {
            if let book = book {
                EPUBChapterListView(
                    book: book,
                    currentIndex: $currentChapterIndex,
                    onSelect: { index in
                        currentChapterIndex = index
                        showingChapterList = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            EPUBSettingsView()
        }
        .onDisappear {
            EPUBParsingManager.shared.unloadBook(id: bookId)
        }
    }
    
    private var backgroundColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveBackgroundColor
        }
        return readerSettings.backgroundColor.color
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在加载...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private func readerContent(book: LazyEPUBBook, geometry: GeometryProxy) -> some View {
        ZStack {
            VStack(spacing: 0) {
                if chapterLoader.isLoading && chapterLoader.chapter == nil {
                    loadingChapterView
                } else if let chapter = chapterLoader.chapter {
                    EPUBLazyChapterContentView(
                        chapter: chapter,
                        stylesheets: book.stylesheets,
                        baseURL: book.baseURL,
                        readerSettings: readerSettings,
                        eyeCareManager: eyeCareManager
                    )
                } else {
                    Text("暂无内容")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingButtons
                }
            }
            
            VStack {
                chapterProgressIndicator(book: book)
                Spacer()
            }
        }
        .onChange(of: currentChapterIndex) { _, newIndex in
            chapterLoader.loadChapter(from: book, at: newIndex)
            book.preloadChapters(around: newIndex, range: 2)
        }
        .onAppear {
            chapterLoader.loadChapter(from: book, at: currentChapterIndex)
            book.preloadChapters(around: currentChapterIndex, range: 2)
        }
    }
    
    private var loadingChapterView: some View {
        VStack {
            Spacer()
            ProgressView()
                .padding()
            Text("正在加载章节...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
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
            
            Button(action: {}) {
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
    
    private func chapterProgressIndicator(book: LazyEPUBBook) -> some View {
        HStack {
            if currentChapterIndex > 0 {
                Button(action: {
                    currentChapterIndex -= 1
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            
            Spacer()
            
            Text("\(currentChapterIndex + 1) / \(book.chapters.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            
            Spacer()
            
            if currentChapterIndex < book.chapters.count - 1 {
                Button(action: {
                    currentChapterIndex += 1
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
        }
        .background(Color.black.opacity(0.3))
    }
    
    private func loadBook() async {
        do {
            let loadedBook = try await EPUBParsingManager.shared.loadBook(data: bookData, id: bookId)
            await MainActor.run {
                self.book = loadedBook
                self.isLoadingBook = false
            }
        } catch {
            await MainActor.run {
                self.bookError = error
                self.isLoadingBook = false
            }
        }
    }
}

struct EPUBLazyChapterContentView: View {
    let chapter: EPUBParser.EPUBChapter
    let stylesheets: [CSSParser.ParsedCSS]
    let baseURL: URL?
    let readerSettings: ReaderSettings
    let eyeCareManager: EyeCareManager
    
    @StateObject private var epubSettings = EPUBSettingsManager.shared
    @State private var renderedHTML: String = ""
    @State private var showingImageViewer: Bool = false
    @State private var selectedImageURL: URL?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(chapter.title)
                    .font(.system(size: readerSettings.fontSize + 4, weight: .bold))
                    .foregroundColor(effectiveTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                
                EPUBHTMLContentView(
                    html: renderedHTML,
                    baseURL: baseURL,
                    readerSettings: readerSettings,
                    epubSettings: epubSettings,
                    onImageTap: { url in
                        selectedImageURL = url
                        showingImageViewer = true
                    }
                )
                .padding(.horizontal, readerSettings.horizontalPadding)
            }
        }
        .onAppear {
            renderChapter()
        }
    }
    
    private var effectiveTextColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveTextColor
        }
        return readerSettings.textColor
    }
    
    private var effectiveBackgroundColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveBackgroundColor
        }
        return readerSettings.backgroundColor.color
    }
    
    private func renderChapter() {
        let cssStyles = generateEmbeddedCSS()
        renderedHTML = wrapWithHTML(cssStyles)
    }
    
    private func generateEmbeddedCSS() -> String {
        var css = """
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: \(readerSettings.fontFamily);
                font-size: \(Int(readerSettings.fontSize))px;
                line-height: \(readerSettings.lineSpacing);
                text-align: \(getTextAlign());
                color: \(effectiveTextColor.toHexString());
                background-color: \(effectiveBackgroundColor.toHexString());
            }
        """
        
        if epubSettings.applyCustomTypography {
            css += epubSettings.generateCSSExtensions()
        }
        
        css += """
            img {
                max-width: \(Int(epubSettings.maxImageWidth * 100))%;
                height: auto;
                display: block;
                margin: 1em auto;
                cursor: pointer;
            }
            img.zoomable {
                cursor: zoom-in;
            }
            p {
                margin-bottom: 1em;
            }
        """
        
        if epubSettings.autoIndentParagraphs && epubSettings.indentFirstLine {
            css += """
            p {
                text-indent: \(epubSettings.indentChars)em;
            }
            """
        }
        
        css += """
            h1, h2, h3, h4, h5, h6 {
                font-weight: bold;
                text-align: center;
            }
            h1 { font-size: 1.8em; }
            h2 { font-size: 1.5em; }
            h3 { font-size: 1.3em; }
            h4 { font-size: 1.1em; }
            h5 { font-size: 1em; }
            h6 { font-size: 0.9em; }
            blockquote {
                margin: 1em 2em;
                padding-left: 1em;
                border-left: 3px solid #ccc;
                font-style: italic;
            }
        """
        
        for stylesheet in stylesheets {
            for rule in stylesheet.rules {
                css += "\(rule.selector) { "
                for declaration in rule.declarations {
                    css += "\(declaration.property): \(declaration.value); "
                }
                css += "}\n"
            }
        }
        
        css += "</style>"
        return css
    }
    
    private func getTextAlign() -> String {
        switch readerSettings.textAlignment {
        case "left": return "left"
        case "center": return "center"
        case "right": return "right"
        case "justify": return "justify"
        default: return "left"
        }
    }
    
    private func wrapWithHTML(_ css: String) -> String {
        var processedContent = chapter.content
        
        if let baseURL = baseURL {
            processedContent = processedContent.replacingOccurrences(
                of: "src=\"",
                with: "src=\"file://\(baseURL.path)/"
            )
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            \(css)
        </head>
        <body>
            \(processedContent)
        </body>
        </html>
        """
    }
}

struct EPUBHTMLContentView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    let readerSettings: ReaderSettings
    let epubSettings: EPUBSettingsManager
    let onImageTap: (URL?) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.contentMode = .scaleAspectFit
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.backgroundColor = .clear
        context.coordinator.onImageTap = onImageTap
        
        webView.loadHTMLString(html, baseURL: baseURL)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageTap: onImageTap)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var onImageTap: (URL?) -> Void
        
        init(onImageTap: @escaping (URL?) -> Void) {
            self.onImageTap = onImageTap
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                if url.pathExtension.lowercased() == "jpg" ||
                   url.pathExtension.lowercased() == "jpeg" ||
                   url.pathExtension.lowercased() == "png" ||
                   url.pathExtension.lowercased() == "gif" {
                    onImageTap(url)
                    decisionHandler(.cancel)
                    return
                }
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let script = """
            document.querySelectorAll('img').forEach(function(img) {
                img.addEventListener('click', function() {
                    window.webkit.messageHandlers.imageTapped.postMessage(this.src);
                });
            });
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}

struct EPUBChapterListView: View {
    @ObservedObject var book: LazyEPUBBook
    @Binding var currentIndex: Int
    let onSelect: (Int) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    
    var filteredChapters: [EPUBParser.EPUBChapter] {
        if searchText.isEmpty {
            return book.chapters
        }
        return book.chapters.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if !searchText.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text("搜索: \(searchText)")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                }
                
                List {
                    ForEach(Array(filteredChapters.enumerated()), id: \.offset) { index, chapter in
                        Button(action: {
                            currentIndex = index
                            onSelect(index)
                        }) {
                            HStack {
                                Text(chapter.title)
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
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索章节")
        }
    }
}

struct EPUBImageViewer: View {
    let imageURL: URL?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let url = imageURL,
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text("无法加载图片")
                    .foregroundColor(.white)
            }
        }
        .onTapGesture {
            dismiss()
        }
    }
}
