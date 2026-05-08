import SwiftUI
import UIKit

struct SelectableReaderContentView: UIViewRepresentable {
    let content: String
    let chapterTitle: String
    let settings: ReaderSettings
    let annotations: [AnnotationService.Annotation]
    let onTextSelected: (String, NSRange) -> Void
    let onAnnotationTapped: (AnnotationService.Annotation) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 50, right: 16)
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.font = UIFont(name: settings.fontFamily, size: settings.fontSize) ?? UIFont.systemFont(ofSize: settings.fontSize)
        textView.textColor = UIColor(settings.currentTextColor)
        textView.isSelectable = true
        textView.dataDetectorTypes = []
        
        applyStyles(to: textView)
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        let attributedString = buildAttributedContent()
        textView.attributedText = attributedString
        
        textView.font = UIFont(name: settings.fontFamily, size: settings.fontSize) ?? UIFont.systemFont(ofSize: settings.fontSize)
        textView.textColor = UIColor(settings.currentTextColor)
        
        applyStyles(to: textView)
    }
    
    private func applyStyles(to textView: UITextView) {
        switch settings.backgroundColor {
        case .white:
            textView.backgroundColor = .white
        case .sepia:
            textView.backgroundColor = UIColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1.0)
        case .green:
            textView.backgroundColor = UIColor(red: 0.85, green: 0.95, blue: 0.85, alpha: 1.0)
        case .blue:
            textView.backgroundColor = UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 1.0)
        case .night:
            textView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        }
    }
    
    private func buildAttributedContent() -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: settings.fontFamily, size: settings.fontSize + 4) ?? UIFont.boldSystemFont(ofSize: settings.fontSize + 4),
            .foregroundColor: UIColor(settings.currentTextColor)
        ]
        let titleString = NSAttributedString(string: chapterTitle + "\n\n", attributes: titleAttributes)
        result.append(titleString)
        
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: settings.fontFamily, size: settings.fontSize) ?? UIFont.systemFont(ofSize: settings.fontSize),
            .foregroundColor: UIColor(settings.currentTextColor),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = settings.lineSpacing * settings.fontSize
                return style
            }()
        ]
        
        let contentString = NSAttributedString(string: content, attributes: contentAttributes)
        result.append(contentString)
        
        for annotation in annotations {
            let range = NSRange(location: annotation.startOffset, length: annotation.endOffset - annotation.startOffset)
            if range.location + range.length <= result.length {
                let color = UIColor(hex: annotation.colorHex)?.withAlphaComponent(0.3) ?? UIColor.yellow.withAlphaComponent(0.3)
                
                switch annotation.style {
                case .highlight:
                    result.addAttribute(.backgroundColor, value: color, range: range)
                case .underline:
                    result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                case .wavyUnderline:
                    result.addAttribute(.underlineStyle, value: NSUnderlineStyle.patternDot.rawValue | NSUnderlineStyle.single.rawValue, range: range)
                case .color:
                    result.addAttribute(.foregroundColor, value: UIColor(hex: annotation.colorHex) ?? UIColor.red, range: range)
                default:
                    result.addAttribute(.backgroundColor, value: color, range: range)
                }
            }
        }
        
        return result
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableReaderContentView
        private var menuController: UIMenuController?
        
        init(_ parent: SelectableReaderContentView) {
            self.parent = parent
            super.init()
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange,
                  !selectedRange.isEmpty else {
                return
            }
            
            let selectedText = textView.text(in: selectedRange) ?? ""
            
            if let start = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start) as Int? {
                let end = start + (selectedText as NSString).length
                parent.onTextSelected(selectedText, NSRange(location: start, length: end))
            }
        }
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
