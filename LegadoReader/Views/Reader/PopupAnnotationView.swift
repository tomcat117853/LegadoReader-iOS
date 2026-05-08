import SwiftUI

struct PopupAnnotationView: View {
    @Environment(\.dismiss) var dismiss
    
    let annotation: AnnotationService.Annotation
    let position: CGPoint
    let onEdit: (AnnotationService.Annotation) -> Void
    let onDelete: (AnnotationService.Annotation) -> Void
    
    @State private var showActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !annotation.note.isEmpty {
                Text(annotation.note)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
            }
            
            if !annotation.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(annotation.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
            
            HStack(spacing: 16) {
                Text(formatDate(annotation.createdTime))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        showActions.toggle()
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                    }
                    
                    if showActions {
                        HStack(spacing: 8) {
                            Button(action: {
                                onEdit(annotation)
                                showActions = false
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: {
                                onDelete(annotation)
                                dismiss()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .transition(.scale)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .position(position)
        .transition(.scale.combined(with: .opacity))
        .onTapGesture {
            showActions = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AnnotationPopupMenuView: View {
    let position: CGPoint
    let selectedText: String
    let onHighlight: () -> Void
    let onAddNote: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            if !selectedText.isEmpty {
                Text(selectedText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(12)
                    .lineLimit(3)
                
                Divider()
            }
            
            VStack(spacing: 0) {
                menuButton(icon: "highlighter", title: "高亮", action: onHighlight)
                Divider()
                menuButton(icon: "note.text", title: "添加笔记", action: onAddNote)
                Divider()
                menuButton(icon: "doc.on.doc", title: "复制", action: onCopy)
                Divider()
                menuButton(icon: "square.and.arrow.up", title: "分享", action: onShare)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .position(position)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func menuButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }
}