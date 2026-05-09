import SwiftUI

struct EditBookView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var bookName = "大明春色"
    @State private var author = "西风紧"
    @State private var summary = ""
    @State private var selectedGroup = "顶层书架"
    @State private var titleNumbering = "与原文一致"
    @State private var encoding = "默认"
    @State private var bookType = "图文模式"
    @State private var isParsing = false
    @State private var parseProgress = 0.0
    @State private var parsedChapters: [ParsedChapter] = []
    @State private var totalChapters = 0
    @State private var showImporting = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    private let groups = ["顶层书架", "我的收藏", "正在阅读", "已读完"]
    private let numberingOptions = ["与原文一致", "自动编号"]
    private let encodingOptions = ["默认", "UTF-8", "GBK", "GB2312"]
    private let bookTypes = ["图文模式", "纯文本模式", "漫画模式"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        Section(header: sectionHeader("解析配置")) {
                            OptionRow(title: "标题中的数字", value: titleNumbering, options: numberingOptions) { newValue in
                                titleNumbering = newValue
                            }
                            
                            OptionRow(title: "指定编码", value: encoding, options: encodingOptions) { newValue in
                                encoding = newValue
                            }
                            
                            OptionRow(title: "书籍类型", value: bookType, options: bookTypes) { newValue in
                                bookType = newValue
                            }
                            
                            Button(action: {
                                startParsing()
                            }) {
                                HStack {
                                    if isParsing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            .scaleEffect(0.8)
                                        Text("解析中... \(Int(parseProgress * 100))%")
                                    } else {
                                        Text("重新解析")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(isParsing)
                        }
                        
                        Section(header: sectionHeader("解析结果")) {
                            HStack(alignment: .top, spacing: 12) {
                                bookCover
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    inputField(label: "书名", text: $bookName)
                                    inputField(label: "作者", text: $author)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Section(header: sectionHeader("简介")) {
                            TextEditor(text: $summary)
                                .foregroundColor(.white)
                                .font(.subheadline)
                                .padding(8)
                                .background(Color(hex: "333333")!)
                                .cornerRadius(8)
                                .frame(height: 100)
                                .padding(.horizontal, 16)
                        }
                        
                        Section(header: sectionHeader("书籍分组")) {
                            OptionRow(title: "所属分组", value: selectedGroup, options: groups) { newValue in
                                selectedGroup = newValue
                            }
                        }
                        
                        Section(header: sectionHeader("其它")) {
                            NavigationLink(destination: EmptyView()) {
                                optionLink("标签")
                            }
                        }
                        
                        if !parsedChapters.isEmpty {
                            Section(header: sectionHeader("章节预览 (共 \(parsedChapters.count) 章)")) {
                                ForEach(parsedChapters.prefix(10)) { chapter in
                                    ChapterPreviewRow(chapter: chapter)
                                }
                                
                                if parsedChapters.count > 10 {
                                    Text("... 还有 \(parsedChapters.count - 10) 个章节")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
                
                if showImporting {
                    ImportingOverlay()
                }
                
                if showSuccess {
                    SuccessOverlay(message: successMessage) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showSuccess = false
                            dismiss()
                        }
                    }
                }
            }
            .background(Color(hex: "1B5E20")!.opacity(0.95))
            .navigationTitle("修改书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("修改") {
                        completeImport()
                    }
                    .foregroundColor(.white)
                    .disabled(parsedChapters.isEmpty)
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
    
    private var bookCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "333333")!)
                .frame(width: 80, height: 100)
            
            Image(systemName: "book")
                .foregroundColor(.white.opacity(0.5))
                .font(.title)
        }
    }
    
    private func inputField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            TextField("", text: text)
                .foregroundColor(.white)
                .font(.subheadline)
                .padding(8)
                .background(Color(hex: "333333")!)
                .cornerRadius(8)
        }
    }
    
    private func optionLink(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func startParsing() {
        isParsing = true
        parseProgress = 0.0
        parsedChapters = []
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            parseProgress = 0.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            parseProgress = 0.6
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            parseProgress = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            parsedChapters = [
                ParsedChapter(id: "1", title: "扉页", level: 1, status: .success),
                ParsedChapter(id: "2", title: "制作信息", level: 0, status: .success),
                ParsedChapter(id: "3", title: "内容简介", level: 0, status: .success),
                ParsedChapter(id: "4", title: "卷一", level: 1, status: .success),
                ParsedChapter(id: "5", title: "第一章 洪公子", level: 2, status: .success),
                ParsedChapter(id: "6", title: "第二章 想再听弹奏", level: 2, status: .success),
                ParsedChapter(id: "7", title: "第三章 岂能算了", level: 2, status: .success),
                ParsedChapter(id: "8", title: "第四章 黄大人的烦恼", level: 2, status: .success),
                ParsedChapter(id: "9", title: "第五章 君影草", level: 2, status: .success),
                ParsedChapter(id: "10", title: "第六章 另有高见", level: 2, status: .success),
            ]
            totalChapters = 1080
            parseProgress = 1.0
            isParsing = false
        }
    }
    
    private func completeImport() {
        showImporting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showImporting = false
            successMessage = "成功导入书籍：\(bookName)"
            showSuccess = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showSuccess = false
                dismiss()
            }
        }
    }
}

struct OptionRow: View {
    let title: String
    let value: String
    let options: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct ParsedChapter: Identifiable {
    let id: String
    let title: String
    let level: Int
    let status: ParseStatus
    
    enum ParseStatus {
        case success
        case failed
        case warning
    }
}

struct ChapterPreviewRow: View {
    let chapter: ParsedChapter
    
    var body: some View {
        HStack {
            Text(String(repeating: "  ", count: chapter.level) + chapter.title)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: chapter.status == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(chapter.status == .success ? .green : .orange)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ImportingOverlay: View {
    @State private var progress: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("导入中...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "8BC34A")!))
                    .scaleEffect(1.5)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("正在返回阅读位置...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(40)
            .background(Color(hex: "333333")!)
            .cornerRadius(16)
        }
        .onAppear {
            animateProgress()
        }
    }
    
    private func animateProgress() {
        withAnimation(.linear(duration: 2.0)) {
            progress = 1.0
        }
    }
}

struct SuccessOverlay: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "8BC34A")!)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(Color(hex: "333333")!)
            .cornerRadius(16)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

struct EditBookView_Previews: PreviewProvider {
    static var previews: some View {
        EditBookView()
    }
}