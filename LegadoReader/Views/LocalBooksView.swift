import SwiftUI

struct LocalBooksView: View {
    @StateObject private var bookManager = LocalBookManager.shared
    @State private var showingImport = false
    @State private var selectedBook: LocalBookManager.LocalBook?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(bookManager.localBooks) { book in
                    Button(action: {
                        selectedBook = book
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(book.type == .txt ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                                    .frame(width: 50, height: 70)
                                
                                Image(systemName: book.type == .txt ? "doc.text.fill" : "book.fill")
                                    .foregroundColor(book.type == .txt ? .orange : .blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                HStack {
                                    Text(book.author)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("·")
                                        .foregroundColor(.secondary)
                                    
                                    Text(book.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if book.progress > 0 {
                                    HStack {
                                        Text("已读 \(Int(book.progress * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        ProgressView(value: book.progress)
                                            .progressViewStyle(.linear)
                                            .frame(width: 80)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            bookManager.deleteBook(book)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
                
                if bookManager.localBooks.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.open")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text("暂无本地书籍")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("点击右上角按钮导入本地TXT或EPUB文件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("本地书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingImport = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $selectedBook != nil) {
                if let book = selectedBook {
                    LocalBookReaderView(book: book)
                }
            }
        }
    }
}

struct LocalBookReaderView: View {
    let book: LocalBookManager.LocalBook
    @State private var chapters: [String] = []
    @State private var content: String = ""
    @State private var currentChapter = 0
    @State private var chapterContent: String = ""
    @State private var isLoading = true
    @State private var showingChapterList = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("加载中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    Text(chapterContent)
                        .font(.system(size: 17))
                        .lineSpacing(8)
                        .padding()
                }
            }
            .navigationTitle(book.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("目录") {
                        showingChapterList = true
                    }
                }
            }
            .sheet(isPresented: $showingChapterList) {
                ChapterListView(chapters: chapters, currentChapter: currentChapter, onSelect: { index in
                    currentChapter = index
                    updateChapterContent()
                    showingChapterList = false
                })
            }
            .onAppear {
                loadBook()
            }
            .onChange(of: currentChapter) {
                updateChapterContent()
            }
        }
    }
    
    private func loadBook() {
        let result = LocalBookManager.shared.readBook(book)
        chapters = result.chapters
        content = result.content
        isLoading = false
        updateChapterContent()
    }
    
    private func updateChapterContent() {
        chapterContent = LocalBookManager.shared.getChapterContent(
            content: content,
            chapterIndex: currentChapter,
            chapters: chapters
        )
    }
}

struct ChapterListView: View {
    let chapters: [String]
    let currentChapter: Int
    let onSelect: (Int) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(chapters.indices, id: \.self) { index in
                    Button(action: {
                        onSelect(index)
                    }) {
                        HStack {
                            Text(chapters[index])
                                .font(.body)
                                .foregroundColor(currentChapter == index ? .blue : .primary)
                            
                            Spacer()
                            
                            if currentChapter == index {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("章节列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        // 关闭
                    }
                }
            }
        }
    }
}
