import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let fileURL: URL
    @StateObject private var pdfManager = PDFManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingSettings = false
    @State private var showingTableOfContents = false
    @State private var showingBookmarks = false
    @State private var showingSearch = false
    @State private var showingShare = false
    @State private var currentPageText: String = "1"
    @State private var isFullScreen = false
    @State private var showControls = true
    
    var body: some View {
        ZStack {
            if let document = pdfManager.currentDocument {
                PDFKitView(
                    document: document,
                    currentPageIndex: $pdfManager.currentPageIndex,
                    showControls: $showControls
                )
                .onTapGesture {
                    withAnimation {
                        showControls.toggle()
                    }
                }
            } else if pdfManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView(value: pdfManager.loadProgress)
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text("加载中... \(Int(pdfManager.loadProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("无法加载PDF")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    if let error = pdfManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button("重试") {
                        loadPDF()
                    }
                    .foregroundColor(.blue)
                }
            }
            
            if showControls {
                VStack {
                    PDFTopBar(
                        fileName: fileURL.lastPathComponent,
                        onBack: { dismiss() },
                        onShowTOC: { showingTableOfContents = true },
                        onShowBookmarks: { showingBookmarks = true },
                        onShowSearch: { showingSearch = true },
                        onShowSettings: { showingSettings = true }
                    )
                    
                    Spacer()
                    
                    PDFBottomBar(
                        currentPage: pdfManager.currentPageIndex + 1,
                        totalPages: pdfManager.totalPages,
                        onPageChange: { page in
                            pdfManager.goToPage(page - 1)
                        },
                        onPrevious: { pdfManager.previousPage() },
                        onNext: { pdfManager.nextPage() },
                        onShare: { showingShare = true }
                    )
                }
                .transition(.move(edge: .top).combined(with: .move(edge: .bottom)))
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .sheet(isPresented: $showingSettings) {
            PDFSettingsView()
        }
        .sheet(isPresented: $showingTableOfContents) {
            PDFTableOfContentsView(pdfManager: pdfManager) { pageIndex in
                pdfManager.goToPage(pageIndex)
                showingTableOfContents = false
            }
        }
        .sheet(isPresented: $showingBookmarks) {
            PDFBookmarksView(pdfManager: pdfManager) { pageIndex in
                pdfManager.goToPage(pageIndex)
                showingBookmarks = false
            }
        }
        .sheet(isPresented: $showingSearch) {
            PDFSearchView(pdfManager: pdfManager) { pageIndex in
                pdfManager.goToPage(pageIndex)
                showingSearch = false
            }
        }
        .sheet(isPresented: $showingShare) {
            if let image = pdfManager.exportCurrentPageAsImage() {
                ShareSheet(items: [image])
            }
        }
        .onAppear {
            loadPDF()
        }
        .onDisappear {
            pdfManager.updateLastPageIndex(pdfManager.currentPageIndex, for: fileURL.path)
        }
    }
    
    private func loadPDF() {
        _ = pdfManager.loadPDF(from: fileURL)
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    let showControls: Bool
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        
        pdfView.delegate = context.coordinator
        
        NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { _ in
            if let page = pdfView.currentPage,
               let index = document.index(for: page) {
                DispatchQueue.main.async {
                    currentPageIndex = index
                }
            }
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        
        if let targetPage = document.page(at: currentPageIndex) {
            pdfView.go(to: targetPage)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
    }
}

struct PDFTopBar: View {
    let fileName: String
    let onBack: () -> Void
    let onShowTOC: () -> Void
    let onShowBookmarks: () -> Void
    let onShowSearch: () -> Void
    let onShowSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            
            Text(fileName)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onShowTOC) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
            }
            
            Button(action: onShowBookmarks) {
                Image(systemName: "bookmark")
                    .font(.system(size: 20))
            }
            
            Button(action: onShowSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
            }
            
            Button(action: onShowSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.95))
    }
}

struct PDFBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let onPageChange: (Int) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onShare: () -> Void
    
    @State private var pageInput = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { Double(currentPage) },
                    set: { onPageChange(Int($0)) }
                ),
                in: 1...Double(max(1, totalPages)),
                step: 1
            )
            .padding(.horizontal)
            
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                }
                .disabled(currentPage <= 1)
                .opacity(currentPage <= 1 ? 0.5 : 1)
                
                Spacer()
                
                if isEditing {
                    TextField("页码", text: $pageInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                        .onSubmit {
                            if let page = Int(pageInput), page >= 1, page <= totalPages {
                                onPageChange(page)
                            }
                            isEditing = false
                        }
                } else {
                    Text("\(currentPage) / \(totalPages)")
                        .font(.system(size: 16, weight: .medium))
                        .onTapGesture {
                            pageInput = "\(currentPage)"
                            isEditing = true
                        }
                }
                
                Spacer()
                
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24))
                }
                .disabled(currentPage >= totalPages)
                .opacity(currentPage >= totalPages ? 0.5 : 1)
            }
            .padding(.horizontal, 40)
            
            HStack(spacing: 40) {
                Button(action: onShare) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                        Text("分享")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.95))
    }
}

struct PDFSettingsView: View {
    @StateObject private var pdfManager = PDFManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("缩放") {
                    Button("适应页面") {
                    }
                    
                    Button("适应宽度") {
                    }
                    
                    Button("原始大小") {
                    }
                }
                
                Section("显示模式") {
                    Picker("显示模式", selection: .constant(0)) {
                        Text("单页连续").tag(0)
                        Text("单页").tag(1)
                        Text("双页").tag(2)
                        Text("滚动").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("背景颜色") {
                    HStack(spacing: 16) {
                        ForEach(["白色", "护眼绿", "浅黄", "深色"], id: \.self) { color in
                            Button(action: {}) {
                                Text(color)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                
                Section("书签") {
                    Button(action: {
                        pdfManager.addBookmark(pageIndex: pdfManager.currentPageIndex)
                    }) {
                        HStack {
                            Image(systemName: "bookmark.fill")
                            Text("添加书签")
                        }
                    }
                }
                
                Section("导出") {
                    Button(action: {
                        if let image = pdfManager.exportCurrentPageAsImage() {
                            
                        }
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            Text("导出当前页为图片")
                        }
                    }
                    
                    Button(action: {
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("提取文本")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("PDF设置")
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

struct PDFTableOfContentsView: View {
    @ObservedObject var pdfManager: PDFManager
    let onSelectPage: (Int) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if pdfManager.getTableOfContents().isEmpty {
                    Text("目录不可用")
                        .foregroundColor(.secondary)
                } else {
                    OutlineList(
                        items: pdfManager.getTableOfContents(),
                        onSelectPage: onSelectPage
                    )
                }
            }
            .navigationTitle("目录")
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

struct OutlineList: View {
    let items: [PDFManager.PDFOutlineItem]
    let onSelectPage: (Int) -> Void
    
    var body: some View {
        ForEach(items) { item in
            Button(action: {
                if let destination = item.destination,
                   let page = destination.page,
                   let index = pdfManager.currentDocument?.index(for: page) {
                    onSelectPage(index)
                }
            }) {
                HStack {
                    Text(item.label)
                        .foregroundColor(.primary)
                        .padding(.leading, CGFloat(item.level * 16))
                    
                    Spacer()
                }
            }
            
            if !item.children.isEmpty {
                OutlineList(items: item.children, onSelectPage: onSelectPage)
            }
        }
    }
    
    private var pdfManager: PDFManager {
        PDFManager.shared
    }
}

struct PDFBookmarksView: View {
    @ObservedObject var pdfManager: PDFManager
    let onSelectPage: (Int) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if pdfManager.bookmarks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("暂无书签")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(pdfManager.bookmarks) { bookmark in
                        Button(action: {
                            onSelectPage(bookmark.pageIndex)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.pageLabel)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(bookmark.fileName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    if !bookmark.note.isEmpty {
                                        Text(bookmark.note)
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .lineLimit(2)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(bookmark.createdTime, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pdfManager.removeBookmark(bookmark)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("书签")
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

struct PDFSearchView: View {
    @ObservedObject var pdfManager: PDFManager
    let onSelectPage: (Int) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [PDFManager.PDFSearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("未找到结果")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(searchResults) { result in
                        Button(action: {
                            onSelectPage(result.pageIndex)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("第 \(result.pageIndex + 1) 页")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(result.context)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索PDF内容")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onSubmit(of: .search) {
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchResults = pdfManager.searchPDF(searchText)
        isSearching = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
