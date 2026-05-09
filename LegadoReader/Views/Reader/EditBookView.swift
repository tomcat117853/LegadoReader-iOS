import SwiftUI

struct EditBookView: View {
    @Environment(\.dismiss) var dismiss
    
    let book: Book
    @State private var bookName: String
    @State private var author: String
    @State private var summary: String
    @State private var selectedGroup: String
    @State private var titleNumbering: String
    @State private var encoding: String
    @State private var bookType: String
    @State private var isParsing = false
    @State private var parseProgress = 0.0
    @State private var parsedChapters: [ParsedChapter] = []
    @State private var totalChapters = 0
    @State private var showImporting = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    init(book: Book) {
        self.book = book
        self._bookName = State(initialValue: book.name)
        self._author = State(initialValue: book.author)
        self._summary = State(initialValue: book.summary)
        self._selectedGroup = State(initialValue: book.groupName)
        self._titleNumbering = State(initialValue: book.titleNumbering ?? "与原文一致")
        self._encoding = State(initialValue: book.encoding ?? "默认")
        self._bookType = State(initialValue: book.bookType ?? "图文模式")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        Section(header: sectionHeader("解析配置")) {
                            OptionRow(title: "标题中的数字", value: titleNumbering)
                            OptionRow(title: "指定编码", value: encoding)
                            OptionRow(title: "书籍类型", value: bookType)
                            
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
                            OptionRow(title: "所属分组", value: selectedGroup)
                        }
                        
                        Section(header: sectionHeader("其它")) {
                            NavigationLink(destination: EmptyView()) {
                                optionLink("标签")
                            }
                        }
                        
                        Section(header: sectionHeader("")) {
                            Text("总章节数:\(totalChapters > 0 ? totalChapters : book.chapters.count)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                        }
                        
                        Section {
                            ForEach(parsedChapters.prefix(3)) { chapter in
                                ChapterPreviewRow(chapter: chapter)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
                
                if showImporting {
                    ImportingOverlay()
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
            .overlay(
                Group {
                    if showSuccess {
                        SuccessBanner(message: successMessage)
                    }
                }
            )
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
            
            if let coverData = book.coverData, let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 100)
                    .cornerRadius(8)
            } else {
                Image(systemName: "book")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.title)
            }
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
            parsedChapters = book.chapters.enumerated().compactMap { index, chapter in
                guard index < 3 else { return nil }
                return ParsedChapter(
                    id: chapter.id,
                    title: chapter.title,
                    level: "等级:\(chapter.level)",
                    status: .success
                )
            }
            totalChapters = book.chapters.count
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
    let level: String
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
            Text(chapter.title)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Text(chapter.level)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ImportingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("导入中")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(hex: "333333")!)
            .cornerRadius(16)
        }
        .transition(.opacity)
    }
}

struct SuccessBanner: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            
            Text(message)
                .font(.headline)
                .foregroundColor(Color(hex: "8BC34A")!)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "333333")!)
                .cornerRadius(20)
        }
        .padding(.bottom, 50)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}