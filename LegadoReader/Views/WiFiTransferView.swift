import SwiftUI

struct WiFiTransferView: View {
    @StateObject private var wifiServer = WiFiTransferServer.shared
    @State private var showingHistory = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(wifiServer.isRunning ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                                
                                Text(wifiServer.isRunning ? "服务运行中" : "服务已停止")
                                    .font(.headline)
                                    .foregroundColor(wifiServer.isRunning ? .green : .secondary)
                            }
                            
                            if wifiServer.isRunning {
                                Text(wifiServer.serverAddress)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.blue)
                                
                                Text("在浏览器中打开此地址")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("服务状态")
                }
                
                Section {
                    Button(action: {
                        if wifiServer.isRunning {
                            wifiServer.stopServer()
                        } else {
                            wifiServer.startServer()
                        }
                    }) {
                        HStack {
                            Image(systemName: wifiServer.isRunning ? "stop.fill" : "play.fill")
                                .foregroundColor(wifiServer.isRunning ? .red : .green)
                            Text(wifiServer.isRunning ? "停止服务" : "启动服务")
                        }
                    }
                    .foregroundColor(wifiServer.isRunning ? .red : .green)
                    
                    if wifiServer.isRunning {
                        Button(action: {
                            copyAddress()
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("复制地址")
                            }
                        }
                    }
                } header: {
                    Text("服务控制")
                }
                
                Section {
                    HStack {
                        Text("已连接设备")
                        Spacer()
                        Text("\(wifiServer.connectedDevices.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("传输记录")
                        Spacer()
                        Button("查看") {
                            showingHistory = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("服务器端口")
                        Spacer()
                        Text("\(wifiServer.port)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("统计信息")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用说明")
                            .font(.headline)
                        
                        Group {
                            Text("1. 点击「启动服务」按钮")
                            Text("2. 确认弹出的网络权限请求")
                            Text("3. 复制显示的IP地址到浏览器")
                            Text("4. 在网页中选择要传输的书籍文件")
                            Text("5. 传输完成后在APP中刷新书架")
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        
                        Text("支持格式：TXT, EPUB, PDF, MOBI, AZW, AZW3, CBZ, CBR, DOCX, ZIP 等")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("帮助")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("WiFi传书")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingHistory) {
                WiFiTransferHistoryView()
            }
            .onAppear {
                if !wifiServer.isRunning {
                    wifiServer.startServer()
                }
            }
            .onDisappear {
                wifiServer.stopServer()
            }
        }
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = wifiServer.serverAddress
    }
}

struct WiFiTransferHistoryView: View {
    @StateObject private var wifiServer = WiFiTransferServer.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if wifiServer.transferHistory.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("暂无传输记录")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    ForEach(wifiServer.transferHistory) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.fileName)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Text(formatSize(record.fileSize))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(record.transferTime, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Circle()
                                .fill(record.success ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                wifiServer.transferHistory.removeAll { $0.id == record.id }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("传输记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !wifiServer.transferHistory.isEmpty {
                        Button("清空") {
                            wifiServer.clearTransferHistory()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func formatSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct WiFiTransferView_Previews: PreviewProvider {
    static var previews: some View {
        WiFiTransferView()
    }
}
