import SwiftUI

struct NoteTemplateListView: View {
    @StateObject private var templateManager = NoteTemplateManager.shared
    @State private var showingAddTemplate = false
    @State private var selectedCategory: NoteTemplateManager.NoteTemplate.TemplateCategory?
    @State private var searchText = ""
    @State private var sortOption: NoteTemplateManager.SortOption = .recentlyUsed
    
    var filteredTemplates: [NoteTemplateManager.NoteTemplate] {
        var templates = templateManager.templates
        
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            templates = templates.filter { template in
                template.name.contains(searchText) ||
                template.content.contains(searchText)
            }
        }
        
        return templateManager.getTemplates(sortedBy: sortOption).filter { template in
            if let category = selectedCategory {
                return template.category == category
            }
            if !searchText.isEmpty {
                return template.name.contains(searchText) || template.content.contains(searchText)
            }
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryChip(
                            title: "全部",
                            icon: "📋",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        ForEach(NoteTemplateManager.NoteTemplate.TemplateCategory.allCases, id: \.id) { category in
                            CategoryChip(
                                title: category.displayName,
                                icon: category.icon,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGray6))
                
                List {
                    if !templateManager.recentTemplates.isEmpty && selectedCategory == nil && searchText.isEmpty {
                        Section {
                            ForEach(templateManager.recentTemplates.prefix(3)) { template in
                                TemplateRowView(template: template)
                            }
                        } header: {
                            HStack {
                                Text("最近使用")
                                Spacer()
                            }
                        }
                    }
                    
                    Section {
                        ForEach(filteredTemplates) { template in
                            TemplateRowView(template: template)
                                .swipeActions(edge: .trailing) {
                                    if !template.isDefault {
                                        Button(role: .destructive) {
                                            templateManager.removeTemplate(template)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    
                                    Button {
                                        templateManager.duplicateTemplate(template)
                                    } label: {
                                        Label("复制", systemImage: "doc.on.doc")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .leading) {
                                    NavigationLink(destination: EditTemplateView(template: template)) {
                                        Button {
                                        } label: {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text("所有模板 (\(filteredTemplates.count))")
                            Spacer()
                            Menu {
                                ForEach(NoteTemplateManager.SortOption.allCases, id: \.self) { option in
                                    Button(action: { sortOption = option }) {
                                        HStack {
                                            Text(option.rawValue)
                                            if sortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("排序")
                                        .font(.caption)
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("笔记模板")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索模板")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTemplate = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTemplate) {
                EditTemplateView(template: nil)
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .shadow(radius: isSelected ? 2 : 0)
        }
    }
}

struct TemplateRowView: View {
    let template: NoteTemplateManager.NoteTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.icon)
                    .font(.title2)
                
                Text(template.name)
                    .font(.headline)
                
                Spacer()
                
                if template.isDefault {
                    Text("默认")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                Circle()
                    .fill(Color(hex: template.color.hexColor) ?? .blue)
                    .frame(width: 12, height: 12)
            }
            
            Text(template.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(template.category.icon)
                    .font(.caption)
                Text(template.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(template.usageCount) 次使用")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditTemplateView: View {
    let template: NoteTemplateManager.NoteTemplate?
    @StateObject private var templateManager = NoteTemplateManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var content = ""
    @State private var category: NoteTemplateManager.NoteTemplate.TemplateCategory = .custom
    @State private var color: NoteTemplateManager.NoteTemplate.TemplateColor = .blue
    @State private var icon = "📝"
    @State private var showingIconPicker = false
    @State private var showingPreview = false
    
    let availableIcons = ["📝", "⭐", "💭", "🤔", "📖", "💡", "❓", "📚", "👤", "✍️", "💗", "📌", "🎯", "💎", "🌟", "📋"]
    
    var isEditing: Bool {
        template != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    HStack {
                        Button(action: { showingIconPicker = true }) {
                            Text(icon)
                                .font(.system(size: 40))
                                .frame(width: 60, height: 60)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("模板名称", text: $name)
                                .font(.headline)
                            
                            HStack {
                                Text("分类：")
                                    .foregroundColor(.secondary)
                                Picker("", selection: $category) {
                                    ForEach(NoteTemplateManager.NoteTemplate.TemplateCategory.allCases, id: \.id) { cat in
                                        Text("\(cat.icon) \(cat.displayName)").tag(cat)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                }
                
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                } header: {
                    Text("模板内容")
                } footer: {
                    Text("可用变量：{{selected_text}} - 选中文本, {{book_title}} - 书名, {{chapter_title}} - 章节名, {{date}} - 日期")
                }
                
                Section("颜色") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 16) {
                        ForEach(NoteTemplateManager.NoteTemplate.TemplateColor.allCases, id: \.self) { colorOption in
                            Button(action: { color = colorOption }) {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: colorOption.hexColor) ?? .blue)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(color == colorOption ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                    
                                    Text(colorOption.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("预览") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(icon)
                                .font(.title2)
                            Text(name.isEmpty ? "模板名称" : name)
                                .font(.headline)
                        }
                        
                        Text(previewContent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                if isEditing, let template = template, !template.isDefault {
                    Section {
                        Button("删除模板") {
                            templateManager.removeTemplate(template)
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑模板" : "新建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTemplate()
                    }
                    .disabled(name.isEmpty || content.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $icon)
            }
            .onAppear {
                if let template = template {
                    name = template.name
                    content = template.content
                    category = template.category
                    color = template.color
                    icon = template.icon
                }
            }
        }
    }
    
    private var previewContent: String {
        templateManager.applyTemplate(
            NoteTemplateManager.NoteTemplate(
                id: UUID().uuidString,
                name: name,
                content: content,
                category: category,
                color: color,
                icon: icon,
                isDefault: false,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            selectedText: "示例选中文本",
            bookTitle: "示例书名",
            chapterTitle: "示例章节"
        )
    }
    
    private func saveTemplate() {
        if let existingTemplate = template {
            var updated = existingTemplate
            updated = NoteTemplateManager.NoteTemplate(
                id: existingTemplate.id,
                name: name,
                content: content,
                category: category,
                color: color,
                icon: icon,
                isDefault: existingTemplate.isDefault,
                usageCount: existingTemplate.usageCount,
                createdTime: existingTemplate.createdTime,
                lastUsedTime: Date()
            )
            templateManager.updateTemplate(updated)
        } else {
            let newTemplate = NoteTemplateManager.NoteTemplate(
                id: UUID().uuidString,
                name: name,
                content: content,
                category: category,
                color: color,
                icon: icon,
                isDefault: false,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            )
            templateManager.addTemplate(newTemplate)
        }
        dismiss()
    }
}

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) var dismiss
    
    let icons = ["📝", "⭐", "💭", "🤔", "📖", "💡", "❓", "📚", "👤", "✍️", "💗", "📌", "🎯", "💎", "🌟", "📋", "📝", "📄", "📃", "📜", "📰", "🗒️", "🗓️", "📆", "✅", "❌", "⚠️", "🔥", "💫", "✨", "🌈", "⚡", "🌊", "⛰️", "🌸", "🌺", "🍀", "🌿", "🎧", "🎵", "🎶", "🎬", "🎥", "📷", "🖼️", "🎨", "🖌️", "📐", "📏"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            dismiss()
                        }) {
                            Text(icon)
                                .font(.system(size: 32))
                                .frame(width: 60, height: 60)
                                .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("选择图标")
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

struct TemplateSelectorView: View {
    let selectedText: String
    let bookTitle: String
    let chapterTitle: String
    let onSelectTemplate: (String) -> Void
    @StateObject private var templateManager = NoteTemplateManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if !templateManager.recentTemplates.isEmpty {
                    Section {
                        ForEach(templateManager.recentTemplates.prefix(3)) { template in
                            Button(action: {
                                let content = templateManager.applyTemplate(
                                    template,
                                    selectedText: selectedText,
                                    bookTitle: bookTitle,
                                    chapterTitle: chapterTitle
                                )
                                templateManager.useTemplate(template, selectedText: selectedText, bookTitle: bookTitle, chapterTitle: chapterTitle)
                                onSelectTemplate(content)
                                dismiss()
                            }) {
                                TemplatePreviewRow(template: template, selectedText: selectedText)
                            }
                        }
                    } header: {
                        Text("最近使用")
                    }
                }
                
                Section {
                    ForEach(NoteTemplateManager.NoteTemplate.TemplateCategory.allCases, id: \.id) { category in
                        let categoryTemplates = templateManager.getTemplates(for: category)
                        if !categoryTemplates.isEmpty {
                            DisclosureGroup {
                                ForEach(categoryTemplates) { template in
                                    Button(action: {
                                        let content = templateManager.applyTemplate(
                                            template,
                                            selectedText: selectedText,
                                            bookTitle: bookTitle,
                                            chapterTitle: chapterTitle
                                        )
                                        templateManager.useTemplate(template, selectedText: selectedText, bookTitle: bookTitle, chapterTitle: chapterTitle)
                                        onSelectTemplate(content)
                                        dismiss()
                                    }) {
                                        TemplatePreviewRow(template: template, selectedText: selectedText)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(category.icon)
                                        .font(.title2)
                                    Text(category.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(categoryTemplates.count)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("所有模板")
                }
            }
            .navigationTitle("选择模板")
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
}

struct TemplatePreviewRow: View {
    let template: NoteTemplateManager.NoteTemplate
    let selectedText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.icon)
                    .font(.title3)
                
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Circle()
                    .fill(Color(hex: template.color.hexColor) ?? .blue)
                    .frame(width: 10, height: 10)
            }
            
            Text(previewText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
    
    private var previewText: String {
        NoteTemplateManager.shared.applyTemplate(
            template,
            selectedText: selectedText.isEmpty ? "选中文本" : selectedText,
            bookTitle: "书名",
            chapterTitle: "章节"
        )
    }
}

struct NoteTemplateListView_Previews: PreviewProvider {
    static var previews: some View {
        NoteTemplateListView()
    }
}
