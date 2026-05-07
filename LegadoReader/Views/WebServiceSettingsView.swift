import SwiftUI

struct WebServiceSettingsView: View {
    @StateObject private var webService = WebServiceManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("服务状态") {
                    HStack {
                        Circle()
                            .fill(webService.isRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(webService.isRunning ? "运行中" : "已停止")
                        
                        Spacer()
                        
                        Button(webService.isRunning ? "停止" : "启动") {
                            if webService.isRunning {
                                webService.stopServer()
                            } else {
                                webService.startServer()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if webService.isRunning {
                        HStack {
                            Text("服务地址")
                            Spacer()
                            Text(webService.serverURL)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("连接数")
                            Spacer()
                            Text("\(webService.connectedClients)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("服务设置") {
                    HStack {
                        Text("端口")
                        Spacer()
                        TextField("端口", value: $webService.port, formatter: NumberFormatter())
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .keyboardType(.numberPad)
                    }
                    
                    Button("保存设置") {
                        webService.saveSettings()
                    }
                }
                
                Section("API 文档") {
                    NavigationLink(destination: APIDocumentationView()) {
                        Text("查看 API 文档")
                    }
                }
                
                Section("请求日志") {
                    if webService.requestLog.isEmpty {
                        Text("暂无请求记录")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(webService.requestLog) { log in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(log.method)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(methodColor(log.method))
                                        
                                        Text(log.path)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    
                                    Text(log.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(log.status)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(statusColor(log.status))
                            }
                        }
                    }
                }
                
                Section("使用说明") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. 启动服务后，在同一网络下访问服务地址")
                        Text("2. 使用 API 接口管理书籍、书源等数据")
                        Text("3. 可用于自动化脚本或第三方工具集成")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Web 服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .green
        case "POST": return .blue
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
    
    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 200..<300: return .green
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .gray
        }
    }
}

struct APIDocumentationView: View {
    var body: some View {
        List {
            Section("书籍管理") {
                APIEndpointView(
                    method: "GET",
                    path: "/getBookshelf",
                    description: "获取书架所有书籍"
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/addToBookshelf",
                    description: "添加书籍到书架",
                    body: #"{"id":"书籍ID","name":"书名","author":"作者"}"#
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/removeFromBookshelf",
                    description: "从书架移除书籍",
                    body: #"{"bookId":"书籍ID"}"#
                )
            }
            
            Section("书源管理") {
                APIEndpointView(
                    method: "GET",
                    path: "/getBookSource",
                    description: "获取所有书源"
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/saveBookSource",
                    description: "保存单个书源",
                    body: #"{"bookSourceName":"书源名称",...}"#
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/saveBookSources",
                    description: "批量保存书源",
                    body: #"[{"bookSourceName":"书源1"},...]"#
                )
            }
            
            Section("搜索与阅读") {
                APIEndpointView(
                    method: "POST",
                    path: "/searchBook",
                    description: "搜索书籍",
                    body: #"{"key":"搜索关键词"}"#
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/getChapterList",
                    description: "获取章节列表",
                    body: #"{"bookUrl":"书籍URL"}"#
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/getBookContent",
                    description: "获取章节内容",
                    body: #"{"bookUrl":"书籍URL","chapterUrl":"章节URL"}"#
                )
            }
            
            Section("阅读进度") {
                APIEndpointView(
                    method: "GET",
                    path: "/getReadProgress",
                    description: "获取所有阅读进度"
                )
            }
            
            Section("数据管理") {
                APIEndpointView(
                    method: "GET",
                    path: "/exportData",
                    description: "导出所有数据"
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/importData",
                    description: "导入数据",
                    body: #"{"books":[...],"sources":[...]}"#
                )
            }
            
            Section("RSS 订阅") {
                APIEndpointView(
                    method: "GET",
                    path: "/getRSSSources",
                    description: "获取所有订阅源"
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/saveRSSSource",
                    description: "保存订阅源",
                    body: #"{"sourceName":"源名称","sourceUrl":"源地址"}"#
                )
                
                APIEndpointView(
                    method: "POST",
                    path: "/getRSSArticles",
                    description: "获取订阅文章",
                    body: #"{"sourceUrl":"订阅源地址"}"#
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("API 文档")
    }
}

struct APIEndpointView: View {
    let method: String
    let path: String
    let description: String
    var body: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(method)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(methodColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                
                Text(path)
                    .font(.system(.caption, design: .monospaced))
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let body = body {
                Text("请求体:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(body)
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var methodColor: Color {
        switch method {
        case "GET": return .green
        case "POST": return .blue
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
}

struct WebServiceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WebServiceSettingsView()
    }
}
