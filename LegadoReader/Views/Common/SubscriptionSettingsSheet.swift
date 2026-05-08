import SwiftUI

struct SubscriptionSettingsSheet: View {
    let book: Book
    let isAlreadySubscribed: Bool
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var sourceStore: SourceStore
    @StateObject private var notificationManager = UpdateNotificationManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("书籍名称")
                        Spacer()
                        Text(book.name)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text("作者")
                        Spacer()
                        Text(book.author)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastChapter = book.lastChapter {
                        HStack {
                            Text("最新章节")
                            Spacer()
                            Text(lastChapter)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("书籍信息")
                }
                
                Section {
                    if isAlreadySubscribed {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("已订阅此书籍的更新提醒")
                        }
                        
                        Button("取消订阅") {
                            notificationManager.unsubscribeBook(book.id)
                            dismiss()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button(action: {
                            subscribeToBook()
                        }) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.orange)
                                Text("订阅此书籍的更新提醒")
                            }
                        }
                    }
                } header: {
                    Text("订阅设置")
                } footer: {
                    Text("订阅后，当书籍有新章节时会收到推送通知")
                }
                
                Section {
                    NavigationLink(destination: UpdateNotificationSettingsView()) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                            Text("全局提醒设置")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("更新提醒")
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
    
    private func subscribeToBook() {
        guard let source = sourceStore.bookSources.first(where: { $0.url == book.sourceUrl }) else { return }
        
        Task {
            await bookStore.loadChapters(for: book, source: source)
            await MainActor.run {
                if let lastChapter = bookStore.chapters.last {
                    let subscribedBook = UpdateNotificationManager.SubscribedBook(
                        book: book,
                        source: source,
                        lastChapter: lastChapter
                    )
                    notificationManager.subscribedBooks.append(subscribedBook)
                    notificationManager.saveSubscribedBooks()
                    dismiss()
                }
            }
        }
    }
}
