import SwiftUI

// MARK: - 软木墙

struct CorkBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.corkBase))

            var rng = SeededRandom(seed: 20261008)
            let dark = Color(red: 0.48, green: 0.32, blue: 0.18)
            let light = Color(red: 0.90, green: 0.75, blue: 0.53)
            let count = Int(size.width * size.height / 70)

            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let w = CGFloat.random(in: 0.8...3.6, using: &rng)
                let h = w * CGFloat.random(in: 0.5...1.0, using: &rng)
                let isDark = Bool.random(using: &rng)
                let alpha = Double.random(in: 0.25...0.6, using: &rng)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)),
                    with: .color((isDark ? dark : light).opacity(alpha))
                )
            }
        }
        .overlay(
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.28)],
                center: .center,
                startRadius: 180,
                endRadius: 700
            )
        )
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - 图钉

/// 钉头的形状，画在 40×40 的格子里再缩放
struct PinHeadShape: Shape {
    let kind: PinShape

    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 40
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * k, y: rect.minY + y * k) }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGRect {
            CGRect(x: rect.minX + (cx - r) * k, y: rect.minY + (cy - r) * k, width: 2 * r * k, height: 2 * r * k)
        }
        var p = Path()
        switch kind {
        case .round:
            p.addEllipse(in: circle(20, 20, 15))
        case .flat:
            p.addEllipse(in: circle(20, 20, 17))
        case .heart:
            p.move(to: pt(20, 34))
            p.addCurve(to: pt(6, 11.5), control1: pt(8, 25.5), control2: pt(3, 18.5))
            p.addCurve(to: pt(20, 11.5), control1: pt(9, 5), control2: pt(17, 5))
            p.addCurve(to: pt(34, 11.5), control1: pt(23, 5), control2: pt(31, 5))
            p.addCurve(to: pt(20, 34), control1: pt(37, 18.5), control2: pt(32, 25.5))
            p.closeSubpath()
        case .star:
            for i in 0..<10 {
                let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let r: CGFloat = i.isMultiple(of: 2) ? 18.5 : 8
                let q = pt(20 + r * cos(a), 21.5 + r * sin(a))
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            p.closeSubpath()
        case .flower:
            for i in 0..<5 {
                let a = -CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / 5
                p.addEllipse(in: circle(20 + 9.5 * cos(a), 20 + 9.5 * sin(a), 7.6))
            }
            p.addEllipse(in: circle(20, 20, 8))
        }
        return p
    }
}

struct PushPin: View {
    var shape: PinShape = .round
    var color: Color = .pinRed
    var size: CGFloat = 20

    var body: some View {
        let head = PinHeadShape(kind: shape)
        ZStack {
            head.fill(color)
            if shape == .flat {
                head.fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.38), location: 0),
                    .init(color: .white.opacity(0), location: 0.5),
                    .init(color: .black.opacity(0.32), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .overlay(Circle().stroke(Color.black.opacity(0.22), lineWidth: size * 0.035))
                    .frame(width: size * 0.525, height: size * 0.525)
            } else {
                head.fill(RadialGradient(stops: [
                    .init(color: .white.opacity(0.5), location: 0),
                    .init(color: .white.opacity(0), location: 0.38),
                    .init(color: .black.opacity(0.5), location: 1)
                ], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
            }
            if shape == .flower {
                Circle()
                    .fill(Color.white.opacity(0.62))
                    .frame(width: size * 0.275, height: size * 0.275)
            }
            if let hl = highlight {
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: size * hl.r / 20, height: size * hl.r / 20)
                    .position(x: size * hl.x / 40, y: size * hl.y / 40)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: max(1, size * 0.06), x: size * 0.08, y: size * 0.16)
        .accessibilityHidden(true)
    }

    private var highlight: (x: CGFloat, y: CGFloat, r: CGFloat)? {
        switch shape {
        case .round: (14.5, 14, 3.6)
        case .flat: (13, 12, 2.4)
        case .heart: (12.5, 13, 2.8)
        case .star: (16.5, 15.5, 2.3)
        case .flower: nil
        }
    }
}

// MARK: - 纸上的花纹

struct PaperPatternView: View {
    let pattern: PaperPattern

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let lw = max(1, w / 300)
            let blue = Color(red: 0.27, green: 0.39, blue: 0.59)
            switch pattern {
            case .plain:
                break
            case .lined:
                for i in 1..<8 {
                    let y = h * CGFloat(i) / 8
                    ctx.fill(Path(CGRect(x: 0, y: y - lw, width: w, height: lw)), with: .color(blue.opacity(0.3)))
                }
            case .grid:
                for i in 0..<10 {
                    let t = CGFloat(i) / 10
                    ctx.fill(Path(CGRect(x: w * t, y: 0, width: lw, height: h)), with: .color(blue.opacity(0.22)))
                    ctx.fill(Path(CGRect(x: 0, y: h * t, width: w, height: lw)), with: .color(blue.opacity(0.22)))
                }
            case .dots:
                let r = max(1.3, w / 110)
                for i in 0..<10 {
                    for j in 0..<10 {
                        let c = CGPoint(x: w * (CGFloat(i) + 0.5) / 10, y: h * (CGFloat(j) + 0.5) / 10)
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(.black.opacity(0.2)))
                    }
                }
            case .stripes:
                var c = ctx
                c.translateBy(x: w / 2, y: h / 2)
                c.rotate(by: .degrees(45))
                let period = w * 0.1, band = w * 0.043
                var x = -w
                while x < w {
                    c.fill(Path(CGRect(x: x, y: -w, width: band, height: 2 * w)), with: .color(.white.opacity(0.42)))
                    x += period
                }
            case .gingham:
                let t = w / 6
                for i in 0..<6 {
                    ctx.fill(Path(CGRect(x: CGFloat(i) * t, y: 0, width: t / 2, height: h)), with: .color(.black.opacity(0.075)))
                    ctx.fill(Path(CGRect(x: 0, y: CGFloat(i) * t, width: w, height: t / 2)), with: .color(.black.opacity(0.075)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 一张纸：底色 + 花纹 + 一点光泽
struct NotePaper: View {
    let style: NoteStyle

    var body: some View {
        ZStack {
            style.paper
            PaperPatternView(pattern: style.pattern)
            LinearGradient(colors: [Color.white.opacity(0.18), .clear, Color.black.opacity(0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - 震一下

/// 图钉扎进去、印章压下去时，便签跟着震一下
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = shakes - shakes.rounded(.down)
        let dx = sin(progress * .pi * 6) * 4 * (1 - progress)
        let s = 1 - sin(progress * .pi) * 0.03
        let t = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .scaledBy(x: s, y: s)
            .translatedBy(x: -size.width / 2 + dx, y: -size.height / 2)
        return ProjectionTransform(t)
    }
}

// MARK: - 按住确认

/// 需要按住一段时间才会触发。给「不可撤回」一点重量。
struct HoldToConfirm: View {
    let title: String
    var holdingTitle = "请保持按住…"
    var duration: Double = 1.3
    var fill: Color = .pinRed
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var progress: CGFloat = 0
    @State private var pressing = false
    @State private var fired = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.ink)
            GeometryReader { geo in
                Capsule()
                    .fill(fill)
                    .frame(width: max(geo.size.height, geo.size.width * progress))
                    .opacity(progress > 0.001 ? 1 : 0)
            }
            Text(pressing ? holdingTitle : title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.paperWhite)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 56)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
        .opacity(isEnabled ? 1 : 0.4)
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: duration, maximumDistance: 40) {
            fire()
        } onPressingChanged: { isPressing in
            guard !fired else { return }
            pressing = isPressing
            if isPressing {
                Haptics.tick()
                withAnimation(.linear(duration: duration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fire() }
    }

    private func fire() {
        guard isEnabled, !fired else { return }
        fired = true
        action()
    }
}
