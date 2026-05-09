import SwiftUI

struct AnnotationStyleSettingsView: View {
    @StateObject private var styleManager = AnnotationStyleManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("设置类型", selection: $selectedTab) {
                Text("标记样式").tag(0)
                Text("颜色设置").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedTab == 0 {
                StyleSettingsContent()
            } else {
                ColorSettingsContent()
            }
            
            Spacer()
        }
        .navigationTitle("标记外观设置")
    }
}

struct StyleSettingsContent: View {
    @StateObject private var styleManager = AnnotationStyleManager.shared
    
    let underlineStyles: [AnnotationService.Annotation.AnnotationStyle] = [
        .underline, .wavyUnderline, .dashedUnderline, .doubleUnderline, .thickUnderline
    ]
    
    let highlightStyles: [AnnotationService.Annotation.AnnotationStyle] = [
        .highlight, .background
    ]
    
    let fontStyles: [AnnotationService.Annotation.AnnotationStyle] = [
        .bold, .italic, .boldItalic, .color
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundColor(.blue)
                            Text("当前样式")
                                .font(.headline)
                        }
                        
                        HStack(spacing: 16) {
                            CurrentStylePreviewView(
                                style: styleManager.currentStyle,
                                color: styleManager.currentColor
                            )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(styleManager.currentStyle.displayName)
                                    .font(.headline)
                                Text(styleManager.currentColor.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("下划线样式", systemImage: "underline")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                            ForEach(underlineStyles, id: \.self) { style in
                                StyleButtonView(
                                    style: style,
                                    isSelected: styleManager.currentStyle == style,
                                    color: styleManager.currentColor,
                                    action: {
                                        styleManager.setCurrentStyle(style)
                                    }
                                )
                            }
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("高亮样式", systemImage: "highlighter")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                            ForEach(highlightStyles, id: \.self) { style in
                                StyleButtonView(
                                    style: style,
                                    isSelected: styleManager.currentStyle == style,
                                    color: styleManager.currentColor,
                                    action: {
                                        styleManager.setCurrentStyle(style)
                                    }
                                )
                            }
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("字体样式", systemImage: "textformat")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                            ForEach(fontStyles, id: \.self) { style in
                                StyleButtonView(
                                    style: style,
                                    isSelected: styleManager.currentStyle == style,
                                    color: styleManager.currentColor,
                                    action: {
                                        styleManager.setCurrentStyle(style)
                                    }
                                )
                            }
                        }
                    }
                }
                
                if !styleManager.recentStyles.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("最近使用", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(styleManager.recentStyles, id: \.self) { style in
                                    Button(action: {
                                        styleManager.setCurrentStyle(style)
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: style.icon)
                                                .font(.title2)
                                            Text(style.displayName)
                                                .font(.caption2)
                                        }
                                        .frame(width: 60, height: 50)
                                        .background(
                                            styleManager.currentStyle == style ?
                                            Color.blue.opacity(0.2) :
                                            Color(.systemGray5)
                                        )
                                        .cornerRadius(8)
                                    }
                                    .foregroundColor(styleManager.currentStyle == style ? .blue : .primary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct ColorSettingsContent: View {
    @StateObject private var styleManager = AnnotationStyleManager.shared
    @State private var showingColorPicker = false
    @State private var customColor = Color.yellow
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "paintpalette")
                                .foregroundColor(.blue)
                            Text("当前颜色")
                                .font(.headline)
                        }
                        
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color(hex: styleManager.currentColor.hex) ?? .yellow)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(styleManager.currentColor.name)
                                    .font(.headline)
                                Text(styleManager.currentColor.hex)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("预设颜色", systemImage: "circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                            ForEach(AnnotationService.AnnotationColor.defaultColors) { color in
                                ColorButtonView(
                                    color: color,
                                    isSelected: styleManager.currentColor.hex == color.hex,
                                    action: {
                                        styleManager.setCurrentColor(color)
                                    }
                                )
                            }
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("自定义颜色", systemImage: "eyedropper")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ColorPicker("选择颜色", selection: $customColor)
                            .onChange(of: customColor) { newColor in
                                let hex = newColor.toHex() ?? "#FFF59D"
                                let color = AnnotationService.AnnotationColor(
                                    name: "自定义",
                                    hex: hex,
                                    alpha: 0.5
                                )
                                styleManager.setCurrentColor(color)
                            }
                    }
                }
                
                if !styleManager.recentColors.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("最近使用", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(styleManager.recentColors) { color in
                                    Button(action: {
                                        styleManager.setCurrentColor(color)
                                    }) {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: color.hex) ?? .yellow)
                                                .frame(width: 30, height: 30)
                                            Text(color.name)
                                                .font(.caption2)
                                        }
                                        .frame(width: 50, height: 50)
                                        .background(
                                            styleManager.currentColor.hex == color.hex ?
                                            Color.blue.opacity(0.2) :
                                            Color(.systemGray5)
                                        )
                                        .cornerRadius(8)
                                    }
                                    .foregroundColor(styleManager.currentColor.hex == color.hex ? .blue : .primary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        styleManager.setCurrentColor(AnnotationService.AnnotationColor.defaultColors[0])
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("恢复默认设置")
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct CurrentStylePreviewView: View {
    let style: AnnotationService.Annotation.AnnotationStyle
    let color: AnnotationService.AnnotationColor
    
    var body: some View {
        Group {
            switch style {
            case .underline:
                Text("示例文本")
                    .underline(style == .doubleUnderline ? .double : .single, color: Color(hex: color.hex) ?? .yellow)
            case .wavyUnderline:
                Text("示例文本")
                    .underline(style: .continuous, color: Color(hex: color.hex) ?? .yellow)
            case .dashedUnderline:
                Text("示例文本")
                    .underline(style: .patternDash, color: Color(hex: color.hex) ?? .yellow)
            case .doubleUnderline:
                Text("示例文本")
                    .underline(style: .double, color: Color(hex: color.hex) ?? .yellow)
            case .thickUnderline:
                Text("示例文本")
                    .underline(style: .thick, color: Color(hex: color.hex) ?? .yellow)
            case .highlight:
                Text("示例文本")
                    .foregroundColor(Color(hex: color.hex) ?? .yellow)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(hex: color.hex)?.opacity(color.alpha) ?? .yellow.opacity(0.5))
                    .cornerRadius(4)
            case .background:
                Text("示例文本")
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(hex: color.hex)?.opacity(color.alpha) ?? .yellow.opacity(0.5))
                    .cornerRadius(4)
            case .bold:
                Text("示例文本")
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: color.hex) ?? .yellow)
            case .italic:
                Text("示例文本")
                    .italic()
                    .foregroundColor(Color(hex: color.hex) ?? .yellow)
            case .boldItalic:
                Text("示例文本")
                    .fontWeight(.bold)
                    .italic()
                    .foregroundColor(Color(hex: color.hex) ?? .yellow)
            case .color:
                Text("示例文本")
                    .foregroundColor(Color(hex: color.hex) ?? .yellow)
            }
        }
    }
}

struct StyleButtonView: View {
    let style: AnnotationService.Annotation.AnnotationStyle
    let isSelected: Bool
    let color: AnnotationService.AnnotationColor
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray5))
                        .frame(width: 60, height: 60)
                    
                    SampleTextPreview(style: style, color: color)
                }
                
                Text(style.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .primary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct SampleTextPreview: View {
    let style: AnnotationService.Annotation.AnnotationStyle
    let color: AnnotationService.AnnotationColor
    
    var body: some View {
        Text("Aa")
            .font(.title2)
            .foregroundColor(Color(hex: color.hex) ?? .yellow)
    }
}

struct ColorButtonView: View {
    let color: AnnotationService.AnnotationColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(hex: color.hex) ?? .yellow)
                        .frame(width: 40, height: 40)
                        .opacity(color.alpha + 0.5)
                    
                    if isSelected {
                        Circle()
                            .stroke(Color.blue, lineWidth: 3)
                            .frame(width: 46, height: 46)
                    }
                }
                
                Text(color.name)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .frame(width: 60, height: 65)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
    }
}
