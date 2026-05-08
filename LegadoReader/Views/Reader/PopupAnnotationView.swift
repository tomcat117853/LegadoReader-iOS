import SwiftUI

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