import SwiftUI

// MARK: - 笔刷

enum Brush: String, CaseIterable, Codable, Identifiable {
    case crayon, water, chalk, eraser
    var id: String { rawValue }
    var name: String {
        switch self {
        case .crayon: "蜡笔"
        case .water: "水彩笔"
        case .chalk: "粉笔"
        case .eraser: "橡皮"
        }
    }
    /// 笔触粗细（占画面宽度的比例）
    var size: Double {
        switch self {
        case .crayon: 0.028
        case .water: 0.036
        case .chalk: 0.03
        case .eraser: 0.045
        }
    }
}

/// 一笔。点的坐标是 0...1 的比例，换任何尺寸画出来都一样
struct DoodleStroke: Codable, Equatable {
    var brush: Brush
    var colorHex: String
    var size: Double
    var seed: UInt64
    var points: [CGPoint]
}

// MARK: - 渲染

enum DoodleRenderer {
    static func draw(_ strokes: [DoodleStroke], in ctx: GraphicsContext, size: CGSize) {
        for s in strokes { draw(s, in: ctx, size: size) }
    }

    static func draw(_ s: DoodleStroke, in ctx: GraphicsContext, size: CGSize) {
        guard !s.points.isEmpty else { return }
        let pts = s.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let w = CGFloat(s.size) * size.width
        let color = Color(hex: s.colorHex)

        switch s.brush {
        case .water, .eraser:
            var path = Path()
            path.move(to: pts[0])
            if pts.count == 1 {
                path.addLine(to: CGPoint(x: pts[0].x + 0.1, y: pts[0].y))
            } else {
                for i in 1..<pts.count - 1 {
                    let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
                    path.addQuadCurve(to: mid, control: pts[i])
                }
                path.addLine(to: pts[pts.count - 1])
            }
            var c = ctx
            if s.brush == .eraser {
                c.blendMode = .destinationOut
                c.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: w * 2, lineCap: .round, lineJoin: .round))
            } else {
                // 水彩：半透明、边缘晕开，叠在一起会变深
                c.opacity = 0.32
                c.blendMode = .multiply
                c.addFilter(.blur(radius: w * 0.22))
                c.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w * 1.5, lineCap: .round, lineJoin: .round))
            }

        case .crayon, .chalk:
            var rng = SeededRandom(seed: s.seed)
            var c = ctx
            let step = max(1, w * 0.22)
            func dab(_ p: CGPoint) {
                if s.brush == .crayon {
                    // 蜡笔：密集的小方块，颗粒感
                    for _ in 0..<10 {
                        let a = CGFloat.random(in: 0..<(2 * .pi), using: &rng)
                        let r = sqrt(CGFloat.random(in: 0...1, using: &rng)) * w / 2
                        let d = w * CGFloat.random(in: 0.08...0.21, using: &rng)
                        c.opacity = Double.random(in: 0.3...0.85, using: &rng)
                        c.fill(Path(CGRect(x: p.x + cos(a) * r, y: p.y + sin(a) * r, width: d, height: d * 0.7)),
                               with: .color(color))
                    }
                } else {
                    // 粉笔：断断续续的粉末
                    if Double.random(in: 0...1, using: &rng) < 0.12 { return }
                    for _ in 0..<6 {
                        let a = CGFloat.random(in: 0..<(2 * .pi), using: &rng)
                        let r = sqrt(CGFloat.random(in: 0...1, using: &rng)) * w * 0.55
                        let d = w * CGFloat.random(in: 0.05...0.15, using: &rng)
                        c.opacity = Double.random(in: 0.4...0.95, using: &rng)
                        c.fill(Path(ellipseIn: CGRect(x: p.x + cos(a) * r - d, y: p.y + sin(a) * r - d, width: 2 * d, height: 2 * d)),
                               with: .color(color))
                    }
                }
            }
            dab(pts[0])
            if pts.count > 1 {
                for i in 1..<pts.count {
                    let a = pts[i - 1], b = pts[i]
                    let n = max(1, Int(ceil(hypot(b.x - a.x, b.y - a.y) / step)))
                    for k in 1...n {
                        let t = CGFloat(k) / CGFloat(n)
                        dab(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                    }
                }
            }
        }
    }
}

/// 只读的涂鸦层（墙上、详情、分享图）
struct DoodleLayer: View {
    let strokes: [DoodleStroke]

    var body: some View {
        Canvas { ctx, size in
            DoodleRenderer.draw(strokes, in: ctx, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 可以画的涂鸦层（写便签时）
struct DoodleCanvasView: View {
    @Binding var strokes: [DoodleStroke]
    let brush: Brush
    let colorHex: String
    let enabled: Bool

    @State private var current: DoodleStroke?

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                DoodleRenderer.draw(strokes, in: ctx, size: size)
                if let current { DoodleRenderer.draw(current, in: ctx, size: size) }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in
                        let p = CGPoint(x: min(1, max(0, v.location.x / geo.size.width)),
                                        y: min(1, max(0, v.location.y / geo.size.height)))
                        if current == nil {
                            current = DoodleStroke(brush: brush, colorHex: colorHex, size: brush.size,
                                                   seed: UInt64.random(in: 1...UInt64.max), points: [p])
                        } else {
                            current?.points.append(p)
                        }
                    }
                    .onEnded { _ in
                        if let current { strokes.append(current) }
                        current = nil
                    },
                including: enabled ? .all : .none
            )
        }
        .allowsHitTesting(enabled)
        .accessibilityLabel("涂鸦画布")
    }
}
