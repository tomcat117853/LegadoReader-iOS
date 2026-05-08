import Foundation
import UIKit
import Combine

class TextLayoutManager: ObservableObject {
    static let shared = TextLayoutManager()
    
    @Published var currentLayout: TextLayout = .horizontal
    @Published var verticalTextDirection: VerticalDirection = .ttb
    @Published var lineSpacingMultiplier: CGFloat = 1.5
    @Published var paragraphSpacing: CGFloat = 16
    @Published var textAlignment: TextAlignment = .leading
    
    private let defaults = UserDefaults.standard
    
    enum TextLayout: String, CaseIterable, Identifiable {
        case horizontal = "horizontal"
        case vertical = "vertical"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .horizontal: return "横排"
            case .vertical: return "竖排"
            }
        }
        
        var icon: String {
            switch self {
            case .horizontal: return "text.alignleft"
            case .vertical: return "text.alignleft.vertical"
            }
        }
    }
    
    enum VerticalDirection: String, CaseIterable, Identifiable {
        case ttb = "ttb"
        case btt = "btt"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .ttb: return "从上到下"
            case .btt: return "从下到上"
            }
        }
        
        var description: String {
            switch self {
            case .ttb: return "文字从上往下排列"
            case .btt: return "文字从下往上排列"
            }
        }
    }
    
    enum TextAlignment: String, CaseIterable, Identifiable {
        case leading = "leading"
        case center = "center"
        case justified = "justified"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .leading: return "左对齐"
            case .center: return "居中"
            case .justified: return "两端对齐"
            }
        }
    }
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        if let layoutString = defaults.string(forKey: "TextLayout_layout"),
           let layout = TextLayout(rawValue: layoutString) {
            currentLayout = layout
        }
        
        if let directionString = defaults.string(forKey: "TextLayout_direction"),
           let direction = VerticalDirection(rawValue: directionString) {
            verticalTextDirection = direction
        }
        
        let lineSpacing = defaults.double(forKey: "TextLayout_lineSpacing")
        if lineSpacing > 0 {
            lineSpacingMultiplier = CGFloat(lineSpacing)
        }
        
        let paragraph = defaults.double(forKey: "TextLayout_paragraphSpacing")
        if paragraph > 0 {
            paragraphSpacing = CGFloat(paragraph)
        }
        
        if let alignmentString = defaults.string(forKey: "TextLayout_alignment"),
           let alignment = TextAlignment(rawValue: alignmentString) {
            textAlignment = alignment
        }
    }
    
    func saveSettings() {
        defaults.set(currentLayout.rawValue, forKey: "TextLayout_layout")
        defaults.set(verticalTextDirection.rawValue, forKey: "TextLayout_direction")
        defaults.set(Double(lineSpacingMultiplier), forKey: "TextLayout_lineSpacing")
        defaults.set(Double(paragraphSpacing), forKey: "TextLayout_paragraphSpacing")
        defaults.set(textAlignment.rawValue, forKey: "TextLayout_alignment")
    }
    
    func setLayout(_ layout: TextLayout) {
        currentLayout = layout
        saveSettings()
    }
    
    func setVerticalDirection(_ direction: VerticalDirection) {
        verticalTextDirection = direction
        saveSettings()
    }
    
    func setLineSpacing(_ spacing: CGFloat) {
        lineSpacingMultiplier = spacing
        saveSettings()
    }
    
    func setParagraphSpacing(_ spacing: CGFloat) {
        paragraphSpacing = spacing
        saveSettings()
    }
    
    func setTextAlignment(_ alignment: TextAlignment) {
        textAlignment = alignment
        saveSettings()
    }
    
    func toggleLayout() {
        currentLayout = currentLayout == .horizontal ? .vertical : .horizontal
        saveSettings()
    }
}

extension TextLayoutManager {
    func getLayoutAttributes() -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        switch currentLayout {
        case .horizontal:
            attributes[.verticalForm] = false
        case .vertical:
            attributes[.verticalForm] = true
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (lineSpacingMultiplier - 1) * 14
        paragraphStyle.paragraphSpacing = paragraphSpacing
        paragraphStyle.firstLineHeadIndent = 0
        
        switch textAlignment {
        case .leading:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .justified:
            paragraphStyle.alignment = .justified
        }
        
        attributes[.paragraphStyle] = paragraphStyle
        
        return attributes
    }
    
    func getVerticalTextAttributes(fontSize: CGFloat, fontName: String = "PingFang SC") -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        attributes[.font] = font
        
        attributes[.verticalForm] = true
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (lineSpacingMultiplier - 1) * fontSize
        paragraphStyle.paragraphSpacing = paragraphSpacing
        
        switch textAlignment {
        case .leading:
            paragraphStyle.alignment = verticalTextDirection == .ttb ? .left : .right
        case .center:
            paragraphStyle.alignment = .center
        case .justified:
            paragraphStyle.alignment = .justified
        }
        
        attributes[.paragraphStyle] = paragraphStyle
        
        return attributes
    }
    
    func getHorizontalTextAttributes(fontSize: CGFloat, fontName: String = "PingFang SC") -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        attributes[.font] = font
        
        attributes[.verticalForm] = false
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (lineSpacingMultiplier - 1) * fontSize
        paragraphStyle.paragraphSpacing = paragraphSpacing
        
        switch textAlignment {
        case .leading:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .justified:
            paragraphStyle.alignment = .justified
        }
        
        attributes[.paragraphStyle] = paragraphStyle
        
        return attributes
    }
}

extension TextLayoutManager {
    func formatVerticalText(_ text: String) -> String {
        guard currentLayout == .vertical else { return text }
        
        let lines = text.components(separatedBy: "\n")
        var formattedLines: [String] = []
        
        for line in lines {
            let chars = Array(line)
            var verticalLine = ""
            
            for (index, char) in chars.enumerated() {
                verticalLine += String(char)
                
                if index < chars.count - 1 {
                    verticalLine += "\n"
                }
            }
            
            formattedLines.append(verticalLine)
        }
        
        return formattedLines.joined(separator: "\n")
    }
    
    func splitIntoColumns(_ text: String, columnCount: Int, pageWidth: CGFloat) -> [[String]] {
        guard currentLayout == .vertical, columnCount > 1 else {
            return [[text]]
        }
        
        let lines = text.components(separatedBy: "\n")
        let linesPerColumn = Int(ceil(Double(lines.count) / Double(columnCount)))
        
        var columns: [[String]] = []
        
        for i in 0..<columnCount {
            let startIndex = i * linesPerColumn
            let endIndex = min(startIndex + linesPerColumn, lines.count)
            
            if startIndex < lines.count {
                let columnLines = Array(lines[startIndex..<endIndex])
                columns.append(columnLines)
            }
        }
        
        return columns
    }
}

extension TextLayoutManager {
    func applyLayoutToText(_ text: String, fontSize: CGFloat, fontName: String = "PingFang SC") -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any]
        
        if currentLayout == .vertical {
            attributes = getVerticalTextAttributes(fontSize: fontSize, fontName: fontName)
        } else {
            attributes = getHorizontalTextAttributes(fontSize: fontSize, fontName: fontName)
        }
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    func getReadingOrder(for text: String) -> [(line: Int, charIndex: Int, char: Character)] {
        var result: [(line: Int, charIndex: Int, char: Character)] = []
        
        let lines = text.components(separatedBy: "\n")
        
        for (lineIndex, line) in lines.enumerated() {
            let chars = Array(line)
            
            if currentLayout == .vertical {
                if verticalTextDirection == .ttb {
                    for (charIndex, char) in chars.enumerated() {
                        result.append((line: charIndex, charIndex: lineIndex, char: char))
                    }
                } else {
                    for (charIndex, char) in chars.enumerated().reversed() {
                        result.append((line: chars.count - 1 - charIndex, charIndex: lineIndex, char: char))
                    }
                }
            } else {
                for (charIndex, char) in chars.enumerated() {
                    result.append((line: lineIndex, charIndex: charIndex, char: char))
                }
            }
        }
        
        return result
    }
}
