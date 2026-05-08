import SwiftUI
import UIKit
import WebKit

struct EPUBCSSReaderView: View {
    let book: EPUBParser.EPUBBook
    @Binding var currentChapterIndex: Int
    @StateObject private var readerSettings = ReaderSettings.shared
    @StateObject private var eyeCareManager = EyeCareManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                if currentChapterIndex < book.chapters.count {
                    EPUBChapterView(
                        chapter: book.chapters[currentChapterIndex],
                        stylesheets: book.stylesheets,
                        baseURL: book.baseURL,
                        readerSettings: readerSettings,
                        eyeCareManager: eyeCareManager
                    )
                }
                
                chapterNavigationOverlay
            }
        }
    }
    
    private var backgroundColor: Color {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveBackgroundColor
        }
        return readerSettings.backgroundColor.color
    }
    
    private var chapterNavigationOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
        }
    }
}

struct EPUBChapterView: View {
    let chapter: EPUBParser.EPUBChapter
    let stylesheets: [CSSParser.ParsedCSS]
    let baseURL: URL?
    let readerSettings: ReaderSettings
    let eyeCareManager: EyeCareManager
    
    @State private var renderedHTML: String = ""
    
    var body: some View {
        ScrollView {
            EPUBContentView(
                html: renderedHTML,
                baseURL: baseURL,
                readerSettings: readerSettings,
                eyeCareManager: eyeCareManager
            )
        }
        .onAppear {
            renderChapter()
        }
        .onChange(of: chapter.href) { _ in
            renderChapter()
        }
    }
    
    private func renderChapter() {
        let cssStyles = generateEmbeddedCSS()
        renderedHTML = wrapWithHTML(cssStyles)
    }
    
    private func generateEmbeddedCSS() -> String {
        var css = """
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: \(getFontFamily());
                font-size: \(Int(readerSettings.fontSize))px;
                line-height: \(readerSettings.lineSpacing);
                text-align: \(getTextAlign());
                padding: \(Int(readerSettings.verticalPadding))px \(Int(readerSettings.horizontalPadding))px;
                color: \(getTextColor());
                background-color: \(getBackgroundColor());
            }
            img {
                max-width: 100%;
                height: auto;
                display: block;
                margin: 1em auto;
            }
            a {
                color: inherit;
                text-decoration: underline;
            }
            p {
                margin-bottom: 1em;
                text-indent: 2em;
            }
            h1, h2, h3, h4, h5, h6 {
                font-weight: bold;
                margin: 1em 0;
                text-align: center;
            }
            h1 { font-size: 1.8em; }
            h2 { font-size: 1.5em; }
            h3 { font-size: 1.3em; }
            h4 { font-size: 1.1em; }
            h5 { font-size: 1em; }
            h6 { font-size: 0.9em; }
            blockquote {
                margin: 1em 2em;
                padding-left: 1em;
                border-left: 3px solid #ccc;
                font-style: italic;
            }
            pre, code {
                font-family: monospace;
                background-color: rgba(0,0,0,0.05);
                padding: 0.2em 0.4em;
                border-radius: 3px;
            }
            pre {
                padding: 1em;
                overflow-x: auto;
                white-space: pre-wrap;
                word-wrap: break-word;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin: 1em 0;
            }
            th, td {
                border: 1px solid #ddd;
                padding: 0.5em;
                text-align: left;
            }
            th {
                background-color: rgba(0,0,0,0.05);
            }
            .calibre {
                display: block;
                margin-bottom: 0.5em;
            }
            .mbppagebreak {
                display: block;
                margin-bottom: 0;
                min-height: 1px;
            }
        """
        
        for stylesheet in stylesheets {
            for rule in stylesheet.rules {
                css += "\(rule.selector) { "
                for declaration in rule.declarations {
                    css += "\(declaration.property): \(declaration.value); "
                }
                css += "}\n"
            }
        }
        
        css += "</style>"
        return css
    }
    
    private func getFontFamily() -> String {
        return readerSettings.fontFamily
    }
    
    private func getTextColor() -> String {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveTextColor.toHexString()
        }
        return readerSettings.textColor.toHexString()
    }
    
    private func getBackgroundColor() -> String {
        if eyeCareManager.isEyeCareEnabled {
            return eyeCareManager.effectiveBackgroundColor.toHexString()
        }
        return readerSettings.backgroundColor.color.toHexString()
    }
    
    private func getTextAlign() -> String {
        switch readerSettings.textAlignment {
        case "left": return "left"
        case "center": return "center"
        case "right": return "right"
        case "justify": return "justify"
        default: return "left"
        }
    }
    
    private func wrapWithHTML(_ css: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            \(css)
        </head>
        <body>
            \(processChapterContent())
        </body>
        </html>
        """
    }
    
    private func processChapterContent() -> String {
        var content = chapter.content
        
        if let baseURL = baseURL {
            content = content.replacingOccurrences(
                of: "src=\"",
                with: "src=\"file://\(baseURL.path)/"
            )
            content = content.replacingOccurrences(
                of: "href=\"",
                with: "href=\"file://\(baseURL.path)/"
            )
        }
        
        return content
    }
}

struct EPUBContentView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    let readerSettings: ReaderSettings
    let eyeCareManager: EyeCareManager
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.backgroundColor = getBackgroundUIColor()
        
        webView.loadHTMLString(html, baseURL: baseURL)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func getBackgroundUIColor() -> UIColor {
        if eyeCareManager.isEyeCareEnabled {
            return UIColor(eyeCareManager.effectiveBackgroundColor)
        }
        return UIColor(readerSettings.backgroundColor.color)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

extension Color {
    func toHexString() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct EPUBSettingsView: View {
    @StateObject private var epubSettings = EPUBSettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("应用自定义排版", isOn: $epubSettings.applyCustomTypography)
                    
                    Toggle("保持原始图片大小", isOn: $epubSettings.keepOriginalImageSize)
                    
                    Toggle("启用图片点击放大", isOn: $epubSettings.enableImageZoom)
                    
                    Toggle("自动段首缩进", isOn: $epubSettings.autoIndentParagraphs)
                } header: {
                    Text("排版设置")
                }
                
                Section {
                    Toggle("首行缩进", isOn: $epubSettings.indentFirstLine)
                    
                    HStack {
                        Text("缩进字符数")
                        Spacer()
                        Text("\(epubSettings.indentChars)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { epubSettings.indentChars },
                        set: { epubSettings.setIndentChars(Int($0)) }
                    ), in: 2...4, step: 1)
                } header: {
                    Text("段落格式")
                }
                
                Section {
                    HStack {
                        Text("行高倍数")
                        Spacer()
                        Text(String(format: "%.1f", epubSettings.lineHeightMultiplier))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $epubSettings.lineHeightMultiplier, in: 1.0...2.5, step: 0.1)
                    .onChange(of: epubSettings.lineHeightMultiplier) { value in
                        epubSettings.setLineHeightMultiplier(value)
                    }
                } header: {
                    Text("行间距")
                }
                
                Section {
                    Toggle("标题上方间距", isOn: $epubSettings.headingTopMargin)
                    
                    Toggle("标题下方间距", isOn: $epubSettings.headingBottomMargin)
                    
                    HStack {
                        Text("标题间距(%)")
                        Spacer()
                        Text("\(Int(epubSettings.headingMargin * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $epubSettings.headingMargin, in: 0.5...2.0, step: 0.1)
                } header: {
                    Text("标题样式")
                }
                
                Section {
                    Toggle("显示边框", isOn: $epubSettings.showBorders)
                    
                    HStack {
                        Text("边框宽度")
                        Spacer()
                        Text("\(Int(epubSettings.borderWidth))px")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $epubSettings.borderWidth, in: 1...5, step: 1)
                    
                    Picker("边框样式", selection: $epubSettings.borderStyle) {
                        Text("实线").tag("solid")
                        Text("虚线").tag("dashed")
                        Text("点线").tag("dotted")
                        Text("双线").tag("double")
                    }
                } header: {
                    Text("边框样式")
                }
                
                Section {
                    Toggle("居中显示图片", isOn: $epubSettings.centerImages)
                    
                    HStack {
                        Text("最大图片宽度")
                        Spacer()
                        Text("\(Int(epubSettings.maxImageWidth * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $epubSettings.maxImageWidth, in: 0.5...1.0, step: 0.1)
                } header: {
                    Text("图片设置")
                }
                
                Section {
                    Button("恢复默认设置") {
                        epubSettings.resetToDefaults()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("EPUB排版")
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

class EPUBSettingsManager: ObservableObject {
    static let shared = EPUBSettingsManager()
    
    @Published var applyCustomTypography: Bool = true
    @Published var keepOriginalImageSize: Bool = false
    @Published var enableImageZoom: Bool = true
    @Published var autoIndentParagraphs: Bool = true
    @Published var indentFirstLine: Bool = true
    @Published var indentChars: Int = 2
    @Published var lineHeightMultiplier: Double = 1.5
    @Published var headingTopMargin: Bool = true
    @Published var headingBottomMargin: Bool = true
    @Published var headingMargin: Double = 1.0
    @Published var showBorders: Bool = true
    @Published var borderWidth: Double = 1.0
    @Published var borderStyle: String = "solid"
    @Published var centerImages: Bool = true
    @Published var maxImageWidth: Double = 0.9
    
    private let defaults = UserDefaults.standard
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        applyCustomTypography = defaults.object(forKey: "EPUBSettings_applyCustomTypography") as? Bool ?? true
        keepOriginalImageSize = defaults.object(forKey: "EPUBSettings_keepOriginalImageSize") as? Bool ?? false
        enableImageZoom = defaults.object(forKey: "EPUBSettings_enableImageZoom") as? Bool ?? true
        autoIndentParagraphs = defaults.object(forKey: "EPUBSettings_autoIndentParagraphs") as? Bool ?? true
        indentFirstLine = defaults.object(forKey: "EPUBSettings_indentFirstLine") as? Bool ?? true
        indentChars = defaults.object(forKey: "EPUBSettings_indentChars") as? Int ?? 2
        lineHeightMultiplier = defaults.object(forKey: "EPUBSettings_lineHeightMultiplier") as? Double ?? 1.5
        headingTopMargin = defaults.object(forKey: "EPUBSettings_headingTopMargin") as? Bool ?? true
        headingBottomMargin = defaults.object(forKey: "EPUBSettings_headingBottomMargin") as? Bool ?? true
        headingMargin = defaults.object(forKey: "EPUBSettings_headingMargin") as? Double ?? 1.0
        showBorders = defaults.object(forKey: "EPUBSettings_showBorders") as? Bool ?? true
        borderWidth = defaults.object(forKey: "EPUBSettings_borderWidth") as? Double ?? 1.0
        borderStyle = defaults.string(forKey: "EPUBSettings_borderStyle") ?? "solid"
        centerImages = defaults.object(forKey: "EPUBSettings_centerImages") as? Bool ?? true
        maxImageWidth = defaults.object(forKey: "EPUBSettings_maxImageWidth") as? Double ?? 0.9
    }
    
    func setIndentChars(_ chars: Int) {
        indentChars = chars
        defaults.set(chars, forKey: "EPUBSettings_indentChars")
    }
    
    func setLineHeightMultiplier(_ multiplier: Double) {
        lineHeightMultiplier = multiplier
        defaults.set(multiplier, forKey: "EPUBSettings_lineHeightMultiplier")
    }
    
    func resetToDefaults() {
        applyCustomTypography = true
        keepOriginalImageSize = false
        enableImageZoom = true
        autoIndentParagraphs = true
        indentFirstLine = true
        indentChars = 2
        lineHeightMultiplier = 1.5
        headingTopMargin = true
        headingBottomMargin = true
        headingMargin = 1.0
        showBorders = true
        borderWidth = 1.0
        borderStyle = "solid"
        centerImages = true
        maxImageWidth = 0.9
        saveAllSettings()
    }
    
    private func saveAllSettings() {
        defaults.set(applyCustomTypography, forKey: "EPUBSettings_applyCustomTypography")
        defaults.set(keepOriginalImageSize, forKey: "EPUBSettings_keepOriginalImageSize")
        defaults.set(enableImageZoom, forKey: "EPUBSettings_enableImageZoom")
        defaults.set(autoIndentParagraphs, forKey: "EPUBSettings_autoIndentParagraphs")
        defaults.set(indentFirstLine, forKey: "EPUBSettings_indentFirstLine")
        defaults.set(indentChars, forKey: "EPUBSettings_indentChars")
        defaults.set(lineHeightMultiplier, forKey: "EPUBSettings_lineHeightMultiplier")
        defaults.set(headingTopMargin, forKey: "EPUBSettings_headingTopMargin")
        defaults.set(headingBottomMargin, forKey: "EPUBSettings_headingBottomMargin")
        defaults.set(headingMargin, forKey: "EPUBSettings_headingMargin")
        defaults.set(showBorders, forKey: "EPUBSettings_showBorders")
        defaults.set(borderWidth, forKey: "EPUBSettings_borderWidth")
        defaults.set(borderStyle, forKey: "EPUBSettings_borderStyle")
        defaults.set(centerImages, forKey: "EPUBSettings_centerImages")
        defaults.set(maxImageWidth, forKey: "EPUBSettings_maxImageWidth")
    }
}

extension EPUBSettingsManager {
    func generateCSSExtensions() -> String {
        var css = ""
        
        if applyCustomTypography {
            css += """
            
            body {
                line-height: \(String(format: "%.1f", lineHeightMultiplier)) !important;
            }
            """
            
            if autoIndentParagraphs && indentFirstLine {
                css += """
                
                p {
                    text-indent: \(indentChars)em !important;
                }
                """
            }
            
            css += """
            
            h1, h2, h3, h4, h5, h6 {
                margin-top: \(String(format: "%.1f", headingMargin))em !important;
                margin-bottom: \(String(format: "%.1f", headingMargin))em !important;
            }
            """
            
            if !keepOriginalImageSize {
                css += """
                
                img {
                    max-width: \(Int(maxImageWidth * 100))% !important;
                    height: auto !important;
                }
                """
            }
            
            if centerImages {
                css += """
                
                img {
                    display: block !important;
                    margin-left: auto !important;
                    margin-right: auto !important;
                }
                """
            }
        }
        
        return css
    }
}
