import SwiftUI
import UIKit

// MARK: - 单张纪念卡

/// 4:5 竖图，适合朋友圈和小红书
struct ShareCard: View {
    let note: Note

    private var headline: String {
        note.isAchieved
            ? "第 \(note.number) / 100 张 · 已达成"
            : "第 \(note.number) / 100 张 · 已钉上"
    }

    private var detail: String {
        if let done = note.achievedAt {
            let took = DateText.days(from: note.createdAt, to: done)
            return "\(DateText.short(note.createdAt)) 钉上 · \(DateText.short(done)) 达成 · 历时 \(took) 天"
        }
        return "钉上于 \(DateText.short(note.createdAt))"
    }

    var body: some View {
        let w: CGFloat = note.kind == .photo && note.frame == .polaroid ? 174 : 200
        ZStack {
            CorkBackground()
            VStack(spacing: 0) {
                Text("此生清单")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .tracking(5)
                    .padding(.top, 34)

                Spacer(minLength: 16)

                ItemView(content: note.content(image: PhotoStore.image(note.photoFile)), width: w)
                    .rotationEffect(.degrees(note.tilt * 0.5))

                Spacer(minLength: 16)

                VStack(spacing: 8) {
                    Text(headline)
                        .font(.system(size: 15, weight: .black, design: .serif))
                    Text(detail)
                        .font(.system(size: 10, weight: .medium, design: .serif).monospacedDigit())
                        .opacity(0.9)
                }

                Text("一生百张 · 落笔无悔")
                    .font(.system(size: 9, design: .serif))
                    .opacity(0.6)
                    .padding(.top, 26)
                    .padding(.bottom, 26)
            }
            .foregroundStyle(Color.paperWhite)
            .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1)
        }
        .frame(width: 360, height: 450)
    }

    /// 渲染成 1080×1350 的图片
    @MainActor
    static func render(note: Note) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCard(note: note))
        renderer.scale = 3
        return renderer.uiImage
    }
}

// MARK: - 整面墙

/// 把整面墙画成一张长图
struct WallSnapshot: View {
    let notes: [Note]
    let remaining: Int
    static let width: CGFloat = 360

    var body: some View {
        let W: CGFloat = Self.width - 40
        let wallH = CGFloat(WallLayout.wallHeight(notes)) * W
        ZStack(alignment: .top) {
            CorkBackground()
            VStack(spacing: 0) {
                Text("此生清单")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .tracking(5)
                    .padding(.top, 30)
                Text("\(remaining)")
                    .font(.system(size: 40, weight: .black, design: .serif).monospacedDigit())
                    .padding(.top, 6)
                Text("已钉上 \(notes.count) 张 · 已达成 \(notes.filter(\.isAchieved).count) 张 · 剩余 \(remaining) 张")
                    .font(.system(size: 10, weight: .medium, design: .serif).monospacedDigit())
                    .opacity(0.85)
                    .padding(.top, 4)

                ZStack(alignment: .topLeading) {
                    ForEach(notes.sorted { $0.z < $1.z }) { n in
                        let w = CGFloat(WallLayout.itemWidth) * W
                        let h = w * CGFloat(WallLayout.aspect(kind: n.kind, frame: n.frame))
                        ItemView(content: n.content(image: PhotoStore.image(n.photoFile)), width: w)
                            .rotationEffect(.degrees(n.tilt))
                            .position(x: CGFloat(n.x) * W + w / 2, y: CGFloat(n.y) * W + h / 2)
                    }
                }
                .frame(width: W, height: wallH, alignment: .topLeading)
                .padding(.top, 24)

                Text("少即是多 · \(DateText.short(Date()))")
                    .font(.system(size: 9, design: .serif))
                    .opacity(0.6)
                    .padding(.vertical, 28)
            }
            .foregroundStyle(Color.paperWhite)
            .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1)
        }
        .frame(width: Self.width)
    }

    @MainActor
    static func render(notes: [Note], remaining: Int) -> UIImage? {
        let renderer = ImageRenderer(content: WallSnapshot(notes: notes, remaining: remaining))
        // 墙很长时降低倍率，避免图片过大
        let approxHeight = 200 + CGFloat(WallLayout.wallHeight(notes)) * (width - 40)
        renderer.scale = min(3, max(1, 14_000 / approxHeight))
        return renderer.uiImage
    }
}

// MARK: - 分享预览

/// 先看一眼图片，再交给系统分享（微信、相册……）
struct ShareImageSheet: View {
    let title: String
    let make: @MainActor () -> UIImage?

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            CorkBackground()
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Text(title).font(.system(size: 15, weight: .bold, design: .serif))
                    Spacer()
                    Button("关闭") { dismiss() }.font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(Color.paperWhite)

                if let image {
                    ScrollView {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.4), radius: 14, y: 10)
                            .padding(.horizontal, 10)
                    }
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(title, image: Image(uiImage: image))) {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundStyle(Color.ink)
                            .background(Capsule().fill(Color.paperWhite))
                    }
                } else if failed {
                    Spacer()
                    Text("图片生成失败，请关闭后重试。").foregroundStyle(Color.paperWhite)
                    Spacer()
                } else {
                    Spacer()
                    ProgressView().tint(Color.paperWhite)
                    Spacer()
                }
            }
            .padding(20)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            let img = await MainActor.run { make() }
            image = img
            failed = img == nil
        }
    }
}
