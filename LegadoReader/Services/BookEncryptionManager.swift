import Foundation
import CryptoKit
import Security

class BookEncryptionManager: ObservableObject {
    static let shared = BookEncryptionManager()
    
    @Published var isUnlocked = false
    @Published var encryptedBooks: [EncryptedBook] = []
    @Published var failedAttempts = 0
    @Published var lockoutUntil: Date?
    
    private let defaults = UserDefaults.standard
    private let encryptedBooksKey = "BookEncryption_encryptedBooks"
    private let settingsKey = "BookEncryption_settings"
    private let maxFailedAttempts = 5
    private let lockoutDuration: TimeInterval = 300
    
    struct EncryptedBook: Identifiable, Codable {
        let id: String
        let bookId: String
        let bookName: String
        let author: String
        let coverURL: String?
        let encryptedAt: Date
        let lastAccessed: Date
        var failedAttempts: Int
        
        init(bookId: String, bookName: String, author: String, coverURL: String?) {
            self.id = UUID().uuidString
            self.bookId = bookId
            self.bookName = bookName
            self.author = author
            self.coverURL = coverURL
            self.encryptedAt = Date()
            self.lastAccessed = Date()
            self.failedAttempts = 0
        }
    }
    
    struct EncryptionSettings: Codable {
        var isEncryptionEnabled: Bool
        var encryptionType: EncryptionType
        var autoLockTimeout: Int
        var requirePasswordOnLaunch: Bool
        
        enum EncryptionType: String, Codable, CaseIterable {
            case simple = "simple"
            case standard = "standard"
            case strong = "strong"
            
            var displayName: String {
                switch self {
                case .simple: return "简单加密"
                case .standard: return "标准加密"
                case .strong: return "强加密"
                }
            }
            
            var description: String {
                switch self {
                case .simple: return "基础加密，快速但安全性较低"
                case .standard: return "推荐使用，平衡安全性和速度"
                case .strong: return "最高安全性，适合敏感内容"
                }
            }
        }
    }
    
    private var currentPassword: String = ""
    
    private init() {
        loadEncryptedBooks()
        loadSettings()
    }
    
    private func loadEncryptedBooks() {
        if let data = defaults.data(forKey: encryptedBooksKey),
           let books = try? JSONDecoder().decode([EncryptedBook].self, from: data) {
            encryptedBooks = books
        }
    }
    
    private func saveEncryptedBooks() {
        if let data = try? JSONEncoder().encode(encryptedBooks) {
            defaults.set(data, forKey: encryptedBooksKey)
        }
    }
    
    private func loadSettings() {
        if let data = defaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(EncryptionSettings.self, from: data) {
            // Settings loaded
        }
    }
    
    func saveSettings(_ settings: EncryptionSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }
    
    func getSettings() -> EncryptionSettings {
        if let data = defaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(EncryptionSettings.self, from: data) {
            return settings
        }
        return EncryptionSettings(
            isEncryptionEnabled: false,
            encryptionType: .standard,
            autoLockTimeout: 5,
            requirePasswordOnLaunch: false
        )
    }
    
    func encryptBook(_ book: Book, password: String) -> Bool {
        guard !isBookEncrypted(book.id) else { return false }
        
        let encryptedBook = EncryptedBook(
            bookId: book.id,
            bookName: book.name,
            author: book.author,
            coverURL: book.cover
        )
        
        encryptedBooks.append(encryptedBook)
        saveEncryptedBooks()
        
        saveBookContentEncrypted(bookId: book.id, content: getBookContent(book.id), password: password)
        
        return true
    }
    
    func decryptBook(_ bookId: String, password: String) -> Bool {
        guard isBookEncrypted(bookId) else { return false }
        
        guard !isLockedOut() else { return false }
        
        guard verifyPassword(bookId: bookId, password: password) else {
            recordFailedAttempt(bookId: bookId)
            return false
        }
        
        resetFailedAttempts(bookId: bookId)
        currentPassword = password
        isUnlocked = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            self?.lock()
        }
        
        return true
    }
    
    func unlockWithPassword(_ password: String) -> Bool {
        guard !isLockedOut() else { return false }
        
        for book in encryptedBooks {
            if verifyPassword(bookId: book.bookId, password: password) {
                currentPassword = password
                isUnlocked = true
                failedAttempts = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
                    self?.lock()
                }
                
                return true
            }
        }
        
        failedAttempts += 1
        
        if failedAttempts >= maxFailedAttempts {
            lockoutUntil = Date().addingTimeInterval(lockoutDuration)
        }
        
        return false
    }
    
    func removeEncryption(_ bookId: String, password: String) -> Bool {
        guard verifyPassword(bookId: bookId, password: password) else { return false }
        
        encryptedBooks.removeAll { $0.bookId == bookId }
        saveEncryptedBooks()
        removeEncryptedContent(bookId: bookId)
        
        return true
    }
    
    func isBookEncrypted(_ bookId: String) -> Bool {
        return encryptedBooks.contains { $0.bookId == bookId }
    }
    
    func lock() {
        currentPassword = ""
        isUnlocked = false
    }
    
    func isLockedOut() -> Bool {
        guard let lockout = lockoutUntil else { return false }
        if Date() > lockout {
            lockoutUntil = nil
            failedAttempts = 0
            return false
        }
        return true
    }
    
    func getRemainingLockoutTime() -> TimeInterval {
        guard let lockout = lockoutUntil else { return 0 }
        return max(0, lockout.timeIntervalSinceNow)
    }
    
    private func recordFailedAttempt(bookId: String) {
        if let index = encryptedBooks.firstIndex(where: { $0.bookId == bookId }) {
            encryptedBooks[index].failedAttempts += 1
            saveEncryptedBooks()
        }
        
        failedAttempts += 1
        
        if failedAttempts >= maxFailedAttempts {
            lockoutUntil = Date().addingTimeInterval(lockoutDuration)
        }
    }
    
    private func resetFailedAttempts(bookId: String) {
        if let index = encryptedBooks.firstIndex(where: { $0.bookId == bookId }) {
            encryptedBooks[index].failedAttempts = 0
            saveEncryptedBooks()
        }
        failedAttempts = 0
        lockoutUntil = nil
    }
    
    private func verifyPassword(bookId: String, password: String) -> Bool {
        let storedHash = getStoredPasswordHash(bookId: bookId)
        let inputHash = hashPassword(password, for: bookId)
        return storedHash == inputHash
    }
    
    private func hashPassword(_ password: String, for bookId: String) -> String {
        let salt = "LegadoReader_\(bookId)_Salt"
        let data = Data((password + salt).utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func getStoredPasswordHash(bookId: String) -> String {
        let key = "PasswordHash_\(bookId)"
        return defaults.string(forKey: key) ?? ""
    }
    
    func savePasswordHash(bookId: String, password: String) {
        let hash = hashPassword(password, for: bookId)
        let key = "PasswordHash_\(bookId)"
        defaults.set(hash, forKey: key)
    }
    
    private func saveBookContentEncrypted(bookId: String, content: String, password: String) {
        guard let encryptedData = encryptContent(content, password: password) else { return }
        
        let key = "EncryptedContent_\(bookId)"
        defaults.set(encryptedData, forKey: key)
    }
    
    private func getEncryptedContent(bookId: String) -> Data? {
        let key = "EncryptedContent_\(bookId)"
        return defaults.data(forKey: key)
    }
    
    private func removeEncryptedContent(bookId: String) {
        let contentKey = "EncryptedContent_\(bookId)"
        let hashKey = "PasswordHash_\(bookId)"
        defaults.removeObject(forKey: contentKey)
        defaults.removeObject(forKey: hashKey)
    }
    
    private func getBookContent(_ bookId: String) -> String {
        return DatabaseManager.shared.getBookContent(bookId: bookId) ?? ""
    }
    
    func encryptContent(_ content: String, password: String) -> Data? {
        guard let data = content.data(using: .utf8) else { return nil }
        
        let key = deriveKey(from: password)
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            return simpleEncrypt(content, password: password)
        }
    }
    
    func decryptContent(_ encryptedData: Data, password: String) -> String? {
        let key = deriveKey(from: password)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            return simpleDecrypt(encryptedData, password: password)
        }
    }
    
    private func deriveKey(from password: String) -> SymmetricKey {
        let salt = "LegadoReader_Encryption_Salt"
        let data = Data((password + salt).utf8)
        let hash = SHA256.hash(data: data)
        let keyData = Data(hash)
        return SymmetricKey(data: keyData)
    }
    
    private func simpleEncrypt(_ content: String, password: String) -> Data? {
        var encrypted = Data()
        let salt = "LegadoReader"
        let fullPassword = password + salt
        
        for (index, char) in content.utf8.enumerated() {
            let keyChar = fullPassword.utf8[fullPassword.utf8.index(fullPassword.utf8.startIndex, offsetBy: index % fullPassword.utf8.count)]
            let encryptedChar = char ^ keyChar
            encrypted.append(encryptedChar)
        }
        
        return encrypted
    }
    
    private func simpleDecrypt(_ data: Data, password: String) -> String? {
        let salt = "LegadoReader"
        let fullPassword = password + salt
        
        var decrypted = Data()
        
        for (index, byte) in data.enumerated() {
            let keyChar = fullPassword.utf8[fullPassword.utf8.index(fullPassword.utf8.startIndex, offsetBy: index % fullPassword.utf8.count)]
            let decryptedChar = byte ^ keyChar
            decrypted.append(decryptedChar)
        }
        
        return String(data: decrypted, encoding: .utf8)
    }
    
    func getDecryptedContent(_ bookId: String) -> String? {
        guard isUnlocked, let encryptedData = getEncryptedContent(bookId: bookId) else { return nil }
        return decryptContent(encryptedData, password: currentPassword)
    }
    
    func changePassword(bookId: String, oldPassword: String, newPassword: String) -> Bool {
        guard verifyPassword(bookId: bookId, password: oldPassword) else { return false }
        
        guard let encryptedData = getEncryptedContent(bookId: bookId),
              let content = decryptContent(encryptedData, password: oldPassword) else {
            return false
        }
        
        savePasswordHash(bookId: bookId, password: newPassword)
        saveBookContentEncrypted(bookId: bookId, content: content, password: newPassword)
        
        currentPassword = newPassword
        
        return true
    }
}

extension BookEncryptionManager {
    func exportEncryptedBooksList() -> Data? {
        return try? JSONEncoder().encode(encryptedBooks)
    }
    
    func getEncryptionStatistics() -> EncryptionStatistics {
        let totalBooks = encryptedBooks.count
        let recentlyEncrypted = encryptedBooks.filter {
            Calendar.current.isDate($0.encryptedAt, inSameDayAs: Date())
        }.count
        
        let totalAttempts = encryptedBooks.reduce(0) { $0 + $1.failedAttempts }
        
        return EncryptionStatistics(
            totalEncryptedBooks: totalBooks,
            todayEncrypted: recentlyEncrypted,
            totalFailedAttempts: totalAttempts,
            isLocked: !isUnlocked,
            lockoutRemaining: getRemainingLockoutTime()
        )
    }
    
    struct EncryptionStatistics {
        let totalEncryptedBooks: Int
        let todayEncrypted: Int
        let totalFailedAttempts: Int
        let isLocked: Bool
        let lockoutRemaining: TimeInterval
    }
}
