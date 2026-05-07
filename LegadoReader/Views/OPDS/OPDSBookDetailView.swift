import SwiftUI

struct OPDSBookDetailView: View {
    let entry: OPDSEntry
    let subscriptionURL: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var opdsClient = OPDSClient.shared
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadedURL: URL?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAuthentication = false
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    
                    Divider()
                    
                    infoSection
                    
                    if !entry.summary.isEmpty {
                        Divider()
                        summarySection
                    }
                    
                    Divider()
                    
                    downloadSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("书籍详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("确定") {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingAuthentication) {
                AuthenticationInputView(
                    username: $username,
                    password: $password,
                    onSubmit: {
                        showingAuthentication = false
                    }
                )
            }
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: URL(string: entry.coverImage ?? "")) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color.blue.opacity(0.1)
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Color.blue.opacity(0.1)
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                @unknown default:
                    Color.gray
                }
            }
            .frame(width: 120, height: 180)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(3)
                
                Text("作者: \(entry.authorName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !entry.categories.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.categories.prefix(3), id: \.self) { category in
                            Text(category)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                
                if let updated = entry.updated {
                    Text("更新: \(updated, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("书籍信息")
                .font(.headline)
            
            HStack {
                Image(systemName: "number")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text("ID:")
                    .foregroundColor(.secondary)
                Text(entry.id)
                    .font(.caption)
                    .lineLimit(1)
            }
            
            if !entry.contributors.isEmpty {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("贡献者:")
                        .foregroundColor(.secondary)
                    Text(entry.contributors.map { $0.name }.joined(separator: ", "))
                        .font(.subheadline)
                }
            }
            
            if let price = entry.price {
                HStack {
                    Image(systemName: "tag")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("价格:")
                        .foregroundColor(.secondary)
                    Text(price.displayString)
                        .fontWeight(.medium)
                        .foregroundColor(price.value == 0 ? .green : .orange)
                }
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("简介")
                .font(.headline)
            
            Text(entry.summary)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
    
    private var downloadSection: some View {
        VStack(spacing: 16) {
            Text("下载格式")
                .font(.headline)
            
            if entry.acquisitionLinks.isEmpty && entry.epubLink == nil && entry.pdfLink == nil {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("暂无可用下载链接")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            } else {
                if let epubLink = entry.epubLink {
                    DownloadButton(
                        title: "下载 EPUB",
                        icon: "doc.fill",
                        color: .blue,
                        isDownloading: $isDownloading,
                        progress: $downloadProgress
                    ) {
                        downloadBook(link: epubLink)
                    }
                }
                
                if let pdfLink = entry.pdfLink {
                    DownloadButton(
                        title: "下载 PDF",
                        icon: "doc.fill",
                        color: .red,
                        isDownloading: $isDownloading,
                        progress: $downloadProgress
                    ) {
                        downloadBook(link: pdfLink)
                    }
                }
                
                ForEach(Array(entry.acquisitionLinks.filter {
                    $0.href != entry.epubLink?.href && $0.href != entry.pdfLink?.href
                }.enumerated()), id: \.offset) { _, link in
                    DownloadButton(
                        title: "下载 (\(link.type ?? "未知格式"))",
                        icon: "arrow.down.doc",
                        color: .purple,
                        isDownloading: $isDownloading,
                        progress: $downloadProgress
                    ) {
                        downloadBook(link: link)
                    }
                }
            }
            
            if let downloadedURL = downloadedURL {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已下载到: \(downloadedURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    private func downloadBook(link: OPDSLink) {
        guard let href = link.href else { return }
        
        isDownloading = true
        downloadProgress = 0
        
        let tempProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if downloadProgress < 0.9 {
                downloadProgress += 0.05
            }
        }
        
        opdsClient.downloadBook(url: href, bookTitle: entry.title) { result in
            tempProgressTimer.invalidate()
            downloadProgress = 1.0
            isDownloading = false
            
            switch result {
            case .success(let url):
                downloadedURL = url
                alertTitle = "下载成功"
                alertMessage = "书籍已保存到: \(url.lastPathComponent)"
                showAlert = true
                
            case .failure(let error):
                alertTitle = "下载失败"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

struct DownloadButton: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isDownloading: Bool
    @Binding var progress: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isDownloading {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 100)
                } else {
                    Image(systemName: icon)
                        .foregroundColor(.white)
                }
                
                Text(isDownloading ? "下载中..." : title)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !isDownloading {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isDownloading ? Color.gray : color)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDownloading)
    }
}

struct AuthenticationInputView: View {
    @Binding var username: String
    @Binding var password: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("请输入认证信息") {
                    TextField("用户名", text: $username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("密码", text: $password)
                }
            }
            .navigationTitle("身份验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        onSubmit()
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                }
            }
        }
    }
}

struct OPDSBookDetailView_Previews: PreviewProvider {
    static var previews: some View {
        OPDSBookDetailView(
            entry: OPDSEntry(),
            subscriptionURL: "https://example.com/opds"
        )
    }
}
