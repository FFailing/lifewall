import SwiftUI

// MARK: - 印章印迹

/// 盖在便签上的印。按设计稿坐标（见 StampShape.designSize）画，再整体缩放到 width
struct StampMark: View {
    let style: StampStyle
    let date: Date
    let width: CGFloat

    var body: some View {
        let d = style.shape.designSize
        let k = width / d.width
        Canvas { ctx, _ in
            ctx.scaleBy(x: k, y: k)
            StampArt(style: style, date: date).draw(in: ctx)
            // 印泥不均匀：随机打掉一些小点，做出颗粒感
            var holes = ctx
            holes.blendMode = .destinationOut
            var rng = SeededRandom(seed: UInt64(style.text.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) &+ 7)
            let count = Int(d.width * d.height / 7)
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...d.width, using: &rng)
                let y = CGFloat.random(in: 0...d.height, using: &rng)
                let r = CGFloat.random(in: 0.25...0.95, using: &rng)
                holes.opacity = Double.random(in: 0.25...0.9, using: &rng)
                holes.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(.black))
            }
        }
        .frame(width: d.width * k, height: d.height * k)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style.text)，\(DateText.full(date))")
    }
}

/// 印章的具体画法（和网页演示里的 stampSVG 一一对应）
struct StampArt {
    let style: StampStyle
    let date: Date

    private var c: Color { style.color }
    private var chars: [String] { Array(style.text.prefix(StampStyle.maxChars)).map(String.init) }
    private let title = "此 生 清 单"

    func draw(in ctx: GraphicsContext) {
        let n = max(1, chars.count)
        let t = chars.joined()
        let ds = DateText.short(date)

        switch style.shape {
        case .round:
            stroke(ctx, Path(ellipseIn: circle(60, 60, 55)), 4.5)
            stroke(ctx, Path(ellipseIn: circle(60, 60, 45)), 1.4)
            ring(ctx, .circle(60, 60, 50))
            if n <= 3 {
                arc(ctx, cx: 60, cy: 60, r: 35, size: 9, list: ["此", "生", "清", "单"], weight: .bold)
                text(ctx, t, 60, 62, n == 1 ? 34 : n == 2 ? 30 : 26)
                text(ctx, ds, 60, 86, 10, .bold)
                deco(ctx, 23, 62, 6.5)
                deco(ctx, 97, 62, 6.5)
            } else {
                let sizes: [Int: CGFloat] = [4: 15, 5: 14, 6: 13, 7: 12, 8: 11]
                arc(ctx, cx: 60, cy: 60, r: 34, size: sizes[n] ?? 11, list: chars)
                if style.ornament == .flowers {
                    flower(ctx, 60, 60, 9, fill: c, center: .white)
                } else {
                    ctx.fill(star(60, 60, 11), with: .color(c))
                }
                text(ctx, ds, 60, 85, 10, .bold)
            }

        case .oval:
            stroke(ctx, Path(ellipseIn: CGRect(x: 4, y: 5, width: 132, height: 90)), 4)
            stroke(ctx, Path(ellipseIn: CGRect(x: 14, y: 15, width: 112, height: 70)), 1.4)
            ring(ctx, .ellipse(70, 50, 61, 40))
            text(ctx, title, 70, 26, 8, .bold)
            if n <= 4 {
                text(ctx, t, 70, 52, n <= 2 ? 28 : n == 3 ? 24 : 20)
                if n <= 3 {
                    deco(ctx, 25, 52, 6)
                    deco(ctx, 115, 52, 6)
                }
            } else {
                let half = Int(ceil(Double(n) / 2))
                text(ctx, chars.prefix(half).joined(), 70, 44, 15)
                text(ctx, chars.dropFirst(half).joined(), 70, 61, 15)
            }
            text(ctx, ds, 70, 76, 9, .bold)

        case .square:
            ctx.fill(Path(roundedRect: CGRect(x: 4, y: 4, width: 102, height: 102), cornerRadius: 6), with: .color(c))
            var inner = ctx
            inner.opacity = 0.75
            inner.stroke(Path(roundedRect: CGRect(x: 10, y: 10, width: 90, height: 90), cornerRadius: 3), with: .color(.white), lineWidth: 1.5)
            ring(ctx, .rect(7, 7, 96, 96), fill: .white)
            if style.ornament == .stars || style.ornament == .flowers {
                for p in [CGPoint(x: 7, y: 7), CGPoint(x: 103, y: 7), CGPoint(x: 7, y: 103), CGPoint(x: 103, y: 103)] {
                    deco(ctx, p.x, p.y, 3.2, fill: .white, center: c)
                }
            }
            var cs = chars
            if [3, 5, 8].contains(cs.count) { cs.append("印") }
            if cs.count == 7 { cs += ["之", "印"] }
            let grid: [(CGFloat, CGFloat, CGFloat)]
            switch cs.count {
            case 1: grid = [(55, 55, 62)]
            case 2: grid = [(55, 33, 40), (55, 77, 40)]
            case 4: grid = [(33, 34, 36), (77, 34, 36), (33, 77, 36), (77, 77, 36)]
            case 6: grid = [(26, 37, 26), (55, 37, 26), (84, 37, 26), (26, 74, 26), (55, 74, 26), (84, 74, 26)]
            default: grid = [27, 55, 83].flatMap { y in [26, 55, 84].map { x in (CGFloat(x), CGFloat(y), CGFloat(23)) } }
            }
            for (i, ch) in cs.enumerated() where i < grid.count {
                text(ctx, ch, grid[i].0, grid[i].1, grid[i].2, .black, color: .white)
            }

        case .postmark:
            stroke(ctx, Path(ellipseIn: circle(55, 55, 49)), 3.4)
            stroke(ctx, Path(ellipseIn: circle(55, 55, 41)), 1.2)
            ring(ctx, .circle(55, 55, 45))
            stroke(ctx, PostmarkWaves().path(in: CGRect(x: 0, y: 0, width: 160, height: 110)), 2.4)
            if n <= 4 {
                text(ctx, title, 55, 30, 8, .bold)
                line(ctx, 17, 42, 93, 42, 1.2)
                line(ctx, 17, 70, 93, 70, 1.2)
                text(ctx, t, 55, 56, n <= 2 ? 22 : n == 3 ? 19 : 16)
                text(ctx, ds, 55, 83, 9.5, .bold)
                if n <= 2 {
                    deco(ctx, 26, 56, 4)
                    deco(ctx, 84, 56, 4)
                }
            } else {
                arc(ctx, cx: 55, cy: 55, r: 31, size: n <= 6 ? 11 : 10, list: chars)
                line(ctx, 20, 48, 90, 48, 1.2)
                line(ctx, 20, 66, 90, 66, 1.2)
                text(ctx, ds, 55, 57, 10, .bold)
                text(ctx, title, 55, 79, 7.5, .bold)
            }

        case .rect:
            let fs = min(28, floor(112 / CGFloat(n)))
            stroke(ctx, Path(roundedRect: CGRect(x: 3, y: 3, width: 144, height: 78), cornerRadius: 4), 3.6)
            stroke(ctx, Path(roundedRect: CGRect(x: 9, y: 9, width: 132, height: 66), cornerRadius: 2), 1.2)
            ring(ctx, .rect(6, 6, 138, 72))
            text(ctx, t, 75, 35, fs, tracking: n <= 4 ? 3 : 0)
            line(ctx, 22, 51, 128, 51, 1)
            text(ctx, ds, 75, 63, 11, .bold, tracking: 2)
            if CGFloat(n) * fs < 92 {
                deco(ctx, 21, 35, 6)
                deco(ctx, 129, 35, 6)
            }
        }
    }

    // MARK: 基本笔画

    private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGRect {
        CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
    }

    private func stroke(_ ctx: GraphicsContext, _ p: Path, _ w: CGFloat) {
        ctx.stroke(p, with: .color(c), lineWidth: w)
    }

    private func line(_ ctx: GraphicsContext, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ w: CGFloat) {
        var p = Path()
        p.move(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        ctx.stroke(p, with: .color(c), lineWidth: w)
    }

    private func text(_ ctx: GraphicsContext, _ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
                      _ weight: Font.Weight = .black, color: Color? = nil, tracking: CGFloat = 0) {
        let t = Text(s)
            .font(.system(size: size, weight: weight, design: .serif).monospacedDigit())
            .tracking(tracking)
            .foregroundColor(color ?? c)
        ctx.draw(t, at: CGPoint(x: x, y: y), anchor: .center)
    }

    /// 沿圆弧排字（字头朝外）
    private func arc(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, size: CGFloat,
                     list: [String], weight: Font.Weight = .black) {
        let step = size * 1.12 / r
        let start = -CGFloat.pi / 2 - step * CGFloat(list.count - 1) / 2
        for (i, ch) in list.enumerated() {
            let a = start + CGFloat(i) * step
            var c2 = ctx
            c2.translateBy(x: cx + r * cos(a), y: cy + r * sin(a))
            c2.rotate(by: .radians(Double(a) + .pi / 2))
            let t = Text(ch).font(.system(size: size, weight: weight, design: .serif)).foregroundColor(c)
            c2.draw(t, at: .zero, anchor: .center)
        }
    }

    // MARK: 纹样

    enum Ring {
        case circle(CGFloat, CGFloat, CGFloat)
        case ellipse(CGFloat, CGFloat, CGFloat, CGFloat)
        case rect(CGFloat, CGFloat, CGFloat, CGFloat)
    }

    /// 沿边框一圈：联珠或齿纹
    private func ring(_ ctx: GraphicsContext, _ r: Ring, fill: Color? = nil) {
        guard style.ornament == .beads || style.ornament == .ticks else { return }
        let col = fill ?? c
        let gap: CGFloat = style.ornament == .beads ? 5.2 : 3.4
        var pts: [(CGPoint, CGVector)] = []
        switch r {
        case let .circle(cx, cy, rr), let .ellipse(cx, cy, rr, _):
            var rx = rr, ry = rr
            if case let .ellipse(_, _, a, b) = r { rx = a; ry = b }
            let per = 2 * CGFloat.pi * sqrt((rx * rx + ry * ry) / 2)
            let count = Int((per / gap).rounded())
            for i in 0..<count {
                let a = 2 * CGFloat.pi * CGFloat(i) / CGFloat(count)
                var nx = cos(a) / rx, ny = sin(a) / ry
                let l = hypot(nx, ny); nx /= l; ny /= l
                pts.append((CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a)), CGVector(dx: nx, dy: ny)))
            }
        case let .rect(x, y, w, h):
            let edges: [(CGPoint, CGVector, CGFloat, CGVector)] = [
                (CGPoint(x: x, y: y), CGVector(dx: 1, dy: 0), w, CGVector(dx: 0, dy: -1)),
                (CGPoint(x: x + w, y: y), CGVector(dx: 0, dy: 1), h, CGVector(dx: 1, dy: 0)),
                (CGPoint(x: x + w, y: y + h), CGVector(dx: -1, dy: 0), w, CGVector(dx: 0, dy: 1)),
                (CGPoint(x: x, y: y + h), CGVector(dx: 0, dy: -1), h, CGVector(dx: -1, dy: 0))
            ]
            for (o, d, len, nrm) in edges {
                let count = max(1, Int((len / gap).rounded()))
                for i in 0..<count {
                    let t = (CGFloat(i) + 0.5) * len / CGFloat(count)
                    pts.append((CGPoint(x: o.x + d.dx * t, y: o.y + d.dy * t), nrm))
                }
            }
        }
        for (p, nrm) in pts {
            if style.ornament == .beads {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.25, y: p.y - 1.25, width: 2.5, height: 2.5)), with: .color(col))
            } else {
                var tick = Path()
                tick.move(to: CGPoint(x: p.x - nrm.dx * 1.7, y: p.y - nrm.dy * 1.7))
                tick.addLine(to: CGPoint(x: p.x + nrm.dx * 1.7, y: p.y + nrm.dy * 1.7))
                ctx.stroke(tick, with: .color(col), lineWidth: 1.1)
            }
        }
    }

    /// 点缀：小花或星星
    private func deco(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat,
                      fill: Color? = nil, center: Color = .white) {
        switch style.ornament {
        case .stars: ctx.fill(star(x, y, s), with: .color(fill ?? c))
        case .flowers: flower(ctx, x, y, s, fill: fill ?? c, center: center)
        default: break
        }
    }

    private func flower(_ ctx: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ s: CGFloat, fill: Color, center: Color) {
        for i in 0..<5 {
            let a = -CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / 5
            ctx.fill(Path(ellipseIn: circle(cx + cos(a) * s * 0.55, cy + sin(a) * s * 0.55, s * 0.45)), with: .color(fill))
        }
        ctx.fill(Path(ellipseIn: circle(cx, cy, s * 0.3)), with: .color(center))
    }

    private func star(_ cx: CGFloat, _ cy: CGFloat, _ R: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let r = i.isMultiple(of: 2) ? R : R * 0.42
            let q = CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }
}

/// 邮戳右边的波浪线（设计稿坐标 160×110）
struct PostmarkWaves: Shape {
    func path(in rect: CGRect) -> Path {
        let k = rect.width / 160
        var p = Path()
        for i in 0..<4 {
            let y = (30 + CGFloat(i) * 16) * k
            p.move(to: CGPoint(x: 104 * k, y: y))
            var x: CGFloat = 104
            var up = true
            while x < 156 {
                p.addQuadCurve(to: CGPoint(x: (x + 14) * k, y: y), control: CGPoint(x: (x + 7) * k, y: y + (up ? -5 : 5) * k))
                x += 14
                up.toggle()
            }
        }
        return p
    }
}
