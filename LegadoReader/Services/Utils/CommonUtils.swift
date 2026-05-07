import Foundation

class AppStorageManager {
    static let shared = AppStorageManager()
    
    private let userDefaults: UserDefaults
    
    private init() {
        self.userDefaults = UserDefaults.standard
    }
    
    func save<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        if let data = userDefaults.data(forKey: key) {
            return try? JSONDecoder().decode(type, from: data)
        }
        return nil
    }
    
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    func set(_ value: Any?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func string(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }
    
    func integer(forKey key: String) -> Int {
        return userDefaults.integer(forKey: key)
    }
    
    func bool(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }
    
    func data(forKey key: String) -> Data? {
        return userDefaults.data(forKey: key)
    }
    
    func register(defaults: [String: Any]) {
        userDefaults.register(defaults: defaults)
    }
}

class JSONHelper {
    static let shared = JSONHelper()
    
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        decoder = JSONDecoder()
    }
    
    func encode<T: Codable>(_ value: T) -> Data? {
        return try? encoder.encode(value)
    }
    
    func encodeAsString<T: Codable>(_ value: T) -> String? {
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func decode<T: Codable>(_ type: T.Type, from data: Data) -> T? {
        return try? decoder.decode(type, from: data)
    }
    
    func decode<T: Codable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? decoder.decode(type, from: data)
    }
    
    func decodeArray<T: Codable>(_ type: T.Type, from data: Data) -> [T]? {
        return try? decoder.decode([T].self, from: data)
    }
    
    func decodeArray<T: Codable>(_ type: T.Type, from string: String) -> [T]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? decoder.decode([T].self, from: data)
    }
}

class FileManagerHelper {
    static let shared = FileManagerHelper()
    
    private let fileManager: FileManager
    
    private init() {
        self.fileManager = FileManager.default
    }
    
    func documentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func libraryDirectory() -> URL {
        return fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
    }
    
    func cachesDirectory() -> URL {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    func removeFile(at url: URL) throws {
        if fileExists(at: url) {
            try fileManager.removeItem(at: url)
        }
    }
    
    func copyFile(from source: URL, to destination: URL) throws {
        if fileExists(at: destination) {
            try removeFile(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }
    
    func moveFile(from source: URL, to destination: URL) throws {
        if fileExists(at: destination) {
            try removeFile(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
    }
    
    func fileSize(at url: URL) -> UInt64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return 0 }
        return attributes[.size] as? UInt64 ?? 0
    }
    
    func listFiles(at directory: URL) -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files
    }
    
    func clearDirectory(_ directory: URL) throws {
        let files = listFiles(at: directory)
        for file in files {
            try removeFile(at: file)
        }
    }
    
    func getFileExtension(_ filename: String) -> String {
        return filename.lowercased().components(separatedBy: ".").last ?? ""
    }
    
    func getFileNameWithoutExtension(_ filename: String) -> String {
        let components = filename.components(separatedBy: ".")
        if components.count > 1 {
            return components.dropLast().joined(separator: ".")
        }
        return filename
    }
}

class Logger {
    static let shared = Logger()
    
    private let logQueue = DispatchQueue(label: "com.legado.reader.logger")
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: "DEBUG", message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: "INFO", message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: "WARN", message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: "ERROR", message: message, file: file, function: function, line: line)
    }
    
    func error(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: "ERROR", message: error.localizedDescription, file: file, function: function, line: line)
    }
    
    private func log(level: String, message: String, file: String, function: String, line: Int) {
        logQueue.async {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestamp = dateFormatter.string(from: Date())
            
            let fileURL = URL(fileURLWithPath: file)
            let fileName = fileURL.lastPathComponent
            
            print("[LegadoReader] \(timestamp) [\(level)] \(fileName):\(line) \(function) - \(message)")
        }
    }
}

protocol Singleton: AnyObject {
    static var shared: Self { get }
}

extension Singleton {
    static var shared: Self {
        struct SharedContainer {
            static let instance = Self.init()
        }
        return SharedContainer.instance
    }
}
