import SwiftUI
import WebKit

struct WebBrowserView: View {
    @StateObject private var browserManager = WebBrowserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var urlText = ""
    @State private var showingSearchBar = true
    @State private var showingFavorites = false
    @State private var showingHistory = false
    @State private var showingDownloads = false
    @State private var showingSettings = false
    @State private var showingSourceExtractor = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if showingSearchBar {
                    SearchBarView(
                        urlText: $urlText,
                        onGo: { navigateToURL() },
                        onSearch: { searchInBrowser() },
                        browserManager: browserManager
                    )
                }
                
                if browserManager.isLoading {
                    ProgressView(value: browserManager.loadingProgress)
                        .progressViewStyle(.linear)
                }
                
                BrowserWebView(
                    url: browserManager.currentURL,
                    onURLChange: { url, title in
                        browserManager.currentURL = url
                        browserManager.currentTitle = title
                        urlText = url?.absoluteString ?? ""
                    },
                    onLoadingChange: { isLoading in
                        browserManager.isLoading = isLoading
                    },
                    onProgressChange: { progress in
                        browserManager.loadingProgress = progress
                    },
                    onNavigationChange: { canGoBack, canGoForward in
                        browserManager.canGoBack = canGoBack
                        browserManager.canGoForward = canGoForward
                    }
                )
                
                BrowserToolBar(
                    canGoBack: browserManager.canGoBack,
                    canGoForward: browserManager.canGoForward,
                    onBack: { goBack() },
                    onForward: { goForward() },
                    onHome: { goHome() },
                    onRefresh: { refresh() },
                    onFavorites: { showingFavorites = true },
                    onHistory: { showingHistory = true },
                    onDownloads: { showingDownloads = true },
                    onSettings: { showingSettings = true },
                    onExtractSources: { showingSourceExtractor = true }
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        toggleSearchBar()
                    }) {
                        Image(systemName: showingSearchBar ? "keyboard.chevron.compact.down" : "keyboard")
                    }
                }
            }
            .sheet(isPresented: $showingFavorites) {
                FavoritesView(onSelect: { url in
                    loadURL(url)
                    showingFavorites = false
                })
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView(onSelect: { url in
                    loadURL(url)
                    showingHistory = false
                })
            }
            .sheet(isPresented: $showingDownloads) {
                DownloadsView()
            }
            .sheet(isPresented: $showingSettings) {
                BrowserSettingsView()
            }
            .sheet(isPresented: $showingSourceExtractor) {
                SourceExtractorView(currentHTML: browserManager.pageHTML)
            }
            .onAppear {
                if let homeURL = URL(string: browserManager.searchEngine.searchURL) {
                    browserManager.currentURL = homeURL
                    urlText = homeURL.absoluteString
                }
            }
        }
    }
    
    private func navigateToURL() {
        if let url = browserManager.parseURL(urlText) {
            loadURL(url)
        }
    }
    
    private func searchInBrowser() {
        if let url = browserManager.searchURL(for: urlText) {
            loadURL(url)
        }
    }
    
    private func loadURL(_ url: URL) {
        browserManager.currentURL = url
        urlText = url.absoluteString
    }
    
    private func goBack() {
        NotificationCenter.default.post(name: .webBrowserGoBack, object: nil)
    }
    
    private func goForward() {
        NotificationCenter.default.post(name: .webBrowserGoForward, object: nil)
    }
    
    private func goHome() {
        if let homeURL = URL(string: browserManager.searchEngine.searchURL) {
            loadURL(homeURL)
        }
    }
    
    private func refresh() {
        NotificationCenter.default.post(name: .webBrowserRefresh, object: nil)
    }
    
    private func toggleSearchBar() {
        withAnimation {
            showingSearchBar.toggle()
        }
    }
}

struct SearchBarView: View {
    @Binding var urlText: String
    let onGo: () -> Void
    let onSearch: () -> Void
    @ObservedObject var browserManager: WebBrowserManager
    @State private var showingEnginePicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingEnginePicker = true
            }) {
                Text(browserManager.searchEngine.icon)
                    .font(.title2)
            }
            
            TextField("搜索或输入网址", text: $urlText)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .onSubmit {
                    onGo()
                }
            
            if !urlText.isEmpty {
                Button(action: {
                    urlText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            Button(action: onGo) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .sheet(isPresented: $showingEnginePicker) {
            SearchEnginePicker(selectedEngine: browserManager.searchEngine) { engine in
                browserManager.setSearchEngine(engine)
                showingEnginePicker = false
            }
        }
    }
}

struct SearchEnginePicker: View {
    let selectedEngine: WebBrowserManager.SearchEngine
    let onSelect: (WebBrowserManager.SearchEngine) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(WebBrowserManager.SearchEngine.allCases) { engine in
                    Button(action: {
                        onSelect(engine)
                    }) {
                        HStack {
                            Text(engine.icon)
                                .font(.title2)
                            Text(engine.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if engine == selectedEngine {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择搜索引擎")
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

struct BrowserWebView: UIViewRepresentable {
    let url: URL?
    let onURLChange: (URL?, String) -> Void
    let onLoadingChange: (Bool) -> Void
    let onProgressChange: (Double) -> Void
    let onNavigationChange: (Bool, Bool) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        
        if let url = url {
            webView.load(URLRequest(url: url))
        }
        
        setupNotifications()
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = url {
            let request = URLRequest(url: url)
            if webView.url != url {
                webView.load(request)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .webBrowserGoBack,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.postGoBack()
        }
        
        NotificationCenter.default.addObserver(
            forName: .webBrowserGoForward,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.postGoForward()
        }
        
        NotificationCenter.default.addObserver(
            forName: .webBrowserRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.postRefresh()
        }
    }
    
    private func postGoBack() {
        NotificationCenter.default.post(name: .browserGoBack, object: nil)
    }
    
    private func postGoForward() {
        NotificationCenter.default.post(name: .browserGoForward, object: nil)
    }
    
    private func postRefresh() {
        NotificationCenter.default.post(name: .browserRefresh, object: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: BrowserWebView
        
        init(_ parent: BrowserWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.onLoadingChange(true)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onLoadingChange(false)
            parent.onURLChange(webView.url, webView.title ?? "")
            parent.onNavigationChange(webView.canGoBack, webView.canGoForward)
            
            webView.evaluateJavaScript("document.documentElement.outerHTML") { html, _ in
                if let htmlString = html as? String {
                    WebBrowserManager.shared.pageHTML = htmlString
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onLoadingChange(false)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            if url.scheme == "file" {
                decisionHandler(.cancel)
                return
            }
            
            if url.scheme != "http" && url.scheme != "https" {
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}

struct BrowserToolBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onHome: () -> Void
    let onRefresh: () -> Void
    let onFavorites: () -> Void
    let onHistory: () -> Void
    let onDownloads: () -> Void
    let onSettings: () -> Void
    let onExtractSources: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ToolBarButton(icon: "chevron.left", isEnabled: canGoBack, action: onBack)
            ToolBarButton(icon: "chevron.right", isEnabled: canGoForward, action: onForward)
            ToolBarButton(icon: "house", isEnabled: true, action: onHome)
            ToolBarButton(icon: "arrow.clockwise", isEnabled: true, action: onRefresh)
            
            Divider().frame(height: 24)
            
            ToolBarButton(icon: "star", isEnabled: true, action: onFavorites)
            ToolBarButton(icon: "clock", isEnabled: true, action: onHistory)
            ToolBarButton(icon: "square.and.arrow.down", isEnabled: true, action: onDownloads)
            ToolBarButton(icon: "gear", isEnabled: true, action: onSettings)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle().frame(height: 0.5),
            alignment: .top
        )
    }
}

struct ToolBarButton: View {
    let icon: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isEnabled ? .primary : .gray)
        }
        .frame(maxWidth: .infinity)
        .disabled(!isEnabled)
    }
}

struct FavoritesView: View {
    let onSelect: (String) -> Void
    @StateObject private var browserManager = WebBrowserManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingAddFavorite = false
    @State private var newFavoriteTitle = ""
    @State private var newFavoriteURL = ""
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        showingAddFavorite = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("添加收藏")
                        }
                    }
                }
                
                Section {
                    ForEach(browserManager.favorites) { favorite in
                        Button(action: {
                            onSelect(favorite.url)
                        }) {
                            HStack {
                                Text(favorite.icon)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(favorite.title)
                                        .foregroundColor(.primary)
                                    Text(favorite.url)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                browserManager.removeFromFavorites(favorite)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("收藏网站")
                }
            }
            .navigationTitle("收藏夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("添加收藏", isPresented: $showingAddFavorite) {
                TextField("网站名称", text: $newFavoriteTitle)
                TextField("网址", text: $newFavoriteURL)
                    .autocapitalization(.none)
                Button("取消", role: .cancel) {
                    newFavoriteTitle = ""
                    newFavoriteURL = ""
                }
                Button("添加") {
                    if !newFavoriteTitle.isEmpty && !newFavoriteURL.isEmpty {
                        browserManager.addToFavorites(title: newFavoriteTitle, url: newFavoriteURL)
                    }
                    newFavoriteTitle = ""
                    newFavoriteURL = ""
                }
            }
        }
    }
}

struct HistoryView: View {
    let onSelect: (String) -> Void
    @StateObject private var browserManager = WebBrowserManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if browserManager.browsingHistory.isEmpty {
                    Section {
                        Text("暂无浏览历史")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(browserManager.browsingHistory) { item in
                        Button(action: {
                            onSelect(item.url)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(item.url)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text(item.visitTime, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                browserManager.removeHistoryItem(item)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("浏览历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !browserManager.browsingHistory.isEmpty {
                        Button("清空") {
                            browserManager.clearHistory()
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DownloadsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var downloadManager = WiFiTransferServer.shared
    @StateObject private var localBookManager = LocalBookManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(downloadManager.getDownloadedFiles(), id: \.path) { fileURL in
                        HStack {
                            Image(systemName: getFileIcon(fileURL))
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text(fileURL.lastPathComponent)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(getFileSize(at: fileURL))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                importBook(from: fileURL)
                            }) {
                                Text("导入")
                                    .foregroundColor(.blue)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                downloadManager.deleteDownloadedFile(at: fileURL)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Wi-Fi传输文件")
                }
                
                Section {
                    Button(action: {
                        downloadManager.clearAllDownloads()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("清空传输文件")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("下载管理")
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
    
    private func getFileIcon(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt": return "doc.text"
        case "epub": return "book"
        case "pdf": return "doc.fill"
        case "mobi", "azw", "azw3": return "ipad"
        case "cbz", "cbr": return "photo.stack"
        default: return "doc"
        }
    }
    
    private func getFileSize(at url: URL) -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func importBook(from url: URL) {
        localBookManager.importBook(from: url)
    }
}

struct BrowserSettingsView: View {
    @StateObject private var browserManager = WebBrowserManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("搜索引擎") {
                    Picker("默认搜索引擎", selection: $browserManager.searchEngine) {
                        ForEach(WebBrowserManager.SearchEngine.allCases) { engine in
                            HStack {
                                Text(engine.icon)
                                Text(engine.displayName)
                            }
                            .tag(engine)
                        }
                    }
                    .onChange(of: browserManager.searchEngine) { newEngine in
                        browserManager.setSearchEngine(newEngine)
                    }
                }
                
                Section("收藏夹") {
                    HStack {
                        Text("收藏网站数量")
                        Spacer()
                        Text("\(browserManager.favorites.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("清空浏览历史") {
                        browserManager.clearHistory()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("浏览器设置")
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

struct SourceExtractorView: View {
    let currentHTML: String
    @StateObject private var browserManager = WebBrowserManager.shared
    @State private var extractedSources: [WebBrowserManager.BookSourceLink] = []
    @State private var extractedDownloads: [WebBrowserManager.DownloadLink] = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("从当前网页中提取书源链接和下载链接")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("书源链接") {
                    if extractedSources.isEmpty {
                        Text("未找到书源链接")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(extractedSources) { source in
                            Button(action: {
                                UIPasteboard.general.string = source.url
                            }) {
                                VStack(alignment: .leading) {
                                    Text(source.title)
                                        .foregroundColor(.primary)
                                    Text(source.url)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                
                Section("下载链接") {
                    if extractedDownloads.isEmpty {
                        Text("未找到下载链接")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(extractedDownloads) { link in
                            Button(action: {
                                UIPasteboard.general.string = link.url
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.doc")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(link.fileName)
                                            .foregroundColor(.primary)
                                        Text(link.fileType.uppercased())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("资源提取")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                extractResources()
            }
        }
    }
    
    private func extractResources() {
        extractedSources = browserManager.extractBookSources(from: currentHTML)
        extractedDownloads = browserManager.extractDownloadLinks(from: currentHTML)
    }
}

extension Notification.Name {
    static let webBrowserGoBack = Notification.Name("webBrowserGoBack")
    static let webBrowserGoForward = Notification.Name("webBrowserGoForward")
    static let webBrowserRefresh = Notification.Name("webBrowserRefresh")
    static let browserGoBack = Notification.Name("browserGoBack")
    static let browserGoForward = Notification.Name("browserGoForward")
    static let browserRefresh = Notification.Name("browserRefresh")
}
