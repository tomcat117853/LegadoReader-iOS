import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var sourceStore: SourceStore
    @State private var selectedCategory: String?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sourceStore.bookSources.filter { $0.isEnabled }) { source in
                    if source.rule.discover != nil {
                        DiscoverSourceSection(source: source)
                    }
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
        // 实现发现页面书籍加载逻辑
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
