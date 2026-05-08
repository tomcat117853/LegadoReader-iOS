import SwiftUI

struct SourceEditorView: View {
    @State private var source: BookSource
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sourceStore: SourceStore
    @State private var showingRuleEditor = false
    @State private var selectedRuleType: RuleType?
    @State private var showingTestResult = false
    @State private var testResult = ""
    @State private var isTesting = false
    
    enum RuleType: String, CaseIterable {
        case search = "搜索规则"
        case detail = "详情规则"
        case chapterList = "目录规则"
        case content = "正文规则"
        
        var icon: String {
            switch self {
            case .search: return "magnifyingglass"
            case .detail: return "info.circle"
            case .chapterList: return "list.bullet"
            case .content: return "doc.text"
            }
        }
    }
    
    init(source: BookSource? = nil) {
        _source = State(initialValue: source ?? BookSource())
    }
    
    var body: some View {
        NavigationView {
            List {
                sourceInfoSection
                ruleConfigSection
                testSection
                moreOptionsSection
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
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingRuleEditor) {
                if let type = selectedRuleType {
                    RuleEditorView(ruleType: type, source: $source)
                }
            }
            .sheet(isPresented: $showingTestResult) {
                TestResultView(result: testResult)
            }
        }
    }
    
    private var sourceInfoSection: some View {
        Section {
            TextField("书源名称", text: $source.name)
                .textContentType(.name)
            
            TextField("书源地址 URL", text: $source.url)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
            
            Picker("书源类型", selection: $source.type) {
                ForEach(SourceType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                }
            }
        } header: {
            Text("基本信息")
        } footer: {
            Text("书源地址应该是能获取到书籍列表的页面")
        }
    }
    
    private var ruleConfigSection: some View {
        Section {
            ForEach(RuleType.allCases, id: \.self) { type in
                Button(action: {
                    selectedRuleType = type
                    showingRuleEditor = true
                }) {
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.rawValue)
                                .foregroundColor(.primary)
                            
                            Text(ruleStatusText(for: type))
                                .font(.caption)
                                .foregroundColor(ruleStatusColor(for: type))
                        }
                        
                        Spacer()
                        
                        if isRuleConfigured(type) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("规则配置")
        } footer: {
            Text("配置书源的解析规则，决定如何获取书籍信息")
        }
    }
    
    private var testSection: some View {
        Section {
            Button(action: testSource) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .padding(.trailing, 8)
                    } else {
                        Image(systemName: "play.fill")
                            .foregroundColor(.blue)
                    }
                    Text("测试书源")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            .disabled(source.url.isEmpty || isTesting)
        } header: {
            Text("测试")
        } footer: {
            Text("测试书源是否能正常访问并获取书籍信息")
        }
    }
    
    private var moreOptionsSection: some View {
        Section {
            Toggle("启用书源", isOn: $source.isEnabled)
            
            HStack {
                Text("权重")
                Spacer()
                Stepper("\(source.weight)", value: $source.weight, in: 0...100)
            }
            
            if !source.id.isEmpty {
                HStack {
                    Text("最后更新")
                    Spacer()
                    Text(source.lastUpdateTime.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("更多选项")
        }
    }
    
    private func isRuleConfigured(_ type: RuleType) -> Bool {
        switch type {
        case .search: return source.rule.searchBook != nil
        case .detail: return source.rule.bookDetail != nil
        case .chapterList: return source.rule.chapterList != nil
        case .content: return source.rule.chapterContent != nil
        }
    }
    
    private func ruleStatusText(for type: RuleType) -> String {
        isRuleConfigured(type) ? "已配置" : "未配置"
    }
    
    private func ruleStatusColor(for type: RuleType) -> Color {
        isRuleConfigured(type) ? .green : .orange
    }
    
    private func saveSource() {
        if source.id.isEmpty {
            source.id = UUID().uuidString
        }
        source.lastUpdateTime = Date()
        
        sourceStore.addSource(source)
        dismiss()
    }
    
    private func testSource() {
        isTesting = true
        testResult = ""
        
        Task {
            do {
                let result = try await testSourceConnection()
                await MainActor.run {
                    testResult = result
                    isTesting = false
                    showingTestResult = true
                }
            } catch {
                await MainActor.run {
                    testResult = "测试失败: \(error.localizedDescription)"
                    isTesting = false
                    showingTestResult = true
                }
            }
        }
    }
    
    private func testSourceConnection() async throws -> String {
        guard let url = URL(string: source.url) else {
            throw NSError(domain: "SourceEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SourceEditor", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }
        
        var result = "状态码: \(httpResponse.statusCode)\n"
        result += "数据大小: \(data.count) 字节\n"
        
        if let html = String(data: data, encoding: .utf8) {
            result += "内容预览:\n\(String(html.prefix(500)))"
        }
        
        return result
    }
}

struct RuleEditorView: View {
    let ruleType: SourceEditorView.RuleType
    @Binding var source: BookSource
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                switch ruleType {
                case .search:
                    SearchRuleEditor(searchRule: searchRuleBinding)
                case .detail:
                    DetailRuleEditor(detailRule: detailRuleBinding)
                case .chapterList:
                    ChapterListRuleEditor(chapterListRule: chapterListRuleBinding)
                case .content:
                    ContentRuleEditor(contentRule: contentRuleBinding)
                }
            }
            .navigationTitle(ruleType.rawValue)
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
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var searchRuleBinding: Binding<SearchRule> {
        Binding(
            get: { source.rule.searchBook ?? SearchRule(url: "", method: "GET", bookList: "", name: "", bookUrl: "") },
            set: { source.rule.searchBook = $0 }
        )
    }
    
    private var detailRuleBinding: Binding<DetailRule> {
        Binding(
            get: { source.rule.bookDetail ?? DetailRule() },
            set: { source.rule.bookDetail = $0 }
        )
    }
    
    private var chapterListRuleBinding: Binding<ChapterListRule> {
        Binding(
            get: { source.rule.chapterList ?? ChapterListRule(chapterList: "", chapterName: "", chapterUrl: "") },
            set: { source.rule.chapterList = $0 }
        )
    }
    
    private var contentRuleBinding: Binding<ContentRule> {
        Binding(
            get: { source.rule.chapterContent ?? ContentRule(content: "") },
            set: { source.rule.chapterContent = $0 }
        )
    }
}

struct SearchRuleEditor: View {
    @Binding var searchRule: SearchRule
    
    var body: some View {
        Section {
            TextField("搜索 URL", text: $searchRule.url)
                .keyboardType(.URL)
                .autocapitalization(.none)
        } header: {
            Text("请求配置")
        } footer: {
            Text("使用 {{key}} 作为搜索关键词占位符\n如: https://example.com/search?q={{key}}")
        }
        
        Section {
            Picker("请求方法", selection: $searchRule.method) {
                Text("GET").tag("GET")
                Text("POST").tag("POST")
            }
            .pickerStyle(.segmented)
            
            if searchRule.method == "POST" {
                TextField("POST 请求体", text: Binding(
                    get: { searchRule.body ?? "" },
                    set: { searchRule.body = $0.isEmpty ? nil : $0 }
                ))
            }
        } header: {
            Text("请求方式")
        }
        
        Section {
            RuleTextField(title: "书籍列表选择器", text: $searchRule.bookList, placeholder: "如: .book-list li")
            RuleTextField(title: "书名选择器", text: $searchRule.name, placeholder: "如: h3.title")
            RuleTextField(title: "作者选择器", text: Binding(
                get: { searchRule.author ?? "" },
                set: { searchRule.author = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .author")
            RuleTextField(title: "封面选择器", text: Binding(
                get: { searchRule.cover ?? "" },
                set: { searchRule.cover = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: img@src")
            RuleTextField(title: "简介选择器", text: Binding(
                get: { searchRule.intro ?? "" },
                set: { searchRule.intro = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .intro")
            RuleTextField(title: "最新章节选择器", text: Binding(
                get: { searchRule.lastChapter ?? "" },
                set: { searchRule.lastChapter = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .last-chapter")
            RuleTextField(title: "书籍链接选择器", text: $searchRule.bookUrl, placeholder: "如: a@href")
        } header: {
            Text("列表项选择器 (CSS/ XPath)")
        } footer: {
            Text("选择器格式: CSS选择器 或 XPath (以//开头)")
        }
    }
}

struct DetailRuleEditor: View {
    @Binding var detailRule: DetailRule
    
    var body: some View {
        Section {
            RuleTextField(title: "书名选择器", text: Binding(
                get: { detailRule.name ?? "" },
                set: { detailRule.name = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: h1.title")
            RuleTextField(title: "作者选择器", text: Binding(
                get: { detailRule.author ?? "" },
                set: { detailRule.author = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .author")
            RuleTextField(title: "封面选择器", text: Binding(
                get: { detailRule.cover ?? "" },
                set: { detailRule.cover = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: img.cover@src")
            RuleTextField(title: "简介选择器", text: Binding(
                get: { detailRule.intro ?? "" },
                set: { detailRule.intro = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .intro")
            RuleTextField(title: "最新章节选择器", text: Binding(
                get: { detailRule.lastChapter ?? "" },
                set: { detailRule.lastChapter = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .last-chapter")
            RuleTextField(title: "目录链接选择器", text: Binding(
                get: { detailRule.chapterListUrl ?? "" },
                set: { detailRule.chapterListUrl = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .chapter-link@href")
        } header: {
            Text("书籍详情选择器")
        }
    }
}

struct ChapterListRuleEditor: View {
    @Binding var chapterListRule: ChapterListRule
    
    var body: some View {
        Section {
            RuleTextField(title: "章节列表选择器", text: $chapterListRule.chapterList, placeholder: "如: .chapter-list li")
            RuleTextField(title: "章节名选择器", text: $chapterListRule.chapterName, placeholder: "如: a")
            RuleTextField(title: "章节链接选择器", text: $chapterListRule.chapterUrl, placeholder: "如: a@href")
        } header: {
            Text("目录列表选择器")
        }
        
        Section {
            RuleTextField(title: "VIP 标识选择器", text: Binding(
                get: { chapterListRule.isVip ?? "" },
                set: { chapterListRule.isVip = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .vip-icon")
            RuleTextField(title: "更新时间选择器", text: Binding(
                get: { chapterListRule.updateTime ?? "" },
                set: { chapterListRule.updateTime = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .update-time")
            RuleTextField(title: "章节排序选择器", text: Binding(
                get: { chapterListRule.sortOrder ?? "" },
                set: { chapterListRule.sortOrder = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: @data-order")
        } header: {
            Text("附加信息选择器")
        }
    }
}

struct ContentRuleEditor: View {
    @Binding var contentRule: ContentRule
    
    var body: some View {
        Section {
            RuleTextField(title: "正文选择器", text: $contentRule.content, placeholder: "如: .content")
            RuleTextField(title: "下一页选择器", text: Binding(
                get: { contentRule.nextPage ?? "" },
                set: { contentRule.nextPage = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .next-page@href")
        } header: {
            Text("正文配置")
        } footer: {
            Text("如果章节内容分多页，设置下一页链接选择器")
        }
        
        Section {
            RuleTextField(title: "标题选择器", text: Binding(
                get: { contentRule.title ?? "" },
                set: { contentRule.title = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: h1.chapter-title")
            RuleTextField(title: "卷名选择器", text: Binding(
                get: { contentRule.volume ?? "" },
                set: { contentRule.volume = $0.isEmpty ? nil : $0 }
            ), placeholder: "如: .volume-name")
        } header: {
            Text("章节标题配置")
        }
        
        Section {
            ReplaceRulesEditor(replaceRules: Binding(
                get: { contentRule.replaceRules ?? [] },
                set: { contentRule.replaceRules = $0 }
            ))
        } header: {
            Text("内容处理")
        } footer: {
            Text("使用正则替换内容，如去除广告、清理格式等")
        }
    }
}

struct RuleTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
}

struct ReplaceRulesEditor: View {
    @Binding var replaceRules: [ReplaceRule]
    @State private var showingAddRule = false
    
    var body: some View {
        ForEach(replaceRules.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("正则", isOn: $replaceRules[index].isRegex)
                    Spacer()
                    Button(action: { replaceRules.remove(at: index) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                TextField("匹配规则", text: $replaceRules[index].pattern)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                
                TextField("替换为", text: $replaceRules[index].replacement)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.vertical, 4)
        }
        
        Button(action: { replaceRules.append(ReplaceRule(pattern: "", replacement: "", isRegex: false)) }) {
            Label("添加替换规则", systemImage: "plus.circle")
        }
    }
}

struct TestResultView: View {
    let result: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(result)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("测试结果")
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
