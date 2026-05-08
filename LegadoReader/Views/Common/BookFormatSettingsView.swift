import SwiftUI

struct BookFormatSettingsView: View {
    @StateObject private var formatManager = BookFormatManager.shared
    @State private var selectedFormat: BookFormatManager.BookFormat?
    @State private var showingConvertTool = false
    @State private var encodingPreview = ""
    @State private var detectedEncoding = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("支持的格式") {
                    ForEach(formatManager.supportedFormats) { format in
                        FormatRow(format: format, isSelected: selectedFormat?.id == format.id) {
                            selectedFormat = format
                        }
                    }
                }
                
                Section("格式转换") {
                    Button {
                        showingConvertTool = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.left")
                                .foregroundColor(.blue)
                            Text("格式转换工具")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("编码检测") {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "textformat")
                                .foregroundColor(.blue)
                            Text("自动检测编码")
                        }
                        
                        Text("支持 UTF-8、UTF-16、GBK、Big5、Windows-1252 等编码自动识别")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                if selectedFormat != nil {
                    Section("格式详情") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("名称")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(selectedFormat!.name)
                            }
                            
                            HStack {
                                Text("扩展名")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(selectedFormat!.extensions.map { ".\($0)" }.joined(", "))
                            }
                            
                            HStack {
                                Text("MIME类型")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(selectedFormat!.mimeType)
                            }
                            
                            HStack {
                                Text("支持元数据")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: selectedFormat!.supportsMetadata ? "checkmark.circle.fill" : "x.circle.fill")
                                    .foregroundColor(selectedFormat!.supportsMetadata ? .green : .red)
                            }
                            
                            HStack {
                                Text("支持图片")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: selectedFormat!.supportsImages ? "checkmark.circle.fill" : "x.circle.fill")
                                    .foregroundColor(selectedFormat!.supportsImages ? .green : .red)
                            }
                            
                            HStack {
                                Text("二进制格式")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: selectedFormat!.isBinary ? "checkmark.circle.fill" : "x.circle.fill")
                                    .foregroundColor(selectedFormat!.isBinary ? .green : .red)
                            }
                            
                            Text(selectedFormat!.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("书籍格式")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingConvertTool) {
                FormatConvertView()
            }
        }
    }
}

struct FormatRow: View {
    let format: BookFormatManager.BookFormat
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.name)
                        .font(.headline)
                    
                    Text(format.extensions.map { ".\($0)" }.joined(", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
    }
}

struct FormatConvertView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var formatManager = BookFormatManager.shared
    @State private var selectedFileURL: URL?
    @State private var sourceFormat: BookFormatManager.BookFormat?
    @State private var targetFormat: BookFormatManager.BookFormat?
    @State private var isConverting = false
    @State private var conversionProgress = 0.0
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var convertibleFormats: [BookFormatManager.BookFormat] {
        if let source = sourceFormat {
            return formatManager.getConvertibleFormats(from: source)
        }
        return []
    }
    
    var canConvert: Bool {
        sourceFormat != nil && targetFormat != nil && !isConverting
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("选择文件") {
                    Button {
                        selectFile()
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                            
                            if let url = selectedFileURL {
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent)
                                        .font(.subheadline)
                                    Text("点击更换")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("选择要转换的文件")
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if selectedFileURL != nil {
                    Section("源格式") {
                        if let format = sourceFormat {
                            Text(format.displayName)
                                .foregroundColor(.blue)
                        } else {
                            Text("检测中...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section("目标格式") {
                        Picker("选择目标格式", selection: $targetFormat) {
                            Text("请选择").tag(nil as BookFormatManager.BookFormat?)
                            
                            ForEach(convertibleFormats) { format in
                                Text(format.displayName).tag(format as BookFormatManager.BookFormat?)
                            }
                        }
                    }
                    
                    Section {
                        Button(action: convert) {
                            HStack {
                                if isConverting {
                                    ProgressView(value: conversionProgress)
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .frame(height: 20)
                                } else {
                                    Text("开始转换")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canConvert ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canConvert)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("格式转换")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("确定") {}
            }
        }
    }
    
    private func selectFile() {
        selectedFileURL = URL(fileURLWithPath: "/sample/book.txt")
        sourceFormat = formatManager.detectFormat(selectedFileURL!.lastPathComponent)
    }
    
    private func convert() {
        guard let source = sourceFormat, let target = targetFormat else { return }
        
        isConverting = true
        conversionProgress = 0.0
        
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if conversionProgress < 0.95 {
                conversionProgress += 0.05
            }
        }
        
        Task {
            do {
                let sampleData = "测试内容".data(using: .utf8) ?? Data()
                let converted = try await formatManager.convert(sampleData, from: source, to: target)
                
                DispatchQueue.main.async {
                    progressTimer.invalidate()
                    conversionProgress = 1.0
                    isConverting = false
                    
                    alertMessage = "转换成功！文件大小: \(converted.count) 字节"
                    showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    progressTimer.invalidate()
                    isConverting = false
                    
                    alertMessage = "转换失败: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

struct EncodingTestView: View {
    @State private var inputText = ""
    @State private var selectedEncoding = 0
    @State private var decodedText = ""
    @State private var detectedEncoding = ""
    
    let encodings = [
        ("UTF-8", String.Encoding.utf8),
        ("UTF-16 LE", String.Encoding.utf16LittleEndian),
        ("UTF-16 BE", String.Encoding.utf16BigEndian),
        ("GBK/GB2312", String.Encoding.gbk),
        ("Big5", String.Encoding.big5),
        ("Windows-1252", String.Encoding.windowsCP1252)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("输入文本") {
                    TextField("输入要测试的文本", text: $inputText)
                }
                
                Section("选择编码") {
                    Picker("编码类型", selection: $selectedEncoding) {
                        ForEach(encodings.indices, id: \.self) { index in
                            Text(encodings[index].0).tag(index)
                        }
                    }
                }
                
                Section("检测结果") {
                    HStack {
                        Text("自动检测")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(detectedEncoding)
                            .foregroundColor(.blue)
                    }
                }
                
                Section("解码结果") {
                    Text(decodedText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("测试解码") {
                        testEncoding()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("编码测试")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func testEncoding() {
        if let data = inputText.data(using: encodings[selectedEncoding].1) {
            detectedEncoding = BookEncodingDetector.detectCharsetName(data: data)
            decodedText = data.toString(encoding: encodings[selectedEncoding].1)
        }
    }
}

struct BookFormatSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BookFormatSettingsView()
    }
}
