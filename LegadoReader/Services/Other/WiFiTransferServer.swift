import Foundation
import Network
import CocoaAsyncSocket

class WiFiTransferServer: NSObject, ObservableObject {
    static let shared = WiFiTransferServer()
    
    @Published var isRunning = false
    @Published var serverAddress: String = ""
    @Published var port: UInt16 = 8080
    @Published var connectedDevices: [ConnectedDevice] = []
    @Published var transferHistory: [TransferRecord] = []
    @Published var currentTransfer: TransferInfo?
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let downloadDirectory: URL
    
    struct ConnectedDevice: Identifiable {
        let id: String
        let address: String
        let connectedTime: Date
    }
    
    struct TransferRecord: Identifiable, Codable {
        let id: String
        let fileName: String
        let fileSize: Int64
        let transferTime: Date
        let success: Bool
        let filePath: String
    }
    
    struct TransferInfo {
        let fileName: String
        let totalSize: Int64
        var receivedSize: Int64
        var progress: Double {
            guard totalSize > 0 else { return 0 }
            return Double(receivedSize) / Double(totalSize)
        }
    }
    
    private override init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        downloadDirectory = documentsDirectory.appendingPathComponent("WiFiTransfers")
        
        super.init()
        
        try? fileManager.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        
        loadTransferHistory()
    }
    
    private func loadTransferHistory() {
        if let data = UserDefaults.standard.data(forKey: "WiFiTransfer_history"),
           let history = try? JSONDecoder().decode([TransferRecord].self, from: data) {
            transferHistory = history
        }
    }
    
    private func saveTransferHistory() {
        if let data = try? JSONEncoder().encode(transferHistory) {
            UserDefaults.standard.set(data, forKey: "WiFiTransfer_history")
        }
    }
    
    func startServer() {
        guard !isRunning else { return }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.updateServerAddress()
                    case .failed(let error):
                        print("服务器启动失败: \(error)")
                        self?.isRunning = false
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
            
        } catch {
            print("无法启动服务器: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        DispatchQueue.main.async {
            self.isRunning = false
            self.serverAddress = ""
            self.connectedDevices.removeAll()
        }
    }
    
    private func updateServerAddress() {
        if let address = getWiFiAddress() {
            serverAddress = "http://\(address):\(port)"
        } else {
            serverAddress = "http://127.0.0.1:\(port)"
        }
    }
    
    private func getWiFiAddress() -> String? {
        var address: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                }
            }
        }
        
        return address
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        
        let device = ConnectedDevice(
            id: UUID().uuidString,
            address: endpointToString(connection.endpoint),
            connectedTime: Date()
        )
        DispatchQueue.main.async {
            self.connectedDevices.append(device)
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveRequest(connection)
            case .failed, .cancelled:
                DispatchQueue.main.async {
                    self?.connectedDevices.removeAll { $0.id == device.id }
                    self?.connections.removeAll { $0 === connection }
                }
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    private func endpointToString(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .hostPort(let host, _):
            return "\(host)"
        default:
            return "未知设备"
        }
    }
    
    private func receiveRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                if isComplete {
                    connection.cancel()
                }
                return
            }
            
            self.processRequest(data, connection: connection)
            
            if !isComplete {
                self.receiveRequest(connection)
            }
        }
    }
    
    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        if method == "GET" {
            handleGET(path: path, connection: connection)
        } else if method == "POST" {
            handlePOST(data: data, connection: connection)
        } else {
            sendResponse(connection: connection, statusCode: 405, body: "Method Not Allowed")
        }
    }
    
    private func handleGET(path: String, connection: NWConnection) {
        if path == "/" || path == "/index.html" {
            sendHTMLPage(connection: connection)
        } else if path == "/files" {
            sendFileList(connection: connection)
        } else if path.hasPrefix("/download/") {
            let fileName = String(path.dropFirst("/download/".count))
            sendFile(fileName: fileName, connection: connection)
        } else if path == "/status" {
            sendStatus(connection: connection)
        } else {
            sendResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }
    
    private func handlePOST(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let headerEndIndex = requestString.range(of: "\r\n\r\n")
        guard let headerEnd = headerEndIndex else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let headers = String(requestString[..<headerEnd.lowerBound])
        let bodyData = Data(requestString[headerEnd.upperBound...].utf8)
        
        guard let contentLength = extractContentLength(from: headers) else {
            sendResponse(connection: connection, statusCode: 400, body: "Content-Length required")
            return
        }
        
        guard bodyData.count >= contentLength else {
            sendResponse(connection: connection, statusCode: 400, body: "Incomplete data")
            return
        }
        
        let fileName = extractFileName(from: headers) ?? "unknown"
        let fileData = bodyData.prefix(contentLength)
        
        saveUploadedFile(data: Data(fileData), fileName: fileName, connection: connection)
    }
    
    private func extractContentLength(from headers: String) -> Int? {
        let lines = headers.components(separatedBy: "\r\n")
        for line in lines {
            if line.lowercased().hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(value)
            }
        }
        return nil
    }
    
    private func extractFileName(from headers: String) -> String? {
        let lines = headers.components(separatedBy: "\r\n")
        for line in lines {
            if line.lowercased().hasPrefix("x-filename:") {
                return String(line.dropFirst("x-filename:".count).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
    
    private func saveUploadedFile(data: Data, fileName: String, connection: NWConnection) {
        let filePath = downloadDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: filePath)
            
            let fileSize = Int64(data.count)
            
            let record = TransferRecord(
                id: UUID().uuidString,
                fileName: fileName,
                fileSize: fileSize,
                transferTime: Date(),
                success: true,
                filePath: filePath.path
            )
            
            DispatchQueue.main.async {
                self.transferHistory.insert(record, at: 0)
                if self.transferHistory.count > 100 {
                    self.transferHistory = Array(self.transferHistory.prefix(100))
                }
                self.saveTransferHistory()
            }
            
            sendJSONResponse(connection: connection, data: [
                "success": true,
                "fileName": fileName,
                "fileSize": fileSize,
                "message": "文件上传成功"
            ])
            
        } catch {
            sendJSONResponse(connection: connection, data: [
                "success": false,
                "message": "保存文件失败: \(error.localizedDescription)"
            ])
        }
    }
    
    private func sendHTMLPage(connection: NWConnection) {
        let html = generateUploadPage()
        sendResponse(connection: connection, statusCode: 200, body: html, contentType: "text/html; charset=utf-8")
    }
    
    private func sendFileList(connection: NWConnection) {
        var files: [[String: Any]] = []
        
        if let enumerator = fileManager.enumerator(at: downloadDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let size = (attributes[.size] as? Int64) ?? 0
                    let date = (attributes[.creationDate] as? Date) ?? Date()
                    
                    files.append([
                        "name": fileURL.lastPathComponent,
                        "size": size,
                        "date": ISO8601DateFormatter().string(from: date)
                    ])
                } catch {}
            }
        }
        
        let jsonData = try? JSONSerialization.data(withJSONObject: files)
        let jsonString = String(data: jsonData ?? Data(), encoding: .utf8) ?? "[]"
        
        sendResponse(connection: connection, statusCode: 200, body: jsonString, contentType: "application/json")
    }
    
    private func sendStatus(connection: NWConnection) {
        let status: [String: Any] = [
            "running": isRunning,
            "address": serverAddress,
            "port": port,
            "connectedCount": connectedDevices.count
        ]
        
        sendJSONResponse(connection: connection, data: status)
    }
    
    private func sendFile(fileName: String, connection: NWConnection) {
        let filePath = downloadDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: filePath.path) else {
            sendResponse(connection: connection, statusCode: 404, body: "File not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            sendDataResponse(connection: connection, data: data, contentType: "application/octet-stream", fileName: fileName)
        } catch {
            sendResponse(connection: connection, statusCode: 500, body: "Error reading file")
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String, contentType: String = "text/plain") {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 400 ? "Bad Request" : (statusCode == 404 ? "Not Found" : (statusCode == 405 ? "Method Not Allowed" : (statusCode == 500 ? "Internal Server Error" : "Unknown"))))
        
        let headers = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        \r
        
        """
        
        let headerData = headers.data(using: .utf8)!
        let bodyData = body.data(using: .utf8)!
        let responseData = headerData + bodyData
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendDataResponse(connection: NWConnection, data: Data, contentType: String, fileName: String) {
        let headers = """
        HTTP/1.1 200 OK\r
        Content-Type: \(contentType)\r
        Content-Length: \(data.count)\r
        Content-Disposition: attachment; filename="\(fileName)"\r
        Connection: close\r
        \r
        
        """
        
        let headerData = headers.data(using: .utf8)!
        let responseData = headerData + data
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendJSONResponse(connection: NWConnection, data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
            sendResponse(connection: connection, statusCode: 500, body: "JSON encoding error")
            return
        }
        
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        sendResponse(connection: connection, statusCode: 200, body: jsonString, contentType: "application/json")
    }
    
    private func generateUploadPage() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>LegadoReader WiFi传输</title>
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; padding: 20px; }
                .container { max-width: 800px; margin: 0 auto; }
                h1 { text-align: center; color: #333; margin-bottom: 30px; }
                .upload-area { background: white; border-radius: 12px; padding: 40px; text-align: center; border: 2px dashed #ddd; margin-bottom: 20px; transition: all 0.3s; }
                .upload-area:hover { border-color: #007AFF; background: #f8f8ff; }
                .upload-area.dragover { border-color: #007AFF; background: #e8f4ff; }
                input[type="file"] { display: none; }
                .upload-btn { display: inline-block; padding: 12px 30px; background: #007AFF; color: white; border-radius: 8px; cursor: pointer; font-size: 16px; }
                .upload-btn:hover { background: #0056b3; }
                .file-list { background: white; border-radius: 12px; overflow: hidden; }
                .file-item { display: flex; justify-content: space-between; align-items: center; padding: 15px 20px; border-bottom: 1px solid #eee; }
                .file-item:last-child { border-bottom: none; }
                .file-name { font-weight: 500; color: #333; }
                .file-size { color: #666; font-size: 14px; }
                .status { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; }
                .status.success { background: #d4edda; color: #155724; }
                .info { background: white; border-radius: 12px; padding: 20px; margin-bottom: 20px; }
                .info p { margin-bottom: 10px; color: #666; }
                .info strong { color: #333; }
                .supported { color: #666; font-size: 14px; margin-top: 10px; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📚 LegadoReader WiFi传输</h1>
                
                <div class="info">
                    <p><strong>使用说明：</strong></p>
                    <p>1. 点击下方按钮选择要传输的书籍文件</p>
                    <p>2. 支持多选，一次可传输多本书籍</p>
                    <p>3. 传输完成后在APP中刷新书架即可看到</p>
                    <p class="supported"><strong>支持格式：</strong>TXT, EPUB, PDF, MOBI, AZW, AZW3, CBZ, CBR, DOCX 等</p>
                </div>
                
                <div class="upload-area" id="dropZone">
                    <p style="margin-bottom: 15px; color: #666;">拖拽文件到这里 或</p>
                    <label class="upload-btn">
                        选择文件
                        <input type="file" id="fileInput" multiple accept=".txt,.epub,.pdf,.mobi,.azw,.azw3,.cbz,.cbr,.docx,.zip,.rar">
                    </label>
                </div>
                
                <div class="file-list" id="fileList">
                    <div class="file-item">
                        <span class="file-name">暂无传输记录</span>
                    </div>
                </div>
            </div>
            
            <script>
                const dropZone = document.getElementById('dropZone');
                const fileInput = document.getElementById('fileInput');
                const fileList = document.getElementById('fileList');
                
                dropZone.addEventListener('dragover', (e) => {
                    e.preventDefault();
                    dropZone.classList.add('dragover');
                });
                
                dropZone.addEventListener('dragleave', () => {
                    dropZone.classList.remove('dragover');
                });
                
                dropZone.addEventListener('drop', (e) => {
                    e.preventDefault();
                    dropZone.classList.remove('dragover');
                    handleFiles(e.dataTransfer.files);
                });
                
                fileInput.addEventListener('change', () => {
                    handleFiles(fileInput.files);
                });
                
                function escapeHTML(str) {
                    const div = document.createElement('div');
                    div.textContent = str;
                    return div.innerHTML;
                }
                
                async function handleFiles(files) {
                    fileList.innerHTML = '';
                    
                    for (const file of files) {
                        await uploadFile(file);
                    }
                    
                    loadTransferHistory();
                }
                
                async function uploadFile(file) {
                    const formData = new FormData();
                    formData.append('file', file);
                    
                    const item = document.createElement('div');
                    item.className = 'file-item';
                    const safeName = escapeHTML(file.name);
                    item.innerHTML = \`
                        <div>
                            <div class="file-name">\${safeName}</div>
                            <div class="file-size">正在上传... 0%</div>
                        </div>
                        <span class="status" style="background: #fff3cd; color: #856404;">上传中</span>
                    \`;
                    fileList.appendChild(item);
                    
                    try {
                        const response = await fetch('/', {
                            method: 'POST',
                            headers: { 'X-FileName': file.name },
                            body: file
                        });
                        
                        const result = await response.json();
                        
                        if (result.success) {
                            const safeFileName = escapeHTML(result.fileName);
                            const safeSize = formatSize(result.fileSize);
                            item.innerHTML = \`
                                <div>
                                    <div class="file-name">\${safeFileName}</div>
                                    <div class="file-size">\${safeSize}</div>
                                </div>
                                <span class="status success">成功</span>
                            \`;
                        } else {
                            const safeMsg = escapeHTML(result.message);
                            item.innerHTML = \`
                                <div>
                                    <div class="file-name">\${safeName}</div>
                                    <div class="file-size">\${safeMsg}</div>
                                </div>
                                <span class="status" style="background: #f8d7da; color: #721c24;">失败</span>
                            \`;
                        }
                    } catch (error) {
                        const safeError = escapeHTML(error.message);
                        item.innerHTML = \`
                            <div>
                                <div class="file-name">\${safeName}</div>
                                <div class="file-size">上传失败: \${safeError}</div>
                            </div>
                            <span class="status" style="background: #f8d7da; color: #721c24;">失败</span>
                        \`;
                    }
                }
                
                function formatSize(bytes) {
                    if (bytes < 1024) return bytes + ' B';
                    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
                    if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(2) + ' MB';
                    return (bytes / 1024 / 1024 / 1024).toFixed(2) + ' GB';
                }
                
                async function loadTransferHistory() {
                    try {
                        const response = await fetch('/files');
                        const files = await response.json();
                        
                        if (files.length > 0) {
                            fileList.innerHTML = '';
                            files.forEach(file => {
                                const item = document.createElement('div');
                                item.className = 'file-item';
                                const safeName = escapeHTML(file.name);
                                const safeSize = formatSize(file.size);
                                item.innerHTML = \`
                                    <div>
                                        <div class="file-name">\${safeName}</div>
                                        <div class="file-size">\${safeSize}</div>
                                    </div>
                                    <span class="status success">已接收</span>
                                \`;
                                fileList.appendChild(item);
                            });
                        }
                    } catch (error) {
                        console.error('加载历史记录失败:', error);
                    }
                }
                
                loadTransferHistory();
            </script>
        </body>
        </html>
        """
    }
    
    func getDownloadedFiles() -> [URL] {
        var files: [URL] = []
        
        if let enumerator = fileManager.enumerator(at: downloadDirectory, includingPropertiesForKeys: nil) {
            while let fileURL = enumerator.nextObject() as? URL {
                files.append(fileURL)
            }
        }
        
        return files
    }
    
    func deleteDownloadedFile(at url: URL) {
        try? fileManager.removeItem(at: url)
    }
    
    func clearAllDownloads() {
        if let enumerator = fileManager.enumerator(at: downloadDirectory, includingPropertiesForKeys: nil) {
            while let fileURL = enumerator.nextObject() as? URL {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    func clearTransferHistory() {
        transferHistory.removeAll()
        saveTransferHistory()
    }
}
