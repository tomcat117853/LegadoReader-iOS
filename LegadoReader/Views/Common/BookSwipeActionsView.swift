import SwiftUI

struct BookSwipeActionsView<Content: View>: View {
    let book: Book
    let content: Content
    let onTap: () -> Void
    let onTop: () -> Void
    let onListen: () -> Void
    let onGroup: () -> Void
    let onDetail: () -> Void
    let onDelete: () -> Void
    
    @State private var offsetX: CGFloat = 0
    @State private var isDragging = false
    
    private let actionWidth: CGFloat = 80
    private let totalActionWidth: CGFloat = 400
    
    init(book: Book, onTap: @escaping () -> Void, onTop: @escaping () -> Void, onListen: @escaping () -> Void, onGroup: @escaping () -> Void, onDetail: @escaping () -> Void, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.book = book
        self.content = content()
        self.onTap = onTap
        self.onTop = onTop
        self.onListen = onListen
        self.onGroup = onGroup
        self.onDetail = onDetail
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                SwipeActionButton(
                    icon: "arrow.up",
                    title: "置顶",
                    color: .purple,
                    action: handleTop
                )
                
                SwipeActionButton(
                    icon: "headphones",
                    title: "听书",
                    color: .blue,
                    action: handleListen
                )
                
                SwipeActionButton(
                    icon: "folder.badge.plus",
                    title: "分组",
                    color: .orange,
                    action: handleGroup
                )
                
                SwipeActionButton(
                    icon: "info.circle",
                    title: "详情",
                    color: .green,
                    action: handleDetail
                )
                
                SwipeActionButton(
                    icon: "trash",
                    title: "删除",
                    color: .red,
                    action: handleDelete,
                    destructive: true
                )
            }
            
            content
                .offset(x: offsetX)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let newOffset = value.translation.width
                            offsetX = max(-totalActionWidth, min(0, newOffset))
                        }
                        .onEnded { value in
                            isDragging = false
                            let threshold = -totalActionWidth / 2
                            
                            if value.translation.width < threshold {
                                withAnimation(.spring()) {
                                    offsetX = -totalActionWidth
                                }
                            } else if value.translation.width > -actionWidth / 2 {
                                withAnimation(.spring()) {
                                    offsetX = 0
                                }
                            }
                        }
                )
                .onTapGesture {
                    if offsetX == 0 {
                        onTap()
                    } else {
                        withAnimation(.spring()) {
                            offsetX = 0
                        }
                    }
                }
        }
        .clipped()
    }
    
    private func handleTop() {
        withAnimation(.spring()) {
            offsetX = 0
        }
        onTop()
    }
    
    private func handleListen() {
        withAnimation(.spring()) {
            offsetX = 0
        }
        onListen()
    }
    
    private func handleGroup() {
        withAnimation(.spring()) {
            offsetX = 0
        }
        onGroup()
    }
    
    private func handleDetail() {
        withAnimation(.spring()) {
            offsetX = 0
        }
        onDetail()
    }
    
    private func handleDelete() {
        withAnimation(.spring()) {
            offsetX = 0
        }
        onDelete()
    }
}

struct SwipeActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    var destructive: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(destructive ? .white : .white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(width: 80, height: 100)
            .background(color)
        }
        .buttonStyle(.plain)
    }
}

struct GridBookshelfView: View {
    let books: [Book]
    @Binding var selectedBook: Book?
    @Binding var showingGroupSelector: Bool
    @Binding var bookToGroup: Book?
    @EnvironmentObject var bookStore: BookStore
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(books) { book in
                    BookSwipeActionsView(
                        book: book,
                        onTap: { selectedBook = book },
                        onTop: { moveBookToTop(book) },
                        onListen: { startListening(book) },
                        onGroup: { showGroupSelector(book) },
                        onDetail: { selectedBook = book },
                        onDelete: { deleteBook(book) }
                    ) {
                        BookGridItem(book: book)
                    }
                    .contextMenu {
                        BookContextMenu(book: book)
                    }
                }
            }
            .padding()
        }
    }
    
    private func moveBookToTop(_ book: Book) {
        bookStore.moveBookToTop(book)
    }
    
    private func startListening(_ book: Book) {
        print("开始听书: \(book.name)")
    }
    
    private func showGroupSelector(_ book: Book) {
        bookToGroup = book
        showingGroupSelector = true
    }
    
    private func deleteBook(_ book: Book) {
        bookStore.removeBook(book)
    }
}

struct ListBookshelfView: View {
    let books: [Book]
    @Binding var selectedBook: Book?
    @Binding var showingGroupSelector: Bool
    @Binding var bookToGroup: Book?
    @EnvironmentObject var bookStore: BookStore
    
    var body: some View {
        List(books) { book in
            BookSwipeActionsView(
                book: book,
                onTap: { selectedBook = book },
                onTop: { moveBookToTop(book) },
                onListen: { startListening(book) },
                onGroup: { showGroupSelector(book) },
                onDetail: { selectedBook = book },
                onDelete: { deleteBook(book) }
            ) {
                BookListItem(book: book)
            }
            .listRowInsets(EdgeInsets())
            .contextMenu {
                BookContextMenu(book: book)
            }
        }
        .listStyle(.plain)
    }
    
    private func moveBookToTop(_ book: Book) {
        bookStore.moveBookToTop(book)
    }
    
    private func startListening(_ book: Book) {
        print("开始听书: \(book.name)")
    }
    
    private func showGroupSelector(_ book: Book) {
        bookToGroup = book
        showingGroupSelector = true
    }
    
    private func deleteBook(_ book: Book) {
        bookStore.removeBook(book)
    }
}
