import SwiftUI

struct ContentFilterSettingsView: View {
    @StateObject private var filterManager = ContentFilterManager.shared
    @State private var showingAddFilter = false
    @State private var selectedCategory: String?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("内容过滤")
                        Spacer()
                        Toggle("", isOn: $filterManager.isEnabled)
                    }
                } header: {
                    Text("过滤开关")
                } footer: {
                    Text("开启后将自动过滤书籍内容中的广告、水印和低俗内容")
                }
                
                Section {
                    ForEach(ContentFilterManager.FilterRule.Category.allCases, id: \.id) { category in
                        NavigationLink(destination: FilterCategoryView(category: category)) {
                            HStack {
                                Image(systemName: getCategoryIcon(category))
                                    .foregroundColor(getCategoryColor(category))
                                Text(category.displayName)
                                Spacer()
                                Text("\(getCategoryFilterCount(category))")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                } header: {
                    Text("过滤分类")
                }
                
                Section {
                    Button("重置为默认规则") {
                        filterManager.resetToDefaults()
                    }
                    .foregroundColor(.red)
                    
                    Button("添加自定义规则") {
                        showingAddFilter = true
                    }
                    .foregroundColor(.blue)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("过滤统计")
                            .font(.headline)
                        
                        HStack {
                            Text("总规则数")
                            Spacer()
                            Text("\(filterManager.filters.count)")
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("启用规则")
                            Spacer()
                            Text("\(filterManager.getEnabledFilters().count)")
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("禁用规则")
                            Spacer()
                            Text("\(filterManager.getDisabledFilters().count)")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                } header: {
                    Text("统计信息")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("内容过滤")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddFilter) {
                AddFilterView()
            }
        }
    }
    
    private func getCategoryIcon(_ category: ContentFilterManager.FilterRule.Category) -> String {
        switch category {
        case .ads: return "xmark.circle"
        case .vulgar: return "eye.slash"
        case .watermark: return "strikethrough"
        case .custom: return "plus.circle"
        }
    }
    
    private func getCategoryColor(_ category: ContentFilterManager.FilterRule.Category) -> Color {
        switch category {
        case .ads: return .red
        case .vulgar: return .purple
        case .watermark: return .orange
        case .custom: return .blue
        }
    }
    
    private func getCategoryFilterCount(_ category: ContentFilterManager.FilterRule.Category) -> Int {
        return filterManager.getFiltersByCategory(category.rawValue).count
    }
}

struct FilterCategoryView: View {
    let category: ContentFilterManager.FilterRule.Category
    @StateObject private var filterManager = ContentFilterManager.shared
    
    var categoryFilters: [ContentFilterManager.FilterRule] {
        filterManager.getFiltersByCategory(category.rawValue)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        filterManager.toggleCategory(category.rawValue)
                    }) {
                        HStack {
                            Text(category.displayName)
                            Spacer()
                            Text(categoryFilters.allSatisfy { $0.isEnabled } ? "全部启用" : "部分启用")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section {
                    ForEach(categoryFilters) { filter in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(filter.name)
                                    if filter.type == .regex {
                                        Text("正则")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                }
                                Text(filter.pattern)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { filter.isEnabled },
                                set: { enabled in
                                    if let index = filterManager.filters.firstIndex(where: { $0.id == filter.id }) {
                                        filterManager.filters[index].isEnabled = enabled
                                        filterManager.saveFilters()
                                    }
                                }
                            ))
                        }
                    }
                    .onDelete(perform: deleteFilters)
                } header: {
                    Text("\(category.displayName)规则 (\(categoryFilters.count))")
                }
                
                if category == .custom {
                    Section {
                        Button("添加自定义规则") {
                            
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func deleteFilters(at offsets: IndexSet) {
        let filtersToDelete = offsets.map { categoryFilters[$0] }
        filtersToDelete.forEach { filterManager.removeFilter($0) }
    }
}

struct AddFilterView: View {
    @StateObject private var filterManager = ContentFilterManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var pattern = ""
    @State private var replacement = ""
    @State private var type = ContentFilterManager.FilterRule.FilterType.keyword
    @State private var category = ContentFilterManager.FilterRule.Category.custom
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("规则名称", text: $name)
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    Picker("过滤类型", selection: $type) {
                        ForEach(ContentFilterManager.FilterRule.FilterType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                
                Section {
                    Picker("分类", selection: $category) {
                        ForEach(ContentFilterManager.FilterRule.Category.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }
                
                Section {
                    TextField("匹配内容", text: $pattern)
                    if type == .regex {
                        Text("使用正则表达式语法")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("匹配规则")
                }
                
                Section {
                    TextField("替换为", text: $replacement)
                    Text("留空则删除匹配内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("替换内容")
                }
                
                Section {
                    Button("保存规则") {
                        saveFilter()
                    }
                    .foregroundColor(.blue)
                    .disabled(name.isEmpty || pattern.isEmpty)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("添加过滤规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveFilter() {
        let filter = ContentFilterManager.FilterRule(
            id: UUID().uuidString,
            name: name,
            pattern: pattern,
            replacement: replacement,
            type: type,
            isEnabled: true,
            category: category.rawValue
        )
        
        filterManager.addFilter(filter)
        dismiss()
    }
}

struct ContentFilterSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ContentFilterSettingsView()
    }
}
