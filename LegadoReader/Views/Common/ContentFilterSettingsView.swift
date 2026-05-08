import SwiftUI

struct ContentFilterSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var filterManager = ContentFilterManager.shared
    @State private var searchText = ""
    @State private var showingMenu = false
    @State private var showingAddRule = false
    
    var filteredRules: [ContentFilterManager.FilterRule] {
        if searchText.isEmpty {
            return filterManager.filters
        }
        return filterManager.filters.filter {
            $0.pattern.lowercased().contains(searchText.lowercased()) ||
            $0.name.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                List {
                    ForEach(filteredRules) { rule in
                        HStack {
                            Text(formatRule(rule))
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .swipeActions(edge: .leading) {
                            Button(role: rule.isEnabled ? .destructive : nil) {
                                toggleRule(rule)
                            } label: {
                                Label(rule.isEnabled ? "禁用" : "启用", systemImage: rule.isEnabled ? "xmark.circle" : "checkmark.circle")
                            }
                            .tint(rule.isEnabled ? .red : .green)
                        }
                    }
                    .onDelete(perform: deleteRules)
                }
                .listStyle(.plain)
            }
            .navigationBarTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("内容过滤规则 (共\(filterManager.filters.count)个)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("创建新的过滤规则") {
                            showingAddRule = true
                        }
                        
                        Divider()
                        
                        Button("导出所有") {
                            exportRules()
                        }
                        
                        Button("反转规则可用性") {
                            reverseRuleStatus()
                        }
                        
                        Button("删除所有禁用规则") {
                            removeDisabledRules()
                        }
                        
                        Button("重置规则配置") {
                            filterManager.resetToDefaults()
                        }
                        
                        Divider()
                        
                        Button("帮助") {
                            showHelp()
                        }
                    } label: {
                        Text("菜单")
                            .foregroundColor(.white)
                    }
                }
            }
            .background(Color.red, alignment: .top)
            .sheet(isPresented: $showingAddRule) {
                AddFilterRuleView()
            }
        }
    }
    
    private var searchBar: some View {
        TextField("显示包括关键词的过滤规则", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding()
            .background(Color(.systemBackground))
    }
    
    private func formatRule(_ rule: ContentFilterManager.FilterRule) -> String {
        if rule.type == .replace {
            return "@str:replace(\(rule.pattern),\(rule.replacement))"
        } else if rule.type == .regex {
            return "@str:regex(\(rule.pattern),\(rule.replacement))"
        } else {
            return "@str:pos(\(rule.pattern))"
        }
    }
    
    private func toggleRule(_ rule: ContentFilterManager.FilterRule) {
        if let index = filterManager.filters.firstIndex(where: { $0.id == rule.id }) {
            filterManager.filters[index].isEnabled.toggle()
            filterManager.saveFilters()
        }
    }
    
    private func deleteRules(at offsets: IndexSet) {
        let rulesToDelete = offsets.map { filteredRules[$0] }
        rulesToDelete.forEach { filterManager.removeFilter($0) }
    }
    
    private func exportRules() {
        let json = filterManager.exportRules()
        print("导出规则: \(json)")
    }
    
    private func reverseRuleStatus() {
        filterManager.filters.forEach { $0.isEnabled.toggle() }
        filterManager.saveFilters()
    }
    
    private func removeDisabledRules() {
        filterManager.filters.removeAll { !$0.isEnabled }
        filterManager.saveFilters()
    }
    
    private func showHelp() {
        print("显示帮助")
    }
}

struct AddFilterRuleView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var filterManager = ContentFilterManager.shared
    
    @State private var pattern = ""
    @State private var replacement = ""
    @State private var type = ContentFilterManager.FilterRule.FilterType.keyword
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("匹配内容", text: $pattern)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text("匹配规则")
                }
                
                Section {
                    TextField("替换为", text: $replacement)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text("替换内容")
                } footer: {
                    Text("留空则删除匹配内容")
                }
                
                Section {
                    Picker("规则类型", selection: $type) {
                        Text("关键词过滤").tag(ContentFilterManager.FilterRule.FilterType.keyword)
                        Text("正则替换").tag(ContentFilterManager.FilterRule.FilterType.regex)
                        Text("文本替换").tag(ContentFilterManager.FilterRule.FilterType.replace)
                    }
                }
                
                Section {
                    Button("添加规则") {
                        addRule()
                    }
                    .disabled(pattern.isEmpty)
                }
            }
            .navigationTitle("创建新的过滤规则")
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
    
    private func addRule() {
        let rule = ContentFilterManager.FilterRule(
            id: UUID().uuidString,
            name: pattern,
            pattern: pattern,
            replacement: replacement,
            type: type,
            isEnabled: true,
            category: "custom"
        )
        
        filterManager.addFilter(rule)
        dismiss()
    }
}

struct ContentFilterSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ContentFilterSettingsView()
    }
}
