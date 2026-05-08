import Foundation
import Combine

class AnnotationService: BaseDataManager<AnnotationService.Annotation> {
    static let shared = AnnotationService()
    
    @Published var annotations: [String: [Annotation]] = [:]
    
    private override init() {
        super.init(dataKey: "AnnotationService_annotations")
        loadAnnotations()
    }
    
    struct Annotation: Identifiable, Codable, Equatable {
        let id: String
        let bookId: String
        let chapterId: String
        let chapterIndex: Int
        let chapterTitle: String
        let bookName: String
        let startOffset: Int
        let endOffset: Int
        let text: String
        var style: AnnotationStyle
        var note: String
        let createdTime: Date
        var modifiedTime: Date
        var tags: [String]
        var colorHex: String
        
        enum AnnotationStyle: String, Codable, CaseIterable {
            case underline = "underline"
            case wavyUnderline = "wavy"
            case dashedUnderline = "dashed"
            case doubleUnderline = "double"
            case thickUnderline = "thick"
            case highlight = "highlight"
            case background = "background"
            case bold = "bold"
            case italic = "italic"
            case boldItalic = "boldItalic"
            case color = "color"
            
            var displayName: String {
                switch self {
                case .underline: return "下划线"
                case .wavyUnderline: return "波浪线"
                case .dashedUnderline: return "虚线"
                case .doubleUnderline: return "双下划线"
                case .thickUnderline: return "粗下划线"
                case .highlight: return "高亮"
                case .background: return "背景色"
                case .bold: return "粗体"
                case .italic: return "斜体"
                case .boldItalic: return "粗斜体"
                case .color: return "字体颜色"
                }
            }
            
            var icon: String {
                switch self {
                case .underline: return "underline"
                case .wavyUnderline: return "waveform"
                case .dashedUnderline: return "line.diagonal"
                case .doubleUnderline: return "equal"
                case .thickUnderline: return "underline.bold"
                case .highlight: return "highlighter"
                case .background: return "rectangle.fill"
                case .bold: return "bold"
                case .italic: return "italic"
                case .boldItalic: return "bold.italic"
                case .color: return "textformat"
                }
            }
            
            var isUnderline: Bool {
                switch self {
                case .underline, .wavyUnderline, .dashedUnderline, .doubleUnderline, .thickUnderline:
                    return true
                default:
                    return false
                }
            }
        }
        
        init(id: String = UUID().uuidString,
             bookId: String,
             chapterId: String,
             chapterIndex: Int,
             chapterTitle: String,
             bookName: String,
             startOffset: Int,
             endOffset: Int,
             text: String,
             style: AnnotationStyle = .highlight,
             note: String = "",
             tags: [String] = [],
             colorHex: String = "#FFF59D") {
            self.id = id
            self.bookId = bookId
            self.chapterId = chapterId
            self.chapterIndex = chapterIndex
            self.chapterTitle = chapterTitle
            self.bookName = bookName
            self.startOffset = startOffset
            self.endOffset = endOffset
            self.text = text
            self.style = style
            self.note = note
            self.createdTime = Date()
            self.modifiedTime = Date()
            self.tags = tags
            self.colorHex = colorHex
        }
    }
    
    struct AnnotationColor: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var hex: String
        var alpha: Double
        
        init(id: String = UUID().uuidString, name: String, hex: String, alpha: Double = 0.5) {
            self.id = id
            self.name = name
            self.hex = hex
            self.alpha = alpha
        }
        
        static let defaultColors: [AnnotationColor] = [
            AnnotationColor(name: "黄色", hex: "#FFF59D", alpha: 0.5),
            AnnotationColor(name: "橙色", hex: "#FFCC80", alpha: 0.5),
            AnnotationColor(name: "绿色", hex: "#A5D6A7", alpha: 0.5),
            AnnotationColor(name: "蓝色", hex: "#90CAF9", alpha: 0.5),
            AnnotationColor(name: "紫色", hex: "#CE93D8", alpha: 0.5),
            AnnotationColor(name: "粉色", hex: "#F48FB1", alpha: 0.5),
            AnnotationColor(name: "红色", hex: "#EF9A9A", alpha: 0.5)
        ]
    }
    
    private func loadAnnotations() {
        if let saved = loadCodable([Annotation].self, key: "all_annotations") {
            for annotation in saved {
                addAnnotationToDict(annotation)
            }
        }
    }
    
    private func addAnnotationToDict(_ annotation: Annotation) {
        if annotations[annotation.bookId] == nil {
            annotations[annotation.bookId] = []
        }
        if !annotations[annotation.bookId]!.contains(where: { $0.id == annotation.id }) {
            annotations[annotation.bookId]!.append(annotation)
        }
    }
    
    var items: [Annotation] {
        annotations.values.flatMap { $0 }
    }
    
    func addAnnotation(_ annotation: Annotation) {
        addAnnotationToDict(annotation)
        saveAllAnnotations()
    }
    
    func updateAnnotation(_ annotation: Annotation) {
        if let bookAnnotations = annotations[annotation.bookId],
           let index = bookAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            var updated = annotation
            updated.modifiedTime = Date()
            annotations[annotation.bookId]![index] = updated
            saveAllAnnotations()
        }
    }
    
    func removeAnnotation(_ annotation: Annotation) {
        annotations[annotation.bookId]?.removeAll { $0.id == annotation.id }
        saveAllAnnotations()
    }
    
    func getAnnotations(for bookId: String) -> [Annotation] {
        return annotations[bookId] ?? []
    }
    
    func getAnnotations(for bookId: String, chapterIndex: Int) -> [Annotation] {
        return getAnnotations(for: bookId).filter { $0.chapterIndex == chapterIndex }
    }
    
    func searchAnnotations(keyword: String) -> [Annotation] {
        guard !keyword.isEmpty else { return items }
        
        return items.filter { annotation in
            annotation.text.localizedCaseInsensitiveContains(keyword) ||
            annotation.note.localizedCaseInsensitiveContains(keyword) ||
            annotation.tags.contains { $0.localizedCaseInsensitiveContains(keyword) }
        }
    }
    
    private func saveAllAnnotations() {
        saveCodable(items, key: "all_annotations")
    }
    
    func exportAnnotations(for bookId: String) -> Data? {
        let bookAnnotations = getAnnotations(for: bookId)
        return encodeJSON(bookAnnotations)
    }
    
    func importAnnotations(from data: Data) -> Bool {
        guard let imported = decodeJSON([Annotation].self, from: data) else {
            return false
        }
        
        for annotation in imported {
            addAnnotation(annotation)
        }
        return true
    }
}

class AnnotationStyleManager: BaseService, ObservableObject {
    static let shared = AnnotationStyleManager()
    
    @Published var currentStyle: AnnotationService.Annotation.AnnotationStyle = .highlight
    @Published var currentColor: AnnotationColor = AnnotationColor.defaultColors[0]
    @Published var recentStyles: [AnnotationService.Annotation.AnnotationStyle] = []
    @Published var recentColors: [AnnotationColor] = []
    
    private let styleKey = "AnnotationStyleManager_currentStyle"
    private let colorKey = "AnnotationStyleManager_currentColor"
    private let recentStylesKey = "AnnotationStyleManager_recentStyles"
    private let recentColorsKey = "AnnotationStyleManager_recentColors"
    
    private override init() {
        super.init()
        loadSettings()
    }
    
    private func loadSettings() {
        if let savedStyle = loadCodable(String.self, key: styleKey),
           let style = AnnotationService.Annotation.AnnotationStyle(rawValue: savedStyle) {
            currentStyle = style
        }
        
        if let savedColor = loadCodable(AnnotationColor.self, key: colorKey) {
            currentColor = savedColor
        }
        
        if let savedRecentStyles = loadCodable([String].self, key: recentStylesKey) {
            recentStyles = savedRecentStyles.compactMap { AnnotationService.Annotation.AnnotationStyle(rawValue: $0) }
        }
        
        if let savedRecentColors = loadCodable([AnnotationColor].self, key: recentColorsKey) {
            recentColors = savedRecentColors
        }
    }
    
    private func saveSettings() {
        saveCodable(currentStyle.rawValue, key: styleKey)
        saveCodable(currentColor, key: colorKey)
        saveCodable(recentStyles.map { $0.rawValue }, key: recentStylesKey)
        saveCodable(recentColors, key: recentColorsKey)
    }
    
    func setCurrentStyle(_ style: AnnotationService.Annotation.AnnotationStyle) {
        currentStyle = style
        recentStyles.removeAll { $0 == style }
        recentStyles.insert(style, at: 0)
        if recentStyles.count > 5 {
            recentStyles = Array(recentStyles.prefix(5))
        }
        saveSettings()
    }
    
    func setCurrentColor(_ color: AnnotationColor) {
        currentColor = color
        recentColors.removeAll { $0.hex == color.hex }
        recentColors.insert(color, at: 0)
        if recentColors.count > 5 {
            recentColors = Array(recentColors.prefix(5))
        }
        saveSettings()
    }
    
    func resetToDefaults() {
        currentStyle = .highlight
        currentColor = AnnotationColor.defaultColors[0]
        recentStyles = []
        recentColors = []
        saveSettings()
    }
}
