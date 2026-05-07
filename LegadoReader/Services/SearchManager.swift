import Foundation
import SQLite3

class SearchManager: ObservableObject {
    static let shared = SearchManager()
    
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchHistory: [String] = []
    
    struct SearchResult: Identifiable {
        let id = UUID()
        let bookId: String
        let bookName: String
        let chapterTitle: String
        let chapterIndex: Int
        let content: String
        let matchText: String
        let matchRange: Range<String.Index>?
        let contextBefore: String
        let contextAfter: String
    }
    
    private let defaults = UserDefaults.standard
    private let historyKey = "SearchManager_searchHistory"
    
    private init() {
        loadSearchHistory()
    }
    
    private func loadSearchHistory() {
        searchHistory = defaults.stringArray(forKey: historyKey) ?? []
    }
    
    private func saveSearchHistory() {
        defaults.set(searchHistory, forKey: historyKey)
    }
    
    func addToHistory(_ keyword: String) {
        if let index = searchHistory.firstIndex(of: keyword) {
            searchHistory.remove(at: index)
        }
        searchHistory.insert(keyword, at: 0)
        if searchHistory.count > 20 {
            searchHistory.removeLast()
        }
        saveSearchHistory()
    }
    
    func clearHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    func searchInBook(_ keyword: String, bookId: String, bookName: String, chapters: [(index: Int, title: String, content: String)], maxResults: Int = 50) -> [SearchResult] {
        var results: [SearchResult] = []
        let lowercasedKeyword = keyword.lowercased()
        
        for chapter in chapters {
            var searchRange = chapter.content.startIndex..<chapter.content.endIndex
            
            while let range = chapter.content.range(of: keyword, options: .caseInsensitive, range: searchRange) {
                let startOffset = chapter.content.distance(from: chapter.content.startIndex, to: range.lowerBound)
                let endOffset = chapter.content.distance(from: chapter.content.startIndex, to: range.upperBound)
                
                let contextStart = chapter.content.index(range.lowerBound, offsetBy: -50, limitedBy: chapter.content.startIndex) ?? chapter.content.startIndex
                let contextEnd = chapter.content.index(range.upperBound, offsetBy: 50, limitedBy: chapter.content.endIndex) ?? chapter.content.endIndex
                
                let contextBefore = String(chapter.content[contextStart..<range.lowerBound])
                let matchText = String(chapter.content[range])
                let contextAfter = String(chapter.content[range.upperBound..<contextEnd])
                
                let result = SearchResult(
                    bookId: bookId,
                    bookName: bookName,
                    chapterTitle: chapter.title,
                    chapterIndex: chapter.index,
                    content: chapter.content,
                    matchText: matchText,
                    matchRange: range,
                    contextBefore: contextBefore,
                    contextAfter: contextAfter
                )
                
                results.append(result)
                
                if results.count >= maxResults {
                    return results
                }
                
                searchRange = range.upperBound..<chapter.content.endIndex
            }
        }
        
        return results
    }
    
    func searchAllBooks(_ keyword: String) {
        isSearching = true
        searchResults.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let books = DatabaseManager.shared.getAllBooks()
            var allResults: [SearchResult] = []
            
            for book in books {
                let chapters = self?.loadBookChapters(book) ?? []
                let results = self?.searchInBook(keyword, bookId: book.id, bookName: book.name, chapters: chapters) ?? []
                allResults.append(contentsOf: results)
            }
            
            DispatchQueue.main.async {
                self?.searchResults = allResults
                self?.isSearching = false
                self?.addToHistory(keyword)
            }
        }
    }
    
    private func loadBookChapters(_ book: Book) -> [(index: Int, title: String, content: String)] {
        return []
    }
    
    func searchInContent(_ keyword: String, content: String, maxResults: Int = 20) -> [(range: Range<String.Index>, context: String)] {
        var results: [(range: Range<String.Index>, context: String)] = []
        var searchRange = content.startIndex..<content.endIndex
        
        while results.count < maxResults,
              let range = content.range(of: keyword, options: .caseInsensitive, range: searchRange) {
            
            let contextStart = content.index(range.lowerBound, offsetBy: -30, limitedBy: content.startIndex) ?? content.startIndex
            let contextEnd = content.index(range.upperBound, offsetBy: 30, limitedBy: content.endIndex) ?? content.endIndex
            
            let context = String(content[contextStart..<contextEnd])
            
            results.append((range: range, context: "..." + context + "..."))
            
            searchRange = range.upperBound..<content.endIndex
        }
        
        return results
    }
}

struct FullTextSearchView: View {
    let bookId: String
    let bookName: String
    let chapters: [(index: Int, title: String, content: String)]
    
    @StateObject private var searchManager = SearchManager.shared
    @State private var searchText = ""
    @State private var selectedResult: SearchManager.SearchResult?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if searchManager.isSearching {
                    Spacer()
                    ProgressView("搜索中...")
                    Spacer()
                } else if searchManager.searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("未找到相关内容")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        Section("搜索结果 (\(searchManager.searchResults.count) 条)") {
                            ForEach(searchManager.searchResults) { result in
                                Button(action: {
                                    selectedResult = result
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(result.bookName)
                                            .font(.headline)
                                        
                                        Text(result.chapterTitle)
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        
                                        Text(result.contextBefore + result.matchText + result.contextAfter)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("全文检索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索内容...")
            .onSubmit(of: .search) {
                if !searchText.isEmpty {
                    searchManager.searchInBook(searchText, bookId: bookId, bookName: bookName, chapters: chapters)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            searchManager.clearHistory()
                        }) {
                            Label("清除历史", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedResult) { result in
                SearchResultDetailView(result: result)
            }
        }
    }
}

struct SearchResultDetailView: View {
    let result: SearchManager.SearchResult
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(result.bookName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(result.chapterTitle)
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Divider()
                    
                    Text(result.contextBefore)
                        .font(.body)
                    
                    Text(result.matchText)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color.yellow.opacity(0.3))
                    
                    Text(result.contextAfter)
                        .font(.body)
                }
                .padding()
            }
            .navigationTitle("搜索结果")
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
