import SwiftUI
import UniformTypeIdentifiers

struct FileImportView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingFilePicker = false
    @State private var importResult: ImportResult?
    @State private var showingResult = false
    @State private var isImporting = false
    
    enum ImportResult {
        case success(bookName: String, isComic: Bool)
        case failure(message: String)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { showingFilePicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 50)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("从文件导入")
                                    .font(.headline)
                                Text("支持 TXT、EPUB、PDF、CBZ、CBR 等格式")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("书籍导入")
                } footer: {
                    Text("导入的书籍将直接添加到书架")
                }
                
                Section("支持的格式") {
                    VStack(alignment: .leading, spacing: 12) {
                        FormatInfoRow(icon: "doc.text", name: "TXT", description: "纯文本书籍")
                        FormatInfoRow(icon: "book", name: "EPUB", description: "电子书格式")
                        FormatInfoRow(icon: "doc.richtext", name: "PDF", description: "文档格式")
                        FormatInfoRow(icon: "doc.zipper", name: "CBZ/CBR", description: "漫画压缩包")
                        FormatInfoRow(icon: "photo.stack", name: "图片文件夹", description: "打包的漫画图片")
                    }
                    .padding(.vertical, 8)
                }
                
                Section("导入说明") {
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(icon: "1.circle.fill", text: "选择要导入的文件")
                        InstructionRow(icon: "2.circle.fill", text: "文件将复制到应用存储空间")
                        InstructionRow(icon: "3.circle.fill", text: "自动识别并添加到书架")
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("导入书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                SmartFilePickerView { urls in
                    importFiles(urls)
                }
            }
            .alert("导入结果", isPresented: $showingResult) {
                Button("确定") {
                    if case .success = importResult {
                        dismiss()
                    }
                }
            } message: {
                if let result = importResult {
                    switch result {
                    case .success(let name, let isComic):
                        Text("已将「\(name)」添加到书架")
                    case .failure(let message):
                        Text("导入失败: \(message)")
                    }
                }
            }
            .overlay {
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("正在导入...")
                                .font(.headline)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.systemBackground))
                        )
                    }
                }
            }
        }
    }
    
    private func importFiles(_ urls: [URL]) {
        isImporting = true
        
        for url in urls {
            let ext = url.pathExtension.lowercased()
            let isComic = ["cbz", "cbr", "cb7", "zip", "rar", "7z", "pdf"].contains(ext)
            
            if isComic {
                LocalBookManager.shared.importComicAndAddToBookshelf(from: url) { success in
                    if success {
                        importResult = .success(bookName: url.deletingPathExtension().lastPathComponent, isComic: true)
                    } else {
                        importResult = .failure(message: "无法读取文件")
                    }
                }
            } else {
                LocalBookManager.shared.importAndAddToBookshelf(from: url) { success in
                    if success {
                        importResult = .success(bookName: url.deletingPathExtension().lastPathComponent, isComic: false)
                    } else {
                        importResult = .failure(message: "无法读取文件")
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isImporting = false
            showingResult = true
        }
    }
}

struct FormatInfoRow: View {
    let icon: String
    let name: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

struct SmartFilePickerView: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .text,
            .epub,
            .pdf,
            .archive,
            .data,
            .content,
            .plainText
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: SmartFilePickerView
        
        init(_ parent: SmartFilePickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

struct QuickImportButton: View {
    @State private var showingImport = false
    
    var body: some View {
        Button(action: { showingImport = true }) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
        }
        .sheet(isPresented: $showingImport) {
            FileImportView()
        }
    }
}
