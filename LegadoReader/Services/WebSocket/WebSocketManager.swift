import Foundation
import Combine

class WebSocketManager: BaseService, NSObject {
    static let shared = WebSocketManager()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var pingTimer: OptimizedTimer?
    private var reconnectTimer: OptimizedTimer?
    private var messageQueue: [String] = []
    
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: WebSocketError?
    @Published var lastMessage: String?
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(Error)
        
        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.connected, .connected):
                return true
            case let (.reconnecting(a1), .reconnecting(a2)):
                return a1 == a2
            default:
                return false
            }
        }
    }
    
    enum WebSocketError: Error, LocalizedError {
        case connectionFailed(String)
        case connectionClosed
        case invalidURL
        case encodingFailed
        case decodingFailed
        case timeout
        case maxReconnectAttemptsReached
        
        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "连接失败: \(msg)"
            case .connectionClosed: return "连接已关闭"
            case .invalidURL: return "无效的URL"
            case .encodingFailed: return "编码失败"
            case .decodingFailed: return "解码失败"
            case .timeout: return "连接超时"
            case .maxReconnectAttemptsReached: return "已达到最大重连次数"
            }
        }
    }
    
    private var currentURL: URL?
    private var currentHeaders: [String: String] = [:]
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectInterval: TimeInterval = 3.0
    private let pingInterval: TimeInterval = 30.0
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }
    
    func connect(to urlString: String, headers: [String: String] = [:]) {
        guard let url = URL(string: urlString) else {
            lastError = .invalidURL
            logError("Invalid WebSocket URL: \(urlString)")
            return
        }
        
        currentURL = url
        currentHeaders = headers
        
        disconnect()
        
        connectionState = .connecting
        logInfo("Connecting to WebSocket: \(urlString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        receiveMessage()
        startPingTimer()
    }
    
    func disconnect() {
        stopPingTimer()
        stopReconnectTimer()
        reconnectAttempts = 0
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        isConnected = false
        connectionState = .disconnected
        
        logInfo("WebSocket disconnected")
    }
    
    func send(_ message: String) {
        guard isConnected else {
            messageQueue.append(message)
            logWarning("Message queued (not connected): \(message.prefix(50))")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(message)
        
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                self?.logError("Failed to send message: \(error.localizedDescription)")
                self?.lastError = .connectionFailed(error.localizedDescription)
            }
        }
    }
    
    func send(data: Data) {
        guard isConnected else {
            logWarning("Data message queued (not connected)")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                self?.logError("Failed to send data: \(error.localizedDescription)")
                self?.lastError = .connectionFailed(error.localizedDescription)
            }
        }
    }
    
    func sendJSON<T: Encodable>(_ object: T) {
        guard let data = try? JSONEncoder().encode(object),
              let jsonString = String(data: data, encoding: .utf8) else {
            lastError = .encodingFailed
            logError("Failed to encode object to JSON")
            return
        }
        
        send(jsonString)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()
                
            case .failure(let error):
                self.handleError(error)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            logDebug("Received text message: \(text.prefix(100))")
            lastMessage = text
            NotificationCenter.default.post(name: .webSocketDidReceiveMessage, object: text)
            
        case .data(let data):
            logDebug("Received data message: \(data.count) bytes")
            NotificationCenter.default.post(name: .webSocketDidReceiveData, object: data)
            
        @unknown default:
            logWarning("Unknown message type received")
        }
    }
    
    private func handleError(_ error: Error) {
        logError("WebSocket error: \(error.localizedDescription)")
        isConnected = false
        connectionState = .disconnected
        
        lastError = .connectionFailed(error.localizedDescription)
        NotificationCenter.default.post(name: .webSocketDidEncounterError, object: error)
        
        attemptReconnect()
    }
    
    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts,
              let url = currentURL else {
            connectionState = .failed(lastError ?? WebSocketError.maxReconnectAttemptsReached)
            logError("Max reconnect attempts reached")
            return
        }
        
        reconnectAttempts += 1
        connectionState = .reconnecting(attempt: reconnectAttempts)
        
        logInfo("Attempting reconnect (\(reconnectAttempts)/\(maxReconnectAttempts)) in \(reconnectInterval)s...")
        
        reconnectTimer = OptimizedTimer(interval: reconnectInterval) { [weak self] in
            self?.connect(to: url.absoluteString, headers: self?.currentHeaders ?? [:])
        }
        reconnectTimer?.start()
    }
    
    private func startPingTimer() {
        pingTimer = OptimizedTimer(interval: pingInterval) { [weak self] in
            self?.sendPing()
        }
        pingTimer?.start()
    }
    
    private func stopPingTimer() {
        pingTimer?.stop()
        pingTimer = nil
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.stop()
        reconnectTimer = nil
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                self?.logWarning("Ping failed: \(error.localizedDescription)")
            }
        }
    }
    
    func flushMessageQueue() {
        guard isConnected else { return }
        
        let messages = messageQueue
        messageQueue.removeAll()
        
        for message in messages {
            send(message)
        }
        
        logInfo("Flushed \(messages.count) queued messages")
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        connectionState = .connected
        reconnectAttempts = 0
        
        logInfo("WebSocket connected")
        NotificationCenter.default.post(name: .webSocketDidConnect, object: nil)
        
        flushMessageQueue()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        connectionState = .disconnected
        
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown"
        logInfo("WebSocket closed with code: \(closeCode), reason: \(reasonString)")
        
        NotificationCenter.default.post(name: .webSocketDidDisconnect, object: closeCode)
        
        if closeCode != .normalClosure {
            attemptReconnect()
        }
    }
}

extension Notification.Name {
    static let webSocketDidConnect = Notification.Name("webSocketDidConnect")
    static let webSocketDidDisconnect = Notification.Name("webSocketDidDisconnect")
    static let webSocketDidReceiveMessage = Notification.Name("webSocketDidReceiveMessage")
    static let webSocketDidReceiveData = Notification.Name("webSocketDidReceiveData")
    static let webSocketDidEncounterError = Notification.Name("webSocketDidEncounterError")
}

struct WebSocketMessage: Codable {
    let type: String
    let action: String?
    let data: [String: AnyCodable]?
    let timestamp: TimeInterval?
    
    init(type: String, action: String? = nil, data: [String: AnyCodable]? = nil) {
        self.type = type
        self.action = action
        self.data = data
        self.timestamp = Date().timeIntervalSince1970
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
    
    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var doubleValue: Double? { value as? Double }
    var boolValue: Bool? { value as? Bool }
    var arrayValue: [Any]? { value as? [Any] }
    var dictValue: [String: Any]? { value as? [String: Any] }
}
