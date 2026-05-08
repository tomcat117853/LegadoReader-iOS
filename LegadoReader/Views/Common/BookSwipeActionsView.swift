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
    @Binding var showingBookDetail: Bool
    @Binding var bookForDetail: Book?
    @Binding var isEditMode: Bool
    @Binding var selectedBooks: [Book]
    @Binding var bookToRead: Book?
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
                    ZStack(alignment: .topTrailing) {
                        BookSwipeActionsView(
                            book: book,
                            onTap: {
                                if isEditMode {
                                    bookToRead = book
                                } else {
                                    selectedBook = book
                                }
                            },
                            onTop: { moveBookToTop(book) },
                            onListen: { startListening(book) },
                            onGroup: { showGroupSelector(book) },
                            onDetail: { showBookDetail(book) },
                            onDelete: { deleteBook(book) }
                        ) {
                            BookGridItem(book: book)
                        }
                        .contextMenu {
                            BookContextMenu(book: book)
                        }
                        .overlay(
                            isEditMode ? selectionOverlay(for: book) : nil
                        )
                        
                        if isEditMode {
                            Button(action: { toggleSelection(book) }) {
                                Image(systemName: selectedBooks.contains { $0.id == book.id } ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(selectedBooks.contains { $0.id == book.id } ? .blue : .gray)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            .padding(8)
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation {
                            isEditMode = true
                            toggleSelection(book)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func selectionOverlay(for book: Book) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(selectedBooks.contains { $0.id == book.id } ? Color.blue : Color.clear, lineWidth: 3)
    }
    
    private func toggleSelection(_ book: Book) {
        if let index = selectedBooks.firstIndex(where: { $0.id == book.id }) {
            selectedBooks.remove(at: index)
        } else {
            selectedBooks.append(book)
        }
    }
    
    private func showBookDetail(_ book: Book) {
        bookForDetail = book
        showingBookDetail = true
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

struct BookGridItem: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(3/4, contentMode: .fit)
                
                if let cover = book.cover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(book.name.prefix(1))
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            
            Text(book.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Text(book.lastChapter ?? book.author)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
    }
}

struct BookListItem: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 80)
                
                if let cover = book.cover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(book.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let lastChapter = book.lastChapter {
                    Text("更新至: \(lastChapter)")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                if let lastRead = book.lastReadChapter {
                    Text("读至: \(lastRead)")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }
}

struct ListBookshelfView: View {
    let books: [Book]
    @Binding var selectedBook: Book?
    @Binding var showingGroupSelector: Bool
    @Binding var bookToGroup: Book?
    @Binding var showingBookDetail: Bool
    @Binding var bookForDetail: Book?
    @Binding var isEditMode: Bool
    @Binding var selectedBooks: [Book]
    @Binding var bookToRead: Book?
    @EnvironmentObject var bookStore: BookStore
    
    var body: some View {
        List(books) { book in
            ZStack(alignment: .leading) {
                BookSwipeActionsView(
                    book: book,
                    onTap: {
                        if isEditMode {
                            bookToRead = book
                        } else {
                            selectedBook = book
                        }
                    },
                    onTop: { moveBookToTop(book) },
                    onListen: { startListening(book) },
                    onGroup: { showGroupSelector(book) },
                    onDetail: { showBookDetail(book) },
                    onDelete: { deleteBook(book) }
                ) {
                    HStack(spacing: 12) {
                        if isEditMode {
                            Button(action: { toggleSelection(book) }) {
                                Image(systemName: selectedBooks.contains { $0.id == book.id } ? "checkmark.circle.fill" : "circle")
                                    .font(.title)
                                    .foregroundColor(selectedBooks.contains { $0.id == book.id } ? .blue : .gray)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        BookListItem(book: book)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .contextMenu {
                BookContextMenu(book: book)
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                withAnimation {
                    isEditMode = true
                    toggleSelection(book)
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func toggleSelection(_ book: Book) {
        if let index = selectedBooks.firstIndex(where: { $0.id == book.id }) {
            selectedBooks.remove(at: index)
        } else {
            selectedBooks.append(book)
        }
    }
    
    private func showBookDetail(_ book: Book) {
        bookForDetail = book
        showingBookDetail = true
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

struct BookGridItem: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(3/4, contentMode: .fit)
                
                if let cover = book.cover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(book.name.prefix(1))
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            
            Text(book.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Text(book.lastChapter ?? book.author)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
    }
}

struct BookListItem: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 80)
                
                if let cover = book.cover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(book.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let lastChapter = book.lastChapter {
                    Text("更新至: \(lastChapter)")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                if let lastRead = book.lastReadChapter {
                    Text("读至: \(lastRead)")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }
}
