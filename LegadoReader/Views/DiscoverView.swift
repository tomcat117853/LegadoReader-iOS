import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var sourceStore: SourceStore
    @State private var selectedCategory: String?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sourceStore.bookSources.filter { $0.isEnabled }) { source in
                    DiscoverSourceSection(source: source)
                }
            }
            .listStyle(.plain)
            .navigationTitle("发现")
        }
    }
}

struct DiscoverSourceSection: View {
    let source: BookSource
    @State private var books: [Book] = []
    @State private var isLoading = false
    
    var body: some View {
        Section(header: Text(source.name).font(.headline)) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if books.isEmpty {
                Text("暂无内容")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(books) { book in
                            DiscoverBookItem(book: book)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadDiscoverBooks()
        }
    }
    
    private func loadDiscoverBooks() {
        guard let discoverRule = source.rule.discover else {
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let html = try await BookSourceParser.shared.fetchHTML(url: discoverRule.url, method: "GET")
                let books = try parseDiscoverBooks(html: html, rule: discoverRule, source: source)
                
                await MainActor.run {
                    self.books = books
                    isLoading = false
                }
            } catch {
                print("Failed to load discover books: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func parseDiscoverBooks(html: String, rule: DiscoverRule, source: BookSource) throws -> [Book] {
        let document = try SwiftSoup.parse(html)
        var books: [Book] = []
        
        for category in rule.categories {
            do {
                let categoryHTML = try await BookSourceParser.shared.fetchHTML(url: category.url, method: "GET")
                let categoryDoc = try SwiftSoup.parse(categoryHTML)
                
                // 默认规则 - 需要根据实际规则解析
                let bookElements = try categoryDoc.select(".book-item, .novel-item, li")
                
                for element in bookElements {
                    do {
                        let name = try element.select("h3, .title, a").first()?.text() ?? ""
                        let author = try element.select(".author, .writer").first()?.text() ?? ""
                        let cover = try element.select("img").first()?.attr("src") ?? ""
                        let bookUrl = try element.select("a").first()?.attr("href") ?? ""
                        
                        if !name.isEmpty {
                            let book = Book(
                                name: name,
                                author: author,
                                cover: cover.isEmpty ? nil : cover.hasPrefix("http") ? cover : source.url + cover,
                                sourceUrl: source.url,
                                sourceName: source.name,
                                bookUrl: bookUrl.hasPrefix("http") ? bookUrl : source.url + bookUrl
                            )
                            books.append(book)
                        }
                    } catch {
                        continue
                    }
                }
            } catch {
                continue
            }
        }
        
        // 去重
        var uniqueBooks: [Book] = []
        var seen = Set<String>()
        for book in books {
            let key = "\(book.name)_\(book.author)"
            if !seen.contains(key) {
                seen.insert(key)
                uniqueBooks.append(book)
            }
        }
        
        return uniqueBooks
    }
}

struct DiscoverBookItem: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 封面
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 110)
                
                if let cover = book.cover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 80, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
            }
            
            // 书名
            Text(book.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
            
            // 作者
            Text(book.author)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
        }
    }
}
