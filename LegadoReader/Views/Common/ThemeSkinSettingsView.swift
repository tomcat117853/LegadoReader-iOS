import SwiftUI

struct ThemeSkinSettingsView: View {
    @StateObject private var themeManager = UnifiedThemeManager.shared
    @State private var showingThemeDetail = false
    @State private var showingCreateTheme = false
    @State private var selectedTheme: UnifiedThemeManager.UnifiedTheme?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                quickActionsSection
                currentThemeSection
                allThemesSection
            }
            .padding()
        }
        .navigationTitle("一键换肤")
        .sheet(item: $selectedTheme) { theme in
            ThemeDetailView(theme: theme)
        }
        .sheet(isPresented: $showingCreateTheme) {
            CreateCustomThemeView()
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("快捷操作", systemImage: "wand.and.stars")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        themeManager.randomSkin()
                    }
                }) {
                    HStack {
                        Image(systemName: "dice.fill")
                        Text("随机换肤")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    withAnimation {
                        themeManager.resetToDefault()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("恢复默认")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                }
            }
            
            NavigationLink(destination: LanguageSettingsView()) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.green)
                    Text("语言设置")
                    Spacer()
                    Text(themeManager.currentLanguage.displayName)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .foregroundColor(.primary)
        }
    }
    
    private var currentThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("当前主题", systemImage: "paintbrush.fill")
                .font(.headline)
            
            ThemePreviewCard(theme: themeManager.currentTheme, isSelected: true)
                .onTapGesture {
                    selectedTheme = themeManager.currentTheme
                }
        }
    }
    
    private var allThemesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("全部主题", systemImage: "square.grid.2x2.fill")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingCreateTheme = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("创建主题")
                    }
                    .font(.subheadline)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(themeManager.availableThemes) { theme in
                    ThemeGridItem(
                        theme: theme,
                        isSelected: theme.id == themeManager.currentTheme.id
                    )
                    .onTapGesture {
                        withAnimation {
                            themeManager.changeTheme(to: theme.id)
                        }
                    }
                    .contextMenu {
                        if !theme.isBuiltIn {
                            Button(role: .destructive, action: {
                                themeManager.deleteCustomTheme(theme)
                            }) {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ThemePreviewCard: View {
    let theme: UnifiedThemeManager.UnifiedTheme
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(theme.previewColors.prefix(4), id: \.self) { colorHex in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: colorHex) ?? .gray)
                        .frame(height: 40)
                }
            }
            .padding(12)
            .background(Color(hex: theme.surfaceColor) ?? .white)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(theme.displayName)
                        .font(.headline)
                        .foregroundColor(Color(hex: theme.textPrimaryColor) ?? .primary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    Text(theme.isDarkMode ? "深色模式" : "浅色模式")
                        .font(.caption)
                        .foregroundColor(Color(hex: theme.textSecondaryColor) ?? .secondary)
                    
                    Spacer()
                    
                    if theme.isBuiltIn {
                        Text("内置")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    } else {
                        Text("自定义")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(12)
            .background(Color(hex: theme.cardBackgroundColor) ?? .white)
        }
        .background(Color(hex: theme.backgroundColor) ?? Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ThemeGridItem: View {
    let theme: UnifiedThemeManager.UnifiedTheme
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(theme.previewColors.prefix(4), id: \.self) { colorHex in
                    Rectangle()
                        .fill(Color(hex: colorHex) ?? .gray)
                }
            }
            .frame(height: 60)
            
            Text(theme.displayName)
                .font(.caption)
                .lineLimit(1)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(hex: theme.surfaceColor) ?? .white)
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ThemeDetailView: View {
    @Environment(\.dismiss) var dismiss
    let theme: UnifiedThemeManager.UnifiedTheme
    @StateObject private var themeManager = UnifiedThemeManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ThemePreviewCard(theme: theme, isSelected: theme.id == themeManager.currentTheme.id)
                        .padding(.horizontal)
                    
                    colorSection(title: "主色调", colors: [
                        ("Primary", theme.primaryColor),
                        ("Secondary", theme.secondaryColor),
                        ("Accent", theme.accentColor)
                    ])
                    
                    colorSection(title: "背景色", colors: [
                        ("Background", theme.backgroundColor),
                        ("Surface", theme.surfaceColor),
                        ("Card", theme.cardBackgroundColor)
                    ])
                    
                    colorSection(title: "文字色", colors: [
                        ("Primary", theme.textPrimaryColor),
                        ("Secondary", theme.textSecondaryColor),
                        ("Divider", theme.dividerColor)
                    ])
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label("主题信息", systemImage: "info.circle")
                            .font(.headline)
                        
                        InfoRow(title: "主题名称", value: theme.displayName)
                        InfoRow(title: "模式", value: theme.isDarkMode ? "深色" : "浅色")
                        InfoRow(title: "类型", value: theme.isBuiltIn ? "内置" : "自定义")
                        InfoRow(title: "ID", value: theme.id)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("主题详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        themeManager.changeTheme(to: theme.id)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func colorSection(title: String, colors: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "paintpalette")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(colors, id: \.0) { name, hex in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text(name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(hex)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct CreateCustomThemeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var themeManager = UnifiedThemeManager.shared
    @State private var themeName = ""
    @State private var themeNameEn = ""
    @State private var selectedColor = Color.blue
    @State private var selectedBaseThemeId = "default"
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("主题名称（中文）", text: $themeName)
                    TextField("主题名称（英文）", text: $themeNameEn)
                }
                
                Section("选择基准主题") {
                    ForEach(themeManager.availableThemes.prefix(4)) { theme in
                        Button(action: {
                            selectedBaseThemeId = theme.id
                        }) {
                            HStack {
                                ThemeGridItem(theme: theme)
                                    .frame(width: 60, height: 60)
                                Text(theme.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedBaseThemeId == theme.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("选择主色调") {
                    ColorPicker("主色调", selection: $selectedColor)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("预览")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 40, height: 40)
                            
                            Text(themeName.isEmpty ? "新主题" : themeName)
                                .font(.headline)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .navigationTitle("创建自定义主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createTheme()
                    }
                    .disabled(themeName.isEmpty)
                }
            }
        }
    }
    
    private func createTheme() {
        guard let baseTheme = themeManager.availableThemes.first(where: { $0.id == selectedBaseThemeId }) else { return }
        
        let colorHex = selectedColor.toHex() ?? "#007AFF"
        
        let newTheme = themeManager.createCustomTheme(
            from: baseTheme,
            name: themeName,
            nameEn: themeNameEn.isEmpty ? themeName : themeNameEn,
            primaryColor: colorHex
        )
        
        themeManager.changeTheme(to: newTheme.id)
        dismiss()
    }
}

struct LanguageSettingsView: View {
    @StateObject private var themeManager = UnifiedThemeManager.shared
    
    var body: some View {
        List {
            ForEach(UnifiedThemeManager.Language.allCases, id: \.self) { language in
                Button(action: {
                    withAnimation {
                        themeManager.setLanguage(language)
                    }
                }) {
                    HStack {
                        Text(language.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        if themeManager.currentLanguage == language {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("语言设置")
    }
}
