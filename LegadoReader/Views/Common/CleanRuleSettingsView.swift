import SwiftUI

struct CleanRuleSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var ruleManager = CleanRuleManager.shared
    @State private var showingAddRule = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("规则类型", selection: $selectedTab) {
                    Text("全局规则").tag(0)
                    Text("书籍规则").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    globalRulesList
                } else {
                    bookRulesList
                }
            }
            .navigationTitle("替换规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        showingAddRule = true
                    }
                }
            }
            .sheet(isPresented: $showingAddRule) {
                AddCleanRuleView(isGlobal: selectedTab == 0)
            }
        }
    }
    
    private var globalRulesList: some View {
        List {
            Section {
                ForEach(Array(ruleManager.globalRules.enumerated()), id: \.offset) { index, rule in
                    CleanRuleRow(rule: rule)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                ruleManager.removeGlobalRule(at: index)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                ruleManager.updateGlobalRule(at: index, with: ReplaceRule(
                                    pattern: rule.pattern,
                                    replacement: rule.replacement,
                                    isRegex: rule.isRegex,
                                    isEnabled: !rule.isEnabled
                                ))
                            } label: {
                                Label(rule.isEnabled ? "禁用" : "启用", systemImage: rule.isEnabled ? "xmark.circle" : "checkmark.circle")
                            }
                            .tint(rule.isEnabled ? .orange : .green)
                        }
                }
            } header: {
                Text("全局替换规则")
            } footer: {
                Text("全局规则将应用于所有书籍的正文内容")
            }
            
            Section {
                Button("重置为默认规则") {
                    ruleManager.globalRules = [
                        ReplaceRule(pattern: "\\s*[第章节]\\s*[0-9零一二三四五六七八九十百千万]+\\s*[章节回卷集篇部].*", replacement: "", isRegex: true),
                        ReplaceRule(pattern: "\\(本章完\\)", replacement: "", isRegex: true),
                        ReplaceRule(pattern: "\\(未完待续\\)", replacement: "", isRegex: true),
                        ReplaceRule(pattern: "请记住本书首发域名.*", replacement: "", isRegex: true),
                        ReplaceRule(pattern: "最新网址.*", replacement: "", isRegex: true),
                        ReplaceRule(pattern: "笔趣阁", replacement: "", isRegex: false),
                        ReplaceRule(pattern: "顶点小说", replacement: "", isRegex: false),
                        ReplaceRule(pattern: "\\s+", replacement: " ", isRegex: true),
                        ReplaceRule(pattern: "^\\s+", replacement: "", isRegex: true),
                        ReplaceRule(pattern: "\\s+$", replacement: "", isRegex: true)
                    ]
                }
                .foregroundColor(.red)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var bookRulesList: some View {
        List {
            if ruleManager.bookRules.isEmpty {
                Section {
                    Text("暂无书籍专属规则")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                }
            } else {
                ForEach(Array(ruleManager.bookRules.keys.sorted()), id: \.self) { bookId in
                    Section(header: Text(bookId)) {
                        if let rules = ruleManager.bookRules[bookId] {
                            ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                                CleanRuleRow(rule: rule)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            ruleManager.removeBookRule(bookId: bookId, at: index)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct CleanRuleRow: View {
    let rule: ReplaceRule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if rule.isRegex {
                    Text("正则")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                Text(rule.isEnabled ? "已启用" : "已禁用")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(rule.isEnabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(rule.isEnabled ? .green : .gray)
                    .cornerRadius(4)
            }
            
            Text("匹配: \(rule.pattern)")
                .font(.system(.caption))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if !rule.replacement.isEmpty {
                Text("替换: \(rule.replacement)")
                    .font(.system(.caption))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCleanRuleView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var ruleManager = CleanRuleManager.shared
    
    let isGlobal: Bool
    var bookId: String?
    
    @State private var pattern = ""
    @State private var replacement = ""
    @State private var isRegex = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("使用正则表达式", isOn: $isRegex)
                } footer: {
                    Text(isRegex ? "将 pattern 作为正则表达式匹配" : "将 pattern 作为普通字符串匹配")
                }
                
                Section {
                    TextField("匹配内容", text: $pattern)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text("匹配规则")
                } footer: {
                    Text(isRegex ? "支持正则表达式，如 .* 表示任意字符" : "输入要替换的原始文本")
                }
                
                Section {
                    TextField("替换为", text: $replacement)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text("替换内容")
                } footer: {
                    Text("留空则删除匹配的内容")
                }
                
                Section {
                    Button("添加规则") {
                        addRule()
                    }
                    .disabled(pattern.isEmpty)
                }
                
                if isRegex {
                    Section {
                        Text("常用正则表达式")
                            .font(.headline)
                    } header: {
                        Text("快速插入")
                    }
                    
                    Section {
                        regexQuickInsert
                    }
                }
            }
            .navigationTitle("添加替换规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var regexQuickInsert: some View {
        Group {
            Button("段首空格") {
                pattern = "^\\s+"
                replacement = ""
                isRegex = true
            }
            
            Button("段尾空格") {
                pattern = "\\s+$"
                replacement = ""
                isRegex = true
            }
            
            Button("多余空格") {
                pattern = "\\s+"
                replacement = " "
                isRegex = true
            }
            
            Button("空行") {
                pattern = "\\n\\s*\\n"
                replacement = "\n"
                isRegex = true
            }
            
            Button("章节标题行") {
                pattern = "第[0-9零一二三四五六七八九十百千]+章.*"
                replacement = ""
                isRegex = true
            }
        }
    }
    
    private func addRule() {
        let rule = ReplaceRule(
            pattern: pattern,
            replacement: replacement,
            isRegex: isRegex,
            isEnabled: true
        )
        
        if isGlobal {
            ruleManager.addGlobalRule(rule)
        } else if let bookId = bookId {
            ruleManager.addBookRule(bookId: bookId, rule: rule)
        }
        
        dismiss()
    }
}

struct CleanRuleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CleanRuleSettingsView()
    }
}
