import SwiftUI

struct ComicReadingSettingsView: View {
    @StateObject private var settings = ComicReadingSettings.shared
    
    var body: some View {
        List {
            Section("阅读模式") {
                ForEach(ComicReadingSettings.ReadingMode.allCases, id: \.self) { mode in
                    Button(action: {
                        settings.readingMode = mode
                        settings.saveSettings()
                    }) {
                        HStack {
                            Image(systemName: mode.icon)
                                .foregroundColor(.blue)
                            Text(mode.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if settings.readingMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section("显示设置") {
                Toggle("显示页码", isOn: $settings.showPageNumber)
                    .onChange(of: settings.showPageNumber) { _ in settings.saveSettings() }
                
                Toggle("显示进度条", isOn: $settings.showPageSlider)
                    .onChange(of: settings.showPageSlider) { _ in settings.saveSettings() }
            }
            
            Section("背景颜色") {
                ForEach(ComicReadingSettings.ComicBackgroundColor.allCases, id: \.self) { color in
                    Button(action: {
                        settings.backgroundColor = color
                        settings.saveSettings()
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(color.color))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: color == settings.backgroundColor ? 2 : 0)
                                )
                            Text(color.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if settings.backgroundColor == color {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section("手势操作") {
                Toggle("双击缩放", isOn: $settings.doubleTapToZoom)
                    .onChange(of: settings.doubleTapToZoom) { _ in settings.saveSettings() }
                
                Toggle("捏合缩放", isOn: $settings.pinchToZoom)
                    .onChange(of: settings.pinchToZoom) { _ in settings.saveSettings() }
                
                Toggle("点击区域切换页码", isOn: $settings.tapZoneEnabled)
                    .onChange(of: settings.tapZoneEnabled) { _ in settings.saveSettings() }
            }
            
            Section("放大镜") {
                Toggle("启用放大镜（长按显示）", isOn: $settings.magnifierEnabled)
                    .onChange(of: settings.magnifierEnabled) { _ in settings.saveSettings() }
                
                if settings.magnifierEnabled {
                    Picker("放大镜大小", selection: $settings.magnifierSize) {
                        ForEach(ComicReadingSettings.MagnifierSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .onChange(of: settings.magnifierSize) { _ in settings.saveSettings() }
                }
            }
            
            Section("其他") {
                Toggle("保持屏幕常亮", isOn: $settings.keepScreenOn)
                    .onChange(of: settings.keepScreenOn) { _ in settings.saveSettings() }
            }
            
            Section("支持的格式") {
                VStack(alignment: .leading, spacing: 8) {
                    FormatRowView(format: "CBZ", description: "ZIP压缩格式", icon: "doc.zipper")
                    FormatRowView(format: "CBR", description: "RAR压缩格式", icon: "doc.fill")
                    FormatRowView(format: "CB7", description: "7z压缩格式", icon: "7.square")
                    FormatRowView(format: "PDF", description: "直接提取页面", icon: "doc.richtext")
                }
            }
            
            Section("使用说明") {
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRowView(
                        title: "翻页",
                        description: "点击屏幕左右两侧翻页，或使用滑块"
                    )
                    InstructionRowView(
                        title: "缩放",
                        description: "双指捏合缩放，或双击放大/缩小"
                    )
                    InstructionRowView(
                        title: "放大镜",
                        description: "长按任意位置显示放大镜"
                    )
                    InstructionRowView(
                        title: "隐藏控件",
                        description: "点击屏幕中央切换控件显示/隐藏"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("漫画模式设置")
    }
}

struct FormatRowView: View {
    let format: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(format)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InstructionRowView: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 70, alignment: .leading)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
