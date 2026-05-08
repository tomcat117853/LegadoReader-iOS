import SwiftUI

struct SearchView: View {
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var sourceStore: SourceStore
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [Book] = []
    @State private var isSearching = false
    @State private var selectedBook: Book?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText, isSearching: $isSearching, onSearch: performSearch)
                    .padding()
                
                // 搜索结果
                if isSearching {
                    ProgressView("搜索中...")
                        .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    EmptySearchView()
                } else {
                    List(searchResults) { book in
                        SearchResultItem(book: book)
                            .onTapGesture {
                                selectedBook = book
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        Task {
            let results = await bookStore.searchBooks(
                keyword: searchText,
                sources: sourceStore.bookSources.filter { $0.isEnabled }
            )
            
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    let onSearch: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索书名或作者", text: $text)
                    .font(.system(size: 16))
                    .submitLabel(.search)
                    .onSubmit(onSearch)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Button(action: onSearch) {
                Text("搜索")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("未找到相关书籍")
                .font(.title3)
                .foregroundColor(.gray)
            Text("请尝试其他关键词")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 100)
    }
}

struct SearchResultItem: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 70)
                
                if let cover = book.cover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 50, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let intro = book.intro {
                    Text(intro)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(book.sourceName)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    if let lastChapter = book.lastChapter {
                        Text(lastChapter)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
