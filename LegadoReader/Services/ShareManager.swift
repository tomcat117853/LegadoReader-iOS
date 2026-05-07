import Foundation
import UIKit
import SwiftUI

class ShareManager: ObservableObject {
    static let shared = ShareManager()
    
    func shareBook(_ book: Book) {
        let shareText = """
        📚 \(book.name)
        
        作者: \(book.author)
        
        \(book.intro ?? "暂无简介")
        
        来源: \(book.sourceName ?? "未知")
        
        推荐给你一个好书阅读应用！
        """
        
        share(text: shareText, image: nil)
    }
    
    func shareChapter(_ bookName: String, chapterTitle: String, content: String) {
        let shareText = """
        📖 \(bookName)
        
        第 \(chapterTitle)
        
        \(content.prefix(500))...
        
        来自 LegadoReader
        """
        
        share(text: shareText, image: nil)
    }
    
    func shareNote(_ note: NoteManager.Note) {
        let shareText = """
        📝 阅读笔记
        
        书籍: \(note.bookName)
        章节: \(note.chapterTitle)
        
        \(note.content)
        
        \(note.highlightText != nil ? "高亮: \"\(note.highlightText!)\"" : "")
        
        来自 LegadoReader
        """
        
        share(text: shareText, image: nil)
    }
    
    func shareBookContent(_ content: String, from bookName: String) {
        let shareText = """
        📖 \(bookName)
        
        \(content.prefix(1000))...
        
        来自 LegadoReader
        """
        
        share(text: shareText, image: nil)
    }
    
    func share(text: String, image: UIImage?) {
        var items: [Any] = [text]
        if let image = image {
            items.append(image)
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.present(activityVC, animated: true)
            } else {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
    
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let applicationActivities: [UIActivity]?
    
    init(items: [Any], applicationActivities: [UIActivity]? = nil) {
        self.items = items
        self.applicationActivities = applicationActivities
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareMenuView: View {
    let book: Book
    @State private var showingShareSheet = false
    
    var body: some View {
        Menu {
            Button(action: {
                ShareManager.shared.shareBook(book)
            }) {
                Label("分享书籍", systemImage: "square.and.arrow.up")
            }
            
            Button(action: {
                if let url = URL(string: book.bookUrl ?? "") {
                    ShareManager.shared.share(text: "\(book.name)\n\(url.absoluteString)")
                }
            }) {
                Label("分享链接", systemImage: "link")
            }
            
            Button(action: {
                ShareManager.shared.copyToClipboard(book.intro ?? "")
            }) {
                Label("复制简介", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: {
                if let url = URL(string: book.sourceUrl ?? "") {
                    ShareManager.shared.share(text: "书源: \(book.sourceName ?? "")\n\(url.absoluteString)")
                }
            }) {
                Label("分享书源", systemImage: "server.rack")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
        }
    }
}

struct ShareButton: View {
    let book: Book
    @State private var showingShareSheet = false
    
    var body: some View {
        Button(action: {
            showingShareSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20))
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [
                "\(book.name)\n\n作者: \(book.author)\n\n\(book.intro ?? "")\n\n来源: \(book.sourceName ?? "")"
            ])
        }
    }
}
