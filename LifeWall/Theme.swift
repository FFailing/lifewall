import SwiftUI
import UIKit
import CoreText

// MARK: - 颜色

extension Color {
    static let ink = Color(red: 0.17, green: 0.13, blue: 0.10)
    static let pinRed = Color(red: 0.78, green: 0.17, blue: 0.13)
    static let paperWhite = Color(red: 0.99, green: 0.97, blue: 0.92)
    static let stampRed = Color(red: 0.76, green: 0.15, blue: 0.11)
    static let corkBase = Color(red: 0.73, green: 0.54, blue: 0.35)
    static let handInk = Color(red: 0.16, green: 0.23, blue: 0.43)
    static let lcdOrange = Color(red: 1.0, green: 0.60, blue: 0.18)

    /// "#RRGGBB" → Color
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt32(s, radix: 16) ?? 0xFBE7A1
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    /// Color → "#RRGGBB"
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let c = { (x: CGFloat) in Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}

func sameHex(_ a: String, _ b: String) -> Bool { a.caseInsensitiveCompare(b) == .orderedSame }

// MARK: - 便签样式

enum PaperPattern: String, CaseIterable, Codable, Identifiable {
    case plain, lined, grid, dots, stripes, gingham
    var id: String { rawValue }
    var name: String {
        switch self {
        case .plain: "素面"
        case .lined: "横线"
        case .grid: "方格"
        case .dots: "圆点"
        case .stripes: "斜纹"
        case .gingham: "格纹"
        }
    }
}

enum PinShape: String, CaseIterable, Codable, Identifiable {
    case round, flat, heart, star, flower
    var id: String { rawValue }
    var name: String {
        switch self {
        case .round: "圆珠"
        case .flat: "平头"
        case .heart: "爱心"
        case .star: "星星"
        case .flower: "小花"
        }
    }
}

struct NoteStyle: Codable, Equatable {
    var paperHex: String = Presets.papers[0].hex
    var pattern: PaperPattern = .plain
    var pinShape: PinShape = .round
    var pinHex: String = Presets.pins[0].hex

    var paper: Color { Color(hex: paperHex) }
    var pin: Color { Color(hex: pinHex) }

    /// 深色纸用浅色字
    var ink: Color {
        let v = UInt32(paperHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        func lin(_ x: UInt32) -> Double {
            let c = Double(x) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let l = 0.2126 * lin((v >> 16) & 0xFF) + 0.7152 * lin((v >> 8) & 0xFF) + 0.0722 * lin(v & 0xFF)
        return l < 0.28 ? .paperWhite : .ink
    }
}

// MARK: - 照片

enum NoteKind: String, Codable {
    case note, photo
}

enum PhotoFrame: String, CaseIterable, Codable, Identifiable {
    case polaroid, print, film
    var id: String { rawValue }
    var name: String {
        switch self {
        case .polaroid: "拍立得"
        case .print: "冲印照片"
        case .film: "胶片"
        }
    }
}

enum TimeStampStyle: String, CaseIterable, Codable, Identifiable {
    case digital, hand, typewriter, none
    var id: String { rawValue }
    var name: String {
        switch self {
        case .digital: "数码日期"
        case .hand: "手写"
        case .typewriter: "打字机"
        case .none: "无"
        }
    }

    func text(for d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        let y = c.year ?? 2026, m = c.month ?? 1, day = c.day ?? 1
        switch self {
        case .digital: return String(format: "'%02d %02d %02d", y % 100, m, day)
        case .hand: return "\(y).\(m).\(day)"
        case .typewriter:
            let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
            return String(format: "%@ %02d %d", months[max(0, min(11, m - 1))], day, y)
        case .none: return ""
        }
    }
}

// MARK: - 印章

enum StampShape: String, CaseIterable, Codable, Identifiable {
    case round, oval, square, postmark, rect
    var id: String { rawValue }
    var name: String {
        switch self {
        case .round: "圆章"
        case .oval: "椭圆章"
        case .square: "方印"
        case .postmark: "邮戳"
        case .rect: "日期章"
        }
    }
    /// 设计稿尺寸（和网页演示里的 SVG viewBox 一致）
    var designSize: CGSize {
        switch self {
        case .round: CGSize(width: 120, height: 120)
        case .oval: CGSize(width: 140, height: 100)
        case .square: CGSize(width: 110, height: 110)
        case .postmark: CGSize(width: 160, height: 110)
        case .rect: CGSize(width: 150, height: 84)
        }
    }
    /// 盖在便签上时占便签宽度的比例
    var widthFactor: CGFloat { self == .postmark || self == .rect ? 0.5 : 0.42 }
}

/// 印章上的纹样
enum StampOrnament: String, CaseIterable, Codable, Identifiable {
    case flowers, beads, ticks, stars, none
    var id: String { rawValue }
    var name: String {
        switch self {
        case .flowers: "花纹"
        case .beads: "联珠"
        case .ticks: "齿纹"
        case .stars: "星纹"
        case .none: "无纹样"
        }
    }
}

struct StampStyle: Codable, Equatable {
    var shape: StampShape = .round
    var colorHex: String = Presets.inks[0].hex
    var text: String = "达成"
    var ornament: StampOrnament = .flowers
    var color: Color { Color(hex: colorHex) }

    /// 改一处，得到一个新样式
    func with(_ change: (inout StampStyle) -> Void) -> StampStyle {
        var copy = self
        change(&copy)
        return copy
    }

    /// 印文最多几个字
    static let maxChars = 8
    static let texts = ["达成", "已实现", "圆梦", "言出必行", "不负此生", "得偿所愿"]
}

// MARK: - 预设

enum Presets {
    static let papers: [(hex: String, name: String)] = [
        ("#FBE7A1", "便利贴黄"), ("#F7C9CC", "樱花粉"), ("#C4DEF0", "天空蓝"),
        ("#CDE8C1", "薄荷绿"), ("#FBD3A5", "杏子橙"), ("#F4EFE3", "素白")
    ]
    static let pins: [(hex: String, name: String)] = [
        ("#C72B21", "红"), ("#262422", "黑"), ("#D4A72C", "金"),
        ("#2B5CC4", "蓝"), ("#2E8B57", "绿"), ("#EFEDE7", "白")
    ]
    static let inks: [(hex: String, name: String)] = [
        ("#C3271D", "朱红"), ("#9E1B32", "胭脂"), ("#1F4FA3", "藏蓝"),
        ("#2B2B2B", "墨黑"), ("#1F7A4D", "墨绿"), ("#6B3FA0", "紫罗兰")
    ]
    static let doodleColors: [(hex: String, name: String)] = [
        ("#2B2119", "墨黑"), ("#D23B2F", "红"), ("#2F5FBF", "蓝"),
        ("#2F8F4E", "绿"), ("#F2B51E", "黄"), ("#FFFFFF", "白")
    ]
}

// MARK: - 字体

enum Fonts {
    /// 手写体：系统可下载的楷体。没下载好之前会自动退回系统字体
    static let handName = "STKaitiSC-Regular"
    static func hand(_ size: CGFloat) -> Font { .custom(handName, size: size) }
    /// 老相机的数码日期
    static func lcd(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
    /// 打字机
    static func typewriter(_ size: CGFloat) -> Font { .custom("AmericanTypewriter", size: size) }
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .serif) }
}

/// iOS 自带但需要下载的楷体，第一次启动时在后台下载
enum FontLoader {
    static func loadHandwriting() {
        if UIFont(name: Fonts.handName, size: 12) != nil { return }
        let attrs = [kCTFontNameAttribute as String: Fonts.handName] as CFDictionary
        let desc = CTFontDescriptorCreateWithAttributes(attrs)
        CTFontDescriptorMatchFontDescriptorsWithProgressHandler([desc] as CFArray, nil) { _, _ in true }
    }
}

// MARK: - 日期

enum DateText {
    private static let dots: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    private static let long: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    static func short(_ d: Date) -> String { dots.string(from: d) }
    static func full(_ d: Date) -> String { long.string(from: d) }

    static func days(from a: Date, to b: Date = Date()) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }
}

// MARK: - 触感

enum Haptics {
    static func thunk() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func tick() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }

    /// 图钉扎进软木：一下很重的
    static func pin() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1) }

    /// 拔起图钉：轻轻一下
    static func pull() { UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7) }

    /// 盖章：重重压下，再轻轻一弹
    static func stamp() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        }
    }
}

/// 稳定的随机数，让纹理和笔触每次绘制都一样
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
