import Foundation
import Combine

class NoteTemplateManager: BaseService {
    static let shared = NoteTemplateManager()
    
    @Published var templates: [NoteTemplate] = []
    @Published var recentTemplates: [NoteTemplate] = []
    
    private let templatesKey = "NoteTemplateManager_templates"
    private let recentKey = "NoteTemplateManager_recent"
    
    struct NoteTemplate: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var content: String
        var category: TemplateCategory
        var color: TemplateColor
        var icon: String
        var isDefault: Bool
        var usageCount: Int
        let createdTime: Date
        var lastUsedTime: Date
        
        enum TemplateCategory: String, Codable, CaseIterable {
            case custom = "custom"
            case reading = "reading"
            case thinking = "thinking"
            case summary = "summary"
            case question = "question"
            case favorite = "favorite"
            
            var displayName: String {
                switch self {
                case .custom: return "自定义"
                case .reading: return "阅读感想"
                case .thinking: return "思考笔记"
                case .summary: return "章节总结"
                case .question: return "疑问"
                case .favorite: return "精彩片段"
                }
            }
            
            var icon: String {
                switch self {
                case .custom: return "✨"
                case .reading: return "💭"
                case .thinking: return "🤔"
                case .summary: return "📝"
                case .question: return "❓"
                case .favorite: return "⭐"
                }
            }
        }
        
        enum TemplateColor: String, Codable, CaseIterable {
            case red = "red"
            case orange = "orange"
            case yellow = "yellow"
            case green = "green"
            case blue = "blue"
            case purple = "purple"
            case pink = "pink"
            
            var displayName: String {
                switch self {
                case .red: return "红色"
                case .orange: return "橙色"
                case .yellow: return "黄色"
                case .green: return "绿色"
                case .blue: return "蓝色"
                case .purple: return "紫色"
                case .pink: return "粉色"
                }
            }
            
            var hexColor: String {
                switch self {
                case .red: return "#FF3B30"
                case .orange: return "#FF9500"
                case .yellow: return "#FFCC00"
                case .green: return "#34C759"
                case .blue: return "#007AFF"
                case .purple: return "#AF52DE"
                case .pink: return "#FF2D55"
                }
            }
        }
    }
    
    private init() {
        super.init()
        loadTemplates()
        loadRecentTemplates()
    }
    
    private func loadTemplates() {
        if let saved = loadCodable([NoteTemplate].self, key: templatesKey) {
            templates = saved
        } else {
            templates = defaultTemplates
            saveTemplates()
        }
    }
    
    private func saveTemplates() {
        saveCodable(templates, key: templatesKey)
    }
    
    private func loadRecentTemplates() {
        if let saved = loadCodable([NoteTemplate].self, key: recentKey) {
            recentTemplates = saved
        }
    }
    
    private func saveRecentTemplates() {
        saveCodable(recentTemplates, key: recentKey)
    }
    
    private var defaultTemplates: [NoteTemplate] {
        [
            NoteTemplate(
                id: UUID().uuidString,
                name: "精彩语句",
                content: "这段文字写得真好，记录下来：\n「{{selected_text}}」\n\n阅读时间：{{date}}",
                category: .favorite,
                color: .yellow,
                icon: "⭐",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "阅读感想",
                content: "📖 阅读笔记\n\n「{{selected_text}}」\n\n💭 我的感想：\n\n{{content}}",
                category: .reading,
                color: .blue,
                icon: "💭",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "章节总结",
                content: "📝 章节总结\n\n章节：{{chapter_title}}\n\n主要内容：\n{{content}}\n\n关键点：\n1. \n2. \n3. ",
                category: .summary,
                color: .green,
                icon: "📝",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "疑问记录",
                content: "❓ 疑问笔记\n\n「{{selected_text}}」\n\n🤔 我的疑问：\n{{content}}\n\n🔍 查找答案：",
                category: .question,
                color: .purple,
                icon: "❓",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "思考延伸",
                content: "🤔 思考笔记\n\n「{{selected_text}}」\n\n📚 相关知识点：\n\n💡 延伸思考：\n\n📖 参考资料：",
                category: .thinking,
                color: .orange,
                icon: "🤔",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "人物分析",
                content: "👤 人物笔记\n\n📖 涉及内容：「{{selected_text}}」\n\n👤 人物特点：\n\n💭 人物评价：\n\n📌 相关情节：",
                category: .custom,
                color: .pink,
                icon: "👤",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "写作技巧",
                content: "✍️ 写作技巧笔记\n\n📖 示例：「{{selected_text}}」\n\n🎯 技巧分析：\n\n💡 可借鉴之处：\n\n📝 实践应用：",
                category: .custom,
                color: .red,
                icon: "✍️",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "金句摘录",
                content: "💎 金句摘录\n\n「{{selected_text}}」\n\n📚 出处：{{book_title}} - {{chapter_title}}\n\n🌟 摘录理由：\n{{content}}",
                category: .favorite,
                color: .yellow,
                icon: "💎",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "待查资料",
                content: "📚 待查资料\n\n📖 相关内容：「{{selected_text}}」\n\n❓ 待查问题：\n{{content}}\n\n📅 计划时间：",
                category: .question,
                color: .blue,
                icon: "📚",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            ),
            NoteTemplate(
                id: UUID().uuidString,
                name: "心情记录",
                content: "💗 阅读心情\n\n📖 内容：「{{selected_text}}」\n\n😊 当时心情：\n\n🎵 配乐推荐：\n\n📝 心情描述：",
                category: .custom,
                color: .pink,
                icon: "💗",
                isDefault: true,
                usageCount: 0,
                createdTime: Date(),
                lastUsedTime: Date()
            )
        ]
    }
    
    func addTemplate(_ template: NoteTemplate) {
        templates.append(template)
        saveTemplates()
    }
    
    func updateTemplate(_ template: NoteTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
        }
    }
    
    func removeTemplate(_ template: NoteTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }
    
    func removeTemplate(id: String) {
        templates.removeAll { $0.id == id }
        saveTemplates()
    }
    
    func useTemplate(_ template: NoteTemplate, selectedText: String = "", bookTitle: String = "", chapterTitle: String = "") {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index].usageCount += 1
            templates[index].lastUsedTime = Date()
            saveTemplates()
            
            recentTemplates.removeAll { $0.id == template.id }
            recentTemplates.insert(templates[index], at: 0)
            if recentTemplates.count > 10 {
                recentTemplates = Array(recentTemplates.prefix(10))
            }
            saveRecentTemplates()
        }
    }
    
    func getTemplates(for category: NoteTemplate.TemplateCategory) -> [NoteTemplate] {
        return templates.filter { $0.category == category }
    }
    
    func getTemplates(sortedBy: SortOption) -> [NoteTemplate] {
        switch sortedBy {
        case .name:
            return templates.sorted { $0.name < $1.name }
        case .usageCount:
            return templates.sorted { $0.usageCount > $1.usageCount }
        case .recentlyUsed:
            return templates.sorted { $0.lastUsedTime > $1.lastUsedTime }
        case .createdTime:
            return templates.sorted { $0.createdTime > $1.createdTime }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case name = "名称"
        case usageCount = "使用次数"
        case recentlyUsed = "最近使用"
        case createdTime = "创建时间"
    }
    
    func applyTemplate(_ template: NoteTemplate, selectedText: String = "", bookTitle: String = "", chapterTitle: String = "") -> String {
        var result = template.content
        
        result = result.replacingOccurrences(of: "{{selected_text}}", with: selectedText)
        result = result.replacingOccurrences(of: "{{book_title}}", with: bookTitle)
        result = result.replacingOccurrences(of: "{{chapter_title}}", with: chapterTitle)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        result = result.replacingOccurrences(of: "{{date}}", with: dateFormatter.string(from: Date()))
        
        let dateFormatter2 = DateFormatter()
        dateFormatter2.dateFormat = "yyyy年MM月dd日"
        result = result.replacingOccurrences(of: "{{date_only}}", with: dateFormatter2.string(from: Date()))
        
        result = result.replacingOccurrences(of: "{{content}}", with: "")
        
        return result
    }
    
    func duplicateTemplate(_ template: NoteTemplate) {
        let newTemplate = NoteTemplate(
            id: UUID().uuidString,
            name: "\(template.name) (副本)",
            content: template.content,
            category: template.category,
            color: template.color,
            icon: template.icon,
            isDefault: false,
            usageCount: 0,
            createdTime: Date(),
            lastUsedTime: Date()
        )
        addTemplate(newTemplate)
    }
    
    func resetToDefaults() {
        templates = defaultTemplates
        saveTemplates()
    }
    
    func searchTemplates(_ keyword: String) -> [NoteTemplate] {
        guard !keyword.isEmpty else { return templates }
        
        return templates.filter { template in
            template.name.contains(keyword) ||
            template.content.contains(keyword)
        }
    }
    
    func exportTemplates() -> Data? {
        return encodeJSON(templates)
    }
    
    func importTemplates(from data: Data) -> Bool {
        guard let imported = decodeJSON([NoteTemplate].self, from: data) else {
            return false
        }
        
        for item in imported {
            if !templates.contains(where: { $0.id == item.id }) {
                let newItem = NoteTemplate(
                    id: UUID().uuidString,
                    name: item.name,
                    content: item.content,
                    category: item.category,
                    color: item.color,
                    icon: item.icon,
                    isDefault: false,
                    usageCount: item.usageCount,
                    createdTime: item.createdTime,
                    lastUsedTime: item.lastUsedTime
                )
                templates.append(newItem)
            }
        }
        
        saveTemplates()
        return true
    }
}

extension NoteTemplateManager {
    func replaceVariables(_ template: String, selectedText: String, bookTitle: String, author: String, chapter: String, page: Int, date: Date) -> String {
        var result = template
        
        result = result.replacingOccurrences(of: "{{selected_text}}", with: selectedText)
        result = result.replacingOccurrences(of: "{{book_title}}", with: bookTitle)
        result = result.replacingOccurrences(of: "{{author}}", with: author)
        result = result.replacingOccurrences(of: "{{chapter}}", with: chapter)
        result = result.replacingOccurrences(of: "{{page}}", with: "\(page)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        result = result.replacingOccurrences(of: "{{date}}", with: dateFormatter.string(from: date))
        
        return result
    }
    
    func getCategories() -> [NoteTemplate.TemplateCategory] {
        return NoteTemplate.TemplateCategory.allCases
    }
    
    func getTemplates() -> [NoteTemplate] {
        return templates
    }
}
