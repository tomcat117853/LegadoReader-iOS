import SwiftUI

struct BookshelfBatchEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var groupManager: BookGroupManager
    
    @Binding var selectedBooks: [Book]
    @State private var showingTagEditor = false
    @State private var newTag = ""
    @State private var showingMoveSheet = false
    @State private var showingMoreMenu = false
    @State private var showDeleteConfirm = false
    @State private var showRenameSheet = false
    @State private var renamePattern = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(bookStore.books) { book in
                    HStack(spacing: 12) {
                        Button(action: { toggleSelect(book) }) {
                            Image(systemName: selectedBooks.contains { $0.id == book.id } ? "checkmark.circle.fill" : "circle")
                                .font(.title)
                                .foregroundColor(selectedBooks.contains { $0.id == book.id } ? .blue : .gray)
                        }
                        .buttonStyle(.plain)
                        
                        BookListItem(book: book)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("编辑中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomToolbar
            }
            .sheet(isPresented: $showingTagEditor) {
                TagEditorView(selectedBooks: $selectedBooks, newTag: $newTag)
            }
            .sheet(isPresented: $showingMoveSheet) {
                GroupSelectorView(books: selectedBooks)
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteSelected()
                }
            } message: {
                Text("确定要删除选中的 \(selectedBooks.count) 本书吗？")
            }
            .sheet(isPresented: $showRenameSheet) {
                RenameSheetView(selectedBooks: $selectedBooks, renamePattern: $renamePattern)
            }
        }
    }
    
    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            Button(action: { showDeleteConfirm = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.title)
                    Text("删除")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            Divider()
                .frame(height: 40)
            
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                    Text("已选(\(selectedBooks.count))")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            Divider()
                .frame(height: 40)
            
            Button(action: { showingMoveSheet = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "folder.move")
                        .font(.title)
                    Text("移动")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            Divider()
                .frame(height: 40)
            
            Menu {
                Button(action: { showingTagEditor = true }) {
                    Label("添加标签", systemImage: "tag")
                }
                Button(action: { showRenameSheet = true }) {
                    Label("格式书名", systemImage: "textformat")
                }
                Button(action: { exportBooks() }) {
                    Label("导出书籍", systemImage: "arrow.up.doc")
                }
                Button(action: { modifyCovers() }) {
                    Label("修改封面", systemImage: "photo")
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title)
                    Text("更多")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, -2)
    }
    
    private func toggleSelect(_ book: Book) {
        if let index = selectedBooks.firstIndex(where: { $0.id == book.id }) {
            selectedBooks.remove(at: index)
        } else {
            selectedBooks.append(book)
        }
    }
    
    private func deleteSelected() {
        selectedBooks.forEach { book in
            bookStore.removeBook(book)
        }
        selectedBooks.removeAll()
        dismiss()
    }
    
    private func exportBooks() {
        let activityVC = UIActivityViewController(activityItems: selectedBooks.compactMap { book in
            if let url = URL(string: book.filePath ?? "") {
                return url as Any
            }
            return nil
        }, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func modifyCovers() {
        if let firstBook = selectedBooks.first {
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .photoLibrary
            imagePicker.delegate = ImagePickerDelegate.shared
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                ImagePickerDelegate.shared.onImagePicked = { image in
                    selectedBooks.forEach { book in
                        var updatedBook = book
                        if let data = image.pngData(), let base64 = data.base64EncodedString() {
                            updatedBook.cover = "data:image/png;base64,\(base64)"
                            self.bookStore.updateBook(updatedBook)
                        }
                    }
                }
                rootViewController.present(imagePicker, animated: true)
            }
        }
    }
}

struct TagEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bookStore: BookStore
    
    @Binding var selectedBooks: [Book]
    @Binding var newTag: String
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("输入标签名称", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("选中 \(selectedBooks.count) 本书")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("添加标签")
                }
                
                Section {
                    ForEach(selectedBooks) { book in
                        Text(book.name)
                            .font(.caption)
                    }
                } header: {
                    Text("选中的书籍")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("添加标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        applyTag()
                        dismiss()
                    }
                    .disabled(newTag.isEmpty)
                }
            }
        }
    }
    
    private func applyTag() {
        selectedBooks.forEach { book in
            var updatedBook = book
            updatedBook.kind = newTag
            bookStore.updateBook(updatedBook)
        }
    }
}

struct GroupSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var groupManager = BookGroupManager.shared
    let books: [Book]
    
    var body: some View {
        NavigationView {
            List {
                Section("移动到分组") {
                    ForEach(groupManager.groups) { group in
                        Button(action: {
                            moveToGroup(group)
                        }) {
                            HStack {
                                Image(systemName: group.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.headline)
                                    Text("\(group.bookCount) 本书")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                                .frame(width: 30)
                            
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("选择分组")
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
    
    private func moveToGroup(_ group: BookGroup) {
        books.forEach { book in
            groupManager.addBookToGroup(bookId: book.id, groupId: group.id)
        }
        dismiss()
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let lastChapter = book.lastChapter {
                        Text(lastChapter)
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    } else {
                        Text("未读")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    if book.totalChapters > 0 {
                        Text("\(book.totalChapters)章")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct RenameSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bookStore: BookStore
    
    @Binding var selectedBooks: [Book]
    @Binding var renamePattern: String
    
    @State private var useAuthorPrefix = false
    @State private var useSeriesPrefix = false
    @State private var removeExtraSpaces = true
    @State private var capitalizeFirstLetter = true
    
    var body: some View {
        NavigationView {
            List {
                Section("批量重命名") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选中 \(selectedBooks.count) 本书")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("自定义格式", text: $renamePattern, prompt: Text("支持 {name}, {author}, {index} 变量"))
                            .textFieldStyle(.roundedBorder)
                        
                        Toggle("作者前缀", isOn: $useAuthorPrefix)
                        Toggle("系列前缀", isOn: $useSeriesPrefix)
                        Toggle("移除多余空格", isOn: $removeExtraSpaces)
                        Toggle("首字母大写", isOn: $capitalizeFirstLetter)
                    }
                }
                
                Section("预览") {
                    if let firstBook = selectedBooks.first {
                        Text("示例: \(previewName(firstBook, index: 0))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Section("选中的书籍") {
                    ForEach(selectedBooks.prefix(5)) { book in
                        Text(book.name)
                            .font(.caption)
                    }
                    if selectedBooks.count > 5 {
                        Text("...还有 \(selectedBooks.count - 5) 本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("格式书名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        applyRename()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func previewName(_ book: Book, index: Int) -> String {
        var name = book.name
        
        if !renamePattern.isEmpty {
            name = renamePattern
                .replacingOccurrences(of: "{name}", with: book.name)
                .replacingOccurrences(of: "{author}", with: book.author)
                .replacingOccurrences(of: "{index}", with: "\(index + 1)")
        } else {
            var parts: [String] = []
            if useAuthorPrefix {
                parts.append(book.author)
            }
            if useSeriesPrefix {
                parts.append(book.series ?? "")
            }
            parts.append(book.name)
            name = parts.filter { !$0.isEmpty }.joined(separator: " - ")
        }
        
        if removeExtraSpaces {
            name = name.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        }
        
        if capitalizeFirstLetter {
            name = name.capitalized
        }
        
        return name
    }
    
    private func applyRename() {
        selectedBooks.enumerated().forEach { index, book in
            var updatedBook = book
            updatedBook.name = previewName(book, index: index)
            bookStore.updateBook(updatedBook)
        }
    }
}

class ImagePickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = ImagePickerDelegate()
    
    var onImagePicked: ((UIImage) -> Void)?
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            onImagePicked?(image)
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
