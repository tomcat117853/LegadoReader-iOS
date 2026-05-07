import SwiftUI

struct BookSourceImportView: View {
    @StateObject private var importManager = BookSourceImportManager.shared
    @EnvironmentObject var sourceStore: SourceStore
    @Environment(\.dismiss) var dismiss
    
    @State private var urlInput = ""
    @State private var showingImportHistory = false
    @State private var showingFormatHelp = false
    @State private var importResult: ImportResult?
    
    struct ImportResult {
        let successCount: Int
        let failCount: Int
        let sources: [BookSource]
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("输入书源URL", text: $urlInput)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Button(action: {
                                validateURL()
                            }) {
                                if importManager.isValidating {
                                    ProgressView()
                                        .frame(width: 60)
                                } else {
                                    Text("验证")
                                        .frame(width: 60)
                                }
                            }
                            .disabled(urlInput.isEmpty || importManager.isValidating)
                        }
                        
                        if let result = importManager.validationResult {
                            HStack {
                                Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.isValid ? .green : .red)
                                
                                if result.isValid {
                                    Text("检测到 \(result.sourceCount) 个书源")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(result.errorMessage ?? "验证失败")
                                        .foregroundColor(.red)
                                }
                            }
                            .font(.footnote)
                            
                            if result.isValid && !result.sourceNames.isEmpty {
                                Text("书源: \(result.sourceNames.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("URL导入")
                } footer: {
                    Text("支持 JSON、XML、TXT 等格式的书源文件")
                }
                
                Section {
                    Button(action: {
                        importFromURL()
                    }) {
                        HStack {
                            Spacer()
                            if importManager.isImporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("导入中... \(Int(importManager.importProgress * 100))%")
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                Text("导入书源")
                            }
                            Spacer()
                        }
                    }
                    .disabled(urlInput.isEmpty || importManager.isImporting)
                }
                
                Section {
                    Button(action: {
                        pasteFromClipboard()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("从剪贴板导入")
                        }
                    }
                    
                    Button(action: {
                        showingImportHistory = true
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("导入历史")
                            Spacer()
                            Text("\(importManager.importHistory.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("其他导入方式")
                }
                
                Section {
                    Button(action: {
                        showingFormatHelp = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("支持的格式说明")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("帮助")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("导入书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImportHistory) {
                ImportHistoryView(onImportAgain: { record in
                    urlInput = record.url
                })
            }
            .sheet(isPresented: $showingFormatHelp) {
                FormatHelpView()
            }
            .alert("导入结果", isPresented: Binding(
                get: { importResult != nil },
                set: { if !$0 { importResult = nil } }
            )) {
                Button("确定") {
                    importResult = nil
                }
            } message: {
                if let result = importResult {
                    Text("成功导入 \(result.successCount) 个书源\(result.failCount > 0 ? "，失败 \(result.failCount) 个" : ""）")
                }
            }
        }
    }
    
    private func validateURL() {
        Task {
            _ = await importManager.validateSourceURL(urlInput)
        }
    }
    
    private func importFromURL() {
        Task {
            let sources = await importManager.importFromURL(urlInput)
            
            for source in sources {
                sourceStore.addSource(source)
            }
            
            await MainActor.run {
                importResult = ImportResult(
                    successCount: sources.count,
                    failCount: importManager.totalCount - sources.count,
                    sources: sources
                )
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            urlInput = string
            validateURL()
        }
    }
}

struct ImportHistoryView: View {
    @StateObject private var importManager = BookSourceImportManager.shared
    @Environment(\.dismiss) var dismiss
    var onImportAgain: (BookSourceImportManager.ImportRecord) -> Void
    
    var body: some View {
        NavigationView {
            List {
                if importManager.importHistory.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("暂无导入历史")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    ForEach(importManager.importHistory) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.sourceName)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Text(record.importDate, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    if record.successCount > 0 {
                                        Text("成功 \(record.successCount)")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                    if record.failCount > 0 {
                                        Text("失败 \(record.failCount)")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                onImportAgain(record)
                                dismiss()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                importManager.deleteHistoryRecord(record)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("导入历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !importManager.importHistory.isEmpty {
                        Button("清空") {
                            importManager.clearHistory()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct FormatHelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        FormatItem(
                            title: "JSON 格式",
                            icon: "curlybraces",
                            example: """
                            [{
                              "bookSourceUrl": "https://example.com",
                              "bookSourceName": "示例书源",
                              "bookSourceGroup": "默认"
                            }]
                            """
                        )
                        
                        Divider()
                        
                        FormatItem(
                            title: "XML 格式",
                            icon: "chevron.left.forwardslash.chevron.right",
                            example: """
                            <sources>
                              <source>
                                <bookSourceUrl>https://example.com</bookSourceUrl>
                                <bookSourceName>示例书源</bookSourceName>
                              </source>
                            </sources>
                            """
                        )
                        
                        Divider()
                        
                        FormatItem(
                            title: "TXT 格式",
                            icon: "doc.text",
                            example: """
                            bookSourceUrl=https://example.com
                            bookSourceName=示例书源
                            bookSourceGroup=默认
                            """
                        )
                    }
                } header: {
                    Text("支持的格式")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("导入说明")
                            .font(.headline)
                        
                        Group {
                            Text("1. 支持从网络URL导入书源")
                            Text("2. 也支持从本地剪贴板导入")
                            Text("3. 导入前会自动验证URL有效性")
                            Text("4. 支持批量导入多个书源")
                            Text("5. 导入历史会保存最近50条记录")
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("使用说明")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("常用书源网站")
                            .font(.headline)
                        
                        ForEach(CommonSources.sources, id: \.url) { source in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.name)
                                        .font(.subheadline)
                                    Text(source.url)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("常用书源")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("格式说明")
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

struct FormatItem: View {
    let title: String
    let icon: String
    let example: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            Text(example)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

struct CommonSources {
    struct Source {
        let name: String
        let url: String
    }
    
    static let sources: [Source] = [
        Source(name: "书源1", url: "https://example.com/source1.json"),
        Source(name: "书源2", url: "https://example.com/source2.json"),
        Source(name: "书源3", url: "https://example.com/source3.json")
    ]
}

struct BookSourceImportView_Previews: PreviewProvider {
    static var previews: some View {
        BookSourceImportView()
            .environmentObject(SourceStore())
    }
}
