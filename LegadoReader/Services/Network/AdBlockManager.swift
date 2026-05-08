import Foundation

class AdBlockManager: ObservableObject {
    static let shared = AdBlockManager()
    
    @Published var globalRules: [AdBlockRule] = []
    @Published var bookRules: [String: [AdBlockRule]] = [:]
    @Published var isEnabled = true
    @Published var showBlockedCount = false
    
    struct AdBlockRule: Identifiable, Codable {
        let id: String
        var pattern: String
        var replacement: String
        var isRegex: Bool
        var isEnabled: Bool
        var ruleType: RuleType
        var description: String?
        
        enum RuleType: String, Codable, CaseIterable {
            case replace = "替换"
            case remove = "移除"
            case custom = "自定义"
        }
    }
    
    private let defaults = UserDefaults.standard
    private let globalRulesKey = "AdBlockManager_globalRules"
    private let enabledKey = "AdBlockManager_enabled"
    
    private init() {
        loadRules()
        loadSettings()
    }
    
    private func loadRules() {
        if let data = defaults.data(forKey: globalRulesKey),
           let rules = try? JSONDecoder().decode([AdBlockRule].self, from: data) {
            globalRules = rules
        } else {
            loadDefaultRules()
        }
    }
    
    private func loadSettings() {
        isEnabled = defaults.bool(forKey: enabledKey)
    }
    
    func saveRules() {
        if let data = try? JSONEncoder().encode(globalRules) {
            defaults.set(data, forKey: globalRulesKey)
        }
        defaults.set(isEnabled, forKey: enabledKey)
    }
    
    func saveSettings() {
        defaults.set(isEnabled, forKey: enabledKey)
    }
    
    private func loadDefaultRules() {
        globalRules = [
            AdBlockRule(id: UUID().uuidString, pattern: #"【.*?广告.*?】"#, replacement: "", isRegex: true, isEnabled: true, ruleType: .replace, description: "移除广告标记"),
            AdBlockRule(id: UUID().uuidString, pattern: #"\[.*?广告.*?\]"#, replacement: "", isRegex: true, isEnabled: true, ruleType: .replace, description: "移除方括号广告"),
            AdBlockRule(id: UUID().uuidString, pattern: #"第\d+章\s*$"#, replacement: "", isRegex: true, isEnabled: true, ruleType: .replace, description: "移除章节重复标题"),
            AdBlockRule(id: UUID().uuidString, pattern: #"\s{2,}"#, replacement: " ", isRegex: true, isEnabled: true, ruleType: .replace, description: "合并多余空格"),
            AdBlockRule(id: UUID().uuidString, pattern: #"本章说.*?\n"#, replacement: "", isRegex: true, isEnabled: false, ruleType: .remove, description: "移除本章说"),
            AdBlockRule(id: UUID().uuidString, pattern: #"最新章节.*?\n"#, replacement: "", isRegex: true, isEnabled: false, ruleType: .remove, description: "移除最新章节提示"),
            AdBlockRule(id: UUID().uuidString, pattern: #"记住网站.*?\.com"#, replacement: "", isRegex: true, isEnabled: true, ruleType: .remove, description: "移除网站推广"),
            AdBlockRule(id: UUID().uuidString, pattern: #"推荐阅读.*?\n"#, replacement: "", isRegex: true, isEnabled: false, ruleType: .remove, description: "移除推荐阅读"),
        ]
        saveRules()
    }
    
    func addRule(_ rule: AdBlockRule) {
        globalRules.insert(rule, at: 0)
        saveRules()
    }
    
    func updateRule(_ rule: AdBlockRule) {
        if let index = globalRules.firstIndex(where: { $0.id == rule.id }) {
            globalRules[index] = rule
            saveRules()
        }
    }
    
    func deleteRule(_ rule: AdBlockRule) {
        globalRules.removeAll { $0.id == rule.id }
        saveRules()
    }
    
    func toggleRule(_ rule: AdBlockRule) {
        if let index = globalRules.firstIndex(where: { $0.id == rule.id }) {
            globalRules[index].isEnabled.toggle()
            saveRules()
        }
    }
    
    func addBookRule(bookId: String, _ rule: AdBlockRule) {
        if bookRules[bookId] == nil {
            bookRules[bookId] = []
        }
        bookRules[bookId]?.insert(rule, at: 0)
    }
    
    func getBookRules(bookId: String) -> [AdBlockRule] {
        return bookRules[bookId] ?? []
    }
    
    func clearBookRules(bookId: String) {
        bookRules[bookId] = nil
    }
    
    func filterContent(_ content: String, bookId: String? = nil) -> String {
        guard isEnabled else { return content }
        
        var result = content
        
        let rules = globalRules.filter { $0.isEnabled }
        let bookSpecificRules = bookId.flatMap { bookRules[$0] }?.filter { $0.isEnabled } ?? []
        let allRules = rules + bookSpecificRules
        
        for rule in allRules {
            do {
                if rule.isRegex {
                    let regex = try NSRegularExpression(pattern: rule.pattern, options: .caseInsensitive)
                    result = regex.stringByReplacingMatches(
                        in: result,
                        options: [],
                        range: NSRange(location: 0, length: result.utf16.count),
                        withTemplate: rule.replacement
                    )
                } else {
                    result = result.replacingOccurrences(of: rule.pattern, with: rule.replacement, options: .caseInsensitive)
                }
            } catch {
                print("AdBlock rule error: \(error)")
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func exportRules() -> String {
        do {
            let data = try JSONEncoder().encode(globalRules)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
    
    func importRules(from json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let rules = try? JSONDecoder().decode([AdBlockRule].self, from: data) else {
            return false
        }
        
        globalRules = rules
        saveRules()
        return true
    }
}

struct AdBlockSettingsView: View {
    @StateObject private var adBlockManager = AdBlockManager.shared
    @State private var showingAddRule = false
    @State private var searchText = ""
    
    var filteredRules: [AdBlockManager.AdBlockRule] {
        if searchText.isEmpty {
            return adBlockManager.globalRules
        }
        return adBlockManager.globalRules.filter {
            $0.pattern.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        List {
            Section {
                Toggle("启用内容过滤", isOn: $adBlockManager.isEnabled)
                    .onChange(of: adBlockManager.isEnabled) { _ in
                        adBlockManager.saveSettings()
                    }
            }
            
            Section("过滤规则 (\(filteredRules.count))") {
                ForEach(filteredRules) { rule in
                    AdBlockRuleRow(rule: rule, adBlockManager: adBlockManager)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                adBlockManager.deleteRule(rule)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            
            Section("快捷操作") {
                Button("添加自定义规则") {
                    showingAddRule = true
                }
                
                Button("导入规则") {
                    // 导入规则
                }
                
                Button("导出规则") {
                    // 导出规则
                }
                
                Button("恢复默认规则") {
                    adBlockManager.loadDefaultRules()
                }
                .foregroundColor(.orange)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("广告过滤")
        .searchable(text: $searchText, prompt: "搜索规则...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddRule = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRule) {
            AdBlockRuleEditView(rule: nil)
        }
    }
}

struct AdBlockRuleRow: View {
    let rule: AdBlockManager.AdBlockRule
    @ObservedObject var adBlockManager: AdBlockManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rule.ruleType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(rule.isEnabled ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(rule.isEnabled ? .blue : .gray)
                    .cornerRadius(4)
                
                if rule.isRegex {
                    Text("正则")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in adBlockManager.toggleRule(rule) }
                ))
            }
            
            Text(rule.pattern)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2)
            
            if let description = rule.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AdBlockRuleEditView: View {
    let rule: AdBlockManager.AdBlockRule?
    @StateObject private var adBlockManager = AdBlockManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var pattern = ""
    @State private var replacement = ""
    @State private var isRegex = true
    @State private var ruleType: AdBlockManager.AdBlockRule.RuleType = .replace
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("规则配置") {
                    Picker("规则类型", selection: $ruleType) {
                        ForEach(AdBlockManager.AdBlockRule.RuleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Toggle("使用正则表达式", isOn: $isRegex)
                    
                    TextField("匹配模式", text: $pattern)
                        .font(.system(.body, design: .monospaced))
                }
                
                Section("替换内容") {
                    if ruleType == .replace {
                        TextField("替换为", text: $replacement)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("将匹配内容完全移除")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("规则说明") {
                    TextField("规则描述（可选）", text: $description)
                }
                
                Section("测试") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("测试文本:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("输入测试内容", text: .constant("这是测试【广告内容】文本"))
                            .font(.caption)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Button("测试规则") {
                            // 测试规则
                        }
                    }
                }
            }
            .navigationTitle(rule == nil ? "添加规则" : "编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRule()
                        dismiss()
                    }
                    .disabled(pattern.isEmpty)
                }
            }
            .onAppear {
                if let rule = rule {
                    pattern = rule.pattern
                    replacement = rule.replacement
                    isRegex = rule.isRegex
                    ruleType = rule.ruleType
                    description = rule.description ?? ""
                }
            }
        }
    }
    
    private func saveRule() {
        let newRule = AdBlockManager.AdBlockRule(
            id: rule?.id ?? UUID().uuidString,
            pattern: pattern,
            replacement: replacement,
            isRegex: isRegex,
            isEnabled: true,
            ruleType: ruleType,
            description: description.isEmpty ? nil : description
        )
        
        if rule != nil {
            adBlockManager.updateRule(newRule)
        } else {
            adBlockManager.addRule(newRule)
        }
    }
}
