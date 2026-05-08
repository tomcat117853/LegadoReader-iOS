import SwiftUI

struct UpdateNotificationSettingsView: View {
    @StateObject private var notificationManager = UpdateNotificationManager.shared
    @State private var showingSubscribedBooks = false
    @State private var showingUpdateHistory = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("开启更新提醒", isOn: Binding(
                        get: { notificationManager.isEnabled },
                        set: { notificationManager.setEnabled($0) }
                    ))
                } header: {
                    Text("提醒开关")
                } footer: {
                    Text("开启后将定期检查订阅书籍的更新并推送通知")
                }
                
                if notificationManager.isEnabled {
                    Section("检查频率") {
                        Picker("检查间隔", selection: Binding(
                            get: { notificationManager.checkInterval },
                            set: { notificationManager.setCheckInterval($0) }
                        )) {
                            ForEach(UpdateNotificationManager.CheckInterval.allCases) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                        
                        if let lastCheck = notificationManager.lastCheckTime {
                            HStack {
                                Text("上次检查")
                                Spacer()
                                Text(lastCheck, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            notificationManager.checkForUpdates()
                        }) {
                            HStack {
                                Text("立即检查")
                                Spacer()
                                if notificationManager.isChecking {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(notificationManager.isChecking)
                    }
                }
                
                Section {
                    NavigationLink(destination: SubscribedBooksView()) {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.blue)
                            Text("订阅管理")
                            Spacer()
                            Text("\(notificationManager.subscribedBooks.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: UpdateHistoryView()) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.green)
                            Text("更新历史")
                            Spacer()
                            let unreadCount = notificationManager.getUnreadCount()
                            if unreadCount > 0 {
                                Text("\(unreadCount) 条未读")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                } header: {
                    Text("订阅管理")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("订阅书籍")
                            Spacer()
                            Text("\(notificationManager.subscribedBooks.count)")
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("待处理更新")
                            Spacer()
                            Text("\(notificationManager.pendingUpdates.filter { !$0.isRead }.count)")
                                .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text("通知状态")
                            Spacer()
                            Image(systemName: notificationManager.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(notificationManager.isEnabled ? .green : .red)
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                } header: {
                    Text("统计信息")
                }
                
                Section {
                    Button("清空更新历史") {
                        notificationManager.clearUpdates()
                    }
                    .foregroundColor(.red)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("更新提醒")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SubscribedBooksView: View {
    @StateObject private var notificationManager = UpdateNotificationManager.shared
    @State private var showingAddSubscription = false
    
    var body: some View {
        List {
            if notificationManager.subscribedBooks.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("暂无订阅")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("在书架中长按书籍，开启更新提醒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(notificationManager.subscribedBooks) { book in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.bookName)
                                .font(.headline)
                            
                            Text(book.author)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("最新：\(book.lastChapter)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                                
                                if book.notifyChapterCount > 0 {
                                    Text("\(book.notifyChapterCount)次更新")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { book.isNotifying },
                            set: { enabled in
                                if let index = notificationManager.subscribedBooks.firstIndex(where: { $0.id == book.id }) {
                                    notificationManager.subscribedBooks[index].isNotifying = enabled
                                    notificationManager.saveSubscribedBooks()
                                }
                            }
                        ))
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            notificationManager.unsubscribeBook(book.id)
                        } label: {
                            Label("取消订阅", systemImage: "bookmark.slash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("订阅管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    notificationManager.checkForUpdates()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

struct UpdateHistoryView: View {
    @StateObject private var notificationManager = UpdateNotificationManager.shared
    
    var body: some View {
        List {
            if notificationManager.pendingUpdates.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("暂无更新")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("当订阅的书籍有新章节时会显示在这里")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section {
                    HStack {
                        Text("\(notificationManager.getUnreadCount()) 条未读")
                            .foregroundColor(.red)
                        Spacer()
                        Button("全部已读") {
                            notificationManager.markAllAsRead()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                ForEach(notificationManager.pendingUpdates.reversed()) { update in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(update.bookName)
                                    .font(.headline)
                                
                                if !update.isRead {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            Text("从「\(update.oldChapter)」更新到")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(update.newChapter)
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(update.updateTime, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .opacity(update.isRead ? 0.6 : 1.0)
                    .onTapGesture {
                        if !update.isRead {
                            notificationManager.markUpdateAsRead(update.id)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            notificationManager.removeUpdate(update.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("更新历史")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UpdateNotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UpdateNotificationSettingsView()
    }
}
