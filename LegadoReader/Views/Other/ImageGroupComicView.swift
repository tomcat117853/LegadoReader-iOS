import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImageGroupComicView: View {
    @StateObject private var imageImporter = ImageGroupImporter.shared
    @StateObject private var readerManager = ImageComicReaderManager.shared
    @StateObject private var comicSettings = ComicReadingSettings.shared
    
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var selectedGroup: ImageGroupImporter.ImageComicGroup?
    @State private var showingReader = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { showingPhotoPicker = true }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.blue)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("从照片导入")
                                    .font(.headline)
                                Text("选择一组图片作为漫画阅读")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Button(action: { showingFilePicker = true }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .foregroundColor(.green)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("从文件夹导入")
                                    .font(.headline)
                                Text("选择图片文件夹")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if !imageImporter.importedGroups.isEmpty {
                    Section("已导入的漫画 (\(imageImporter.importedGroups.count))") {
                        ForEach(imageImporter.importedGroups) { group in
                            ImageGroupRowView(group: group)
                                .onTapGesture {
                                    selectedGroup = group
                                    readerManager.openGroup(group)
                                    showingReader = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        imageImporter.deleteGroup(group)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                } else {
                    Section {
                        EmptyImageGroupsView()
                    }
                }
            }
            .navigationTitle("图片漫画")
            .refreshable {
                loadGroups()
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView { images in
                    handlePhotoSelection(images)
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPickerView { urls in
                    handleFileSelection(urls)
                }
            }
            .fullScreenCover(isPresented: $showingReader) {
                if let group = readerManager.currentGroup {
                    ImageGroupReaderView(group: group)
                }
            }
        }
    }
    
    private func loadGroups() {
        ImageGroupImporter.shared.loadFromAppGroup()
    }
    
    private func handlePhotoSelection(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let title = "漫画 \(dateFormatter.string(from: Date()))"
        
        Task {
            if let group = await MainActor.run(body: { imageImporter.importFromPhotos(images: images, title: title) }) {
                await MainActor.run(body: {
                    selectedGroup = group
                    readerManager.openGroup(group)
                    showingReader = true
                })
            }
        }
    }
    
    private func handleFileSelection(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                let title = "漫画 \(dateFormatter.string(from: Date()))"
                
                if let group = try await imageImporter.importFromURLs(urls, title: title) {
                    await MainActor.run(body: {
                        selectedGroup = group
                        readerManager.openGroup(group)
                        showingReader = true
                    })
                }
            } catch {
                print("Failed to import files: \(error)")
            }
        }
    }
}

struct ImageGroupReaderView: View {
    @StateObject private var readerManager = ImageComicReaderManager.shared
    @StateObject private var settings = ComicReadingSettings.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showingSettings = false
    @State private var showingSlider = true
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    let group: ImageGroupImporter.ImageComicGroup
    
    var body: some View {
        ZStack {
            settings.backgroundColor.color
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                ZStack {
                    if let image = ImageGroupImporter.shared.getImage(at: readerManager.currentPage, for: group) {
                        ZoomableImageView(
                            image: image,
                            scale: $currentScale,
                            lastScale: $lastScale,
                            offset: $offset,
                            lastOffset: $lastOffset
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if currentScale > 1.0 {
                                    currentScale = 1.0
                                    offset = .zero
                                } else {
                                    currentScale = 2.0
                                }
                            }
                        }
                        .onTapGesture { location in
                            handleTap(at: location, in: geometry.size)
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            
            if showingSlider {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(readerManager.currentPage + 1) / \(group.totalPages)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(16)
                            
                            Spacer()
                            
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        
                        if settings.showPageSlider {
                            Slider(
                                value: Binding(
                                    get: { Double(readerManager.currentPage) },
                                    set: { readerManager.goToPage(Int($0)) }
                                ),
                                in: 0...Double(max(0, group.totalPages - 1)),
                                step: 1
                            )
                            .padding(.horizontal)
                            .tint(.white)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .sheet(isPresented: $showingSettings) {
            ComicSettingsView()
        }
        .onTapGesture { location in
            let centerY = UIScreen.main.bounds.height / 2
            if abs(location.y - centerY) < 50 {
                withAnimation {
                    showingSlider.toggle()
                }
            }
        }
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize) {
        let leftZone = size.width / 3
        let rightZone = size.width * 2 / 3
        
        if settings.readingMode == .rightToLeft {
            if location.x < leftZone {
                readerManager.nextPage()
            } else if location.x > rightZone {
                readerManager.previousPage()
            }
        } else {
            if location.x < leftZone {
                readerManager.previousPage()
            } else if location.x > rightZone {
                readerManager.nextPage()
            }
        }
    }
}

struct ImageGroupRowView: View {
    let group: ImageGroupImporter.ImageComicGroup
    
    var body: some View {
        HStack(spacing: 12) {
            if let coverPath = group.coverPath,
               let image = UIImage(contentsOfFile: coverPath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 60, height: 90)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 90)
                    .cornerRadius(6)
                    .overlay(
                        Image(systemName: "photo.stack")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("\(group.totalPages) 页")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if group.lastReadPage > 0 {
                    Text("阅读至第 \(group.lastReadPage + 1) 页")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EmptyImageGroupsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无导入的漫画")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("从照片或文件夹导入图片作为漫画阅读")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct PhotoPickerView: UIViewControllerRepresentable {
    var onSelect: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard !results.isEmpty else {
                parent.onSelect([])
                return
            }
            
            var images: [UIImage] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        images.append(image)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.parent.onSelect(images)
            }
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.image, .jpeg, .png, .gif, .heic]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                _ = url.startAccessingSecurityScopedResource()
            }
            parent.onPick(urls)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                for url in urls {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
}
