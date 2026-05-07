import SwiftUI

struct CustomAudioSourceListView: View {
    @StateObject private var sourceManager = CustomAudioSourceManager.shared
    @State private var showAddSource = false
    @State private var showEditSource = false
    @State private var selectedSource: CustomAudioSourceManager.AudioSource?
    
    var body: some View {
        NavigationView {
            List {
                if sourceManager.isConnected, let source = sourceManager.activeSource {
                    Section("已连接") {
                        HStack {
                            Image(systemName: source.type.iconName)
                                .foregroundColor(.green)
                            Text(source.name)
                            Spacer()
                            Text("已连接")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section("自定义源") {
                    ForEach(sourceManager.getSources(sortedBy: .priority)) { source in
                        SourceRowView(source: source, isConnected: sourceManager.activeSource?.id == source.id && sourceManager.isConnected)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSource = source
                                if sourceManager.activeSource?.id == source.id && sourceManager.isConnected {
                                    sourceManager.disconnect()
                                } else {
                                    sourceManager.connect(to: source)
                                }
                            }
                    }
                    .onDelete { indexSet in
                        let sortedSources = sourceManager.getSources(sortedBy: .priority)
                        for index in indexSet {
                            sourceManager.removeSource(sortedSources[index])
                        }
                    }
                }
                
                Section("默认源") {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text("本地TTS引擎")
                        Spacer()
                        Text("始终可用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("听书源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSource = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSource) {
                CustomAudioSourceEditorView(source: nil)
            }
            .sheet(isPresented: $showEditSource) {
                if let source = selectedSource {
                    CustomAudioSourceEditorView(source: source)
                }
            }
        }
    }
}

struct SourceRowView: View {
    let source: CustomAudioSourceManager.AudioSource
    let isConnected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: source.type.iconName)
                .foregroundColor(isConnected ? .green : .blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.subheadline)
                
                Text(source.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isConnected {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("已连接")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CustomAudioSourceEditorView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var sourceManager = CustomAudioSourceManager.shared
    
    var source: CustomAudioSourceManager.AudioSource?
    
    @State private var name = ""
    @State private var url = ""
    @State private var sourceType: CustomAudioSourceManager.AudioSource.SourceType = .websocket
    @State private var authType: CustomAudioSourceManager.AudioSource.AuthConfig.AuthType = .none
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var token = ""
    @State private var headers: [(key: String, value: String)] = []
    @State private var showAddHeader = false
    @State private var newHeaderKey = ""
    @State private var newHeaderValue = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $name)
                    
                    Picker("类型", selection: $sourceType) {
                        ForEach(CustomAudioSourceManager.AudioSource.SourceType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.iconName)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section("URL地址") {
                    TextField("WebSocket URL", text: $url)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    Text("支持占位符: {bookId}, {chapterId}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("认证配置") {
                    Picker("认证类型", selection: $authType) {
                        Text("无").tag(CustomAudioSourceManager.AudioSource.AuthConfig.AuthType.none)
                        Text("Basic认证").tag(CustomAudioSourceManager.AudioSource.AuthConfig.AuthType.basic)
                        Text("Bearer Token").tag(CustomAudioSourceManager.AudioSource.AuthConfig.AuthType.bearer)
                        Text("API Key").tag(CustomAudioSourceManager.AudioSource.AuthConfig.AuthType.apiKey)
                    }
                    
                    if authType == .basic {
                        TextField("用户名", text: $username)
                            .autocapitalization(.none)
                        SecureField("密码", text: $password)
                    } else if authType == .bearer {
                        TextField("Token", text: $token)
                            .autocapitalization(.none)
                    } else if authType == .apiKey {
                        TextField("API Key", text: $apiKey)
                            .autocapitalization(.none)
                    }
                }
                
                Section("自定义请求头") {
                    ForEach(headers.indices, id: \.self) { index in
                        HStack {
                            Text(headers[index].key)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(headers[index].value)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        headers.remove(atOffsets: indexSet)
                    }
                    
                    Button {
                        showAddHeader = true
                    } label: {
                        Label("添加请求头", systemImage: "plus")
                    }
                }
                
                Section {
                    Button("测试连接") {
                        testConnection()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("保存") {
                        saveSource()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
            .navigationTitle(source == nil ? "添加听书源" : "编辑听书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("添加请求头", isPresented: $showAddHeader) {
                TextField("键", text: $newHeaderKey)
                TextField("值", text: $newHeaderValue)
                Button("添加") {
                    if !newHeaderKey.isEmpty && !newHeaderValue.isEmpty {
                        headers.append((key: newHeaderKey, value: newHeaderValue))
                        newHeaderKey = ""
                        newHeaderValue = ""
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .onAppear {
                if let source = source {
                    name = source.name
                    url = source.url
                    sourceType = source.type
                    
                    if let auth = source.authConfig {
                        authType = auth.type
                        username = auth.username ?? ""
                        password = auth.password ?? ""
                        apiKey = auth.apiKey ?? ""
                        token = auth.token ?? ""
                    }
                    
                    headers = source.headers.map { (key: $0.key, value: $0.value) }
                }
            }
        }
    }
    
    private func testConnection() {
        let testSource = CustomAudioSourceManager.AudioSource(
            name: name,
            url: url,
            type: sourceType,
            headers: Dictionary(uniqueKeysWithValues: headers.map { ($0.key, $0.value) })
        )
        sourceManager.connect(to: testSource)
    }
    
    private func saveSource() {
        var authConfig: CustomAudioSourceManager.AudioSource.AuthConfig?
        
        if authType != .none {
            authConfig = CustomAudioSourceManager.AudioSource.AuthConfig(
                type: authType,
                username: authType == .basic ? username : nil,
                password: authType == .basic ? password : nil,
                apiKey: authType == .apiKey ? apiKey : nil,
                token: authType == .bearer ? token : nil
            )
        }
        
        var headersDict: [String: String] = [:]
        for header in headers {
            headersDict[header.key] = header.value
        }
        
        if var existingSource = source {
            existingSource.name = name
            existingSource.url = url
            existingSource.type = sourceType
            existingSource.headers = headersDict
            existingSource.authConfig = authConfig
            sourceManager.updateSource(existingSource)
        } else {
            let newSource = CustomAudioSourceManager.AudioSource(
                name: name,
                url: url,
                type: sourceType,
                headers: headersDict,
                authConfig: authConfig
            )
            sourceManager.addSource(newSource)
        }
        
        dismiss()
    }
}

struct WebSocketStatusView: View {
    @StateObject private var webSocketManager = WebSocketManager.shared
    @StateObject private var sourceManager = CustomAudioSourceManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            if sourceManager.isConnected, let source = sourceManager.activeSource {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已连接到: \(source.name)")
                        .font(.subheadline)
                }
                
                HStack(spacing: 20) {
                    Button {
                        sourceManager.disconnect()
                    } label: {
                        Label("断开", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        let message = WebSocketMessage(type: "ping", action: "health_check")
                        webSocketManager.sendJSON(message)
                    } label: {
                        Label("发送Ping", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                    Text("未连接")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if case .reconnecting(let attempt) = sourceManager.connectionState {
                    HStack {
                        ProgressView()
                        Text("正在重连 (\(attempt)/5)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let error = webSocketManager.lastError {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CustomAudioSourceSettingsView: View {
    @StateObject private var sourceManager = CustomAudioSourceManager.shared
    @StateObject private var audioService = WebSocketAudioService.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("听书源") {
                    NavigationLink {
                        CustomAudioSourceListView()
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.blue)
                            Text("自定义WebSocket源")
                            Spacer()
                            Text("\(sourceManager.sources.count)个")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("连接状态") {
                    WebSocketStatusView()
                }
                
                Section("流媒体设置") {
                    Toggle("自动获取音频URL", isOn: .constant(true))
                    Toggle("流式下载音频", isOn: .constant(true))
                    Toggle("缓存音频片段", isOn: .constant(true))
                }
                
                Section("请求设置") {
                    Stepper("请求超时: 30秒", value: .constant(30), in: 10...120)
                }
            }
            .navigationTitle("听书源设置")
        }
    }
}

struct CustomAudioSourceListView_Previews: PreviewProvider {
    static var previews: some View {
        CustomAudioSourceListView()
    }
}
