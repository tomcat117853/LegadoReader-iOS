import SwiftUI

struct OPDSBrowserView: View {
    let subscription: OPDSClient.OPDSSubscription
    @StateObject private var opdsClient = OPDSClient.shared
    @State private var currentURL: String
    @State private var currentFeed: OPDSFeed?
    @State private var navigationStack: [OPDSNavItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var selectedEntry: OPDSEntry?
    @State private var showingBookDetail = false
    
    struct OPDSNavItem: Identifiable {
        let id = UUID()
        let title: String
        let url: String
    }
    
    init(subscription: OPDSClient.OPDSSubscription) {
        self.subscription = subscription
        _currentURL = State(initialValue: subscription.url)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !navigationStack.isEmpty {
                NavigationBreadcrumb(items: navigationStack) { index in
                    navigationStack = Array(navigationStack.prefix(index + 1))
                    if let last = navigationStack.last {
                        loadFeed(url: last.url)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            
            Divider()
            
            if isLoading {
                Spacer()
                ProgressView("加载中...")
                    .progressViewStyle(CircularProgressViewStyle())
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadFeed(url: currentURL)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else if let feed = currentFeed {
                List {
                    if !feed.links.filter({ !$0.isImageLink && !$0.isAcquisitionLink }).isEmpty {
                        Section {
                            ForEach(Array(feed.links.filter({ !$0.isImageLink && !$0.isAcquisitionLink }).enumerated()), id: \.offset) { _, link in
                                if let href = link.href {
                                    Button {
                                        navigateTo(link: link, href: href)
                                    } label: {
                                        OPDSLinkRow(link: link)
                                    }
                                }
                            }
                        } header: {
                            Text("目录")
                        }
                    }
                    
                    if !feed.entries.isEmpty {
                        Section {
                            ForEach(feed.entries) { entry in
                                OPDSEntryRow(entry: entry)
                                    .onTapGesture {
                                        selectedEntry = entry
                                        showingBookDetail = true
                                    }
                            }
                        } header: {
                            Text("书籍 (\(feed.entries.count))")
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                Spacer()
                Text("暂无内容")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .navigationTitle(subscription.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        refreshFeed()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    
                    Button {
                        navigationStack.removeAll()
                        loadFeed(url: subscription.url)
                    } label: {
                        Label("返回首页", systemImage: "house")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingBookDetail) {
            if let entry = selectedEntry {
                OPDSBookDetailView(entry: entry, subscriptionURL: currentURL)
            }
        }
        .sheet(isPresented: $showingSearch) {
            OPDSSearchView(subscriptionURL: currentURL)
        }
        .onAppear {
            if currentFeed == nil {
                loadFeed(url: subscription.url)
            }
        }
    }
    
    private func loadFeed(url: String) {
        isLoading = true
        errorMessage = nil
        currentURL = url
        
        opdsClient.fetchFeed(url: url) { result in
            isLoading = false
            switch result {
            case .success(let feed):
                currentFeed = feed
                if let title = currentFeed?.title, title != subscription.title {
                    if !navigationStack.contains(where: { $0.url == url }) {
                        navigationStack.append(OPDSNavItem(title: title, url: url))
                    }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func navigateTo(link: OPDSLink, href: String) {
        loadFeed(url: href)
    }
    
    private func refreshFeed() {
        loadFeed(url: currentURL)
    }
}

struct NavigationBreadcrumb: View {
    let items: [OPDSBrowserView.OPDSNavItem]
    let onTap: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        onTap(index)
                    } label: {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundColor(index == items.count - 1 ? .primary : .blue)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

struct OPDSLinkRow: View {
    let link: OPDSLink
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title ?? hrefTitle)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if let href = link.href {
                    Text(href)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
    }
    
    private var iconName: String {
        if link.rel.contains("subsection") {
            return "folder"
        } else if link.rel.contains("collection") {
            return "books.vertical"
        } else {
            return "doc.text"
        }
    }
    
    private var hrefTitle: String {
        if let href = link.href {
            return URL(string: href)?.lastPathComponent ?? "链接"
        }
        return "链接"
    }
}

struct OPDSEntryRow: View {
    let entry: OPDSEntry
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: entry.thumbnailImage ?? entry.coverImage ?? "")) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color.blue.opacity(0.1)
                        Image(systemName: "book.closed")
                            .foregroundColor(.blue)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Color.blue.opacity(0.1)
                        Image(systemName: "book.closed")
                            .foregroundColor(.blue)
                    }
                @unknown default:
                    Color.gray
                }
            }
            .frame(width: 60, height: 80)
            .cornerRadius(6)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(entry.authorName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if let price = entry.price {
                        Text(price.displayString)
                            .font(.caption)
                            .foregroundColor(price.value == 0 ? .green : .orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (price.value == 0 ? Color.green : Color.orange).opacity(0.1)
                            )
                            .cornerRadius(4)
                    }
                    
                    ForEach(entry.categories.prefix(2), id: \.self) { category in
                        Text(category)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                if entry.epubLink != nil {
                    Label("EPUB", systemImage: "doc.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                if entry.pdfLink != nil {
                    Label("PDF", systemImage: "doc.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct OPDSSearchView: View {
    let subscriptionURL: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var opdsClient = OPDSClient.shared
    @State private var searchText = ""
    @State private var searchResults: [OPDSEntry] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selectedEntry: OPDSEntry?
    @State private var showingBookDetail = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isSearching {
                    Spacer()
                    ProgressView("搜索中...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("未找到相关书籍")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(searchResults) { entry in
                        OPDSEntryRow(entry: entry)
                            .onTapGesture {
                                selectedEntry = entry
                                showingBookDetail = true
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "输入书名或作者")
            .onSubmit(of: .search) {
                performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingBookDetail) {
                if let entry = selectedEntry {
                    OPDSBookDetailView(entry: entry, subscriptionURL: subscriptionURL)
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        opdsClient.searchInCatalog(url: subscriptionURL, query: searchText) { result in
            isSearching = false
            switch result {
            case .success(let entries):
                searchResults = entries
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct OPDSBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        OPDSBrowserView(
            subscription: OPDSClient.OPDSSubscription(
                title: "Sample",
                url: "https://example.com/opds"
            )
        )
    }
}
