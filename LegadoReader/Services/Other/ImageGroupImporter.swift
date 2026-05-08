import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ImageGroupImporter: BaseService, ObservableObject {
    static let shared = ImageGroupImporter()
    
    @Published var importedGroups: [ImageComicGroup] = []
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    
    private let groupsKey = "ImageGroupImporter_groups"
    private let appGroupId = "group.com.legadoreader.comics"
    
    struct ImageComicGroup: Identifiable, Codable {
        let id: String
        var title: String
        var imagePaths: [String]
        var coverPath: String?
        var createdAt: Date
        var lastReadPage: Int
        var lastReadTime: Date?
        var totalPages: Int
        
        init(title: String, imagePaths: [String]) {
            self.id = UUID().uuidString
            self.title = title
            self.imagePaths = imagePaths
            self.coverPath = imagePaths.first
            self.createdAt = Date()
            self.lastReadPage = 0
            self.totalPages = imagePaths.count
        }
    }
    
    private override init() {
        super.init()
        loadGroups()
        loadFromAppGroup()
    }
    
    private func loadGroups() {
        if let saved = loadCodable([ImageComicGroup].self, key: groupsKey) {
            importedGroups = saved
        }
    }
    
    private func loadFromAppGroup() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return
        }
        
        let pendingDir = containerURL.appendingPathComponent("PendingImports")
        
        guard FileManager.default.fileExists(atPath: pendingDir.path) else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil)
            let imageFiles = files.filter { isImageFile($0) }
            
            if !imageFiles.isEmpty {
                let paths = imageFiles.map { $0.path }
                let group = ImageComicGroup(title: "导入的漫画", imagePaths: paths)
                addGroup(group)
                
                try FileManager.default.removeItem(at: pendingDir)
            }
        } catch {
            print("Failed to load from app group: \(error)")
        }
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    func addGroup(_ group: ImageComicGroup) {
        importedGroups.insert(group, at: 0)
        saveGroups()
    }
    
    func deleteGroup(_ group: ImageComicGroup) {
        for path in group.imagePaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        importedGroups.removeAll { $0.id == group.id }
        saveGroups()
    }
    
    func updateGroup(_ group: ImageComicGroup) {
        if let index = importedGroups.firstIndex(where: { $0.id == group.id }) {
            importedGroups[index] = group
            saveGroups()
        }
    }
    
    func getGroup(by id: String) -> ImageComicGroup? {
        return importedGroups.first { $0.id == id }
    }
    
    private func saveGroups() {
        saveCodable(importedGroups, key: groupsKey)
    }
    
    func importFromPhotos(images: [UIImage], title: String) -> ImageComicGroup? {
        isImporting = true
        importProgress = 0
        
        defer {
            Task { @MainActor in
                isImporting = false
            }
        }
        
        let documentsDir = fileManager.documentsDirectory()
        let comicsDir = documentsDir.appendingPathComponent("ImageComics")
        try? fileManager.createDirectory(at: comicsDir, withIntermediateDirectories: true)
        
        let groupDir = comicsDir.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: groupDir, withIntermediateDirectories: true)
        
        var imagePaths: [String] = []
        
        for (index, image) in images.enumerated() {
            Task { @MainActor in
                importProgress = Double(index) / Double(images.count)
            }
            
            let fileName = String(format: "%04d.jpg", index)
            let filePath = groupDir.appendingPathComponent(fileName)
            
            if let data = image.jpegData(compressionQuality: 0.9) {
                try? data.write(to: filePath)
                imagePaths.append(filePath.path)
            }
        }
        
        let group = ImageComicGroup(title: title, imagePaths: imagePaths)
        
        Task { @MainActor in
            importProgress = 1.0
            addGroup(group)
        }
        
        return group
    }
    
    func importFromURLs(_ urls: [URL], title: String) async throws -> ImageComicGroup? {
        await MainActor.run { isImporting = true }
        
        defer {
            Task { @MainActor in
                isImporting = false
            }
        }
        
        let documentsDir = fileManager.documentsDirectory()
        let comicsDir = documentsDir.appendingPathComponent("ImageComics")
        try? fileManager.createDirectory(at: comicsDir, withIntermediateDirectories: true)
        
        let groupDir = comicsDir.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: groupDir, withIntermediateDirectories: true)
        
        var imagePaths: [String] = []
        
        for (index, url) in urls.enumerated() {
            await MainActor.run {
                importProgress = Double(index) / Double(urls.count)
            }
            
            let fileName = String(format: "%04d_%@", index, url.lastPathComponent)
            let destURL = groupDir.appendingPathComponent(fileName)
            
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            
            try FileManager.default.copyItem(at: url, to: destURL)
            imagePaths.append(destURL.path)
        }
        
        let group = ImageComicGroup(title: title, imagePaths: imagePaths)
        
        await MainActor.run {
            importProgress = 1.0
            addGroup(group)
        }
        
        return group
    }
    
    func getImage(at index: Int, for group: ImageComicGroup) -> UIImage? {
        guard index >= 0 && index < group.imagePaths.count else { return nil }
        return UIImage(contentsOfFile: group.imagePaths[index])
    }
}

class ImageComicReaderManager: ObservableObject {
    static let shared = ImageComicReaderManager()
    
    @Published var currentGroup: ImageGroupImporter.ImageComicGroup?
    @Published var currentPage: Int = 0
    
    private init() {}
    
    func openGroup(_ group: ImageGroupImporter.ImageComicGroup) {
        currentGroup = group
        currentPage = group.lastReadPage
    }
    
    func closeGroup() {
        if let group = currentGroup {
            var updatedGroup = group
            updatedGroup.lastReadPage = currentPage
            updatedGroup.lastReadTime = Date()
            ImageGroupImporter.shared.updateGroup(updatedGroup)
        }
        currentGroup = nil
        currentPage = 0
    }
    
    func nextPage() {
        guard let group = currentGroup else { return }
        if currentPage < group.totalPages - 1 {
            currentPage += 1
        }
    }
    
    func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }
    
    func goToPage(_ page: Int) {
        guard let group = currentGroup else { return }
        if page >= 0 && page < group.totalPages {
            currentPage = page
        }
    }
}
