import SwiftUI

struct OPDSSubscriptionsView: View {
    @StateObject private var opdsClient = OPDSClient.shared
    @State private var showingAddSubscription = false
    @State private var showingPopularCatalogs = false
    @State private var searchText = ""
    
    var filteredSubscriptions: [OPDSClient.OPDSSubscription] {
        if searchText.isEmpty {
            return opdsClient.subscriptions
        }
        return opdsClient.subscriptions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !opdsClient.feedHistory.isEmpty {
                    Section("最近浏览") {
                        ForEach(opdsClient.feedHistory.prefix(5), id: \.self) { url in
                            RecentFeedRow(url: url)
                        }
                    }
                }
                
                Section {
                    ForEach(filteredSubscriptions) { subscription in
                        SubscriptionRow(subscription: subscription)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    opdsClient.removeSubscription(id: subscription.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    opdsClient.toggleSubscription(id: subscription.id)
                                } label: {
                                    Label(
                                        subscription.isEnabled ? "禁用" : "启用",
                                        systemImage: subscription.isEnabled ? "pause.circle" : "play.circle"
                                    )
                                }
                                .tint(subscription.isEnabled ? .orange : .green)
                            }
                    }
                } header: {
                    HStack {
                        Text("订阅源")
                        Spacer()
                        Text("\(filteredSubscriptions.count)个")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("OPDS订阅")
            .searchable(text: $searchText, prompt: "搜索订阅源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddSubscription = true
                        } label: {
                            Label("添加订阅源", systemImage: "plus")
                        }
                        
                        Button {
                            showingPopularCatalogs = true
                        } label: {
                            Label("热门书库", systemImage: "star")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSubscription) {
                AddOPDSubscriptionView()
            }
            .sheet(isPresented: $showingPopularCatalogs) {
                PopularCatalogsView()
            }
            .refreshable {
            }
        }
    }
}

struct RecentFeedRow: View {
    let url: String
    @State private var feedTitle: String?
    
    var body: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feedTitle ?? "最近访问")
                    .font(.subheadline)
                
                Text(url)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
    }
}

struct SubscriptionRow: View {
    let subscription: OPDSClient.OPDSSubscription
    @StateObject private var opdsClient = OPDSClient.shared
    @State private var showingEdit = false
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: subscription.iconURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Color.blue.opacity(0.1)
                    Image(systemName: "books.vertical")
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 50, height: 70)
            .cornerRadius(6)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(subscription.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let lastUpdated = subscription.lastUpdated {
                        Text("更新: \(lastUpdated, formatter: dateFormatter)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if subscription.username != nil {
                        Label("已认证", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            if !subscription.isEnabled {
                Text("已禁用")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
        .opacity(subscription.isEnabled ? 1 : 0.6)
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditSubscriptionView(subscription: subscription)
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

struct AddOPDSSubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var opdsClient = OPDSClient.shared
    @State private var title = ""
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var useAuthentication = false
    @State private var isValidating = false
    @State private var errorMessage = ""
    @State private var discoveredFeeds: [OPDSFeed] = []
    @State private var showingDiscover = false
    
    var isValid: Bool {
        !title.isEmpty && !url.isEmpty && URL(string: url) != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("订阅源名称", text: $title)
                        .textContentType(.name)
                    
                    TextField("OPDS URL地址", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("基本信息")
                } footer: {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Toggle("需要身份验证", isOn: $useAuthentication)
                } footer: {
                    Text("如果订阅源需要用户名和密码认证，请开启此选项")
                }
                
                if useAuthentication {
                    Section("认证信息") {
                        TextField("用户名", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        SecureField("密码", text: $password)
                            .textContentType(.password)
                    }
                }
                
                Section {
                    Button {
                        discoverFeeds()
                    } label: {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text("自动发现订阅源")
                        }
                    }
                    .disabled(url.isEmpty || isValidating)
                } footer: {
                    Text("自动检测URL地址中的OPDS目录")
                }
                
                if !discoveredFeeds.isEmpty {
                    Section("发现的订阅源") {
                        ForEach(discoveredFeeds) { feed in
                            Button {
                                url = feed.href ?? ""
                                if title.isEmpty {
                                    title = feed.title
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(feed.title)
                                            .foregroundColor(.primary)
                                        Text(feed.href ?? "")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加订阅源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        addSubscription()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func discoverFeeds() {
        isValidating = true
        errorMessage = ""
        
        opdsClient.discoverCatalogs(url: url) { result in
            isValidating = false
            switch result {
            case .success(let feeds):
                discoveredFeeds = feeds
                if feeds.isEmpty {
                    errorMessage = "未发现OPDS订阅源"
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func addSubscription() {
        let success = opdsClient.addSubscription(
            title: title,
            url: url,
            username: useAuthentication ? username : nil,
            password: useAuthentication ? password : nil
        )
        
        if success {
            dismiss()
        } else {
            errorMessage = "订阅源已存在或URL无效"
        }
    }
}

struct EditSubscriptionView: View {
    let subscription: OPDSClient.OPDSSubscription
    @Environment(\.dismiss) var dismiss
    @StateObject private var opdsClient = OPDSClient.shared
    @State private var title: String
    @State private var url: String
    @State private var username: String
    @State private var password: String
    @State private var useAuthentication: Bool
    
    init(subscription: OPDSClient.OPDSSubscription) {
        self.subscription = subscription
        _title = State(initialValue: subscription.title)
        _url = State(initialValue: subscription.url)
        _username = State(initialValue: subscription.username ?? "")
        _password = State(initialValue: subscription.password ?? "")
        _useAuthentication = State(initialValue: subscription.username != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("订阅源名称", text: $title)
                    TextField("OPDS URL地址", text: $url)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Toggle("需要身份验证", isOn: $useAuthentication)
                }
                
                if useAuthentication {
                    Section("认证信息") {
                        TextField("用户名", text: $username)
                            .autocapitalization(.none)
                        SecureField("密码", text: $password)
                    }
                }
            }
            .navigationTitle("编辑订阅源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveChanges() {
        var updated = subscription
        updated.title = title
        updated.url = url
        updated.username = useAuthentication ? username : nil
        updated.password = useAuthentication ? password : nil
        
        opdsClient.updateSubscription(updated)
        dismiss()
    }
}

struct PopularCatalogsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var opdsClient = OPDSClient.shared
    @State private var addedURLs: Set<String> = []
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(PopularCatalogs) { catalog in
                        PopularCatalogRow(
                            catalog: catalog,
                            isAdded: addedURLs.contains(catalog.url)
                        ) {
                            addCatalog(catalog)
                        }
                    }
                } header: {
                    Text("推荐书库")
                } footer: {
                    Text("这些是流行的开源电子书OPDS源，可以直接添加订阅")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("热门书库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkAddedCatalogs()
            }
        }
    }
    
    private func checkAddedCatalogs() {
        addedURLs = Set(opdsClient.subscriptions.map { $0.url })
    }
    
    private func addCatalog(_ catalog: OPDSClient.OPDSSubscription) {
        if opdsClient.addSubscription(title: catalog.title, url: catalog.url) {
            addedURLs.insert(catalog.url)
        }
    }
}

struct PopularCatalogRow: View {
    let catalog: OPDSClient.OPDSSubscription
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(catalog.title)
                    .font(.headline)
                
                Text(catalog.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                onAdd()
            } label: {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    Text("添加")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .disabled(isAdded)
        }
        .padding(.vertical, 4)
    }
}

struct PopularCatalogs: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let description: String
    
    static let list: [PopularCatalogs] = [
        PopularCatalogs(
            title: "Project Gutenberg",
            url: "https://www.gutenberg.org/ebooks/",
            description: "公版书籍"
        ),
        PopularCatalogs(
            title: "Standard Ebooks",
            url: "https://standardebooks.org/opds",
            description: "高质量公版电子书"
        ),
        PopularCatalogs(
            title: "Feedbooks",
            url: "https://www.feedbooks.com/store",
            description: "商业和公版书籍"
        ),
        PopularCatalogs(
            title: "Open Library",
            url: "https://openlibrary.org/developers/vanity/opds",
            description: "开放的图书馆目录"
        ),
        PopularCatalogs(
            title: "Internet Archive",
            url: "https://archive.org/opds.php",
            description: "互联网档案馆"
        ),
        PopularCatalogs(
            title: "Mobilism",
            url: "https://forum.mobilism.org/opds.php",
            description: "社区分享书籍"
        )
    ]
}

struct OPDSSubscriptionsView_Previews: PreviewProvider {
    static var previews: some View {
        OPDSSubscriptionsView()
    }
}
