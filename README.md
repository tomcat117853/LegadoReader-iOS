# LegadoReader iOS

一款基于 Legado 书源规则的 iOS 原生阅读器应用，使用 SwiftUI 开发。

## 功能特性

### 核心功能
- **书架管理**: 支持列表/网格两种展示模式，长按菜单操作
- **书源搜索**: 多书源并发搜索，自动去重
- **阅读器**: 自定义字体、背景、行间距、翻页模式
- **书源导入**: 完整支持 Legado 书源 JSON 格式
- **书源编辑**: 可视化规则编辑器，支持搜索/详情/目录/正文规则配置
- **订阅源**: RSS 订阅功能，支持 RSS/Atom 格式
- **发现页面**: 书源推荐内容展示
- **书籍缓存**: 离线阅读支持，进度管理
- **替换净化**: 全局/书籍级别的内容净化规则
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

### 阅读器特性
- 多种背景颜色（白天、护眼、清新、夜间、纯黑）
- 字体大小调节（12-32pt）
- 行间距调节
- 夜间模式
- 章节导航
- 阅读进度保存
- 屏幕常亮选项

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
├── Models/                 # 数据模型
│   ├── Book.swift         # 书籍模型
│   ├── BookSource.swift   # 书源模型
│   ├── RSSSource.swift    # 订阅源模型
│   └── ReaderSettings.swift # 阅读设置
├── Views/                 # UI 视图
│   ├── SearchView.swift   # 搜索页面
│   ├── BookDetailView.swift # 书籍详情
│   ├── ReaderView.swift   # 阅读器
│   ├── DiscoverView.swift # 发现页面
│   ├── RSSView.swift      # 订阅页面
│   ├── SourceManagementView.swift # 书源管理
│   ├── SettingsView.swift # 设置页面
│   ├── LocalBooksView.swift # 本地书籍
│   ├── PageTurnView.swift # 翻页效果
│   └── ThemeSettingsView.swift # 主题设置
├── ViewModels/            # 视图模型
│   ├── BookStore.swift    # 书籍数据管理
│   └── SourceStore.swift  # 书源数据管理
├── Services/              # 服务层
│   ├── DatabaseManager.swift # 数据库管理
│   ├── BookSourceParser.swift # 书源解析引擎
│   ├── ReadingProgressSync.swift # 阅读进度同步
│   ├── CloudSyncManager.swift # 云同步管理
│   ├── AudioBookManager.swift # 听书功能
│   ├── ThemeManager.swift # 主题管理
│   ├── LocalBookManager.swift # 本地书籍管理
│   ├── ChineseConverter.swift # 简繁转换
│   └── WebDAVManager.swift # WebDAV 同步
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

### 1. 导入书源
1. 进入"书源"页面
2. 点击右上角"+"按钮
3. 选择"导入书源"
4. 粘贴 Legado 书源 JSON 或书源链接
5. 点击"导入"

### 2. 搜索书籍
1. 在"书架"页面点击右上角搜索按钮
2. 输入书名或作者名
3. 应用会自动在所有启用的书源中搜索
4. 点击搜索结果查看详情

### 3. 阅读书籍
1. 在书籍详情页点击"开始阅读"
2. 点击屏幕中央显示/隐藏菜单
3. 使用底部按钮切换章节
4. 点击"设置"调整阅读参数

### 4. 管理书架
- **列表/网格切换**: 书架页面左上角按钮
- **删除书籍**: 长按书籍封面，选择"删除"
- **置顶书籍**: 长按书籍封面，选择"置顶"

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
- [x] 替换净化规则
- [x] RSS 订阅功能
- [x] 发现页面内容加载
- [x] 书源编辑功能
- [x] 数据备份/恢复
- [x] 阅读进度同步
- [x] 云书架同步
- [x] 听书功能
- [x] 主题自定义

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
