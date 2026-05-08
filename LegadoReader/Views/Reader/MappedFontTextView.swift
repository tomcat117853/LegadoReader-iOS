import SwiftUI
import UIKit

struct MappedFontTextView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: UIColor
    let lineSpacing: CGFloat
    let textAlignment: NSTextAlignment
    let mappingManager = FontMappingManager.shared
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = createAttributedString()
        uiView.textAlignment = textAlignment
    }
    
    private func createAttributedString() -> NSAttributedString {
        if !mappingManager.enabled {
            return NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont(name: mappingManager.defaultFont, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize),
                    .foregroundColor: textColor,
                    .kern: lineSpacing
                ]
            )
        }
        
        let attributedString = NSMutableAttributedString(string: text)
        
        var currentFontName = ""
        var rangeStart = 0
        
        for (index, char) in text.enumerated() {
            let fontName = mappingManager.getFontName(for: char)
            
            if fontName != currentFontName {
                if rangeStart < index {
                    let range = NSRange(location: rangeStart, length: index - rangeStart)
                    let font = UIFont(name: currentFontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
                    attributedString.addAttributes([
                        .font: font,
                        .foregroundColor: textColor,
                        .kern: lineSpacing
                    ], range: range)
                }
                currentFontName = fontName
                rangeStart = index
            }
        }
        
        if rangeStart < text.count {
            let range = NSRange(location: rangeStart, length: text.count - rangeStart)
            let font = UIFont(name: currentFontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            attributedString.addAttributes([
                .font: font,
                .foregroundColor: textColor,
                .kern: lineSpacing
            ], range: range)
        }
        
        return attributedString
    }
}

struct MappedFontText: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let lineSpacing: CGFloat
    let textAlignment: TextAlignment
    
    @StateObject private var mappingManager = FontMappingManager.shared
    
    var body: some View {
        if mappingManager.enabled {
            MappedFontTextView(
                text: text,
                fontSize: fontSize,
                textColor: textColor.uiColor,
                lineSpacing: lineSpacing,
                textAlignment: textAlignment.nsTextAlignment
            )
        } else {
            Text(text)
                .font(.custom(mappingManager.defaultFont, size: fontSize))
                .foregroundColor(textColor)
                .lineSpacing(lineSpacing)
                .multilineTextAlignment(textAlignment)
        }
    }
}

extension TextAlignment {
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        @unknown default: return .left
        }
    }
}

struct MappedFontTextView_Previews: PreviewProvider {
    static var previews: some View {
        MappedFontText(
            text: "中文 English 日本語 한국어 123",
            fontSize: 18,
            textColor: .black,
            lineSpacing: 8,
            textAlignment: .leading
        )
        .padding()
    }
}