import SwiftUI

struct TitleSegmentationSettingsView: View {
    @StateObject private var manager = TitleSegmentationManager.shared
    @State private var showingAddRule = false
    @State private var showingImportExport = false
    @State private var editingRule: TitleSegmentationManager.SegmentationRule?
    @State private var searchText = ""
    
    var filteredRules: [TitleSegmentationManager.SegmentationRule] {
        if searchText.isEmpty {
            return manager.customRules.sorted { $0.priority > $1.priority }
        }
        return manager.customRules.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.pattern.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.priority > $1.priority }
    }
    
    var body: some View {
        List {
            Section {
                Toggle("启用标题分段", isOn: .constant(true))
                    .tint(.blue)
            } footer: {
                Text("开启后会自动应用标题分段规则")
            }
            
            Section("测试分段") {
                TestSegmentationView()
            }
            
            Section {
                ForEach(filteredRules) { rule in
                    RuleRowView(
                        rule: rule,
                        isEnabled: manager.isRuleEnabled(rule.id),
                        onToggle: {
                            manager.toggleRule(rule.id)
                        },
                        onEdit: {
                            editingRule = rule
                        },
                        onDelete: {
                            manager.deleteRule(rule)
                        }
                    )
                }
            } header: {
                HStack {
                    Text("分段规则")
                    Spacer()
                    Button(action: { showingAddRule = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section {
                Button(action: { manager.resetToDefaults() }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("恢复默认规则")
                    }
                }
                
                Button(action: { showingImportExport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导入/导出规则")
                    }
                }
            }
        }
        .navigationTitle("标题分段设置")
        .searchable(text: $searchText, prompt: "搜索规则")
        .sheet(isPresented: $showingAddRule) {
            AddSegmentationRuleView()
        }
        .sheet(item: $editingRule) { rule in
            EditSegmentationRuleView(rule: rule)
        }
        .sheet(isPresented: $showingImportExport) {
            ImportExportRulesView()
        }
    }
}

struct RuleRowView: View {
    let rule: TitleSegmentationManager.SegmentationRule
    let isEnabled: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: rule.ruleType.icon)
                    .foregroundColor(isEnabled ? .blue : .gray)
                
                Text(rule.name)
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(.blue)
            }
            
            Text(rule.pattern)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if !rule.description.isEmpty {
                Text(rule.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("优先级: \(rule.priority)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                
                Text(rule.ruleType.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            Button(action: onToggle) {
                Label(isEnabled ? "禁用" : "启用", systemImage: isEnabled ? "slash.circle" : "checkmark.circle")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

struct TestSegmentationView: View {
    @State private var inputTitle = ""
    @State private var result: TitleSegmentationManager.SegmentationResult?
    @StateObject private var manager = TitleSegmentationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("输入标题测试", text: $inputTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    result = manager.segmentTitle(inputTitle)
                }
            
            if let result = result {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("原始标题:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(result.originalTitle)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("格式化结果:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(result.formattedTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("标题级别:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(result.level.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddSegmentationRuleView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = TitleSegmentationManager.shared
    
    @State private var name = ""
    @State private var pattern = ""
    @State private var replacement = ""
    @State private var priority = 50
    @State private var ruleType: TitleSegmentationManager.SegmentationRule.RuleType = .custom
    @State private var description = ""
    @State private var isEnabled = true
    @State private var testInput = ""
    @State private var testResult = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $name)
                    TextField("规则描述", text: $description)
                    
                    Picker("规则类型", selection: $ruleType) {
                        ForEach(TitleSegmentationManager.SegmentationRule.RuleType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    Stepper("优先级: \(priority)", value: $priority, in: 1...100)
                    
                    Toggle("默认启用", isOn: $isEnabled)
                }
                
                Section("匹配规则") {
                    TextField("正则表达式", text: $pattern)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                    
                    TextField("替换文本（可选）", text: $replacement)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                }
                
                Section("测试") {
                    TextField("测试输入", text: $testInput)
                        .autocapitalization(.none)
                    
                    Button("测试匹配") {
                        testRegex()
                    }
                    
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("正则表达式示例：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• ^第([\\d]+)章 - 匹配「第数字章」")
                        Text("• ^【([^】]+)】 - 匹配【卷名】")
                        Text("• \\s+ - 匹配空白字符")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("添加规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRule()
                    }
                    .disabled(name.isEmpty || pattern.isEmpty)
                }
            }
        }
    }
    
    private func testRegex() {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            testResult = "无效的正则表达式"
            return
        }
        
        let range = NSRange(testInput.startIndex..., in: testInput)
        if let match = regex.firstMatch(in: testInput, options: [], range: range) {
            if let matchRange = Range(match.range, in: testInput) {
                testResult = "匹配成功: \(testInput[matchRange])"
            }
        } else {
            testResult = "未匹配"
        }
    }
    
    private func saveRule() {
        let rule = TitleSegmentationManager.SegmentationRule(
            name: name,
            pattern: pattern,
            replacement: replacement,
            priority: priority,
            isEnabled: isEnabled,
            ruleType: ruleType,
            description: description
        )
        manager.addRule(rule)
        dismiss()
    }
}

struct EditSegmentationRuleView: View {
    @Environment(\.dismiss) var dismiss
    let rule: TitleSegmentationManager.SegmentationRule
    @StateObject private var manager = TitleSegmentationManager.shared
    
    @State private var name: String
    @State private var pattern: String
    @State private var replacement: String
    @State private var priority: Int
    @State private var ruleType: TitleSegmentationManager.SegmentationRule.RuleType
    @State private var description: String
    @State private var isEnabled: Bool
    
    init(rule: TitleSegmentationManager.SegmentationRule) {
        self.rule = rule
        _name = State(initialValue: rule.name)
        _pattern = State(initialValue: rule.pattern)
        _replacement = State(initialValue: rule.replacement)
        _priority = State(initialValue: rule.priority)
        _ruleType = State(initialValue: rule.ruleType)
        _description = State(initialValue: rule.description)
        _isEnabled = State(initialValue: rule.isEnabled)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $name)
                    TextField("规则描述", text: $description)
                    
                    Picker("规则类型", selection: $ruleType) {
                        ForEach(TitleSegmentationManager.SegmentationRule.RuleType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    Stepper("优先级: \(priority)", value: $priority, in: 1...100)
                    
                    Toggle("启用规则", isOn: $isEnabled)
                }
                
                Section("匹配规则") {
                    TextField("正则表达式", text: $pattern)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                    
                    TextField("替换文本（可选）", text: $replacement)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRule()
                    }
                    .disabled(name.isEmpty || pattern.isEmpty)
                }
            }
        }
    }
    
    private func saveRule() {
        var updatedRule = rule
        updatedRule.name = name
        updatedRule.pattern = pattern
        updatedRule.replacement = replacement
        updatedRule.priority = priority
        updatedRule.ruleType = ruleType
        updatedRule.description = description
        updatedRule.isEnabled = isEnabled
        manager.updateRule(updatedRule)
        dismiss()
    }
}

struct ImportExportRulesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = TitleSegmentationManager.shared
    @State private var showingFilePicker = false
    @State private var showingShareSheet = false
    @State private var exportData: Data?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("导入") {
                    Button(action: { showingFilePicker = true }) {
                        Label("从文件导入", systemImage: "doc.badge.plus")
                    }
                    
                    Text("从其他设备导出的规则文件导入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("导出") {
                    Button(action: exportRules) {
                        Label("导出当前规则", systemImage: "square.and.arrow.up")
                    }
                    
                    Text("将当前所有分段规则导出为文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    HStack {
                        Text("当前规则数")
                        Spacer()
                        Text("\(manager.customRules.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("已启用规则")
                        Spacer()
                        Text("\(manager.enabledRules.count)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("统计")
                }
            }
            .navigationTitle("导入/导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = exportData {
                    ShareSheet(items: [data])
                }
            }
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func exportRules() {
        if let data = manager.exportRules() {
            exportData = data
            showingShareSheet = true
        } else {
            alertMessage = "导出失败"
            showingAlert = true
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                if manager.importRules(from: data) {
                    alertMessage = "导入成功"
                } else {
                    alertMessage = "导入失败：无效的文件格式"
                }
            } catch {
                alertMessage = "导入失败：\(error.localizedDescription)"
            }
            showingAlert = true
            
        case .failure(let error):
            alertMessage = "选择文件失败：\(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
