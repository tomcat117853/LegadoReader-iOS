import SwiftUI
import UIKit

struct BookDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State private var book: Book
    @State private var editingTitle = false
    @State private var editingAuthor = false
    @State private var editingTag = false
    @State private var editingDesc = false
    @State private var showChapterList = false
    
    @State private var tempTitle: String = ""
    @State private var tempAuthor: String = ""
    @State private var tempTag: String = ""
    @State private var tempDesc: String = ""
    
    init(book: Book) {
        self._book = State(initialValue: book)
        self._tempTitle = State(initialValue: book.name)
        self._tempAuthor = State(initialValue: book.author)
        self._tempTag = State(initialValue: book.kind ?? "")
        self._tempDesc = State(initialValue: book.intro ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    
                    infoSection
                    
                    detailSection
                    
                    syncSection
                    
                    fileSection
                    
                    contentSection
                    
                    securitySection
                    
                    actionSection
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showChapterList) {
                ChapterListView(book: book, chapters: [])
            }
        }
    }
    
    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.red.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            
            VStack(alignment: .leading) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 160)
                        
                        if let cover = book.cover, let url = URL(string: cover) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                VStack {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 40))
                                    Text(book.name.prefix(1))
                                        .font(.title)
                                }
                                .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            VStack {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 40))
                                Text(book.name.prefix(1))
                                    .font(.title)
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 4) {
                            Text(book.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Button(action: { editingTitle = true }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        HStack(alignment: .center, spacing: 4) {
                            Text(book.author)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                            Button(action: { editingAuthor = true }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var infoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { editingTag = true }) {
                    HStack(spacing: 4) {
                        Text(book.kind?.isEmpty ?? true ? "无标签" : book.kind!)
                            .font(.system(size: 14))
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(16)
                }
            }
            
            Button(action: { editingDesc = true }) {
                HStack {
                    Text(book.intro?.isEmpty ?? true ? "无简介，点击可修改" : book.intro!)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
        .margin(.top, -20)
        .margin(.horizontal, 16)
    }
    
    private var detailSection: some View {
        VStack(spacing: 0) {
            DetailRow(title: "书籍类型", value: "图文模式", hasArrow: true)
            DetailRow(title: "统计详情", value: "打开", hasArrow: true)
            DetailRow(title: "书籍所属", value: "顶层书架", hasArrow: true)
            DetailRow(title: "听书配置", value: "未指定", hasArrow: true)
            DetailRow(title: "阅读布局关联", value: "未关联", hasArrow: true)
            DetailRow(title: "导出", value: "", hasArrow: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .margin(.top, 12)
        .margin(.horizontal, 16)
    }
    
    private var syncSection: some View {
        VStack(spacing: 0) {
            DetailRow(title: "书籍数据同步配置", value: "上传,下载,删除", hasArrow: true)
            DetailRow(title: "原文件同步配置", value: "上传,下载,删除", hasArrow: true)
            DetailRow(title: "上传状态", value: "成功", hasArrow: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .margin(.top, 12)
        .margin(.horizontal, 16)
    }
    
    private var fileSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("数据来源: pdf")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.top, 12)
            }
            
            DetailRow(title: "原文件", value: "8.05 MB", hasArrow: true)
        }
        .padding(.horizontal, 16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .margin(.top, 12)
        .margin(.horizontal, 16)
    }
    
    private var contentSection: some View {
        VStack(spacing: 0) {
            DetailRow(title: "目录·书签", value: "", hasArrow: true) {
                showChapterList = true
            }
            DetailRow(title: "标题格式化", value: "", hasArrow: true)
            
            Button(action: { reparseBook() }) {
                HStack {
                    Spacer()
                    Text("重新解析")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .margin(.top, 12)
        .margin(.horizontal, 16)
    }
    
    private var securitySection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("隐藏标记为空时，表示一直可见。否则仅在书架搜索框输入与隐藏标记相同的字符时，才会显示！")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            }
            
            DetailRow(title: "隐藏标记", value: "", hasArrow: true)
            DetailRow(title: "书籍密码", value: "", hasArrow: true)
        }
        .padding(.horizontal, 16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .margin(.top, 12)
        .margin(.horizontal, 16)
    }
    
    private var actionSection: some View {
        Button(action: { readBook() }) {
            HStack {
                Spacer()
                Text("阅读")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .margin(.top, 16)
        .margin(.horizontal, 16)
        .margin(.bottom, 32)
    }
    
    private func reparseBook() {
        print("重新解析书籍: \(book.name)")
    }
    
    private func readBook() {
        print("开始阅读: \(book.name)")
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let hasArrow: Bool
    var action: (() -> Void)?
    
    init(title: String, value: String, hasArrow: Bool, action: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.hasArrow = hasArrow
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                if hasArrow {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 14)
        }
        
        Divider()
            .padding(.leading, 16)
    }
}

extension View {
    func margin(_ edge: Edge.Set, _ length: CGFloat) -> some View {
        switch edge {
        case .top:
            return self.padding(.top, length)
        case .bottom:
            return self.padding(.bottom, length)
        case .leading, .horizontal:
            return self.padding(.leading, length)
        case .trailing:
            return self.padding(.trailing, length)
        default:
            return self.padding(length)
        }
    }
}
