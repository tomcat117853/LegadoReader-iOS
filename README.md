# 阅读 iOS

一款基于 Legado 书源规则的 iOS 原生阅读器应用，使用 SwiftUI 开发。

## 功能特性

### 核心功能
- **书架管理**: 支持列表/网格两种展示模式，长按菜单操作，下拉出现搜索框
- **书源搜索**: 多书源并发搜索，自动去重，支持多种匹配类型（原始、含键、包含、匹配）
- **阅读器**: 自定义字体、背景、行间距、翻页模式，点击弹出丰富设置菜单
- **书源导入**: 完整支持 Legado 书源 JSON 格式
- **书源编辑**: 可视化规则编辑器，支持搜索/详情/目录/正文规则配置
- **订阅源**: RSS 订阅功能，支持 RSS/Atom 格式
- **发现页面**: 书源推荐内容展示
- **书籍缓存**: 离线阅读支持，进度管理
- **内容过滤**: 整合替换规则和内容过滤，支持关键词、正则、文本替换
- **数据备份**: 完整的数据备份与恢复功能
- **阅读进度同步**: 本地阅读进度记录
- **云书架同步**: iCloud 云端同步，支持书籍、书源、进度同步
- **听书功能**: TTS 语音朗读，支持语速调节和多音色选择
- **主题自定义**: 8种内置主题，支持自定义颜色创建主题
- **本地书籍**: 支持 TXT、EPUB 格式本地文件阅读
- **翻页效果**: 支持滚动、滑动、覆盖、仿真四种翻页模式
- **简繁转换**: 支持简体中文与繁体中文相互转换
- **WebDAV 同步**: 支持 WebDAV 服务器同步数据
- **Web 服务 API**: RESTful API 接口，支持远程管理

### 书架功能
- **多种布局**: 列表视图和网格视图一键切换
- **快速搜索**: 下拉书架显示搜索框，支持书名、作者名、类型匹配
- **滑动操作**: 向左滑动书籍支持置顶、听书、分组、详情、删除
- **批量编辑**: 长按进入编辑模式，支持多选批量操作
- **拼音排序**: 支持按拼音 A-Z 排序中文书籍
- **分组管理**: 书籍分组管理，支持不同分组不同布局和排序
- **书架设置**: 自定义每组的显示布局和排序方式
- **快捷操作栏**: 未读、最近阅读、进度、作者、标签快速筛选

### 阅读器功能
- **点击弹出菜单**: 点击阅读界面弹出顶部和底部工具栏
- **顶部工具栏**: 返回、书名章节显示、目录、书源选择、更多设置
- **底部工具栏**: 上一章/下一章按钮、进度条滑动、目录、布局、缓存、翻页、设置
- **书源选择**: 点击切换来源，显示当前源、可用源、失效源
- **布局管理**: 
  - 布局类型（自定义、管理、初号、小初、一号、一号宽、小一、二号、小二、三号、小三）
  - 5种配色方案（护眼绿、白色、护眼黄、黑色、深灰）
  - 字体大小滑块调节（12-32pt）
  - 护眼、修改、配色、管理快捷按钮
  - 阅读布局管理（长按进入编辑模式，支持置顶、删除）
- **双指亮度**: 双指上下滑动调节屏幕亮度
- **动态背景**: 书籍详情页从封面提取颜色生成渐变背景
- **阅读轨迹**: 记录阅读位置和历史
- **书籍统计**: 阅读时长、章节进度等数据统计

### 内容过滤
- **规则整合**: 所有替换和过滤规则整合到内容过滤中
- **过滤类型**: 关键词过滤、正则替换、文本替换、整行删除
- **分类管理**: 广告过滤、低俗内容、水印过滤、自定义规则
- **搜索过滤**: 支持搜索过滤规则
- **批量操作**: 创建规则、导出所有、反转可用性、删除禁用、重置配置
- **滑动启用**: 左滑规则可快速启用/禁用

### 侧边栏功能
- 我的
- 激励视频
- 书架编辑
- 书架排序
- 文件导入
- 书籍总统计
- 颜色管理
- 书源管理
- 书海无涯
- 内容过滤
- 设置

### 云同步功能
- **WebDAV**: 支持坚果云、InfiniCloud 等 WebDAV 服务
- **百度云盘**: 支持百度云盘账号绑定
- **阿里云盘**: 支持阿里云盘账号绑定
- **OPDS 协议**: 支持 OPDS 订阅协议

### 书源搜索
- **匹配类型**: 原始、含键、包含、匹配
- **指定源搜索**: 可指定仅搜索选中书源
- **书海无涯**: 浏览所有可用书源，支持左滑禁用/置顶

### 新增功能
- **标注笔记**: 支持下划线、波浪线、虚线、高亮等多种标注样式
- **书签管理**: 书签添加、编辑、备注功能
- **全书页数显示**: 可配置显示全书总页数
- **智能替换**: 自动修正图片、标注等位置，不会因替换而导入错位
- **TXT导入优化**: 支持自定义分卷标志，解析更加精准
- **EPUB优化**: 支持书籍标签，自适应图片，夜间图片优化
- **书籍导出**: 支持文本、图片、样式、笔记等多种导出格式
- **护眼模式**: 多种护眼配色方案，保护眼睛健康
- **书籍加密**: 不同密码显示不同内容，保护隐私
- **分组管理**: 书籍分组管理，支持按阅读/听书时长排序
- **压缩包支持**: 支持 RAR、ZIP 格式自动识别导入
- **标题格式化**: 自动格式化书籍章节标题
- **听书跟随**: 听书时自动跟随朗读进度

### 阅读器特性
- 多种背景颜色（白天、护眼、清新、夜间、纯黑）
- 字体大小调节（12-32pt）
- 行间距调节
- 夜间模式
- 章节导航
- 阅读进度保存
- 屏幕常亮选项
- 上下滑动（连续）翻页模式
- 双指滑动亮度调节

## 技术架构

### 技术栈
- **UI 框架**: SwiftUI
- **数据存储**: SQLite3
- **网络请求**: URLSession
- **HTML 解析**: SwiftSoup
- **最低版本**: iOS 15.4.1

### 项目结构
```
LegadoReader/
├── Models/                 # 数据模型（按功能分类）
│   ├── Book/              # 书籍相关
│   │   ├── Book.swift
│   │   ├── BookGroup.swift
│   │   └── BookSource.swift
│   ├── Common/            # 通用模型
│   │   └── Bookmark.swift
│   ├── Reading/           # 阅读相关
│   │   ├── ReaderSettings.swift
│   │   └── ReadingEnhancement.swift
│   ├── RSS/               # RSS订阅
│   │   └── RSSSource.swift
│   └── Search/            # 搜索相关
│       └── MultiLevelChapter.swift
├── Views/                  # UI 视图（按功能分类）
│   ├── Archive/           # 归档管理
│   ├── Audio/             # 听书功能
│   ├── AudioSource/        # 音频源
│   ├── Book/              # 书籍相关
│   ├── Common/            # 通用组件
│   │   ├── AnnotationStyleSettingsView.swift
│   │   ├── BookFormatSettingsView.swift
│   │   ├── BookSwipeActionsView.swift
│   │   ├── BookshelfBatchEditView.swift
│   │   ├── CacheManagementView.swift
│   │   ├── CardLayoutView.swift
│   │   ├── ContentFilterSettingsView.swift
│   │   ├── CoverManagementView.swift
│   │   ├── EyeCareSettingsView.swift
│   │   ├── FileImportView.swift
│   │   ├── FontMappingSettingsView.swift
│   │   ├── GroupDetailView.swift
│   │   ├── GroupSelectorView.swift
│   │   ├── GroupSettingsView.swift
│   │   ├── LockUnlockView.swift
│   │   ├── NoteTemplateListView.swift
│   │   ├── PageTurnView.swift
│   │   ├── ReadingHistoryView.swift
│   │   ├── SidebarMenuView.swift
│   │   ├── SubscriptionSettingsSheet.swift
│   │   ├── TextLayoutSettingsView.swift
│   │   ├── ThemeSkinSettingsView.swift
│   │   ├── TitleSegmentationSettingsView.swift
│   │   ├── UnderlineSettingsView.swift
│   │   ├── UpdateNotificationSettingsView.swift
│   │   ├── WebBrowserView.swift
│   │   └── WiFiTransferView.swift
│   ├── OPDS/              # OPDS订阅
│   ├── Other/             # 其他功能
│   │   ├── AudioBookView.swift
│   │   ├── AudioTimerView.swift
│   │   ├── BookSourceSearchView.swift
│   │   ├── BookshelfView.swift
│   │   ├── CloudSyncView.swift
│   │   ├── ComicReaderView.swift
│   │   ├── DiscoverView.swift
│   │   ├── ExploreView.swift
│   │   ├── LibraryView.swift
│   │   ├── ReadingProgressView.swift
│   │   ├── SearchView.swift
│   │   ├── SelectableReaderContentView.swift
│   │   ├── SourceEditorView.swift
│   │   └── WebServiceSettingsView.swift
│   ├── Reader/            # 阅读器核心
│   │   ├── AnnotationEditView.swift
│   │   ├── AutoScrollManager.swift
│   │   ├── AudioBookView.swift
│   │   ├── AutoScrollSettingsView.swift
│   │   ├── BrightnessGestureView.swift
│   │   ├── ChapterSelectorView.swift
│   │   ├── EPUBCSSContentView.swift
│   │   ├── LazyChapterListView.swift
│   │   ├── LazySelectableTextView.swift
│   │   ├── MappedFontTextView.swift
│   │   ├── PopupAnnotationView.swift
│   │   ├── ReaderLayoutView.swift
│   │   ├── ReaderSettingsMenuView.swift
│   │   ├── ReaderToolbarViews.swift
│   │   ├── UnifiedBookStatisticsView.swift
│   │   └── UniversalReaderView.swift
│   └── Settings/          # 设置页面
├── ViewModels/             # 视图模型（按功能分类）
│   ├── Book/              # 书籍管理
│   │   └── BookStore.swift
│   ├── RSS/               # RSS订阅
│   │   └── RSSViewModel.swift
│   └── Search/            # 搜索相关
│       └── SourceStore.swift
├── Services/               # 服务层（按功能分类）
│   ├── Annotation/        # 标注笔记
│   ├── Audio/             # 音频听书
│   ├── Book/              # 书籍管理
│   ├── ImportExport/      # 导入导出
│   ├── Network/           # 网络请求
│   │   └── ContentFilterManager.swift
│   ├── Other/             # 其他服务
│   ├── Reading/           # 阅读核心
│   ├── Search/            # 搜索相关
│   ├── Settings/          # 设置管理
│   ├── Storage/           # 存储管理
│   ├── Sync/              # 同步服务
│   ├── Utils/             # 工具类
│   └── WebSocket/          # WebSocket
└── Resources/             # 资源文件
```

## 书源规则支持

### 支持的规则类型
- `searchBook` - 搜索规则
- `bookDetail` - 书籍详情规则
- `chapterList` - 目录列表规则
- `chapterContent` - 正文内容规则
- `discover` - 发现页面规则

### 书源导入格式
支持标准的 Legado 书源 JSON 格式：
```json
{
  "bookSourceName": "书源名称",
  "bookSourceUrl": "https://example.com",
  "bookSourceType": "0",
  "searchUrl": "https://example.com/search?key={{key}}",
  "ruleSearch": {
    "bookList": ".book-list li",
    "name": "h3",
    "author": ".author",
    "coverUrl": "img@src",
    "bookUrl": "a@href"
  },
  "ruleBookInfo": {
    "name": "h1",
    "author": ".info .author",
    "intro": ".intro",
    "coverUrl": ".cover img@src"
  },
  "ruleToc": {
    "chapterList": ".chapter-list li",
    "chapterName": "a",
    "chapterUrl": "a@href"
  },
  "ruleContent": {
    "content": ".content"
  }
}
```

## 使用说明

### 1. 书架使用
1. 下拉书架显示搜索框，可搜索书名、作者、类型
2. 点击书籍直接阅读，长按进入编辑模式
3. 向左滑动书籍：置顶、听书、分组、详情、删除
4. 点击右上角切换列表/网格视图
5. 点击省略号打开侧边栏菜单

### 2. 导入书源
1. 进入"书源"页面
2. 点击右上角"+"按钮
3. 选择"导入书源"
4. 粘贴 Legado 书源 JSON 或书源链接
5. 点击"导入"

### 3. 搜索书籍
1. 在"书架"页面下拉显示搜索框
2. 选择匹配类型（原始、含键、包含、匹配）
3. 输入书名或作者名
4. 可选：点击"指定源"仅搜索特定书源
5. 点击搜索结果查看详情

### 4. 阅读书籍
1. 在书籍详情页点击"开始阅读"
2. 点击屏幕中央显示/隐藏菜单
3. 使用底部按钮切换章节（上一章/下一章）
4. 点击右上角"书源选择"切换来源
5. 点击"布局"调整阅读布局
6. 点击"设置"调整阅读参数

### 5. 管理书架
- **列表/网格切换**: 书架页面左上角按钮
- **删除书籍**: 向左滑动书籍，选择"删除"
- **置顶书籍**: 向左滑动书籍，选择"置顶"
- **分组管理**: 向左滑动书籍，选择"分组"

### 6. 内容过滤
1. 通过侧边栏进入"内容过滤"
2. 点击右上角菜单创建新规则
3. 支持关键词、正则、文本替换
4. 左滑规则快速启用/禁用
5. 支持搜索过滤规则

## 开发计划

### 已实现
- [x] 项目基础架构
- [x] SQLite 数据库管理
- [x] 书源解析引擎
- [x] 书架管理（列表/网格）
- [x] 搜索功能
- [x] 阅读器基础功能
- [x] 阅读设置
- [x] 书源导入/管理
- [x] 书籍缓存下载
- [x] 内容过滤规则
- [x] RSS 订阅功能
- [x] 发现页面内容加载
- [x] 书源编辑功能
- [x] 数据备份/恢复
- [x] 阅读进度同步
- [x] 云书架同步
- [x] 听书功能
- [x] 主题自定义
- [x] 书架滑动操作
- [x] 批量编辑模式
- [x] 拼音排序
- [x] 分组管理
- [x] 动态渐变背景
- [x] 双指亮度调节
- [x] 阅读布局管理
- [x] 书源选择功能
- [x] 侧边栏菜单
- [x] 云同步（WebDAV/百度/阿里）

### 待实现
- [ ] 更多功能等你来添加

## 依赖库

```swift
// SwiftSoup - HTML 解析
https://github.com/scinfu/SwiftSoup
```

## 构建说明

### 环境要求
- Xcode 15.0+
- iOS 15.4.1+
- Swift 5.9+

### 构建步骤
1. 克隆项目
```bash
git clone https://github.com/yourusername/LegadoReader-iOS.git
```

2. 打开项目
```bash
cd LegadoReader-iOS
open LegadoReader.xcodeproj
```

3. 添加依赖（SwiftSoup）
   - 在 Xcode 中选择 File → Add Package Dependencies
   - 输入: `https://github.com/scinfu/SwiftSoup`
   - 选择版本并添加

4. 构建运行
   - 选择目标设备或模拟器
   - 点击 Run 按钮或按 Cmd+R

## 注意事项

1. **网络权限**: 应用需要网络权限来加载书籍内容
2. **书源安全**: 请从可信来源导入书源
3. **版权问题**: 请遵守当地版权法规

## 开源协议

本项目基于 Legado 开源项目开发，遵循开源协议。

## 致谢

- [Legado](https://github.com/gedoor/legado) - 开源阅读器项目
- [SwiftSoup](https://github.com/scinfu/SwiftSoup) - Swift HTML 解析库

## 联系方式

如有问题或建议，欢迎提交 Issue 或 Pull Request。
