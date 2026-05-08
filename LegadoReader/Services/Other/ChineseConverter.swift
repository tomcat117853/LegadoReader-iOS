import Foundation

class ChineseConverter: ObservableObject {
    static let shared = ChineseConverter()
    
    @Published var conversionMode: ConversionMode = .none
    
    enum ConversionMode: String, CaseIterable, Identifiable {
        case none = "无"
        case simplifiedToTraditional = "简转繁"
        case traditionalToSimplified = "繁转简"
        
        var id: String { rawValue }
    }
    
    private let simplifiedToTraditionalMap: [Character: Character]
    private let traditionalToSimplifiedMap: [Character: Character]
    
    private init() {
        self.simplifiedToTraditionalMap = Self.loadSimplifiedToTraditionalMap()
        self.traditionalToSimplifiedMap = Self.loadTraditionalToSimplifiedMap()
    }
    
    private static func loadSimplifiedToTraditionalMap() -> [Character: Character] {
        let map: [Character: Character] = [
            "爱": "愛", "罢": "罷", "备": "備", "贝": "貝", "笔": "筆",
            "变": "變", "宾": "賓", "补": "補", "才": "纔", "参": "參",
            "仓": "倉", "层": "層", "产": "產", "长": "長", "尝": "嘗",
            "车": "車", "齿": "齒", "虫": "蟲", "刍": "芻", "从": "從",
            "窜": "竄", "达": "達", "带": "帶", "单": "單", "当": "當",
            "党": "黨", "岛": "島", "导": "導", "灯": "燈", "邓": "鄧",
            "敌": "敵", "籴": "糴", "递": "遞", "点": "點", "电": "電",
            "东": "東", "动": "動", "断": "斷", "对": "對", "队": "隊",
            "儿": "兒", "发": "發", "矾": "礬", "范": "範", "飞": "飛",
            "丰": "豐", "风": "風", "妇": "婦", "复": "復", "干": "乾",
            "赶": "趕", "个": "個", "巩": "鞏", "沟": "溝", "构": "構",
            "购": "購", "谷": "穀", "顾": "顧", "刮": "颳", "关": "關",
            "观": "觀", "广": "廣", "归": "歸", "龟": "龜", "国": "國",
            "过": "過", "骇": "駭", "汉": "漢", "号": "號", "合": "閤",
            "轰": "轟", "后": "後", "胡": "鬍", "壶": "壺", "沪": "滬",
            "护": "護", "划": "劃", "华": "華", "画": "畫", "汇": "匯",
            "会": "會", "获": "獲", "击": "擊", "机": "機", "积": "積",
            "极": "極", "际": "際", "继": "繼", "家": "傢", "价": "價",
            "艰": "艱", "歼": "殲", "茧": "繭", "拣": "揀", "鉴": "鑒",
            "舰": "艦", "姜": "薑", "浆": "漿", "奖": "獎", "讲": "講",
            "酱": "醬", "胶": "膠", "阶": "階", "洁": "潔", "借": "藉",
            "仅": "僅", "惊": "驚", "竞": "競", "旧": "舊", "剧": "劇",
            "据": "據", "惧": "懼", "壳": "殼", "课": "課", "亏": "虧",
            "困": "睏", "来": "來", "乐": "樂", "离": "離", "历": "歷",
            "丽": "麗", "两": "兩", "量": "量", "疗": "療", "辽": "遼",
            "猎": "獵", "临": "臨", "邻": "鄰", "岭": "嶺", "庐": "廬",
            "芦": "蘆", "炉": "爐", "陆": "陸", "录": "錄", "驴": "驢",
            "乱": "亂", "么": "麼", "霉": "黴", "蒙": "矇", "梦": "夢",
            "面": "麵", "庙": "廟", "灭": "滅", "亩": "畝", "难": "難",
            "鸟": "鳥", "宁": "寧", "农": "農", "疟": "瘧", "盘": "盤",
            "辟": "闢", "苹": "蘋", "凭": "憑", "扑": "撲", "仆": "僕",
            "朴": "樸", "启": "啟", "弃": "棄", "千": "韆", "牵": "牽",
            "纤": "纖", "签": "籤", "浅": "淺", "窃": "竊", "亲": "親",
            "穷": "窮", "区": "區", "权": "權", "劝": "勸", "确": "確",
            "让": "讓", "扰": "擾", "热": "熱", "认": "認", "绒": "絨",
            "荣": "榮", "洒": "灑", "伞": "傘", "丧": "喪", "扫": "掃",
            "涩": "澀", "晒": "曬", "伤": "傷", "舍": "捨", "沈": "瀋",
            "声": "聲", "胜": "勝", "湿": "濕", "实": "實", "势": "勢",
            "适": "適", "寿": "壽", "书": "書", "术": "術", "树": "樹",
            "帅": "帥", "松": "鬆", "苏": "蘇", "虽": "雖", "随": "隨",
            "岁": "歲", "孙": "孫", "台": "臺", "态": "態", "坛": "壇",
            "叹": "嘆", "汤": "湯", "烫": "燙", "体": "體", "条": "條",
            "铁": "鐵", "听": "聽", "厅": "廳", "头": "頭", "图": "圖",
            "涂": "塗", "团": "團", "洼": "窪", "袜": "襪", "网": "網",
            "卫": "衛", "稳": "穩", "务": "務", "雾": "霧", "习": "習",
            "系": "繫", "戏": "戲", "虾": "蝦", "吓": "嚇", "咸": "鹹",
            "显": "顯", "险": "險", "县": "縣", "响": "響", "向": "嚮",
            "萧": "蕭", "销": "銷", "晓": "曉", "协": "協", "胁": "脅",
            "亵": "褻", "衅": "釁", "兴": "興", "须": "鬚", "许": "許",
            "学": "學", "寻": "尋", "亚": "亞", "严": "嚴", "厌": "厭",
            "业": "業", "医": "醫", "亿": "億", "义": "義", "议": "議",
            "艺": "藝", "阴": "陰", "隐": "隱", "应": "應", "营": "營",
            "拥": "擁", "佣": "傭", "痈": "癰", "优": "優", "犹": "猶",
            "鱼": "魚", "与": "與", "屿": "嶼", "远": "遠", "园": "園",
            "愿": "願", "跃": "躍", "运": "運", "酝": "醞", "载": "載",
            "择": "擇", "泽": "澤", "占": "佔", "栈": "棧", "战": "戰",
            "赵": "趙", "这": "這", "折": "摺", "贞": "貞", "针": "針",
            "争": "爭", "症": "癥", "证": "證", "织": "織", "执": "執",
            "职": "職", "钟": "鐘", "肿": "腫", "种": "種", "众": "眾",
            "昼": "晝", "朱": "硃", "烛": "燭", "筑": "築", "庄": "莊",
            "装": "裝", "壮": "壯", "状": "狀", "准": "準", "浊": "濁",
            "总": "總", "钻": "鑽", "邹": "鄒", "爱": "愛"
        ]
        return map
    }
    
    private static func loadTraditionalToSimplifiedMap() -> [Character: Character] {
        let simplifiedMap = loadSimplifiedToTraditionalMap()
        return Dictionary(uniqueKeysWithValues: simplifiedMap.map { ($0.value, $0.key) })
    }
    
    func convert(_ text: String) -> String {
        switch conversionMode {
        case .none:
            return text
        case .simplifiedToTraditional:
            return convertToTraditional(text)
        case .traditionalToSimplified:
            return convertToSimplified(text)
        }
    }
    
    func convertToTraditional(_ text: String) -> String {
        return String(text.map { simplifiedToTraditionalMap[$0] ?? $0 })
    }
    
    func convertToSimplified(_ text: String) -> String {
        return String(text.map { traditionalToSimplifiedMap[$0] ?? $0 })
    }
    
    func setConversionMode(_ mode: ConversionMode) {
        conversionMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "ChineseConverter_conversionMode")
    }
    
    func loadConversionMode() {
        if let savedMode = UserDefaults.standard.string(forKey: "ChineseConverter_conversionMode"),
           let mode = ConversionMode(rawValue: savedMode) {
            conversionMode = mode
        }
    }
}

struct ChineseConverterSettingsView: View {
    @StateObject private var converter = ChineseConverter.shared
    
    var body: some View {
        List {
            Section("简繁转换") {
                ForEach(ChineseConverter.ConversionMode.allCases) { mode in
                    Button(action: {
                        converter.setConversionMode(mode)
                    }) {
                        HStack {
                            Text(mode.rawValue)
                            
                            Spacer()
                            
                            if converter.conversionMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section("示例") {
                VStack(spacing: 8) {
                    Text("原文：我爱中国")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("转换后：\(converter.convert("我爱中国"))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("简繁转换")
        .onAppear {
            converter.loadConversionMode()
        }
    }
}
