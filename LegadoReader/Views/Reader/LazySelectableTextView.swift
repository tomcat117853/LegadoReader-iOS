import SwiftUI
import UIKit

struct LazySelectableTextView: UIViewRepresentable {
    let chapterTitle: String
    let content: String
    let fontSize: CGFloat
    let fontFamily: String
    let lineSpacing: CGFloat
    let horizontalPadding: CGFloat
    let textColor: Color
    let annotations: [AnnotationService.Annotation]
    let onTextSelected: (String, NSRange) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 16, left: horizontalPadding, bottom: 50, right: horizontalPadding)
        textView.backgroundColor = .clear
        textView.isSelectable = true
        textView.dataDetectorTypes = []
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        let attributedString = buildAttributedContent()
        textView.attributedText = attributedString
    }
    
    private func buildAttributedContent() -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize + 4, weight: .bold),
            .foregroundColor: UIColor(textColor)
        ]
        let titleString = NSAttributedString(string: chapterTitle + "\n\n", attributes: titleAttributes)
        result.append(titleString)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: fontFamily, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor(textColor),
            .paragraphStyle: paragraphStyle
        ]
        
        let contentString = NSAttributedString(string: content, attributes: contentAttributes)
        result.append(contentString)
        
        let titleLength = chapterTitle.count + 2
        
        for annotation in annotations {
            let adjustedStart = annotation.startOffset + titleLength
            let adjustedEnd = annotation.endOffset + titleLength
            
            guard adjustedStart >= 0, adjustedEnd <= result.length, adjustedStart < adjustedEnd else {
                continue
            }
            
            let range = NSRange(location: adjustedStart, length: adjustedEnd - adjustedStart)
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
        
        return result
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: LazySelectableTextView
        
        init(_ parent: LazySelectableTextView) {
            self.parent = parent
            super.init()
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange,
                  !selectedRange.isEmpty else {
                return
            }
            
            let selectedText = textView.text(in: selectedRange) ?? ""
            let titleLength = parent.chapterTitle.count + 2
            
            if let start = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start) as Int? {
                let adjustedStart = max(0, start - titleLength)
                let end = start + (selectedText as NSString).length
                let adjustedEnd = min(end - titleLength, (textView.text as NSString).length - titleLength)
                
                if adjustedStart < adjustedEnd {
                    parent.onTextSelected(selectedText, NSRange(location: adjustedStart, length: adjustedEnd - adjustedStart))
                }
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
