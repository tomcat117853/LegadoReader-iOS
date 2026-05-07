import Foundation

class ContentFilterManager: ObservableObject {
    static let shared = ContentFilterManager()
    
    @Published var filters: [FilterRule] = []
    @Published var isEnabled = true
    
    private let defaults = UserDefaults.standard
    private let filtersKey = "ContentFilter_filters"
    private let enabledKey = "ContentFilter_enabled"
    
    struct FilterRule: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var pattern: String
        var replacement: String
        var type: FilterType
        var isEnabled: Bool
        var category: String
        
        enum FilterType: String, Codable, CaseIterable, Identifiable {
            case regex = "regex"
            case keyword = "keyword"
            case replace = "replace"
            case removeLines = "removeLines"
            
            var id: String { rawValue }
            
            var displayName: String {
                switch self {
                case .regex: return "正则表达式"
                case .keyword: return "关键词过滤"
                case .replace: return "文本替换"
                case .removeLines: return "删除整行"
                }
            }
        }
        
        enum Category: String, Codable, CaseIterable, Identifiable {
            case ads = "ads"
            case vulgar = "vulgar"
            case watermark = "watermark"
            case custom = "custom"
            
            var id: String { rawValue }
            
            var displayName: String {
                switch self {
                case .ads: return "广告"
                case .vulgar: return "低俗内容"
                case .watermark: return "水印"
                case .custom: return "自定义"
                }
            }
        }
    }
    
    private init() {
        loadFilters()
        loadEnabled()
    }
    
    private func loadFilters() {
        if let data = defaults.data(forKey: filtersKey),
           let savedFilters = try? JSONDecoder().decode([FilterRule].self, from: data) {
            filters = savedFilters
        } else {
            filters = loadDefaultFilters()
        }
    }
    
    private func loadEnabled() {
        isEnabled = defaults.bool(forKey: enabledKey)
        if !defaults.bool(forKey: enabledKey) {
            isEnabled = true
        }
    }
    
    private func saveFilters() {
        if let data = try? JSONEncoder().encode(filters) {
            defaults.set(data, forKey: filtersKey)
        }
    }
    
    func saveEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: enabledKey)
    }
    
    private func loadDefaultFilters() -> [FilterRule] {
        var allFilters: [FilterRule] = []
        
        allFilters.append(contentsOf: defaultAdFilters)
        allFilters.append(contentsOf: defaultVulgarFilters)
        allFilters.append(contentsOf: defaultWatermarkFilters)
        
        return allFilters
    }
    
    private var defaultAdFilters: [FilterRule] {
        [
            FilterRule(id: UUID().uuidString, name: "网站域名", pattern: "【.*www\\..*\\.com】", replacement: "", type: .regex, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "网址过滤", pattern: "www\\..*\\.com", replacement: "", type: .regex, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "微信公众号", pattern: "微信公众号", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "订阅提示", pattern: "订阅", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "加微信", pattern: "加微信", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "QQ群", pattern: "QQ群", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "弹窗广告", pattern: "请记住本站域名", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "下载APP", pattern: "下载APP", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "笔趣阁", pattern: "笔趣阁", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "顶点小说", pattern: "顶点小说", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "全本小说网", pattern: "全本小说网", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "最新章节", pattern: "最新章节", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "全文阅读", pattern: "全文阅读", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "无弹窗", pattern: "无弹窗", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "本站首发", pattern: "本站首发", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "版权声明", pattern: "版权声明", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "手机版", pattern: "手机版", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "更新时间", pattern: "更新时间：", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "作者：", pattern: "作者：", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "书名：", pattern: "书名：", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "字数：", pattern: "字数：", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "状态：", pattern: "状态：", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "内容简介", pattern: "内容简介", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "加入书架", pattern: "加入书架", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "推荐票", pattern: "推荐票", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "月票", pattern: "月票", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "打赏", pattern: "打赏", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "收藏", pattern: "收藏", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "分享", pattern: "分享", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "章节目录", pattern: "章节目录", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "本章完", pattern: "本章完", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "下一章", pattern: "下一章", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "上一章", pattern: "上一章", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "返回目录", pattern: "返回目录", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "VIP章节", pattern: "VIP章节", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "付费章节", pattern: "付费章节", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "充值", pattern: "充值", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "会员", pattern: "会员", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "支持正版", pattern: "支持正版", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "版权所有", pattern: "版权所有", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "严禁转载", pattern: "严禁转载", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "免责声明", pattern: "免责声明", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "网站地图", pattern: "网站地图", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "联系我们", pattern: "联系我们", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "关于我们", pattern: "关于我们", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "用户协议", pattern: "用户协议", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "隐私政策", pattern: "隐私政策", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "友情链接", pattern: "友情链接", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "排行榜", pattern: "排行榜", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "热门推荐", pattern: "热门推荐", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "编辑推荐", pattern: "编辑推荐", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "活动", pattern: "活动", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "签到", pattern: "签到", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "任务", pattern: "任务", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "积分", pattern: "积分", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "金币", pattern: "金币", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "个人中心", pattern: "个人中心", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "我的书架", pattern: "我的书架", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "系统消息", pattern: "系统消息", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "公告", pattern: "公告", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "置顶", pattern: "置顶", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "热门", pattern: "热门", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "最新", pattern: "最新", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "精选", pattern: "精选", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "独家", pattern: "独家", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "首发", pattern: "首发", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "完本", pattern: "完本", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "连载", pattern: "连载", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "上一页", pattern: "上一页", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "下一页", pattern: "下一页", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "共\\d+页", pattern: "共\\d+页", replacement: "", type: .regex, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "阅读记录", pattern: "阅读记录", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "书签", pattern: "书签", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "笔记", pattern: "笔记", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "分享到", pattern: "分享到", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "举报", pattern: "举报", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "反馈", pattern: "反馈", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "帮助", pattern: "帮助", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "客服热线", pattern: "客服热线", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "QQ客服", pattern: "QQ客服", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "微信客服", pattern: "微信客服", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "官方公众号", pattern: "官方公众号", replacement: "", type: .keyword, isEnabled: true, category: "ads"),
            FilterRule(id: UUID().uuidString, name: "官方微博", pattern: "官方微博", replacement: "", type: .keyword, isEnabled: true, category: "ads")
        ]
    }
    
    private var defaultVulgarFilters: [FilterRule] {
        [
            FilterRule(id: UUID().uuidString, name: "低俗词1", pattern: "操", replacement: "*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词2", pattern: "艹", replacement: "*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词3", pattern: "日", replacement: "*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词4", pattern: "他妈", replacement: "他*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词5", pattern: "逼", replacement: "*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词6", pattern: "傻逼", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词7", pattern: "娘炮", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词8", pattern: "靠", replacement: "*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词9", pattern: "卧槽", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词10", pattern: "你妹", replacement: "你*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词11", pattern: "尼玛", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词12", pattern: "吊", replacement: "*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词13", pattern: "屌", replacement: "*", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词14", pattern: "鸡巴", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词15", pattern: "阴茎", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词16", pattern: "阴道", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词17", pattern: "乳房", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词18", pattern: "奶子", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词19", pattern: "屁股", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar"),
            FilterRule(id: UUID().uuidString, name: "低俗词20", pattern: "屁眼", replacement: "**", type: .keyword, isEnabled: true, category: "vulgar")
        ]
    }
    
    private var defaultWatermarkFilters: [FilterRule] {
        [
            FilterRule(id: UUID().uuidString, name: "水印1", pattern: "【.*】", replacement: "", type: .regex, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "水印2", pattern: "\\(.*\\)", replacement: "", type: .regex, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "水印3", pattern: "\\[.*\\]", replacement: "", type: .regex, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "水印4", pattern: "<.*>", replacement: "", type: .regex, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "水印5", pattern: "『.*』", replacement: "", type: .regex, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "水印6", pattern: "「.*」", replacement: "", type: .regex, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "水印7", pattern: "《.*》", replacement: "", type: .regex, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "水印8", pattern: "——", replacement: "", type: .keyword, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "水印9", pattern: "——", replacement: "", type: .keyword, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "重复空行", pattern: "\\n\\n+", replacement: "\\n\\n", type: .regex, isEnabled: true, category: "watermark"),
            FilterRule(id: UUID().uuidString, name: "首尾空格", pattern: "^\\s+|\\s+$", replacement: "", type: .regex, isEnabled: true, category: "watermark")
        ]
    }
    
    func addFilter(_ filter: FilterRule) {
        filters.append(filter)
        saveFilters()
    }
    
    func removeFilter(_ filter: FilterRule) {
        filters.removeAll { $0.id == filter.id }
        saveFilters()
    }
    
    func updateFilter(_ filter: FilterRule) {
        if let index = filters.firstIndex(where: { $0.id == filter.id }) {
            filters[index] = filter
            saveFilters()
        }
    }
    
    func toggleFilter(_ filter: FilterRule) {
        if let index = filters.firstIndex(where: { $0.id == filter.id }) {
            filters[index].isEnabled.toggle()
            saveFilters()
        }
    }
    
    func clearAllFilters() {
        filters.removeAll()
        saveFilters()
    }
    
    func resetToDefaults() {
        filters = loadDefaultFilters()
        saveFilters()
    }
    
    func filter(_ content: String) -> String {
        guard isEnabled else { return content }
        
        var result = content
        
        let enabledFilters = filters.filter { $0.isEnabled }
        
        for filter in enabledFilters {
            result = applyFilter(filter, to: result)
        }
        
        return cleanContent(result)
    }
    
    private func applyFilter(_ filter: FilterRule, to content: String) -> String {
        switch filter.type {
        case .regex:
            return applyRegexFilter(filter, to: content)
        case .keyword:
            return content.replacingOccurrences(of: filter.pattern, with: filter.replacement)
        case .replace:
            return content.replacingOccurrences(of: filter.pattern, with: filter.replacement)
        case .removeLines:
            return removeLinesContaining(filter.pattern, from: content)
        }
    }
    
    private func applyRegexFilter(_ filter: FilterRule, to content: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: filter.pattern, options: [])
            return regex.stringByReplacingMatches(
                in: content,
                options: [],
                range: NSRange(content.startIndex..., in: content),
                withTemplate: filter.replacement
            )
        } catch {
            return content
        }
    }
    
    private func removeLinesContaining(_ pattern: String, from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        let filteredLines = lines.filter { !$0.contains(pattern) }
        return filteredLines.joined(separator: "\n")
    }
    
    private func cleanContent(_ content: String) -> String {
        var result = content
        
        result = result.replacingOccurrences(of: "\\n\\n+", with: "\n\n", options: .regularExpression)
        
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return trimmed.isEmpty ? content : trimmed
    }
    
    func getFiltersByCategory(_ category: String) -> [FilterRule] {
        return filters.filter { $0.category == category }
    }
    
    func getEnabledFilters() -> [FilterRule] {
        return filters.filter { $0.isEnabled }
    }
    
    func getDisabledFilters() -> [FilterRule] {
        return filters.filter { !$0.isEnabled }
    }
    
    func isFilterEnabled(_ filterId: String) -> Bool {
        return filters.first { $0.id == filterId }?.isEnabled ?? false
    }
    
    func enableCategory(_ category: String) {
        for index in filters.indices where filters[index].category == category {
            filters[index].isEnabled = true
        }
        saveFilters()
    }
    
    func disableCategory(_ category: String) {
        for index in filters.indices where filters[index].category == category {
            filters[index].isEnabled = false
        }
        saveFilters()
    }
    
    func toggleCategory(_ category: String) {
        let categoryFilters = filters.filter { $0.category == category }
        let allEnabled = categoryFilters.allSatisfy { $0.isEnabled }
        
        for index in filters.indices where filters[index].category == category {
            filters[index].isEnabled = !allEnabled
        }
        saveFilters()
    }
    
    func getCategories() -> [String] {
        let categories = Set(filters.map { $0.category })
        return categories.sorted()
    }
}

extension ContentFilterManager {
    static func preloadFilters() {
        _ = ContentFilterManager.shared
    }
}
