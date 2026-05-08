import SwiftUI

struct ThemeSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingCustomThemeSheet = false
    @State private var newThemeName = ""
    @State private var selectedBackgroundColor = "#FFFFFF"
    @State private var selectedTextColor = "#1C1C1E"
    @State private var selectedAccentColor = "#007AFF"
    
    var body: some View {
        NavigationView {
            List {
                Section("内置主题") {
                    ForEach(themeManager.availableThemes.filter { !$0.isCustom }) { theme in
                        ThemeRow(theme: theme, isSelected: themeManager.currentTheme.id == theme.id) {
                            themeManager.setTheme(theme)
                        }
                    }
                }
                
                if themeManager.availableThemes.contains(where: { $0.isCustom }) {
                    Section("自定义主题") {
                        ForEach(themeManager.availableThemes.filter { $0.isCustom }) { theme in
                            ThemeRow(theme: theme, isSelected: themeManager.currentTheme.id == theme.id) {
                                themeManager.setTheme(theme)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    themeManager.deleteCustomTheme(theme)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        showingCustomThemeSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                            Text("创建自定义主题")
                        }
                    }
                }
                
                Section("主题预览") {
                    ThemePreviewCard(theme: themeManager.currentTheme)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("主题设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomThemeSheet) {
                CustomThemeCreatorView(
                    onSave: { name, bg, text, accent in
                        let newTheme = themeManager.createCustomTheme(name: name, backgroundColor: bg, textColor: text, accentColor: accent)
                        themeManager.setTheme(newTheme)
                        showingCustomThemeSheet = false
                    },
                    onCancel: {
                        showingCustomThemeSheet = false
                    }
                )
            }
        }
    }
}

struct ThemeRow: View {
    let theme: ThemeManager.Theme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 主题预览色块
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: theme.backgroundColor))
                        .frame(width: 48, height: 48)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: theme.accentColor))
                        .frame(width: 20, height: 20)
                        .offset(x: 10, y: 10)
                }
                
                // 主题信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundColor(Color(hex: theme.textColor))
                    
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(Color(hex: theme.secondaryColor))
                }
                
                // 选中标记
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: theme.accentColor))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ThemePreviewCard: View {
    let theme: ThemeManager.Theme
    
    var body: some View {
        VStack(spacing: 12) {
            // 预览标题
            Text("当前主题预览")
                .font(.headline)
                .foregroundColor(Color(hex: theme.textColor))
            
            // 模拟界面预览
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: theme.backgroundColor))
                    .shadow(radius: 2)
                
                VStack(spacing: 8) {
                    // 导航栏
                    HStack {
                        Text("预览")
                            .font(.headline)
                            .foregroundColor(Color(hex: theme.textColor))
                        Spacer()
                        Image(systemName: "search")
                            .foregroundColor(Color(hex: theme.secondaryColor))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    // 内容区域
                    VStack(spacing: 8) {
                        // 卡片
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: theme.cardColor))
                            .frame(height: 60)
                            .overlay(
                                HStack {
                                    Circle()
                                        .fill(Color(hex: theme.accentColor))
                                        .frame(width: 40, height: 40)
                                        .padding(.leading, 12)
                                    VStack(alignment: .leading) {
                                        Text("内容标题")
                                            .font(.subheadline)
                                            .foregroundColor(Color(hex: theme.textColor))
                                        Text("内容描述")
                                            .font(.caption)
                                            .foregroundColor(Color(hex: theme.secondaryColor))
                                    }
                                    Spacer()
                                }
                            )
                        
                        // 按钮组
                        HStack(spacing: 8) {
                            Button(action: {}) {
                                Text("主要按钮")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: theme.accentColor))
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {}) {
                                Text("次要按钮")
                                    .foregroundColor(Color(hex: theme.accentColor))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: theme.cardColor))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .frame(height: 180)
            
            // 颜色示例
            HStack(spacing: 8) {
                ColorSampleView(color: Color(hex: theme.backgroundColor), label: "背景")
                ColorSampleView(color: Color(hex: theme.textColor), label: "文字")
                ColorSampleView(color: Color(hex: theme.accentColor), label: "强调")
                ColorSampleView(color: Color(hex: theme.cardColor), label: "卡片")
            }
        }
        .padding()
    }
}

struct ColorSampleView: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CustomThemeCreatorView: View {
    let onSave: (String, String, String, String) -> Void
    let onCancel: () -> Void
    
    @State private var themeName = ""
    @State private var backgroundColor = "#FFFFFF"
    @State private var textColor = "#1C1C1E"
    @State private var accentColor = "#007AFF"
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("主题名称") {
                    TextField("输入主题名称", text: $themeName)
                }
                
                Section("背景颜色") {
                    ColorPickerRow(color: $backgroundColor, label: "背景色")
                }
                
                Section("文字颜色") {
                    ColorPickerRow(color: $textColor, label: "文字色")
                }
                
                Section("强调颜色") {
                    ColorPickerRow(color: $accentColor, label: "强调色")
                }
                
                Section("快速配色") {
                    VStack(spacing: 8) {
                        ForEach(QuickColorPresets.allCases) { preset in
                            Button(action: {
                                backgroundColor = preset.backgroundColor
                                textColor = preset.textColor
                                accentColor = preset.accentColor
                            }) {
                                HStack {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color(hex: preset.backgroundColor)).frame(width: 16, height: 16)
                                        Circle().fill(Color(hex: preset.textColor)).frame(width: 16, height: 16)
                                        Circle().fill(Color(hex: preset.accentColor)).frame(width: 16, height: 16)
                                    }
                                    Text(preset.name)
                                }
                            }
                        }
                    }
                }
                
                Section("预览") {
                    ThemePreviewCard(theme: ThemeManager.Theme(
                        id: "preview",
                        name: "预览",
                        description: "",
                        isCustom: false,
                        backgroundColor: backgroundColor,
                        textColor: textColor,
                        accentColor: accentColor,
                        secondaryColor: adjustBrightness(hex: textColor, percent: -40),
                        navigationBarColor: backgroundColor,
                        tabBarColor: backgroundColor,
                        cardColor: adjustBrightness(hex: backgroundColor, percent: -5),
                        borderColor: adjustBrightness(hex: textColor, percent: -60),
                        linkColor: accentColor,
                        successColor: "#34C759",
                        warningColor: "#FF9500",
                        errorColor: "#FF3B30"
                    ))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("创建自定义主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if !themeName.isEmpty {
                            onSave(themeName, backgroundColor, textColor, accentColor)
                        }
                    }
                    .disabled(themeName.isEmpty)
                }
            }
        }
    }
    
    private func adjustBrightness(hex: String, percent: Int) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000ff) / 255
        }
        
        let brightnessAdjustment = CGFloat(percent) / 100
        r = max(0, min(1, r + brightnessAdjustment))
        g = max(0, min(1, g + brightnessAdjustment))
        b = max(0, min(1, b + brightnessAdjustment))
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

struct ColorPickerRow: View {
    @Binding var color: String
    let label: String
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            Text(label)
            
            Spacer()
            
            HStack(spacing: 12) {
                // 自定义颜色选择器
                Button(action: {
                    // 可以弹出颜色选择器
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 36, height: 36)
                        
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 1)
                            .frame(width: 40, height: 40)
                    }
                }
                
                // 快捷颜色选择
                HStack(spacing: 4) {
                    ForEach(themeManager.customColors) { customColor in
                        Button(action: {
                            color = customColor.hex
                        }) {
                            Circle()
                                .fill(Color(hex: customColor.hex))
                                .frame(width: 24, height: 24)
                                .opacity(color == customColor.hex ? 1 : 0.5)
                        }
                    }
                }
            }
        }
    }
}

enum QuickColorPresets: String, CaseIterable, Identifiable {
    case ocean = "海洋"
    case sunset = "日落"
    case forest = "森林"
    case lavender = "薰衣草"
    case dark = "深色"
    case light = "浅色"
    
    var id: String { rawValue }
    
    var backgroundColor: String {
        switch self {
        case .ocean: return "#E6F4F9"
        case .sunset: return "#FFF5EB"
        case .forest: return "#E8F5E9"
        case .lavender: return "#F3E5F5"
        case .dark: return "#1C1C1E"
        case .light: return "#FFFFFF"
        }
    }
    
    var textColor: String {
        switch self {
        case .ocean: return "#0A1628"
        case .sunset: return "#5C2E0A"
        case .forest: return "#1B3A1B"
        case .lavender: return "#4A148C"
        case .dark: return "#FFFFFF"
        case .light: return "#1C1C1E"
        }
    }
    
    var accentColor: String {
        switch self {
        case .ocean: return "#006994"
        case .sunset: return "#D45A1A"
        case .forest: return "#2E7D32"
        case .lavender: return "#7B1FA2"
        case .dark: return "#0A84FF"
        case .light: return "#007AFF"
        }
    }
}
