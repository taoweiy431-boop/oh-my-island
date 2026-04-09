import Markdown
import SwiftUI

// MARK: - Markdown Text View

private final class DocumentCache: @unchecked Sendable {
    static let shared = DocumentCache()
    private var cache: [String: Document] = [:]
    private let lock = NSLock()
    private let maxSize = 100

    func document(for text: String) -> Document {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[text] { return cached }
        let doc = Document(parsing: text, options: [.parseBlockDirectives, .parseSymbolLinks])
        if cache.count >= maxSize { cache.removeAll() }
        cache[text] = doc
        return doc
    }
}

struct MarkdownText: View {
    let text: String
    let baseColor: Color
    let fontSize: CGFloat
    private let document: Document

    init(_ text: String, color: Color = .white.opacity(0.9), fontSize: CGFloat = 13) {
        self.text = text
        self.baseColor = color
        self.fontSize = fontSize
        self.document = DocumentCache.shared.document(for: text)
    }

    var body: some View {
        let children = Array(document.children)
        if children.isEmpty {
            SwiftUI.Text(text)
                .foregroundColor(baseColor)
                .font(.system(size: fontSize))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    BlockRenderer(markup: child, baseColor: baseColor, fontSize: fontSize)
                }
            }
        }
    }
}

// MARK: - Block Renderer

private struct BlockRenderer: View {
    let markup: Markup
    let baseColor: Color
    let fontSize: CGFloat

    var body: some View { content }

    @ViewBuilder
    private var content: some View {
        if let paragraph = markup as? Paragraph {
            InlineRenderer(children: Array(paragraph.inlineChildren), baseColor: baseColor, fontSize: fontSize)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        } else if let heading = markup as? Heading {
            headingView(heading)
        } else if let codeBlock = markup as? CodeBlock {
            CodeBlockView(code: codeBlock.code)
        } else if let blockQuote = markup as? BlockQuote {
            blockQuoteView(blockQuote)
        } else if let list = markup as? UnorderedList {
            unorderedListView(list)
        } else if let list = markup as? OrderedList {
            orderedListView(list)
        } else if markup is ThematicBreak {
            Divider().background(baseColor.opacity(0.3)).padding(.vertical, 4)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func headingView(_ heading: Heading) -> some View {
        let text = InlineRenderer(children: Array(heading.inlineChildren), baseColor: baseColor, fontSize: fontSize).asText()
        switch heading.level {
        case 1: text.bold().italic().underline()
        case 2: text.bold()
        default: text.bold().foregroundColor(baseColor.opacity(0.7))
        }
    }

    @ViewBuilder
    private func blockQuoteView(_ blockQuote: BlockQuote) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(baseColor.opacity(0.4)).frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(blockQuote.children.enumerated()), id: \.offset) { _, child in
                    if let para = child as? Paragraph {
                        InlineRenderer(children: Array(para.inlineChildren), baseColor: baseColor.opacity(0.7), fontSize: fontSize)
                            .asText().italic()
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func unorderedListView(_ list: UnorderedList) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    SwiftUI.Text("•")
                        .font(.system(size: fontSize))
                        .foregroundColor(baseColor.opacity(0.6))
                        .frame(width: 12, alignment: .center)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            if let para = child as? Paragraph {
                                InlineRenderer(children: Array(para.inlineChildren), baseColor: baseColor, fontSize: fontSize)
                            } else {
                                BlockRenderer(markup: child, baseColor: baseColor, fontSize: fontSize)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func orderedListView(_ list: OrderedList) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 6) {
                    SwiftUI.Text("\(index + 1).")
                        .font(.system(size: fontSize))
                        .foregroundColor(baseColor.opacity(0.6))
                        .frame(width: 20, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            if let para = child as? Paragraph {
                                InlineRenderer(children: Array(para.inlineChildren), baseColor: baseColor, fontSize: fontSize)
                            } else {
                                BlockRenderer(markup: child, baseColor: baseColor, fontSize: fontSize)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Inline Renderer

private struct InlineRenderer: View {
    let children: [InlineMarkup]
    let baseColor: Color
    let fontSize: CGFloat

    var body: some View { asText() }

    func asText() -> SwiftUI.Text {
        var result = SwiftUI.Text("")
        for child in children { result = result + renderInline(child) }
        return result
    }

    private func renderInline(_ inline: InlineMarkup) -> SwiftUI.Text {
        if let text = inline as? Markdown.Text {
            return SwiftUI.Text(text.string).foregroundColor(baseColor)
        } else if let strong = inline as? Strong {
            return SwiftUI.Text(strong.plainText).fontWeight(.bold).foregroundColor(baseColor)
        } else if let emphasis = inline as? Emphasis {
            return SwiftUI.Text(emphasis.plainText).italic().foregroundColor(baseColor)
        } else if let code = inline as? InlineCode {
            return SwiftUI.Text(code.code).font(.system(size: fontSize, design: .monospaced)).foregroundColor(baseColor)
        } else if let link = inline as? Markdown.Link {
            return SwiftUI.Text(link.plainText).foregroundColor(Color.blue).underline()
        } else if let strike = inline as? Strikethrough {
            return SwiftUI.Text(strike.plainText).strikethrough().foregroundColor(baseColor)
        } else if inline is SoftBreak {
            return SwiftUI.Text(" ")
        } else if inline is LineBreak {
            return SwiftUI.Text("\n")
        } else {
            return SwiftUI.Text(inline.plainText).foregroundColor(baseColor)
        }
    }
}

// MARK: - Code Block View

private struct CodeBlockView: View {
    let code: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            SwiftUI.Text(code)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
}

// MARK: - Processing Spinner (symbol rotation)

struct ProcessingSpinner: View {
    @State private var phase: Int = 0
    private let symbols = ["·", "✢", "✳", "∗", "✻", "✽"]
    private let color = Color(red: 0.85, green: 0.47, blue: 0.34)
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(symbols[phase % symbols.count])
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(color)
            .frame(width: 12, alignment: .center)
            .onReceive(timer) { _ in phase = (phase + 1) % symbols.count }
    }
}

// MARK: - Terminal Colors

struct TerminalColors {
    static let amber = Color.orange
}

// MARK: - Rounded Corner Helper

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: RectCorner

    struct RectCorner: OptionSet {
        let rawValue: Int
        static let topLeft = RectCorner(rawValue: 1 << 0)
        static let topRight = RectCorner(rawValue: 1 << 1)
        static let bottomLeft = RectCorner(rawValue: 1 << 2)
        static let bottomRight = RectCorner(rawValue: 1 << 3)
        static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 { path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 { path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 { path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 { path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
        path.closeSubpath()
        return path
    }
}
