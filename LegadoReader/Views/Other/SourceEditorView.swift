import SwiftUI

struct SourceEditorView: View {
    @Binding var source: BookSource
    @Environment(\.dismiss) var dismiss
    @State private var showingRuleEditor = false
    @State private var selectedRuleType: RuleType?
    
    enum RuleType {
        case search
        case detail
        case chapterList
        case content
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("基本信息") {
                    TextField("书源名称", text: $source.name)
                    
                    TextField("书源地址", text: $source.url)
                    
                    Picker("书源类型", selection: $source.type) {
                        ForEach(SourceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    HStack {
                        Text("启用")
                        Spacer()
                        Toggle("", isOn: $source.isEnabled)
                    }
                    
                    HStack {
                        Text("权重")
                        Spacer()
                        TextField("", value: $source.weight, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("规则配置") {
                    Button(action: { selectedRuleType = .search; showingRuleEditor = true }) {
                        HStack {
                            Text("搜索规则")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { selectedRuleType = .detail; showingRuleEditor = true }) {
                        HStack {
                            Text("详情规则")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { selectedRuleType = .chapterList; showingRuleEditor = true }) {
                        HStack {
                            Text("目录规则")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { selectedRuleType = .content; showingRuleEditor = true }) {
                        HStack {
                            Text("正文规则")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("测试规则") {
                    Button("测试搜索") {
                        testSearch()
                    }
                    
                    Button("测试解析") {
                        testParse()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(source.id.isEmpty ? "新建书源" : "编辑书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSource()
                    }
                }
            }
            .sheet(isPresented: $showingRuleEditor) {
                if let type = selectedRuleType {
                    RuleEditorView(ruleType: type, source: $source)
                }
            }
        }
    }
    
    private func saveSource() {
        if source.id.isEmpty {
            source.id = UUID().uuidString
        }
        source.lastUpdateTime = Date()
        
        DatabaseManager.shared.saveBookSource(source)
        dismiss()
    }
    
    private func testSearch() {
        // 测试搜索规则
    }
    
    private func testParse() {
        // 测试解析规则
    }
}

struct RuleEditorView: View {
    let ruleType: SourceEditorView.RuleType
    @Binding var source: BookSource
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                switch ruleType {
                case .search:
                    SearchRuleEditor(searchRule: Binding(
                        get: { source.rule.searchBook ?? SearchRule(url: "", method: "GET", bookList: "", name: "", bookUrl: "") },
                        set: { source.rule.searchBook = $0 }
                    ))
                case .detail:
                    DetailRuleEditor(detailRule: Binding(
                        get: { source.rule.bookDetail ?? DetailRule() },
                        set: { source.rule.bookDetail = $0 }
                    ))
                case .chapterList:
                    ChapterListRuleEditor(chapterListRule: Binding(
                        get: { source.rule.chapterList ?? ChapterListRule(chapterList: "", chapterName: "", chapterUrl: "") },
                        set: { source.rule.chapterList = $0 }
                    ))
                case .content:
                    ContentRuleEditor(contentRule: Binding(
                        get: { source.rule.chapterContent ?? ContentRule(content: "") },
                        set: { source.rule.chapterContent = $0 }
                    ))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(ruleTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var ruleTitle: String {
        switch ruleType {
        case .search: return "搜索规则"
        case .detail: return "详情规则"
        case .chapterList: return "目录规则"
        case .content: return "正文规则"
        }
    }
}

struct SearchRuleEditor: View {
    @Binding var searchRule: SearchRule
    
    var body: some View {
        TextField("搜索 URL", text: $searchRule.url)
            .hintText("如: https://example.com/search?key={{key}}")
        
        Picker("请求方法", selection: $searchRule.method) {
            Text("GET").tag("GET")
            Text("POST").tag("POST")
        }
        
        TextField("请求体", text: Binding(
            get: { searchRule.body ?? "" },
            set: { searchRule.body = $0.isEmpty ? nil : $0 }
        ))
            .hintText("POST 请求时使用")
        
        TextField("书籍列表选择器", text: $searchRule.bookList)
            .hintText("如: .book-list li")
        
        TextField("书名选择器", text: $searchRule.name)
            .hintText("如: h3.title")
        
        TextField("作者选择器", text: Binding(
            get: { searchRule.author ?? "" },
            set: { searchRule.author = $0.isEmpty ? nil : $0 }
        ))
            .hintText("如: .author")
        
        TextField("封面选择器", text: Binding(
            get: { searchRule.cover ?? "" },
            set: { searchRule.cover = $0.isEmpty ? nil : $0 }
        ))
            .hintText("如: img@src")
        
        TextField("简介选择器", text: Binding(
            get: { searchRule.intro ?? "" },
            set: { searchRule.intro = $0.isEmpty ? nil : $0 }
        ))
            .hintText("如: .intro")
        
        TextField("最新章节选择器", text: Binding(
            get: { searchRule.lastChapter ?? "" },
            set: { searchRule.lastChapter = $0.isEmpty ? nil : $0 }
        ))
            .hintText("如: .last-chapter")
        
        TextField("书籍链接选择器", text: $searchRule.bookUrl)
            .hintText("如: a@href")
    }
}

struct DetailRuleEditor: View {
    @Binding var detailRule: DetailRule
    
    var body: some View {
        TextField("书名选择器", text: Binding(
            get: { detailRule.name ?? "" },
            set: { detailRule.name = $0.isEmpty ? nil : $0 }
        ))
        
        TextField("作者选择器", text: Binding(
            get: { detailRule.author ?? "" },
            set: { detailRule.author = $0.isEmpty ? nil : $0 }
        ))
        
        TextField("封面选择器", text: Binding(
            get: { detailRule.cover ?? "" },
            set: { detailRule.cover = $0.isEmpty ? nil : $0 }
        ))
        
        TextField("简介选择器", text: Binding(
            get: { detailRule.intro ?? "" },
            set: { detailRule.intro = $0.isEmpty ? nil : $0 }
        ))
        
        TextField("最新章节选择器", text: Binding(
            get: { detailRule.lastChapter ?? "" },
            set: { detailRule.lastChapter = $0.isEmpty ? nil : $0 }
        ))
        
        TextField("目录链接选择器", text: Binding(
            get: { detailRule.chapterListUrl ?? "" },
            set: { detailRule.chapterListUrl = $0.isEmpty ? nil : $0 }
        ))
    }
}

struct ChapterListRuleEditor: View {
    @Binding var chapterListRule: ChapterListRule
    
    var body: some View {
        TextField("章节列表选择器", text: $chapterListRule.chapterList)
            .hintText("如: .chapter-list li")
        
        TextField("章节名选择器", text: $chapterListRule.chapterName)
            .hintText("如: a")
        
        TextField("章节链接选择器", text: $chapterListRule.chapterUrl)
            .hintText("如: a@href")
        
        TextField("VIP标识选择器", text: Binding(
            get: { chapterListRule.isVip ?? "" },
            set: { chapterListRule.isVip = $0.isEmpty ? nil : $0 }
        ))
        
        TextField("更新时间选择器", text: Binding(
            get: { chapterListRule.updateTime ?? "" },
            set: { chapterListRule.updateTime = $0.isEmpty ? nil : $0 }
        ))
    }
}

struct ContentRuleEditor: View {
    @Binding var contentRule: ContentRule
    
    var body: some View {
        TextField("正文选择器", text: $contentRule.content)
            .hintText("如: .content")
        
        TextField("下一页选择器", text: Binding(
            get: { contentRule.nextPage ?? "" },
            set: { contentRule.nextPage = $0.isEmpty ? nil : $0 }
        ))
            .hintText("如: .next-page@href")
        
        Section("替换规则") {
            if let rules = contentRule.replaceRules, !rules.isEmpty {
                ForEach(rules.indices, id: \.self) { index in
                    HStack {
                        TextField("匹配", text: Binding(
                            get: { rules[index].pattern },
                            set: { contentRule.replaceRules?[index].pattern = $0 }
                        ))
                        
                        Toggle("正则", isOn: Binding(
                            get: { rules[index].isRegex },
                            set: { contentRule.replaceRules?[index].isRegex = $0 }
                        ))
                    }
                    
                    TextField("替换为", text: Binding(
                        get: { rules[index].replacement },
                        set: { contentRule.replaceRules?[index].replacement = $0 }
                    ))
                }
            }
            
            Button("添加替换规则") {
                if contentRule.replaceRules == nil {
                    contentRule.replaceRules = []
                }
                contentRule.replaceRules?.append(ReplaceRule(pattern: "", replacement: "", isRegex: false))
            }
        }
    }
}

extension TextField {
    func hintText(_ text: String) -> some View {
        self
            .foregroundColor(.primary)
            .font(.system(size: 14))
            .padding(.vertical, 8)
            .overlay(
                Text(text)
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                    .opacity(text.isEmpty ? 0 : 0)
            )
    }
}
