import SwiftUI

struct TXTImportSettingsView: View {
    @StateObject private var reader = EnhancedTXTReader()
    @State private var testContent = ""
    @State private var testResult: EnhancedTXTReader.EnhancedParseResult?
    @State private var showingTest = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TXT导入说明")
                        .font(.headline)
                    
                    Text("优化后的TXT解析器支持智能识别书籍标题、作者、简介和章节结构。支持多种章节标题格式。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("支持的格式") {
                VStack(alignment: .leading, spacing: 8) {
                    FormatExampleView(
                        title: "章节标题",
                        examples: [
                            "第1章 开始",
                            "第1章: 开始阅读",
                            "第一章 新的开始",
                            "Chapter 1. 开始",
                            "1. 第一章内容"
                        ]
                    )
                    
                    FormatExampleView(
                        title: "分卷标题",
                        examples: [
                            "【第一卷】序章",
                            "【卷一】开始的故事",
                            "卷一 序章"
                        ]
                    )
                    
                    FormatExampleView(
                        title: "作者信息",
                        examples: [
                            "作者：张三",
                            "Author: 李四"
                        ]
                    )
                }
            }
            
            Section("解析选项") {
                Toggle("启用智能标题识别", isOn: .constant(true))
                
                Toggle("自动去除多余空行", isOn: .constant(true))
                
                Toggle("识别书籍简介", isOn: .constant(true))
                
                Toggle("识别作者信息", isOn: .constant(true))
            }
            
            Section("高级设置") {
                NavigationLink(destination: TitleSegmentationSettingsView()) {
                    HStack {
                        Image(systemName: "text.badge.checkmark")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("标题分段规则")
                            Text("自定义章节标题识别规则")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("测试解析") {
                Button(action: { showingTest = true }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.blue)
                        Text("测试TXT解析")
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("提示")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("确保TXT文件开头包含书名和作者信息，以便准确识别")
                                .font(.caption)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("章节标题应单独成行，便于准确识别")
                                .font(.caption)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("支持自定义标题分段规则以适应特殊格式")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("TXT导入设置")
        .sheet(isPresented: $showingTest) {
            TXTParserTestView()
        }
    }
}

struct FormatExampleView: View {
    let title: String
    let examples: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(examples, id: \.self) { example in
                Text(example)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
        }
    }
}

struct TXTParserTestView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var reader = EnhancedTXTReader()
    @State private var testContent = ""
    @State private var testResult: EnhancedTXTReader.EnhancedParseResult?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Section {
                    TextEditor(text: $testContent)
                        .frame(minHeight: 200)
                        .border(Color.gray.opacity(0.3), width: 1)
                        .padding()
                } header: {
                    Text("输入测试内容")
                        .font(.headline)
                        .padding(.top)
                }
                
                Button(action: testParsing) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("开始解析")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(testContent.isEmpty || isLoading)
                .padding()
                
                if let result = testResult {
                    Divider()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ResultSection(title: "识别结果", icon: "checkmark.circle.fill") {
                                ResultRow(title: "书名", value: result.title)
                                if let author = result.author {
                                    ResultRow(title: "作者", value: author)
                                }
                                ResultRow(title: "章节数", value: "\(result.chapters.count)")
                                ResultRow(title: "分卷数", value: "\(result.volumes.count)")
                            }
                            
                            if let intro = result.intro {
                                ResultSection(title: "简介", icon: "text.alignleft") {
                                    Text(intro)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !result.chapters.isEmpty {
                                ResultSection(title: "章节列表（前10个）", icon: "list.bullet") {
                                    ForEach(Array(result.chapters.prefix(10).enumerated()), id: \.offset) { index, chapter in
                                        HStack {
                                            Text("\(index + 1).")
                                                .foregroundColor(.secondary)
                                                .frame(width: 30)
                                            Text(chapter.formattedTitle)
                                                .font(.caption)
                                            Spacer()
                                            Text("L\(chapter.startLine + 1)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Divider()
                                    }
                                }
                            }
                            
                            if !result.warnings.isEmpty {
                                ResultSection(title: "警告", icon: "exclamationmark.triangle") {
                                    ForEach(result.warnings, id: \.self) { warning in
                                        Text("⚠️ \(warning)")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("TXT解析测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func testParsing() {
        guard !testContent.isEmpty else { return }
        
        isLoading = true
        testResult = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            testResult = reader.parseEnhanced(testContent)
            isLoading = false
        }
    }
}

struct ResultSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ResultRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
