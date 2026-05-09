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
    
    private let groups = ["顶层书架", "我的收藏", "正在阅读", "已读完"]
    private let numberingOptions = ["与原文一致", "自动编号"]
    private let encodingOptions = ["默认", "UTF-8", "GBK", "GB2312"]
    private let bookTypes = ["图文模式", "纯文本模式", "漫画模式"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Section(header: Text("解析配置").font(.headline).foregroundColor(.white).padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)) {
                        OptionRow(title: "标题中的数字", value: titleNumbering, options: numberingOptions) { newValue in
                            titleNumbering = newValue
                        }
                        
                        OptionRow(title: "指定编码", value: encoding, options: encodingOptions) { newValue in
                            encoding = newValue
                        }
                        
                        OptionRow(title: "书籍类型", value: bookType, options: bookTypes) { newValue in
                            bookType = newValue
                        }
                        
                        Button(action: {}) {
                            Text("重新解析")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding(.vertical, 16)
                        }
                    }
                    
                    Section(header: Text("解析结果").font(.headline).foregroundColor(.white).padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)) {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "333333")!)
                                    .frame(width: 80, height: 100)
                                
                                Image(systemName: "book")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.title)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("书名")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    TextField("", text: $bookName)
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                        .padding(8)
                                        .background(Color(hex: "333333")!)
                                        .cornerRadius(8)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("作者")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    TextField("", text: $author)
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                        .padding(8)
                                        .background(Color(hex: "333333")!)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Section(header: Text("简介").font(.headline).foregroundColor(.white).padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)) {
                        TextEditor(text: $summary)
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .padding(8)
                            .background(Color(hex: "333333")!)
                            .cornerRadius(8)
                            .frame(height: 100)
                            .padding(.horizontal, 16)
                    }
                    
                    Section(header: Text("书籍分组").font(.headline).foregroundColor(.white).padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)) {
                        OptionRow(title: "所属分组", value: selectedGroup, options: groups) { newValue in
                            selectedGroup = newValue
                        }
                    }
                    
                    Section(header: Text("其它").font(.headline).foregroundColor(.white).padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)) {
                        NavigationLink(destination: EmptyView()) {
                            HStack {
                                Text("标签")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    Section(header: Text("").font(.headline).foregroundColor(.white).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)) {
                        Text("总章节数: 1080")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                    }
                    
                    Section {
                        ChapterRow(title: "扉页", level: "等级:1")
                        ChapterRow(title: "制作信息", level: "等级:0")
                    }
                    .padding(.bottom, 32)
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
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
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

struct ChapterRow: View {
    let title: String
    let level: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(level)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct EditBookView_Previews: PreviewProvider {
    static var previews: some View {
        EditBookView()
    }
}