import SwiftUI
import UIKit

/// 图钉的状态
enum PinState {
    case seated     // 钉在墙上
    case hovering   // 写便签时悬在上方
    case windUp     // 往上一提，准备扎下去
    case pulled     // 被拔起来（挪位置时）
}

/// 一件东西的几何：所有尺寸都按宽度 w 等比
struct ItemGeometry {
    let w: CGFloat
    let h: CGFloat
    let pic: CGRect?
    let cap: CGRect?
    let hasLabel: Bool
    let isFilm: Bool

    init(kind: NoteKind, frame: PhotoFrame, width w: CGFloat) {
        self.w = w
        if kind != .photo {
            h = w; pic = nil; cap = nil; hasLabel = false; isFilm = false
            return
        }
        switch frame {
        case .polaroid:
            h = 1.2 * w
            pic = CGRect(x: 0.06 * w, y: 0.06 * w, width: 0.88 * w, height: 0.88 * w)
            cap = CGRect(x: 0.06 * w, y: 0.94 * w, width: 0.88 * w, height: 0.26 * w)
            hasLabel = false; isFilm = false
        case .print:
            h = 0.8 * w
            pic = CGRect(x: 0.045 * w, y: 0.045 * w, width: 0.91 * w, height: 0.71 * w)
            cap = nil; hasLabel = true; isFilm = false
        case .film:
            h = 0.74 * w
            pic = CGRect(x: 0.05 * w, y: 0.13 * w, width: 0.9 * w, height: 0.48 * w)
            cap = nil; hasLabel = true; isFilm = true
        }
    }

    /// 印章的位置（中心点和大小）
    func stampFrame(_ shape: StampShape) -> CGRect {
        let sw = shape.widthFactor * w
        let sh = sw * shape.designSize.height / shape.designSize.width
        let c = CGPoint(x: 0.7 * w, y: h - 0.3 * w)
        return CGRect(x: c.x - sw / 2, y: c.y - sh / 2, width: sw, height: sh)
    }

    var pinSize: CGFloat { 0.16 * w }
}

/// 墙上、详情、写便签、分享图里的同一件东西
struct ItemView<Placeholder: View>: View {
    let content: ItemContent
    let width: CGFloat
    /// 传入时可编辑文字
    var text: Binding<String>? = nil
    var pinState: PinState = .seated
    var showStamp = true
    var showDoodle = true
    /// 为 true 时印章悬在半空（放大、模糊、透明），变回 false 时「啪」地盖下去
    var stampDrop = false
    /// 照片还没选时显示的东西（写便签时放「选一张照片」）
    @ViewBuilder var placeholder: () -> Placeholder

    var body: some View {
        let g = ItemGeometry(kind: content.kind, frame: content.frame, width: width)
        ZStack(alignment: .topLeading) {
            Group {
                if content.kind == .photo { photoBody(g) } else { noteBody(g) }
            }
            .frame(width: g.w, height: g.h)
            .clipped()
            .shadow(color: .black.opacity(0.33), radius: g.w * 0.03, x: g.w * 0.008, y: g.w * 0.028)

            if g.hasLabel, text != nil || !content.text.isEmpty {
                label(g)
                    .rotationEffect(.degrees(-2.5), anchor: .topLeading)
                    .offset(x: 0.08 * g.w, y: g.h - 0.05 * g.w)
            }

            if showDoodle {
                DoodleLayer(strokes: content.doodle).frame(width: g.w, height: g.h)
            }

            if showStamp, let stamp = content.stamp, let date = content.achievedAt {
                let f = g.stampFrame(stamp.shape)
                StampMark(style: stamp, date: date, width: f.width)
                    .scaleEffect(stampDrop ? 2.3 : 1)
                    .blur(radius: stampDrop ? 5 : 0)
                    .rotationEffect(.degrees(stampDrop ? -30 : -12))
                    .blendMode(content.kind == .note ? .multiply : .normal)
                    .opacity(stampDrop ? 0 : (content.kind == .note ? 0.9 : 0.88))
                    .offset(y: stampDrop ? -0.25 * g.w : 0)
                    .position(x: f.midX, y: f.midY)
                    .transition(.opacity)
            }

            pin(g)
        }
        .frame(width: g.w, height: g.h)
    }

    // MARK: 图钉

    private func pin(_ g: ItemGeometry) -> some View {
        let s = g.pinSize
        let (dy, scale, rot): (CGFloat, CGFloat, Double) = {
            switch pinState {
            case .seated: return (0, 1, 0)
            case .hovering: return (-0.05 * g.w, 1.18, 0)
            case .windUp: return (-0.22 * g.w, 1.6, 0)
            case .pulled: return (-0.13 * g.w, 1.3, -8)
            }
        }()
        let lifted = pinState != .seated
        return PushPin(shape: content.style.pinShape, color: content.style.pin, size: s)
            .shadow(color: .black.opacity(lifted ? 0.18 : 0), radius: lifted ? 5 : 0, x: lifted ? s * 0.4 : 0, y: lifted ? s * 0.8 : 0)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rot))
            .position(x: g.w / 2, y: -0.065 * g.w + s / 2 + dy)
    }

    // MARK: 便签

    private func noteBody(_ g: ItemGeometry) -> some View {
        let w = g.w
        let long = content.text.count > 22
        let fs = w * (long ? 0.072 : 0.085)
        let ink = content.style.ink
        return ZStack(alignment: .topLeading) {
            NotePaper(style: content.style)
            VStack(alignment: .leading, spacing: 0) {
                if let text {
                    TextField("", text: text, prompt: Text("此生清单").foregroundStyle(ink.opacity(0.32)), axis: .vertical)
                        .font(Fonts.serif(w * 0.085))
                        .lineSpacing(w * 0.035)
                        .lineLimit(1...7)
                        .foregroundStyle(ink)
                } else {
                    Text(content.text)
                        .font(Fonts.serif(fs))
                        .lineSpacing(fs * 0.45)
                        .foregroundStyle(ink)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                Spacer(minLength: 0)
                HStack {
                    Text("No.\(content.number)")
                    Spacer()
                    Text(text != nil ? "\(content.text.count) / \(WallStore.maxLength)" : DateText.short(content.createdAt))
                }
                .font(.system(size: w * 0.062, weight: .medium).monospacedDigit())
                .foregroundStyle(ink.opacity(0.5))
            }
            .padding(.top, 0.17 * w)
            .padding(.horizontal, 0.09 * w)
            .padding(.bottom, 0.06 * w)
            .frame(width: w, height: g.h, alignment: .topLeading)
        }
    }

    // MARK: 照片

    private func photoBody(_ g: ItemGeometry) -> some View {
        let w = g.w
        let P = g.pic ?? .zero
        let bg: Color = switch content.frame {
        case .polaroid: Color(red: 0.98, green: 0.98, blue: 0.96)
        case .print: .white
        case .film: Color(red: 0.09, green: 0.08, blue: 0.07)
        }
        return ZStack(alignment: .topLeading) {
            bg

            Group {
                if let img = content.image {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color(red: 0.85, green: 0.82, blue: 0.76)
                        placeholder()
                    }
                }
            }
            .frame(width: P.width, height: P.height)
            .clipped()
            .offset(x: P.minX, y: P.minY)

            if g.isFilm { filmEdges(g) }

            if content.image != nil { timestamp(g, P) }

            if let cap = g.cap {
                caption(w: w)
                    .frame(width: cap.width - (content.timestamp == .hand && content.image != nil ? 0.3 * w : 0),
                           height: cap.height - 0.04 * w, alignment: .leading)
                    .padding(.horizontal, 0.02 * w)
                    .offset(x: cap.minX, y: cap.minY)
            }

            LinearGradient(colors: [Color.white.opacity(0.18), .clear, Color.black.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func caption(w: CGFloat) -> some View {
        if let text {
            TextField("", text: text, prompt: Text("此生清单").foregroundStyle(Color.handInk.opacity(0.35)), axis: .vertical)
                .font(Fonts.hand(w * 0.095))
                .lineLimit(1...2)
                .foregroundStyle(Color.handInk)
        } else {
            Text(content.text)
                .font(Fonts.hand(w * 0.095))
                .foregroundStyle(Color.handInk)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }

    private func label(_ g: ItemGeometry) -> some View {
        let w = g.w
        return Group {
            if let text {
                TextField("", text: text, prompt: Text("此生清单").foregroundStyle(Color.handInk.opacity(0.35)))
                    .frame(width: 0.7 * w)
            } else {
                Text(content.text).lineLimit(1).truncationMode(.tail)
            }
        }
        .font(Fonts.hand(w * 0.085))
        .foregroundStyle(Color.handInk)
        .padding(.vertical, 0.012 * w)
        .padding(.horizontal, 0.04 * w)
        .background(Color(red: 0.97, green: 0.95, blue: 0.89).shadow(color: .black.opacity(0.25), radius: 1.5, y: 1))
        .frame(maxWidth: 0.84 * w, alignment: .leading)
    }

    private func filmEdges(_ g: ItemGeometry) -> some View {
        let w = g.w
        return Canvas { ctx, _ in
            let hole = Color(red: 0.85, green: 0.81, blue: 0.74)
            var x = 0.03 * w
            while x < w {
                ctx.fill(Path(roundedRect: CGRect(x: x, y: 0.04 * w, width: 0.045 * w, height: 0.045 * w), cornerRadius: 1), with: .color(hole))
                ctx.fill(Path(roundedRect: CGRect(x: x, y: g.h - 0.085 * w, width: 0.045 * w, height: 0.045 * w), cornerRadius: 1), with: .color(hole))
                x += 0.09 * w
            }
        }
        .overlay(alignment: .topLeading) {
            Text("24A")
                .font(Fonts.lcd(0.045 * w))
                .foregroundStyle(Color(red: 0.95, green: 0.6, blue: 0.23))
                .offset(x: 0.06 * w, y: 0.615 * w)
        }
        .frame(width: g.w, height: g.h)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func timestamp(_ g: ItemGeometry, _ P: CGRect) -> some View {
        let w = g.w
        let t = content.timestamp.text(for: content.createdAt)
        switch content.timestamp {
        case .none:
            EmptyView()
        case .digital:
            Color.clear.frame(width: P.width, height: P.height)
                .overlay(alignment: .bottomTrailing) {
                    Text(t)
                        .font(Fonts.lcd(0.072 * w))
                        .foregroundStyle(Color.lcdOrange)
                        .shadow(color: Color.lcdOrange.opacity(0.9), radius: 3)
                        .padding(.trailing, 0.035 * w)
                        .padding(.bottom, 0.035 * w)
                }
                .offset(x: P.minX, y: P.minY)
        case .typewriter:
            Text(t)
                .font(Fonts.typewriter(0.052 * w))
                .foregroundStyle(Color(red: 0.11, green: 0.1, blue: 0.09))
                .padding(.vertical, 0.008 * w)
                .padding(.horizontal, 0.02 * w)
                .background(Color(red: 0.96, green: 0.94, blue: 0.88).shadow(color: .black.opacity(0.3), radius: 1, y: 1))
                .rotationEffect(.degrees(-3))
                .offset(x: P.minX + 0.03 * w, y: P.minY + 0.03 * w)
        case .hand:
            if let cap = g.cap {
                Color.clear.frame(width: cap.width, height: cap.height)
                    .overlay(alignment: .bottomTrailing) {
                        Text(t).font(Fonts.hand(0.085 * w)).foregroundStyle(Color.handInk)
                            .padding(.trailing, 0.02 * w).padding(.bottom, 0.05 * w)
                    }
                    .offset(x: cap.minX, y: cap.minY)
            } else {
                Color.clear.frame(width: P.width, height: P.height)
                    .overlay(alignment: .bottomLeading) {
                        Text(t).font(Fonts.hand(0.085 * w)).foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.55), radius: 1.5, y: 1)
                            .padding(.leading, 0.04 * w).padding(.bottom, 0.035 * w)
                    }
                    .offset(x: P.minX, y: P.minY)
            }
        }
    }
}

extension ItemView where Placeholder == EmptyView {
    init(content: ItemContent, width: CGFloat, text: Binding<String>? = nil,
         pinState: PinState = .seated, showStamp: Bool = true, showDoodle: Bool = true, stampDrop: Bool = false) {
        self.content = content
        self.width = width
        self.text = text
        self.pinState = pinState
        self.showStamp = showStamp
        self.showDoodle = showDoodle
        self.stampDrop = stampDrop
        self.placeholder = { EmptyView() }
    }
}
