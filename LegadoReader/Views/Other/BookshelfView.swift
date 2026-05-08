import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject var bookStore: BookStore
    @State private var searchText = ""
    @State private var searchExpanded = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showingBrowser = false
    @State private var showingSidebar = false
    @State private var showingBookSourceSearch = false
    
    private let searchThreshold: CGFloat = 60
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return bookStore.books
        }
        let query = searchText.lowercased()
        return bookStore.books.filter { book in
            book.name.lowercased().contains(query) ||
            book.author.lowercased().contains(query) ||
            book.tags.contains { $0.lowercased().contains(query) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 0) {
                            searchHeader
                            
                            if searchExpanded {
                                searchResultsList
                            } else {
                                bookList
                            }
                        }
                        .background(Color(.systemBackground))
                    }
                    .background(Color(.systemBackground))
                    .coordinateSpace(name: "BookshelfScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        scrollOffset = offset
                        searchExpanded = offset > searchThreshold
                    }
                }
                
                if showingSidebar {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showingSidebar = false
                        }
                    
                    SidebarMenuView()
                        .frame(width: UIScreen.main.bounds.width * 0.85)
                        .offset(x: showingSidebar ? 0 : -UIScreen.main.bounds.width)
                        .animation(.spring(), value: showingSidebar)
                }
            }
            .navigationTitle("阅读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingBookSourceSearch = true }) {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                        }
                        
                        Button(action: { showingBrowser = true }) {
                            Image(systemName: "globe")
                                .font(.title)
                        }
                        
                        Button(action: { showingSidebar = true }) {
                            Image(systemName: "ellipsis.circle")
                                .font(.title)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingBrowser) {
                WebBrowserView()
            }
            .sheet(isPresented: $showingBookSourceSearch) {
                BookSourceSearchView()
            }
        }
    }
    
    private var searchHeader: some View {
        VStack(spacing: 8) {
            if !searchExpanded {
                HStack {
                    Spacer()
                }
                .frame(height: 20)
            }
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索书架", text: $searchText) { isEditing in
                    if isEditing {
                        searchExpanded = true
                    }
                }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)
            .opacity(searchExpanded ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: searchExpanded)
        }
    }
    
    private var searchResultsList: some View {
        VStack(spacing: 12) {
            ForEach(filteredBooks) { book in
                HStack(spacing: 12) {
                    CoverImageView(book: book, size: CGSize(width: 60, height: 80))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.name)
                            .font(.headline)
                        
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !book.tags.isEmpty {
                            HStack {
                                ForEach(book.tags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .onTapGesture {
                    openBook(book)
                }
            }
            
            if filteredBooks.isEmpty && !searchText.isEmpty {
                Text("未找到匹配的书籍")
                    .foregroundColor(.secondary)
                    .padding(20)
            }
        }
    }
    
    private var bookList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(bookStore.books) { book in
                    BookRowView(book: book)
                        .onTapGesture {
                            openBook(book)
                        }
                        .swipeActions(edge: .leading) {
                            Button("置顶", action: { bookStore.moveBookToTop(book) })
                                .tint(.orange)
                            
                            Button("听书", action: { startListening(book) })
                                .tint(.purple)
                            
                            Button("分组", action: { moveToGroup(book) })
                                .tint(.blue)
                            
                            Button("详情", action: { showDetail(book) })
                                .tint(.green)
                            
                            Button("删除", action: { bookStore.removeBook(book) })
                                .tint(.red)
                        }
                }
            }
            .padding()
        }
    }
    
    private func openBook(_ book: Book) {
        print("打开书籍: \(book.name)")
    }
    
    private func startListening(_ book: Book) {
        print("开始听书: \(book.name)")
    }
    
    private func moveToGroup(_ book: Book) {
        print("移动到分组: \(book.name)")
    }
    
    private func showDetail(_ book: Book) {
        print("显示详情: \(book.name)")
    }
}

struct BookRowView: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            CoverImageView(book: book, size: CGSize(width: 80, height: 100))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(book.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    if book.chapterCount > 0 {
                        Text("\(book.chapterCount) 章")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if book.readProgress > 0 {
                        Text("已读 \(book.readProgress)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct CoverImageView: View {
    let book: Book
    let size: CGSize
    
    var body: some View {
        if let coverData = book.cover, let uiImage = UIImage(data: coverData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .cornerRadius(8)
                .shadow(radius: 2)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size.width, height: size.height)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "book")
                        .foregroundColor(.gray)
                        .font(.system(size: 30))
                )
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}