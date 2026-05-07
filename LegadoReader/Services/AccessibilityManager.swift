import Foundation
import UIKit
import SwiftUI

class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isVoiceOverEnabled = false
    @Published var dynamicTypeEnabled = true
    @Published var highContrastEnabled = false
    @Published var reduceMotionEnabled = false
    @Published var boldTextEnabled = false
    @Published var increasedContrastEnabled = false
    @Published var speakTouchEnabled = false
    @Published var largeReaderFont = false
    
    private let defaults = UserDefaults.standard
    
    private init() {
        loadSettings()
        checkSystemAccessibility()
    }
    
    private func loadSettings() {
        dynamicTypeEnabled = defaults.bool(forKey: "Accessibility_dynamicType")
        highContrastEnabled = defaults.bool(forKey: "Accessibility_highContrast")
        reduceMotionEnabled = defaults.bool(forKey: "Accessibility_reduceMotion")
        boldTextEnabled = defaults.bool(forKey: "Accessibility_boldText")
        increasedContrastEnabled = defaults.bool(forKey: "Accessibility_increasedContrast")
        speakTouchEnabled = defaults.bool(forKey: "Accessibility_speakTouch")
        largeReaderFont = defaults.bool(forKey: "Accessibility_largeReaderFont")
    }
    
    func saveSettings() {
        defaults.set(dynamicTypeEnabled, forKey: "Accessibility_dynamicType")
        defaults.set(highContrastEnabled, forKey: "Accessibility_highContrast")
        defaults.set(reduceMotionEnabled, forKey: "Accessibility_reduceMotion")
        defaults.set(boldTextEnabled, forKey: "Accessibility_boldText")
        defaults.set(increasedContrastEnabled, forKey: "Accessibility_increasedContrast")
        defaults.set(speakTouchEnabled, forKey: "Accessibility_speakTouch")
        defaults.set(largeReaderFont, forKey: "Accessibility_largeReaderFont")
    }
    
    func checkSystemAccessibility() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
    }
    
    func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    func announcePageChange(_ pageName: String) {
        UIAccessibility.post(notification: .pageScrolled, argument: pageName)
    }
    
    func setAccessibilityFocus(to element: Any) {
        UIAccessibility.setAccessibilityFocus(element)
    }
    
    func prefersBoldText() -> Bool {
        return UIAccessibility.isBoldTextEnabled
    }
    
    func prefersReducedMotion() -> Bool {
        return UIAccessibility.isReduceMotionEnabled
    }
    
    func prefersIncreasedContrast() -> Bool {
        return UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    func preferredContentSizeCategory() -> UIContentSizeCategory {
        return UIApplication.shared.preferredContentSizeCategory
    }
    
    func getReaderFontSizeMultiplier() -> CGFloat {
        let category = preferredContentSizeCategory()
        
        switch category {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.5
        case .accessibilityLarge: return 1.7
        case .accessibilityExtraLarge: return 1.9
        case .accessibilityExtraExtraLarge: return 2.1
        case .accessibilityExtraExtraExtraLarge: return 2.3
        default: return 1.0
        }
    }
}

struct AccessibilitySettingsView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: accessibilityManager.isVoiceOverEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(accessibilityManager.isVoiceOverEnabled ? .green : .secondary)
                    Text("VoiceOver 已开启")
                        .foregroundColor(accessibilityManager.isVoiceOverEnabled ? .primary : .secondary)
                }
            } header: {
                Text("系统状态")
            } footer: {
                Text("此功能依赖于系统 VoiceOver 设置")
            }
            
            Section("阅读器无障碍") {
                Toggle("大字体模式", isOn: $accessibilityManager.largeReaderFont)
                    .onChange(of: accessibilityManager.largeReaderFont) { _ in
                        accessibilityManager.saveSettings()
                    }
                
                Toggle("跟随系统字体大小", isOn: $accessibilityManager.dynamicTypeEnabled)
                    .onChange(of: accessibilityManager.dynamicTypeEnabled) { _ in
                        accessibilityManager.saveSettings()
                    }
                
                Toggle("高对比度", isOn: $accessibilityManager.highContrastEnabled)
                    .onChange(of: accessibilityManager.highContrastEnabled) { _ in
                        accessibilityManager.saveSettings()
                    }
            }
            
            Section("交互无障碍") {
                Toggle("减弱动效", isOn: $accessibilityManager.reduceMotionEnabled)
                    .onChange(of: accessibilityManager.reduceMotionEnabled) { _ in
                        accessibilityManager.saveSettings()
                    }
                
                Toggle("粗体文字", isOn: $accessibilityManager.boldTextEnabled)
                    .onChange(of: accessibilityManager.boldTextEnabled) { _ in
                        accessibilityManager.saveSettings()
                    }
                
                Toggle("增加对比度", isOn: $accessibilityManager.increasedContrastEnabled)
                    .onChange(of: accessibilityManager.increasedContrastEnabled) { _ in
                        accessibilityManager.saveSettings()
                    }
                
                Toggle("触摸反馈朗读", isOn: $accessibilityManager.speakTouchEnabled)
                    .onChange(of: accessibilityManager.speakTouchEnabled) { _ in
                        accessibilityManager.saveSettings()
                    }
            }
            
            Section("朗读设置") {
                NavigationLink(destination: VoiceOverSettingsView()) {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                        Text("VoiceOver 阅读设置")
                    }
                }
            }
            
            Section("预览") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("预览文本")
                        .font(.headline)
                        .accessibilityLabel("预览文本标题")
                    
                    Text("这是一段示例文本，用于预览无障碍设置效果。开启相应选项后，文本将根据您的设置进行调整。")
                        .font(.body)
                        .fontWeight(accessibilityManager.boldTextEnabled ? .bold : .regular)
                        .foregroundColor(accessibilityManager.highContrastEnabled ? .primary : .secondary)
                }
                .padding()
                .background(accessibilityManager.highContrastEnabled ? Color.primary.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("无障碍模式")
        .onAppear {
            accessibilityManager.checkSystemAccessibility()
        }
    }
}

struct VoiceOverSettingsView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @State private var speakingRate: Double = 0.5
    @State private var punctuationLevel: PunctuationLevel = .some
    
    enum PunctuationLevel: String, CaseIterable {
        case none = "无"
        case some = "部分"
        case all = "全部"
    }
    
    var body: some View {
        List {
            Section("朗读速度") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("慢")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $speakingRate, in: 0.1...1.0)
                        Text("快")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("当前速度: \(Int(speakingRate * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section("标点符号") {
                ForEach(PunctuationLevel.allCases, id: \.self) { level in
                    Button(action: {
                        punctuationLevel = level
                    }) {
                        HStack {
                            Text(level.rawValue)
                            Spacer()
                            if punctuationLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section {
                Button("测试朗读") {
                    accessibilityManager.announce("这是一段测试朗读，用于检查语音设置是否正确。")
                }
            }
            
            Section("说明") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("无标点: 不朗读标点符号")
                    Text("部分标点: 仅朗读重要标点")
                    Text("全部标点: 朗读所有标点符号")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("VoiceOver 阅读")
    }
}

extension View {
    func accessibilityBookCard(book: Book) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(book.name), 作者: \(book.author)")
            .accessibilityHint("双击打开书籍详情")
    }
    
    func accessibilityChapterRow(chapter: Chapter) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("第 \(chapter.index + 1) 章, \(chapter.title)")
            .accessibilityHint("双击跳转到此章节")
    }
    
    func accessibilityReaderText() -> some View {
        self
            .accessibilityAddTraits(.isStaticText)
    }
}

struct AccessibleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(configuration.isPressed ? Color.blue.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AccessibilityPreviewView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("无障碍预览")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text("当前设置")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("VoiceOver: \(accessibilityManager.isVoiceOverEnabled ? "开启" : "关闭")", systemImage: "speaker.wave.2")
                    Label("动态字体: \(accessibilityManager.dynamicTypeEnabled ? "开启" : "关闭")", systemImage: "textformat.size")
                    Label("高对比度: \(accessibilityManager.highContrastEnabled ? "开启" : "关闭")", systemImage: "circle.lefthalf.filled")
                    Label("减弱动效: \(accessibilityManager.reduceMotionEnabled ? "开启" : "关闭")", systemImage: "wind")
                }
                .font(.caption)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Text("示例内容")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .accessibilityAddTraits(.isHeader)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("第一章 穿越")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("张伟缓缓睁开眼睛，发现自己躺在一个陌生的地方。四周是一片茂密的森林，阳光从树叶间洒落，形成斑驳的光影。")
                        .font(.body)
                        .lineSpacing(8)
                        .fontWeight(accessibilityManager.boldTextEnabled ? .bold : .regular)
                    
                    Text("这是什么地方？我怎么会在这里？")
                        .font(.body)
                        .italic()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .padding()
        }
        .navigationTitle("无障碍预览")
    }
}
