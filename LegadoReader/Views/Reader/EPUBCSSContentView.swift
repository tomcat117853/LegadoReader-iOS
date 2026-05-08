import SwiftUI
import UIKit
import WebKit

struct EPUBCSSContentView: UIViewRepresentable {
    let chapter: BookChapterContent
    let baseURL: URL?
    let fontSize: CGFloat
    let fontFamily: String
    let backgroundColor: Color
    let textColor: Color
    let annotations: [AnnotationService.Annotation]
    let onTextSelected: (String, NSRange) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = false
        config.allowsInlineMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsLinkPreview = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = buildHTML()
        webView.loadHTMLString(html, baseURL: baseURL)
    }
    
    private func buildHTML() -> String {
        let bgColor = UIColor(backgroundColor).toHexString() ?? "#FFFFFF"
        let txtColor = UIColor(textColor).toHexString() ?? "#000000"
        
        let cssStyles = buildCSS(fontSize: fontSize, fontFamily: fontFamily, bgColor: bgColor, txtColor: txtColor)
        
        let annotatedContent = applyAnnotations(to: chapter.content)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
            \(cssStyles)
            </style>
        </head>
        <body>
            <article class="chapter-content">
                <h1 class="chapter-title">\(chapter.title)</h1>
                <div class="chapter-body">
                    \(annotatedContent)
                </div>
            </article>
        </body>
        </html>
        """
    }
    
    private func buildCSS(fontSize: CGFloat, fontFamily: String, bgColor: String, txtColor: String) -> String {
        return """
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: '\(fontFamily)', -apple-system, sans-serif;
            font-size: \(fontSize)px;
            line-height: 1.8;
            color: \(txtColor);
            background-color: \(bgColor);
            padding: 16px;
            -webkit-text-size-adjust: 100%;
        }
        
        .chapter-content {
            max-width: 100%;
        }
        
        .chapter-title {
            font-size: \(fontSize + 6)px;
            font-weight: bold;
            text-align: center;
            margin-bottom: 24px;
            padding: 16px 0;
            color: \(txtColor);
        }
        
        .chapter-body {
            text-align: justify;
        }
        
        p {
            margin-bottom: 1em;
            text-indent: 2em;
        }
        
        h1, h2, h3, h4, h5, h6 {
            margin: 1.5em 0 0.5em 0;
            font-weight: bold;
            line-height: 1.3;
        }
        
        h1 { font-size: \(fontSize + 10)px; }
        h2 { font-size: \(fontSize + 8)px; }
        h3 { font-size: \(fontSize + 6)px; }
        h4 { font-size: \(fontSize + 4)px; }
        h5 { font-size: \(fontSize + 2)px; }
        h6 { font-size: \(fontSize)px; }
        
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 1em auto;
        }
        
        blockquote {
            margin: 1em 0;
            padding: 0.5em 1em;
            border-left: 4px solid #ddd;
            background-color: rgba(0,0,0,0.05);
            font-style: italic;
        }
        
        pre, code {
            font-family: 'Menlo', monospace;
            font-size: \(fontSize - 2)px;
            background-color: rgba(0,0,0,0.05);
            border-radius: 4px;
        }
        
        pre {
            padding: 1em;
            overflow-x: auto;
        }
        
        code {
            padding: 0.2em 0.4em;
        }
        
        pre code {
            padding: 0;
            background: none;
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
        
        .highlight-yellow {
            background-color: rgba(255, 245, 157, 0.5);
        }
        
        .highlight-orange {
            background-color: rgba(255, 204, 128, 0.5);
        }
        
        .highlight-green {
            background-color: rgba(165, 214, 167, 0.5);
        }
        
        .highlight-blue {
            background-color: rgba(144, 202, 249, 0.5);
        }
        
        .highlight-purple {
            background-color: rgba(206, 147, 216, 0.5);
        }
        
        .underline {
            text-decoration: underline;
        }
        
        .wavy-underline {
            text-decoration: underline wavy;
        }
        
        a {
            color: #007AFF;
            text-decoration: none;
        }
        
        ul, ol {
            margin: 1em 0;
            padding-left: 2em;
        }
        
        li {
            margin-bottom: 0.5em;
        }
        
        hr {
            border: none;
            border-top: 1px solid #ddd;
            margin: 2em 0;
        }
        
        .text-selection-enabled {
            -webkit-user-select: text;
            user-select: text;
        }
        """
    }
    
    private func applyAnnotations(to html: String) -> String {
        guard !annotations.isEmpty else { return html }
        
        var processed = html
        let sortedAnnotations = annotations.sorted { $0.startOffset > $1.startOffset }
        
        for annotation in sortedAnnotations {
            guard annotation.startOffset < annotation.endOffset,
                  annotation.startOffset >= 0,
                  annotation.endOffset <= processed.count else {
                continue
            }
            
            let startIndex = processed.index(processed.startIndex, offsetBy: annotation.startOffset)
            let endIndex = processed.index(processed.startIndex, offsetBy: annotation.endOffset)
            
            let colorClass = getColorClass(for: annotation.colorHex)
            let styleClass = getStyleClass(for: annotation.style)
            
            let span = "<span class=\"\(colorClass) \(styleClass)\">"
            let closeSpan = "</span>"
            
            processed.insert(contentsOf: closeSpan, at: endIndex)
            processed.insert(contentsOf: "</span>", at: startIndex)
        }
        
        return processed
    }
    
    private func getColorClass(for hex: String) -> String {
        let normalizedHex = hex.uppercased()
        switch normalizedHex {
        case "#FFF59D", "FFF59D": return "highlight-yellow"
        case "#FFCC80", "FFCC80": return "highlight-orange"
        case "#A5D6A7", "A5D6A7": return "highlight-green"
        case "#90CAF9", "90CAF9": return "highlight-blue"
        case "#CE93D8", "CE93D8": return "highlight-purple"
        default: return "highlight-yellow"
        }
    }
    
    private func getStyleClass(for style: AnnotationService.Annotation.AnnotationStyle) -> String {
        switch style {
        case .highlight: return ""
        case .underline: return "underline"
        case .wavyUnderline: return "wavy-underline"
        default: return ""
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EPUBCSSContentView
        
        init(_ parent: EPUBCSSContentView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
            webView.evaluateJavaScript("document.body.classList.add('text-selection-enabled');") { _, _ in }
        }
    }
}

extension UIColor {
    func toHexString() -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard self.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        
        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255) << 0
        
        return String(format: "#%06X", rgb)
    }
}
