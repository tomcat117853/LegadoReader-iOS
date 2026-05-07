import SwiftUI

struct ArchiveManagerView: View {
    @StateObject private var archiveManager = ArchiveManager.shared
    @State private var showImporter = false
    @State private var selectedArchive: ArchiveManager.ArchiveInfo?
    @State private var showArchiveDetail = false
    @State private var archiveEntries: [ArchiveManager.ArchiveEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            List {
                Section("支持的压缩格式") {
                    ForEach(archiveManager.supportedArchiveFormats) { format in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Text(format.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("完整支持")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("最近打开") {
                    if archiveManager.recentArchives.isEmpty {
                        HStack {
                            Spacer()
                            Text("暂无历史记录")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    } else {
                        ForEach(archiveManager.recentArchives) { archive in
                            Button {
                                selectedArchive = archive
                                showArchiveDetail = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(archive.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        HStack(spacing: 8) {
                                            Text(archive.sizeFormatted)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text("·")
                                                .foregroundColor(.secondary)
                                            
                                            Text("\(archive.entryCount)个文件")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                archiveManager.recentArchives.remove(at: index)
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        showImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.blue)
                            Text("导入压缩文件")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("压缩包管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            archiveManager.clearRecentArchives()
                        } label: {
                            Label("清除历史", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showArchiveDetail) {
                if let archive = selectedArchive {
                    ArchiveDetailView(archive: archive, entries: $archiveEntries, isLoading: $isLoading)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }
}

struct ArchiveDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var archiveManager = ArchiveManager.shared
    
    let archive: ArchiveManager.ArchiveInfo
    @Binding var entries: [ArchiveManager.ArchiveEntry]
    @Binding var isLoading: Bool
    
    @State private var selectedEntries: Set<String> = []
    @State private var showExtractOptions = false
    @State private var extractedFiles: [URL] = []
    @State private var showExtractedFiles = false
    @State private var extractionProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if entries.isEmpty {
                    emptyView
                } else {
                    fileListView
                }
            }
            .navigationTitle(archive.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !entries.isEmpty {
                        Button {
                            showExtractOptions = true
                        } label: {
                            Text("解压")
                        }
                    }
                }
            }
            .confirmationDialog("解压选项", isPresented: $showExtractOptions) {
                Button("解压全部文件") {
                    extractAll()
                }
                
                if !selectedEntries.isEmpty {
                    Button("解压选中文件 (\(selectedEntries.count))") {
                        extractSelected()
                    }
                }
                
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showExtractedFiles) {
                ExtractedFilesView(files: extractedFiles)
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onAppear {
                loadEntries()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在分析压缩文件...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("未能读取压缩文件内容")
                .font(.headline)
            
            Text("可能文件损坏或格式不支持")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var fileListView: some View {
        VStack(spacing: 0) {
            List(entries, selection: $selectedEntries) { entry in
                ArchiveEntryRow(entry: entry)
            }
            .listStyle(.plain)
            
            VStack(spacing: 8) {
                if archiveManager.isExtracting {
                    ProgressView(value: extractionProgress)
                        .tint(.blue)
                    Text("正在解压... \(Int(extractionProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("\(entries.count) 个文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !selectedEntries.isEmpty {
                        Text("已选择 \(selectedEntries.count) 个")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }
    
    private func loadEntries() {
        isLoading = true
        
        Task {
            do {
                let url = URL(fileURLWithPath: archive.path)
                let loadedEntries = try await archiveManager.analyzeArchive(at: url)
                
                await MainActor.run {
                    entries = loadedEntries
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func extractAll() {
        extractEntries(nil)
    }
    
    private func extractSelected() {
        let selected = entries.filter { selectedEntries.contains($0.id) }
        extractEntries(selected)
    }
    
    private func extractEntries(_ entriesToExtract: [ArchiveManager.ArchiveEntry]?) {
        isLoading = true
        
        Task {
            do {
                let url = URL(fileURLWithPath: archive.path)
                let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                
                let files = try await archiveManager.extractArchive(at: url, to: destination, entries: entriesToExtract)
                
                await MainActor.run {
                    extractedFiles = files
                    isLoading = false
                    showExtractedFiles = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

struct ArchiveEntryRow: View {
    let entry: ArchiveManager.ArchiveEntry
    
    var fileIcon: String {
        if entry.isDirectory {
            return "folder.fill"
        }
        
        let ext = URL(fileURLWithPath: entry.name).pathExtension.lowercased()
        
        switch ext {
        case "epub", "mobi", "azw", "pdf", "fb2", "txt", "chm", "rtf", "html":
            return "book.fill"
        case "jpg", "jpeg", "png", "gif", "webp", "bmp":
            return "photo.fill"
        case "mp3", "wav", "aac", "m4a":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        default:
            return "doc.fill"
        }
    }
    
    var fileColor: Color {
        let ext = URL(fileURLWithPath: entry.name).pathExtension.lowercased()
        
        switch ext {
        case "epub", "mobi", "azw":
            return .blue
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "gif", "webp":
            return .green
        case "mp3", "wav", "aac":
            return .purple
        case "zip", "rar", "7z":
            return .orange
        default:
            return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon)
                .foregroundColor(fileColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(entry.sizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if entry.compressionRatio > 0 {
                        Text("压缩率: \(Int(entry.compressionRatio * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ExtractedFilesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var archiveManager = ArchiveManager.shared
    
    let files: [URL]
    @State private var bookFiles: [ArchiveManager.ArchiveEntry] = []
    @State private var imageFiles: [ArchiveManager.ArchiveEntry] = []
    @State private var otherFiles: [ArchiveManager.ArchiveEntry] = []
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("分类", selection: $selectedTab) {
                    Text("书籍 (\(bookFiles.count))").tag(0)
                    Text("图片 (\(imageFiles.count))").tag(1)
                    Text("其他 (\(otherFiles.count))").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    fileListView(for: bookFiles, icon: "book.fill", color: .blue)
                        .tag(0)
                    
                    fileListView(for: imageFiles, icon: "photo.fill", color: .green)
                        .tag(1)
                    
                    fileListView(for: otherFiles, icon: "doc.fill", color: .secondary)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("解压结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                categorizeFiles()
            }
        }
    }
    
    private func fileListView(for files: [ArchiveManager.ArchiveEntry], icon: String, color: Color) -> some View {
        if files.isEmpty {
            return AnyView(emptyCategoryView)
        } else {
            return AnyView(
                List(files, id: \.path) { file in
                    HStack {
                        Image(systemName: icon)
                            .foregroundColor(color)
                        
                        VStack(alignment: .leading) {
                            Text(file.name)
                                .font(.subheadline)
                            
                            Text(file.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            )
        }
    }
    
    private var emptyCategoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("没有此类文件")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func categorizeFiles() {
        let allEntries = files.map { url in
            ArchiveManager.ArchiveEntry(
                id: UUID().uuidString,
                name: url.lastPathComponent,
                path: url.path,
                size: Int64((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0),
                isDirectory: false,
                compressedSize: 0,
                modificationDate: nil
            )
        }
        
        bookFiles = allEntries.filter { file in
            let ext = URL(fileURLWithPath: file.name).pathExtension.lowercased()
            return ["epub", "mobi", "azw", "pdf", "fb2", "txt", "chm", "rtf", "html"].contains(ext)
        }
        
        imageFiles = allEntries.filter { file in
            let ext = URL(fileURLWithPath: file.name).pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "gif", "webp", "bmp"].contains(ext)
        }
        
        otherFiles = allEntries.filter { file in
            !bookFiles.contains(where: { $0.path == file.path }) &&
            !imageFiles.contains(where: { $0.path == file.path })
        }
    }
}

struct ArchiveImportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var archiveManager = ArchiveManager.shared
    
    @State private var showFilePicker = false
    @State private var selectedFiles: [URL] = []
    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var showResults = false
    @State private var importedBooks: [ImportedBook] = []
    
    struct ImportedBook: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let format: String
        let size: Int64
        
        var sizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if selectedFiles.isEmpty {
                    emptyState
                } else {
                    fileList
                }
                
                if isProcessing {
                    processingView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("导入压缩文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("选择文件") {
                        showFilePicker = true
                    }
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.archive], allowsMultipleSelection: true) { result in
                handleFileSelection(result)
            }
            .sheet(isPresented: $showResults) {
                ImportResultsView(importedBooks: importedBooks)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("选择要导入的压缩文件")
                .font(.headline)
            
            Text("支持ZIP、RAR、7Z等格式\n包含的电子书将被自动识别")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showFilePicker = true
            } label: {
                Label("选择文件", systemImage: "folder")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
    
    private var fileList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("已选择 \(selectedFiles.count) 个文件")
                    .font(.headline)
                
                Spacer()
                
                Button("清除") {
                    selectedFiles.removeAll()
                }
                .font(.caption)
            }
            
            List(selectedFiles, id: \.path) { url in
                HStack {
                    Image(systemName: "doc.zipper")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                        
                        if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .listStyle(.plain)
            
            Button {
                processFiles()
            } label: {
                Text("开始导入")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isProcessing)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(processingStatus)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles = urls
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
    
    private func processFiles() {
        isProcessing = true
        importedBooks.removeAll()
        
        Task {
            for (index, url) in selectedFiles.enumerated() {
                await MainActor.run {
                    processingStatus = "正在处理 \(index + 1)/\(selectedFiles.count)"
                }
                
                do {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let entries = try await archiveManager.analyzeArchive(at: url)
                    let bookFiles = archiveManager.getBookFiles(from: entries)
                    
                    for book in bookFiles {
                        let bookInfo = ImportedBook(
                            name: book.name,
                            path: url.path,
                            format: URL(fileURLWithPath: book.name).pathExtension.uppercased(),
                            size: book.size
                        )
                        
                        await MainActor.run {
                            importedBooks.append(bookInfo)
                        }
                    }
                } catch {
                    print("Error processing \(url.lastPathComponent): \(error)")
                }
            }
            
            await MainActor.run {
                isProcessing = false
                processingStatus = ""
                showResults = true
            }
        }
    }
}

struct ImportResultsView: View {
    @Environment(\.dismiss) var dismiss
    let importedBooks: [ArchiveImportView.ImportedBook]
    
    var body: some View {
        NavigationView {
            VStack {
                if importedBooks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("未找到可导入的电子书")
                            .font(.headline)
                        
                        Text("压缩包中可能不包含支持的电子书格式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(importedBooks) { book in
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(book.name)
                                    .font(.subheadline)
                                
                                HStack {
                                    Text(book.format)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                    
                                    Text(book.sizeFormatted)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("导入结果")
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

struct ArchiveManagerView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveManagerView()
    }
}
