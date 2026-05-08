import SwiftUI

struct GroupSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var groupManager = BookGroupManager.shared
    let book: Book
    
    var body: some View {
        NavigationView {
            List {
                Section("添加到分组") {
                    ForEach(groupManager.groups) { group in
                        Button(action: {
                            addBookToGroup(group)
                        }) {
                            HStack {
                                Image(systemName: group.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.headline)
                                    Text("\(group.bookCount) 本书")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if group.bookIds.contains(book.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                                .frame(width: 30)
                            
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("选择分组")
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
    
    private func addBookToGroup(_ group: BookGroup) {
        groupManager.addBookToGroup(bookId: book.id, groupId: group.id)
        dismiss()
    }
}
