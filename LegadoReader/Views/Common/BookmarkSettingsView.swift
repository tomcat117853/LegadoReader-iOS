import SwiftUI

struct BookmarkSettingsView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var showingAddBookmark = false
    @State private var searchText = ""
    @State private var selectedFilter: BookmarkFilter = .all
    
    enum BookmarkFilter: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case thisWeek = "本周"
        case withNotes = "有笔记"
    }
    
    var filteredBookmarks: [BookmarkManager.Bookmark] {
        var bookmarks = bookmarkManager.bookmarks
        
        switch selectedFilter {
        case .all:
            break
        case .today:
            bookmarks = bookmarks.filter {
                Calendar.current.isDate($0.createdTime, inSameDayAs: Date())
            }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            bookmarks = bookmarks.filter { $0.createdTime > weekAgo }
        case .withNotes:
            bookmarks = bookmarks.filter { !$0.note.isEmpty }
        }
        
        if !searchText.isEmpty {
            bookmarks = bookmarks.filter { bookmark in
                bookmark.bookName.contains(searchText) ||
                bookmark.chapterTitle.contains(searchText) ||
                bookmark.content.contains(searchText) ||
                bookmark.note.contains(searchText)
            }
        }
        
        return bookmarks
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("筛选", selection: $selectedFilter) {
                    ForEach(BookmarkFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if bookmarkManager.bookmarks.isEmpty {
                    EmptyBookmarkView()
                } else {
                    List {
                        Section {
                            HStack {
                                Text("书签总数")
                                Spacer()
                                Text("\(bookmarkManager.bookmarks.count)")
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("涉及书籍")
                                Spacer()
                                Text("\(Set(bookmarkManager.bookmarks.map { $0.bookId }).count)")
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("涉及章节")
                                Spacer()
                                Text("\(Set(bookmarkManager.bookmarks.map { "\($0.bookId)_\($0.chapterId)" }).count)")
                                    .foregroundColor(.orange)
                            }
                        } header: {
                            Text("统计信息")
                        }
                        
                        Section {
                            ForEach(filteredBookmarks) { bookmark in
                                BookmarkRowView(bookmark: bookmark)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            bookmarkManager.removeBookmark(bookmark)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        NavigationLink(destination: EditBookmarkView(bookmark: bookmark)) {
                                            Button {
                                            } label: {
                                                Label("编辑", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                    }
                            }
                        } header: {
                            Text("书签列表 (\(filteredBookmarks.count))")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("书签管理")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索书签")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            bookmarkManager.clearAllBookmarks()
                        }) {
                            Label("清空全部书签", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct BookmarkRowView: View {
    let bookmark: BookmarkManager.Bookmark
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: bookmark.color.colorValue) ?? .blue)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(bookmark.bookName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(bookmark.createdTime, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(bookmark.chapterTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if !bookmark.note.isEmpty {
                    Text(bookmark.note)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyBookmarkView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("暂无书签")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("在阅读时点击书签图标添加书签")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EditBookmarkView: View {
    let bookmark: BookmarkManager.Bookmark
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var note: String = ""
    @State private var selectedColor: BookmarkManager.Bookmark.BookmarkColor = .blue
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("书籍")
                    Spacer()
                    Text(bookmark.bookName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("章节")
                    Spacer()
                    Text(bookmark.chapterTitle)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("位置")
                    Spacer()
                    Text("第 \(bookmark.position) 字")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("书签信息")
            }
            
            Section {
                TextEditor(text: $note)
                    .frame(minHeight: 100)
            } header: {
                Text("笔记")
            }
            
            Section {
                ForEach(BookmarkManager.Bookmark.BookmarkColor.allCases, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(hex: color.colorValue) ?? .blue)
                                .frame(width: 20, height: 20)
                            
                            Text(color.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedColor == color {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("书签颜色")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(bookmark.content)
                        .font(.body)
                        .lineLimit(5)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("内容预览")
            }
            
            Section {
                Button("保存修改") {
                    saveChanges()
                }
                .foregroundColor(.blue)
                
                Button("删除书签") {
                    bookmarkManager.removeBookmark(bookmark)
                    dismiss()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("编辑书签")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            note = bookmark.note
            selectedColor = bookmark.color
        }
    }
    
    private func saveChanges() {
        bookmarkManager.updateNote(id: bookmark.id, note: note)
        bookmarkManager.updateColor(id: bookmark.id, color: selectedColor)
        dismiss()
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

struct BookmarkSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BookmarkSettingsView()
    }
}
