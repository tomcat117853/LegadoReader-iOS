import SwiftUI

struct LockUnlockView: View {
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isUnlocking = false
    
    let groupId: String
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
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
                
                Text("分组已锁定")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("请输入密码解锁")
                    .font(.body)
                    .foregroundColor(.secondary)
                
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
                
                Spacer()
            }
            .navigationTitle("解锁分组")
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
        isUnlocking = true
        errorMessage = nil
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                let storedPassword = loadPassword()
                
                if password == storedPassword || storedPassword.isEmpty {
                    if let group = groupManager.getGroupById(groupId) {
                        groupManager.unlockGroup(group)
                        isUnlocking = false
                        onSuccess()
                    }
                } else {
                    isUnlocking = false
                    errorMessage = "密码错误，请重试"
                    password = ""
                }
            }
        }
    }
    
    private func loadPassword() -> String {
        return UserDefaults.standard.string(forKey: "BookGroupLockPassword") ?? ""
    }
}

struct SetPasswordSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSettingPassword = false
    @State private var isRemovingPassword = false
    
    let groupId: String
    let onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("当前密码", text: $currentPassword)
                        .textContentType(.password)
                        .autocapitalization(.none)
                } header: {
                    Text("当前密码")
                } footer: {
                    Text("如果尚未设置密码，请留空")
                }
                
                Section {
                    SecureField("新密码", text: $newPassword)
                        .textContentType(.newPassword)
                        .autocapitalization(.none)
                    
                    SecureField("确认新密码", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocapitalization(.none)
                } header: {
                    Text("设置新密码")
                } footer: {
                    Text("密码至少4个字符")
                }
                
                Section {
                    Button(action: savePassword) {
                        HStack {
                            Spacer()
                            if isSettingPassword {
                                ProgressView()
                            } else {
                                Text("保存密码")
                            }
                            Spacer()
                        }
                    }
                    .disabled(newPassword.isEmpty || newPassword != confirmPassword || isSettingPassword)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(role: .destructive, action: removePassword) {
                        HStack {
                            Spacer()
                            if isRemovingPassword {
                                ProgressView()
                            } else {
                                Text("移除密码保护")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!currentPassword.isEmpty && currentPassword != loadPassword() || isRemovingPassword)
                } footer: {
                    Text("移除密码后，任何人都可以访问此分组")
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
    
    private func savePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        
        guard newPassword.count >= 4 else {
            errorMessage = "密码至少需要4个字符"
            return
        }
        
        if !currentPassword.isEmpty && currentPassword != loadPassword() {
            errorMessage = "当前密码错误"
            return
        }
        
        isSettingPassword = true
        
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                UserDefaults.standard.set(newPassword, forKey: "BookGroupLockPassword")
                isSettingPassword = false
                onComplete()
                dismiss()
            }
        }
    }
    
    private func removePassword() {
        isRemovingPassword = true
        
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: "BookGroupLockPassword")
                isRemovingPassword = false
                onComplete()
                dismiss()
            }
        }
    }
    
    private func loadPassword() -> String {
        return UserDefaults.standard.string(forKey: "BookGroupLockPassword") ?? ""
    }
}

struct HiddenContentRevealView: View {
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var showingPasswordSheet = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("已隐藏的内容")
                .font(.headline)
                .foregroundColor(.gray)
            
            Button(action: { showingPasswordSheet = true }) {
                Text("显示隐藏内容")
                    .font(.body)
                    .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingPasswordSheet) {
            VStack {
                Text("显示隐藏内容")
                    .font(.headline)
                    .padding()
                
                Button("显示所有分组") {
                    groupManager.currentFilter.showHidden = true
                    showingPasswordSheet = false
                }
                .padding()
                
                Button("取消", role: .cancel) {
                    showingPasswordSheet = false
                }
                .padding()
            }
        }
    }
}
