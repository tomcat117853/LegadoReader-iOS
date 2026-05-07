import Foundation
import Combine

class CustomAudioSourceManager: BaseService {
    static let shared = CustomAudioSourceManager()
    
    @Published var sources: [AudioSource] = []
    @Published var activeSource: AudioSource?
    @Published var isConnected = false
    @Published var connectionState: WebSocketManager.ConnectionState = .disconnected
    
    private var cancellables = Set<AnyCancellable>()
    
    struct AudioSource: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var url: String
        var headers: [String: String]
        var type: SourceType
        var isEnabled: Bool
        var priority: Int
        var authConfig: AuthConfig?
        var requestConfig: RequestConfig
        let createdTime: Date
        var lastUsedTime: Date
        
        enum SourceType: String, Codable, CaseIterable {
            case websocket = "websocket"
            case http = "http"
            case local = "local"
            
            var displayName: String {
                switch self {
                case .websocket: return "WebSocket"
                case .http: return "HTTP"
                case .local: return "本地"
                }
            }
            
            var iconName: String {
                switch self {
                case .websocket: return "antenna.radiowaves.left.and.right"
                case .http: return "globe"
                case .local: return "folder"
                }
            }
        }
        
        struct AuthConfig: Codable, Equatable {
            var type: AuthType
            var username: String?
            var password: String?
            var apiKey: String?
            var token: String?
            
            enum AuthType: String, Codable {
                case none = "none"
                case basic = "basic"
                case bearer = "bearer"
                case apiKey = "apiKey"
            }
        }
        
        struct RequestConfig: Codable, Equatable {
            var method: String
            var headers: [String: String]
            var bodyTemplate: String?
            var timeout: TimeInterval
            
            init(method: String = "GET", headers: [String: String] = [:], bodyTemplate: String? = nil, timeout: TimeInterval = 30) {
                self.method = method
                self.headers = headers
                self.bodyTemplate = bodyTemplate
                self.timeout = timeout
            }
        }
        
        init(name: String, url: String, type: SourceType = .websocket, headers: [String: String] = [:], authConfig: AuthConfig? = nil) {
            self.id = UUID().uuidString
            self.name = name
            self.url = url
            self.headers = headers
            self.type = type
            self.isEnabled = true
            self.priority = 0
            self.authConfig = authConfig
            self.requestConfig = RequestConfig()
            self.createdTime = Date()
            self.lastUsedTime = Date()
        }
    }
    
    private init() {
        super.init()
        loadSources()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .webSocketDidConnect)
            .sink { [weak self] _ in
                self?.isConnected = true
                self?.connectionState = .connected
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .webSocketDidDisconnect)
            .sink { [weak self] _ in
                self?.isConnected = false
                self?.connectionState = .disconnected
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .webSocketDidEncounterError)
            .sink { [weak self] notification in
                if let error = notification.object as? Error {
                    self?.connectionState = .failed(error)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadSources() {
        if let savedSources = loadCodable([AudioSource].self, key: "CustomAudioSource_sources") {
            sources = savedSources
        } else {
            sources = defaultSources
            saveSources()
        }
    }
    
    private func saveSources() {
        saveCodable(sources, key: "CustomAudioSource_sources")
    }
    
    private var defaultSources: [AudioSource] {
        [
            AudioSource(
                name: "本地TTS",
                url: "local://tts",
                type: .local,
                headers: [:]
            )
        ]
    }
    
    func addSource(_ source: AudioSource) {
        sources.append(source)
        saveSources()
    }
    
    func updateSource(_ source: AudioSource) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = source
            saveSources()
        }
    }
    
    func removeSource(_ source: AudioSource) {
        sources.removeAll { $0.id == source.id }
        saveSources()
    }
    
    func removeSource(id: String) {
        sources.removeAll { $0.id == id }
        saveSources()
    }
    
    func connect(to source: AudioSource) {
        activeSource = source
        isConnected = false
        connectionState = .connecting
        
        var headers = source.headers
        
        if let auth = source.authConfig {
            switch auth.type {
            case .basic:
                if let username = auth.username, let password = auth.password {
                    let credentials = "\(username):\(password)"
                    if let data = credentials.data(using: .utf8) {
                        let base64 = data.base64EncodedString()
                        headers["Authorization"] = "Basic \(base64)"
                    }
                }
            case .bearer:
                if let token = auth.token {
                    headers["Authorization"] = "Bearer \(token)"
                }
            case .apiKey:
                if let apiKey = auth.apiKey {
                    headers["X-API-Key"] = apiKey
                }
            case .none:
                break
            }
        }
        
        WebSocketManager.shared.connect(to: source.url, headers: headers)
        
        var updatedSource = source
        updatedSource.lastUsedTime = Date()
        updateSource(updatedSource)
    }
    
    func disconnect() {
        WebSocketManager.shared.disconnect()
        activeSource = nil
        isConnected = false
        connectionState = .disconnected
    }
    
    func sendRequest(_ request: AudioRequest) {
        guard isConnected, let source = activeSource else {
            logWarning("Cannot send request: not connected")
            return
        }
        
        var message: [String: Any] = [
            "type": "audio_request",
            "action": request.action,
            "bookId": request.bookId,
            "chapterId": request.chapterId,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let text = request.text {
            message["text"] = text
        }
        if let voiceId = request.voiceId {
            message["voiceId"] = voiceId
        }
        if let speed = request.speed {
            message["speed"] = speed
        }
        if let pitch = request.pitch {
            message["pitch"] = pitch
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            WebSocketManager.shared.send(jsonString)
        }
    }
    
    func sendTextToSpeech(text: String, bookId: String, chapterId: String, voiceId: String? = nil, speed: Float? = nil) {
        let request = AudioRequest(
            action: "tts",
            bookId: bookId,
            chapterId: chapterId,
            text: text,
            voiceId: voiceId,
            speed: speed
        )
        sendRequest(request)
    }
    
    func getAudioStreamUrl(bookId: String, chapterId: String) -> String? {
        guard let source = activeSource, isConnected else { return nil }
        
        let urlTemplate = source.url.replacingOccurrences(of: "{bookId}", with: bookId)
            .replacingOccurrences(of: "{chapterId}", with: chapterId)
        
        return urlTemplate
    }
    
    func getSources(sortedBy: SortOption = .priority) -> [AudioSource] {
        switch sortedBy {
        case .name:
            return sources.sorted { $0.name < $1.name }
        case .priority:
            return sources.sorted { $0.priority > $1.priority }
        case .lastUsed:
            return sources.sorted { $0.lastUsedTime > $1.lastUsedTime }
        case .created:
            return sources.sorted { $0.createdTime > $1.createdTime }
        }
    }
    
    func getEnabledSources() -> [AudioSource] {
        return sources.filter { $0.isEnabled }
    }
    
    enum SortOption: String, CaseIterable {
        case name = "名称"
        case priority = "优先级"
        case lastUsed = "最近使用"
        case created = "创建时间"
    }
}

struct AudioRequest: Codable {
    let action: String
    let bookId: String
    let chapterId: String
    var text: String?
    var voiceId: String?
    var speed: Float?
    var pitch: Float?
    var volume: Float?
    
    init(action: String, bookId: String, chapterId: String, text: String? = nil, voiceId: String? = nil, speed: Float? = nil, pitch: Float? = nil, volume: Float? = nil) {
        self.action = action
        self.bookId = bookId
        self.chapterId = chapterId
        self.text = text
        self.voiceId = voiceId
        self.speed = speed
        self.pitch = pitch
        self.volume = volume
    }
}

struct AudioResponse: Codable {
    let type: String
    let action: String?
    let status: ResponseStatus
    let audioUrl: String?
    let audioData: String?
    let error: String?
    let metadata: [String: String]?
    
    enum ResponseStatus: String, Codable {
        case success
        case pending
        case error
    }
}

class WebSocketAudioService: BaseService {
    static let shared = WebSocketAudioService()
    
    private var cancellables = Set<AnyCancellable>()
    private var audioDataBuffer = Data()
    
    @Published var isStreaming = false
    @Published var currentStreamUrl: String?
    @Published var downloadProgress: Double = 0
    
    private init() {
        super.init()
        setupMessageHandler()
    }
    
    private func setupMessageHandler() {
        NotificationCenter.default.publisher(for: .webSocketDidReceiveMessage)
            .sink { [weak self] notification in
                guard let message = notification.object as? String else { return }
                self?.handleMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let response = try? JSONDecoder().decode(AudioResponse.self, from: data) else {
            logWarning("Failed to decode WebSocket message")
            return
        }
        
        switch response.type {
        case "audio_url":
            handleAudioUrl(response)
        case "audio_chunk":
            handleAudioChunk(response)
        case "audio_complete":
            handleAudioComplete(response)
        case "error":
            handleError(response)
        default:
            logDebug("Unknown message type: \(response.type)")
        }
    }
    
    private func handleAudioUrl(_ response: AudioResponse) {
        if let url = response.audioUrl {
            currentStreamUrl = url
            logInfo("Received audio URL: \(url)")
            NotificationCenter.default.post(name: .audioStreamUrlReceived, object: url)
        }
    }
    
    private func handleAudioChunk(_ response: AudioResponse) {
        if let base64Data = response.audioData,
           let chunkData = Data(base64Encoded: base64Data) {
            audioDataBuffer.append(chunkData)
            logDebug("Received audio chunk: \(chunkData.count) bytes")
        }
    }
    
    private func handleAudioComplete(_ response: AudioResponse) {
        isStreaming = false
        downloadProgress = 1.0
        logInfo("Audio streaming complete")
        NotificationCenter.default.post(name: .audioStreamComplete, object: audioDataBuffer)
        audioDataBuffer.removeAll()
    }
    
    private func handleError(_ response: AudioResponse) {
        logError("WebSocket audio error: \(response.error ?? "Unknown error")")
        NotificationCenter.default.post(name: .audioStreamError, object: response.error)
    }
    
    func requestAudioUrl(bookId: String, chapterId: String, voiceId: String? = nil) {
        let message: [String: Any] = [
            "type": "audio_request",
            "action": "get_url",
            "bookId": bookId,
            "chapterId": chapterId,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let voiceId = voiceId {
            message["voiceId"] = voiceId
        }
        
        sendMessage(message)
    }
    
    func requestTextToSpeech(text: String, voiceId: String? = nil, speed: Float? = nil) {
        let message: [String: Any] = [
            "type": "tts_request",
            "action": "synthesize",
            "text": text,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let voiceId = voiceId {
            message["voiceId"] = voiceId
        }
        if let speed = speed {
            message["speed"] = speed
        }
        
        sendMessage(message)
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8) else {
            logError("Failed to serialize message")
            return
        }
        
        WebSocketManager.shared.send(jsonString)
    }
    
    func cancelRequest() {
        let message: [String: Any] = [
            "type": "cancel",
            "timestamp": Date().timeIntervalSince1970
        ]
        sendMessage(message)
        isStreaming = false
        audioDataBuffer.removeAll()
    }
}

extension Notification.Name {
    static let audioStreamUrlReceived = Notification.Name("audioStreamUrlReceived")
    static let audioStreamComplete = Notification.Name("audioStreamComplete")
    static let audioStreamError = Notification.Name("audioStreamError")
}
