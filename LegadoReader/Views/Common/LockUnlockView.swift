import SwiftUI

struct LockUnlockView: View {
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isUnlocking = false
    @State private var attempts = 0
    
    let groupId: String?
    let onSuccess: (BookGroup?) -> Void
    let onCancel: () -> Void
    
    init(groupId: String? = nil, onSuccess: @escaping (BookGroup?) -> Void = { _ in }, onCancel: @escaping () -> Void = {}) {
        self.groupId = groupId
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                }
                
                if let targetGroup = getTargetGroup() {
                    VStack(spacing: 4) {
                        Text("分组已锁定")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Image(systemName: targetGroup.icon)
                                .foregroundColor(.blue)
                            Text(targetGroup.name)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        if let hint = targetGroup.passwordHint, !hint.isEmpty {
                            Text("提示: \(hint)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                    }
                } else {
                    Text("输入密码解锁内容")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if attempts > 0 {
                        Text("密码错误，还可以尝试 \(3 - attempts) 次")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(spacing: 16) {
                    SecureField("输入密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 40)
                        .textContentType(.password)
                        .autocapitalization(.none)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Button(action: attemptUnlock) {
                    HStack {
                        if isUnlocking {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isUnlocking ? "验证中..." : "解锁")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .disabled(password.isEmpty || isUnlocking)
                
                if attempts >= 3 {
                    Text("连续错误次数过多，请稍后再试")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .navigationTitle(groupId != nil ? "解锁分组" : "解锁内容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func getTargetGroup() -> BookGroup? {
        guard let groupId = groupId else { return nil }
        return groupManager.getGroupById(groupId)
    }
    
    private func attemptUnlock() {
        guard !password.isEmpty else { return }
        
        isUnlocking = true
        errorMessage = nil
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                if let groupId = groupId {
                    unlockSpecificGroup(groupId)
                } else {
                    unlockAnyContent()
                }
            }
        }
    }
    
    private func unlockSpecificGroup(_ groupId: String) {
        guard let group = groupManager.getGroupById(groupId) else {
            isUnlocking = false
            errorMessage = "分组不存在"
            return
        }
        
        if groupManager.verifyGroupPassword(group, password: password) {
            isUnlocking = false
            groupManager.unlockGroup(group)
            onSuccess(group)
        } else {
            handleFailedAttempt()
        }
    }
    
    private func unlockAnyContent() {
        if let result = groupManager.verifyAnyGroupPassword(password), result.isMatch {
            isUnlocking = false
            let group = result.group
            groupManager.unlockGroup(group)
            onSuccess(group)
        } else if groupManager.verifyGlobalPassword(password) {
            isUnlocking = false
            onSuccess(nil)
        } else {
            handleFailedAttempt()
        }
    }
    
    private func handleFailedAttempt() {
        attempts += 1
        isUnlocking = false
        
        if attempts >= 3 {
            errorMessage = "错误次数过多，请稍后再试"
        } else {
            errorMessage = "密码错误，请重试"
        }
        
        password = ""
    }
}

struct MultiPasswordUnlockView: View {
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isUnlocking = false
    @State private var attempts = 0
    @State private var unlockedGroups: Set<String> = []
    
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "key.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                
                Text("输入密码解锁内容")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("输入任意已设置分组密码即可解锁")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !unlockedGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已解锁:")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        ForEach(unlockedGroups.map { id in groupManager.getGroupById(id) }.compactMap { $0 }) { group in
                            HStack {
                                Image(systemName: group.icon)
                                Text(group.name)
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    SecureField("输入密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 40)
                        .textContentType(.password)
                        .autocapitalization(.none)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Button(action: attemptUnlock) {
                    HStack {
                        if isUnlocking {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isUnlocking ? "验证中..." : "解锁")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .disabled(password.isEmpty || isUnlocking)
                
                Button("完成") {
                    onComplete()
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("解锁内容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func attemptUnlock() {
        guard !password.isEmpty else { return }
        
        isUnlocking = true
        errorMessage = nil
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                if let result = groupManager.verifyAnyGroupPassword(password), result.isMatch {
                    let group = result.group
                    if !unlockedGroups.contains(group.id) {
                        unlockedGroups.insert(group.id)
                        groupManager.unlockGroup(group)
                    }
                    isUnlocking = false
                    password = ""
                } else if groupManager.verifyGlobalPassword(password) {
                    isUnlocking = false
                    onComplete()
                } else {
                    attempts += 1
                    isUnlocking = false
                    errorMessage = attempts >= 3 ? "错误次数过多" : "密码错误"
                    password = ""
                }
            }
        }
    }
}

struct SetPasswordSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordHint = ""
    @State private var errorMessage: String?
    @State private var isSettingPassword = false
    @State private var passwordMode: PasswordMode = .perGroup
    
    let groupId: String?
    let onComplete: () -> Void
    
    init(groupId: String? = nil, onComplete: @escaping () -> Void = {}) {
        self.groupId = groupId
        self.onComplete = onComplete
    }
    
    enum PasswordMode: String, CaseIterable {
        case perGroup = "每个分组独立密码"
        case global = "全局密码"
    }
    
    var body: some View {
        NavigationView {
            Form {
                if groupId == nil {
                    Section {
                        Picker("密码模式", selection: $passwordMode) {
                            ForEach(PasswordMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("设置模式")
                    } footer: {
                        Text(passwordMode == .perGroup ? 
                             "为每个分组设置不同的密码，输入密码将解锁对应分组" : 
                             "设置一个全局密码，输入密码可解锁所有内容")
                    }
                }
                
                if passwordMode == .perGroup {
                    Section {
                        SecureField("新密码", text: $newPassword)
                            .textContentType(.newPassword)
                            .autocapitalization(.none)
                        
                        SecureField("确认密码", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .autocapitalization(.none)
                    } header: {
                        Text("设置密码")
                    } footer: {
                        Text("密码至少4个字符")
                    }
                    
                    Section {
                        TextField("密码提示（可选）", text: $passwordHint)
                    } header: {
                        Text("密码提示")
                    } footer: {
                        Text("设置提示可帮助您记住密码")
                    }
                } else {
                    Section {
                        SecureField("当前密码", text: $currentPassword)
                            .textContentType(.password)
                            .autocapitalization(.none)
                        
                        SecureField("新密码", text: $newPassword)
                            .textContentType(.newPassword)
                            .autocapitalization(.none)
                        
                        SecureField("确认密码", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .autocapitalization(.none)
                    } header: {
                        Text("设置全局密码")
                    } footer: {
                        Text("全局密码可解锁所有加锁内容")
                    }
                }
                
                Section {
                    Button(action: savePassword) {
                        HStack {
                            Spacer()
                            if isSettingPassword {
                                ProgressView()
                            } else {
                                Text(passwordMode == .perGroup ? "设置密码" : "设置全局密码")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSave || isSettingPassword)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if groupId == nil && passwordMode == .perGroup {
                    let groupsWithPassword = groupManager.getGroupsWithPassword()
                    if !groupsWithPassword.isEmpty {
                        Section {
                            ForEach(groupsWithPassword) { group in
                                HStack {
                                    Image(systemName: group.icon)
                                        .foregroundColor(.blue)
                                    Text(group.name)
                                    Spacer()
                                    if group.passwordHint != nil {
                                        Image(systemName: "questionmark.circle")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("已设置密码的分组")
                        } footer: {
                            Text("点击分组可修改或移除密码")
                        }
                    }
                }
                
                if passwordMode == .global || groupId != nil {
                    Section {
                        Button(role: .destructive, action: removePassword) {
                            HStack {
                                Spacer()
                                Text("移除密码保护")
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("移除后，任何人都可以访问相关内容")
                    }
                }
            }
            .navigationTitle("密码设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onComplete()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canSave: Bool {
        if passwordMode == .perGroup {
            return newPassword.count >= 4 && newPassword == confirmPassword
        } else {
            if !currentPassword.isEmpty && currentPassword != getCurrentStoredPassword() {
                return false
            }
            return newPassword.count >= 4 && newPassword == confirmPassword
        }
    }
    
    private func getCurrentStoredPassword() -> String {
        return UserDefaults.standard.string(forKey: "BookGroupGlobalPassword") ?? ""
    }
    
    private func savePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        
        guard newPassword.count >= 4 else {
            errorMessage = "密码至少需要4个字符"
            return
        }
        
        isSettingPassword = true
        
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                if passwordMode == .perGroup {
                    if let groupId = groupId, let group = groupManager.getGroupById(groupId) {
                        groupManager.setGroupPassword(group, password: newPassword, hint: passwordHint.isEmpty ? nil : passwordHint)
                    }
                } else {
                    groupManager.setGlobalPassword(newPassword)
                }
                
                isSettingPassword = false
                onComplete()
                dismiss()
            }
        }
    }
    
    private func removePassword() {
        if passwordMode == .perGroup {
            if let groupId = groupId, let group = groupManager.getGroupById(groupId) {
                groupManager.removeGroupPassword(group)
            }
        } else {
            groupManager.removeGlobalPassword()
        }
        onComplete()
        dismiss()
    }
}

struct HiddenContentRevealView: View {
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var showingPasswordSheet = false
    @State private var showingMultiUnlock = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("已隐藏的内容")
                .font(.headline)
                .foregroundColor(.gray)
            
            HStack(spacing: 16) {
                Button(action: { showingPasswordSheet = true }) {
                    Text("解锁")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                
                Button(action: { showingMultiUnlock = true }) {
                    Text("多密码解锁")
                        .font(.body)
                        .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showingPasswordSheet) {
            SetPasswordSheet(onComplete: {
                groupManager.currentFilter.showHidden = true
            })
        }
        .sheet(isPresented: $showingMultiUnlock) {
            MultiPasswordUnlockView(
                onComplete: {
                    groupManager.currentFilter.showHidden = true
                    showingMultiUnlock = false
                },
                onCancel: {
                    showingMultiUnlock = false
                }
            )
        }
    }
}
