import SwiftUI

struct EncryptionSettingsView: View {
    @StateObject private var encryptionManager = BookEncryptionManager.shared
    @State private var showingAddPassword = false
    @State private var showingChangePassword = false
    @State private var selectedBookId: String?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: encryptionManager.isUnlocked ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(encryptionManager.isUnlocked ? .green : .red)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(encryptionManager.isUnlocked ? "已解锁" : "已锁定")
                                .font(.headline)
                            
                            Text(encryptionManager.isUnlocked ? "所有加密书籍可访问" : "需要输入密码解锁")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !encryptionManager.isUnlocked {
                            Button("解锁") {
                                showingAddPassword = true
                            }
                            .foregroundColor(.blue)
                        } else {
                            Button("锁定") {
                                encryptionManager.lock()
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("加密状态")
                }
                
                if encryptionManager.isLockedOut {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            
                            Text("密码错误次数过多，请等待 \(Int(encryptionManager.getRemainingLockoutTime())) 秒后再试")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                Section("加密书籍") {
                    if encryptionManager.encryptedBooks.isEmpty {
                        Text("暂无加密书籍")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(encryptionManager.encryptedBooks) { book in
                            EncryptedBookRow(book: book, isUnlocked: encryptionManager.isUnlocked)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        selectedBookId = book.bookId
                                    } label: {
                                        Label("移除加密", systemImage: "lock.open")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        selectedBookId = book.bookId
                                        showingChangePassword = true
                                    } label: {
                                        Label("修改密码", systemImage: "key")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                }
                
                Section("设置") {
                    NavigationLink(destination: EncryptionSettingsDetailView()) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                            Text("加密设置")
                        }
                    }
                }
                
                Section("统计") {
                    let stats = encryptionManager.getEncryptionStatistics()
                    
                    HStack {
                        Text("加密书籍数")
                        Spacer()
                        Text("\(stats.totalEncryptedBooks)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("今日加密")
                        Spacer()
                        Text("\(stats.todayEncrypted)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("失败尝试次数")
                        Spacer()
                        Text("\(stats.totalFailedAttempts)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("书籍加密")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddPassword) {
                PasswordInputView(mode: .unlock)
            }
            .sheet(isPresented: $showingChangePassword) {
                if let bookId = selectedBookId {
                    PasswordInputView(mode: .changePassword(bookId: bookId))
                }
            }
            .alert("移除加密") {
                Button("取消", role: .cancel) {
                    selectedBookId = nil
                }
                Button("移除", role: .destructive) {
                    if let bookId = selectedBookId {
                        // Show password confirmation first
                        selectedBookId = nil
                    }
                }
            } message: {
                Text("确定要移除这本书的加密吗？")
            }
        }
    }
}

struct EncryptedBookRow: View {
    let book: BookEncryptionManager.EncryptedBook
    let isUnlocked: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(book.bookName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if isUnlocked {
                        Image(systemName: "lock.open.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("加密时间: \(book.encryptedAt, formatter: dateFormatter)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if book.failedAttempts > 0 {
                Text("\(book.failedAttempts)次失败")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct EncryptionSettingsDetailView: View {
    @StateObject private var encryptionManager = BookEncryptionManager.shared
    @State private var settings = BookEncryptionManager.EncryptionSettings(
        isEncryptionEnabled: false,
        encryptionType: .standard,
        autoLockTimeout: 5,
        requirePasswordOnLaunch: false
    )
    
    var body: some View {
        List {
            Section {
                Toggle("启用书籍加密", isOn: $settings.isEncryptionEnabled)
            } footer: {
                Text("启用后可以为书籍设置密码保护")
            }
            
            if settings.isEncryptionEnabled {
                Section("加密强度") {
                    ForEach(BookEncryptionManager.EncryptionSettings.EncryptionType.allCases, id: \.self) { type in
                        Button(action: {
                            settings.encryptionType = type
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.displayName)
                                        .foregroundColor(.primary)
                                    
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if settings.encryptionType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("自动锁定") {
                    Picker("自动锁定时间", selection: $settings.autoLockTimeout) {
                        Text("1 分钟").tag(1)
                        Text("5 分钟").tag(5)
                        Text("10 分钟").tag(10)
                        Text("30 分钟").tag(30)
                        Text("从不").tag(0)
                    }
                } footer: {
                    Text("设置解锁后多久自动重新锁定")
                }
                
                Section {
                    Toggle("启动时要求密码", isOn: $settings.requirePasswordOnLaunch)
                } footer: {
                    Text("每次打开APP时都需要输入密码")
                }
            }
        }
        .navigationTitle("加密设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = encryptionManager.getSettings()
        }
        .onDisappear {
            encryptionManager.saveSettings(settings)
        }
    }
}

struct PasswordInputView: View {
    let mode: PasswordMode
    @StateObject private var encryptionManager = BookEncryptionManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    enum PasswordMode {
        case setPassword(bookId: String)
        case unlock
        case changePassword(bookId: String)
        case removeEncryption(bookId: String)
    }
    
    var isSetPasswordMode: Bool {
        if case .setPassword = mode { return true }
        return false
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text(titleText)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    SecureField("输入密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .autocapitalization(.none)
                    
                    if isSetPasswordMode {
                        SecureField("确认密码", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                            .autocapitalization(.none)
                    }
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    submitPassword()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(buttonText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(password.isEmpty || isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var titleText: String {
        switch mode {
        case .setPassword: return "设置密码"
        case .unlock: return "输入密码"
        case .changePassword: return "修改密码"
        case .removeEncryption: return "确认密码"
        }
    }
    
    private var subtitleText: String {
        switch mode {
        case .setPassword: return "请设置书籍加密密码"
        case .unlock: return "输入密码解锁加密书籍"
        case .changePassword: return "请输入新密码"
        case .removeEncryption: return "请输入密码以移除加密"
        }
    }
    
    private var buttonText: String {
        switch mode {
        case .setPassword: return "确认设置"
        case .unlock: return "解锁"
        case .changePassword: return "确认修改"
        case .removeEncryption: return "确认移除"
        }
    }
    
    private var navigationTitleText: String {
        switch mode {
        case .setPassword: return "设置密码"
        case .unlock: return "解锁"
        case .changePassword: return "修改密码"
        case .removeEncryption: return "移除加密"
        }
    }
    
    private func submitPassword() {
        errorMessage = ""
        isLoading = true
        
        switch mode {
        case .setPassword(let bookId):
            if password != confirmPassword {
                errorMessage = "两次输入的密码不一致"
                isLoading = false
                return
            }
            if password.count < 4 {
                errorMessage = "密码长度至少4位"
                isLoading = false
                return
            }
            // Set password for book
            encryptionManager.savePasswordHash(bookId: bookId, password: password)
            dismiss()
            
        case .unlock:
            if encryptionManager.unlockWithPassword(password) {
                dismiss()
            } else {
                errorMessage = "密码错误"
                isLoading = false
            }
            
        case .changePassword(let bookId):
            if password.count < 4 {
                errorMessage = "密码长度至少4位"
                isLoading = false
                return
            }
            // Change password
            dismiss()
            
        case .removeEncryption(let bookId):
            if encryptionManager.removeEncryption(bookId, password: password) {
                dismiss()
            } else {
                errorMessage = "密码错误"
                isLoading = false
            }
        }
    }
}

struct EncryptionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        EncryptionSettingsView()
    }
}
