import Foundation
import Combine

class BaseService: ObservableObject {
    let storageManager = AppStorageManager.shared
    let jsonHelper = JSONHelper.shared
    let fileManager = FileManagerHelper.shared
    let logger = Logger.shared
    
    var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.removeAll()
    }
    
    func saveCodable<T: Codable>(_ value: T, key: String) {
        storageManager.save(value, forKey: key)
    }
    
    func loadCodable<T: Codable>(_ type: T.Type, key: String) -> T? {
        return storageManager.load(type, forKey: key)
    }
    
    func removeKey(_ key: String) {
        storageManager.remove(forKey: key)
    }
    
    func encodeJSON<T: Codable>(_ value: T) -> Data? {
        return jsonHelper.encode(value)
    }
    
    func decodeJSON<T: Codable>(_ type: T.Type, from data: Data) -> T? {
        return jsonHelper.decode(type, from: data)
    }
    
    func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.debug(message, file: file, function: function, line: line)
    }
    
    func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.info(message, file: file, function: function, line: line)
    }
    
    func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.warning(message, file: file, function: function, line: line)
    }
    
    func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error(message, file: file, function: function, line: line)
    }
    
    func logError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error(error, file: file, function: function, line: line)
    }
}

class BaseSettingsManager<T: Codable>: BaseService {
    private let settingsKey: String
    private let defaultValue: T
    
    init(settingsKey: String, defaultValue: T) {
        self.settingsKey = settingsKey
        self.defaultValue = defaultValue
        super.init()
    }
    
    func getSettings() -> T {
        if let settings = loadCodable(T.self, key: settingsKey) {
            return settings
        }
        return defaultValue
    }
    
    func saveSettings(_ settings: T) {
        saveCodable(settings, key: settingsKey)
        logInfo("Settings saved for key: \(settingsKey)")
    }
}

class BaseDataManager<T: Identifiable & Codable>: BaseService {
    private let dataKey: String
    @Published var items: [T] = []
    private var isLoaded = false
    
    init(dataKey: String) {
        self.dataKey = dataKey
        super.init()
    }
    
    func ensureLoaded() {
        guard !isLoaded else { return }
        loadData()
        isLoaded = true
    }
    
    private func loadData() {
        if let saved = loadCodable([T].self, key: dataKey) {
            items = saved
            logInfo("Loaded \(items.count) items for key: \(dataKey)")
        }
    }
    
    private func saveData() {
        saveCodable(items, key: dataKey)
        logInfo("Saved \(items.count) items for key: \(dataKey)")
    }
    
    func addItem(_ item: T) {
        ensureLoaded()
        items.append(item)
        saveData()
    }
    
    func removeItem(_ id: T.ID) {
        ensureLoaded()
        items.removeAll { $0.id == id }
        saveData()
    }
    
    func updateItem(_ item: T) {
        ensureLoaded()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveData()
        }
    }
    
    func getItem(_ id: T.ID) -> T? {
        ensureLoaded()
        return items.first { $0.id == id }
    }
    
    func clearAll() {
        items.removeAll()
        saveData()
    }
    
    func exportData() -> Data? {
        ensureLoaded()
        return encodeJSON(items)
    }
}

extension BaseService {
    func safeDispatchMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
    
    func asyncTask<T>(_ task: @escaping () async throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
        Task {
            do {
                let result = try await task()
                safeDispatchMain {
                    completion(.success(result))
                }
            } catch {
                safeDispatchMain {
                    completion(.failure(error))
                }
            }
        }
    }
}

class OptimizedTimer {
    private var timer: Timer?
    private var handler: (() -> Void)?
    private let interval: TimeInterval
    private let queue: DispatchQueue
    
    init(interval: TimeInterval, queue: DispatchQueue = .main, handler: @escaping () -> Void) {
        self.interval = interval
        self.queue = queue
        self.handler = handler
    }
    
    func start() {
        stop()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.handler?()
        }
        
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func pause() {
        timer?.invalidate()
    }
    
    func resume() {
        guard timer != nil else {
            start()
            return
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    deinit {
        stop()
    }
}

class ThrottledPublisher<T> {
    private var cancellable: AnyCancellable?
    private let subject = PassthroughSubject<T, Never>()
    private let interval: TimeInterval
    
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    func publisher() -> AnyPublisher<T, Never> {
        return subject
            .throttle(for: .seconds(interval), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    func send(_ value: T) {
        subject.send(value)
    }
}

class DebouncedPublisher<T> {
    private var cancellable: AnyCancellable?
    private let subject = PassthroughSubject<T, Never>()
    private let interval: TimeInterval
    
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    func publisher() -> AnyPublisher<T, Never> {
        return subject
            .debounce(for: .seconds(interval), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func send(_ value: T) {
        subject.send(value)
    }
}
