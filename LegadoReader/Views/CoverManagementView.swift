import SwiftUI
import PhotosUI

struct CoverManagementView: View {
    let book: Book
    @StateObject private var coverManager = CoverManager.shared
    @State private var showingURLInput = false
    @State private var showingImagePicker = false
    @State private var showingCoverGallery = false
    @State private var customURL = ""
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var currentCover: UIImage?
    @State private var showingPreview = false
    @State private var previewImage: UIImage?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 16) {
                        if let cover = currentCover {
                            Image(uiImage: cover)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                .onTapGesture {
                                    previewImage = cover
                                    showingPreview = true
                                }
                        } else if let coverURL = book.cover, let url = URL(string: coverURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            } placeholder: {
                                ProgressView()
                                    .frame(height: 200)
                            }
                        } else {
                            Image(uiImage: coverManager.generatePlaceholderCover(for: book))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .cornerRadius(8)
                        }
                        
                        Text(book.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("当前封面")
                }
                
                Section {
                    Button(action: {
                        showingCoverGallery = true
                        loadCoverOptions()
                    }) {
                        HStack {
                            Image(systemName: "photo.stack")
                                .foregroundColor(.blue)
                            Text("从封面库选择")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        showingURLInput = true
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.green)
                            Text("输入图片URL")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.orange)
                            Text("从相册选择")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        setOriginalCover()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.purple)
                            Text("恢复原始封面")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("更换封面")
                }
                
                Section {
                    HStack {
                        Text("封面来源")
                        Spacer()
                        Text(getCoverSourceText())
                            .foregroundColor(.secondary)
                    }
                    
                    if coverManager.getCoverURL(for: book.id) != nil {
                        HStack {
                            Text("自定义URL")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("清除") {
                                clearCustomCover()
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("封面信息")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("更换封面")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingURLInput) {
                URLInputSheet(book: book, currentCover: $currentCover, onURLSet: { url in
                    setCustomCover(url: url)
                })
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, onImageSelected: { image in
                    setImageCover(image: image)
                })
            }
            .sheet(isPresented: $showingCoverGallery) {
                CoverGalleryView(book: book, coverManager: coverManager, currentCover: $currentCover)
            }
            .sheet(isPresented: $showingPreview) {
                if let image = previewImage {
                    FullScreenCoverView(image: image)
                }
            }
            .onAppear {
                loadCurrentCover()
            }
        }
    }
    
    private func loadCurrentCover() {
        Task {
            if let image = await coverManager.fetchCoverImage(for: book) {
                await MainActor.run {
                    currentCover = image
                }
            }
        }
    }
    
    private func loadCoverOptions() {
        Task {
            await coverManager.fetchAvailableCovers(for: book)
        }
    }
    
    private func setCustomCover(url: String) {
        isLoading = true
        Task {
            if let image = await coverManager.loadCoverFromURL(url) {
                await MainActor.run {
                    currentCover = image
                    coverManager.setCover(for: book.id, coverURL: url)
                    coverManager.saveCustomCover(for: book.id, image: image)
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func setImageCover(image: UIImage) {
        currentCover = image
        coverManager.saveCustomCover(for: book.id, image: image)
        coverManager.setCover(for: book.id, coverURL: nil)
    }
    
    private func setOriginalCover() {
        currentCover = nil
        coverManager.deleteCustomCover(for: book.id)
        coverManager.setCover(for: book.id, coverURL: nil)
        loadCurrentCover()
    }
    
    private func clearCustomCover() {
        coverManager.deleteCustomCover(for: book.id)
        coverManager.setCover(for: book.id, coverURL: nil)
        loadCurrentCover()
    }
    
    private func getCoverSourceText() -> String {
        if coverManager.getCoverURL(for: book.id) != nil {
            return "自定义URL"
        }
        if coverManager.loadCustomCover(for: book.id) != nil {
            return "自定义图片"
        }
        return "原始封面"
    }
}

struct URLInputSheet: View {
    let book: Book
    @Binding var currentCover: UIImage?
    let onURLSet: (String) -> Void
    
    @StateObject private var coverManager = CoverManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var urlInput = ""
    @State private var previewImage: UIImage?
    @State private var isValidating = false
    @State private var validationError: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("图片URL")
                        .font(.headline)
                    
                    TextField("输入图片链接", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if let image = previewImage {
                    VStack(spacing: 12) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                        
                        Text("预览")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        validateAndPreview()
                    }) {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("预览图片")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(urlInput.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(urlInput.isEmpty || isValidating)
                    
                    Button(action: {
                        onURLSet(urlInput)
                        dismiss()
                    }) {
                        Text("确认更换")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(previewImage != nil ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(previewImage == nil)
                }
            }
            .padding()
            .navigationTitle("输入URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func validateAndPreview() {
        guard coverManager.validateImageURL(urlInput) else {
            validationError = "无效的图片URL"
            return
        }
        
        validationError = nil
        isValidating = true
        
        Task {
            if let image = await coverManager.loadCoverFromURL(urlInput) {
                await MainActor.run {
                    previewImage = image
                    isValidating = false
                }
            } else {
                await MainActor.run {
                    validationError = "无法加载图片"
                    isValidating = false
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }
            
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                if let uiImage = image as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.onImageSelected(uiImage)
                    }
                }
            }
        }
    }
}

struct CoverGalleryView: View {
    let book: Book
    @ObservedObject var coverManager: CoverManager
    @Binding var currentCover: UIImage?
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Group {
                if coverManager.isLoading {
                    ProgressView("加载封面选项...")
                } else if coverManager.availableCovers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("暂无封面选项")
                            .foregroundColor(.secondary)
                        
                        Button("重新加载") {
                            Task {
                                await coverManager.fetchAvailableCovers(for: book)
                            }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(coverManager.availableCovers) { option in
                                CoverOptionView(option: option) {
                                    selectCover(option)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("封面库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await coverManager.fetchAvailableCovers(for: book)
                }
            }
        }
    }
    
    private func selectCover(_ option: CoverManager.CoverOption) {
        switch option.source {
        case .original:
            currentCover = nil
            coverManager.deleteCustomCover(for: book.id)
            coverManager.setCover(for: book.id, coverURL: nil)
        case .source:
            if let urlString = option.url {
                setCoverFromURL(urlString)
            }
        case .custom, .generated:
            if let image = option.image {
                currentCover = image
                coverManager.saveCustomCover(for: book.id, image: image)
                coverManager.setCover(for: book.id, coverURL: nil)
            }
        }
        
        dismiss()
    }
    
    private func setCoverFromURL(_ url: String) {
        Task {
            if let image = await coverManager.loadCoverFromURL(url) {
                await MainActor.run {
                    currentCover = image
                    coverManager.saveCustomCover(for: book.id, image: image)
                    coverManager.setCover(for: book.id, coverURL: url)
                }
            }
        }
    }
}

struct CoverOptionView: View {
    let option: CoverManager.CoverOption
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Group {
                    if let image = option.image {
                        Image(uiImage: image)
                            .resizable()
                    } else if let urlString = option.url, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                }
                .aspectRatio(0.7, contentMode: .fit)
                .cornerRadius(8)
                .shadow(radius: 2)
                
                Text(option.source.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FullScreenCoverView: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("封面预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CoverManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CoverManagementView(book: Book(
            id: "1",
            name: "测试书籍",
            author: "测试作者",
            sourceUrl: "",
            sourceName: "",
            cover: nil,
            intro: nil,
            lastChapter: nil,
            lastReadChapter: nil,
            readingProgress: 0
        ))
    }
}
