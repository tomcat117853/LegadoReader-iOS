import SwiftUI

struct TableOfContentsView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var expandedSections: Set<String> = ["卷一"]
    @State private var currentChapter = "第一章 洪公子"
    
    private struct Chapter {
        let title: String
        let wordCount: Int
        let isSection: Bool
        let parentSection: String?
    }
    
    private var chapters: [Chapter] = [
        Chapter(title: "扉页", wordCount: 0, isSection: false, parentSection: nil),
        Chapter(title: "制作信息", wordCount: 92, isSection: false, parentSection: nil),
        Chapter(title: "内容简介", wordCount: 51, isSection: false, parentSection: nil),
        Chapter(title: "卷一", wordCount: 2, isSection: true, parentSection: nil),
        Chapter(title: "第一章 洪公子", wordCount: 2542, isSection: false, parentSection: "卷一"),
        Chapter(title: "第二章 想再听弹奏", wordCount: 2579, isSection: false, parentSection: "卷一"),
        Chapter(title: "第三章 岂能算了", wordCount: 1948, isSection: false, parentSection: "卷一"),
        Chapter(title: "第四章 黄大人的烦恼", wordCount: 2616, isSection: false, parentSection: "卷一"),
        Chapter(title: "第五章 君影草", wordCount: 2576, isSection: false, parentSection: "卷一"),
        Chapter(title: "第六章 另有高见", wordCount: 3186, isSection: false, parentSection: "卷一"),
        Chapter(title: "第七章 插翅难飞", wordCount: 1692, isSection: false, parentSection: "卷一"),
        Chapter(title: "第八章 试探与猜忌", wordCount: 2572, isSection: false, parentSection: "卷一"),
        Chapter(title: "第九章 何必太执着", wordCount: 2551, isSection: false, parentSection: "卷一"),
        Chapter(title: "第十章 赤红的粉末", wordCount: 2602, isSection: false, parentSection: "卷一"),
        Chapter(title: "第十一章 野村", wordCount: 2599, isSection: false, parentSection: "卷一"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("大明春色")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.white)
                }
                
                Button(action: {}) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Text("可用左滑手势对项进行操作")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(chapters, id: \.title) { chapter in
                        if chapter.parentSection == nil {
                            if chapter.isSection {
                                Button(action: {
                                    if expandedSections.contains(chapter.title) {
                                        expandedSections.remove(chapter.title)
                                    } else {
                                        expandedSections.insert(chapter.title)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: expandedSections.contains(chapter.title) ? "chevron.down" : "chevron.right")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                        
                                        Text(chapter.title)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Text("\(chapter.wordCount)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            } else {
                                Button(action: {
                                    currentChapter = chapter.title
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(chapter.title)
                                            .font(.subheadline)
                                            .foregroundColor(currentChapter == chapter.title ? Color(hex: "8BC34A")! : .white)
                                        
                                        Spacer()
                                        
                                        if chapter.wordCount > 0 {
                                            Text("\(chapter.wordCount)")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                        } else if expandedSections.contains(chapter.parentSection!) {
                            Button(action: {
                                currentChapter = chapter.title
                                dismiss()
                            }) {
                                HStack {
                                    Text("  ")
                                        .font(.subheadline)
                                    
                                    Text(chapter.title)
                                        .font(.subheadline)
                                        .foregroundColor(currentChapter == chapter.title ? Color(hex: "8BC34A")! : .white)
                                    
                                    Spacer()
                                    
                                    Text("\(chapter.wordCount)")
                                        .font(.caption)
                                        .foregroundColor(currentChapter == chapter.title ? Color(hex: "8BC34A")! : .white.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                }
            }
            .background(Color(hex: "1B5E20")!.opacity(0.5))
            
            HStack(spacing: 16) {
                Text("第一章 洪公子 (5/1080)")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Text("序号")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "1B5E20")!)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            HStack(spacing: 0) {
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(Color(hex: "8BC34A")!)
                        
                        Text("目录")
                            .font(.caption)
                            .foregroundColor(Color(hex: "8BC34A")!)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "bookmark")
                            .foregroundColor(.white)
                        
                        Text("书签")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .foregroundColor(.white)
                        
                        Text("笔记")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .background(Color(hex: "1B5E20")!)
        }
        .background(Color(hex: "1B5E20")!.opacity(0.95))
        .presentationDetents([.large])
        
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.down")
                .foregroundColor(.white)
                .padding(12)
                .background(Color(hex: "1B5E20")!)
                .cornerRadius(30)
        }
        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 20)
    }
}

struct TableOfContentsView_Previews: PreviewProvider {
    static var previews: some View {
        TableOfContentsView()
    }
}