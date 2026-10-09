import SwiftUI
import UIKit

/// 墙上的一件东西：便签或照片。
/// 内容（文字、样式、照片、涂鸦、日期）全是 let：写下之后，代码层面就无法再改。
/// 只有两样会变：盖章（只能从无到有一次），以及在墙上的位置（可以拔起图钉挪动）。
struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    let number: Int
    let kind: NoteKind
    let text: String
    let createdAt: Date
    let style: NoteStyle
    let frame: PhotoFrame
    let timestamp: TimeStampStyle
    let photoFile: String?
    let doodle: [DoodleStroke]

    private(set) var achievedAt: Date?
    private(set) var stamp: StampStyle?

    /// 位置，单位是「墙宽」：x、y 都是相对于墙宽的比例
    var x: Double
    var y: Double
    var z: Int

    var isAchieved: Bool { achievedAt != nil }

    /// 每张固定的倾斜角度（由 id 决定）
    var tilt: Double { (Double(id.uuid.0) / 255.0 - 0.5) * 7.0 }

    mutating func markAchieved(with stamp: StampStyle, on date: Date = Date()) {
        guard achievedAt == nil else { return }
        achievedAt = date
        self.stamp = stamp
    }

    func content(image: UIImage?) -> ItemContent {
        ItemContent(number: number, kind: kind, text: text, createdAt: createdAt, style: style,
                    frame: frame, timestamp: timestamp, image: image, doodle: doodle,
                    achievedAt: achievedAt, stamp: stamp, tilt: tilt)
    }
}

/// 画一件东西需要的全部信息（墙上的便签和正在写的草稿都用它）
struct ItemContent {
    var number: Int
    var kind: NoteKind
    var text: String
    var createdAt: Date
    var style: NoteStyle
    var frame: PhotoFrame
    var timestamp: TimeStampStyle
    var image: UIImage?
    var doodle: [DoodleStroke]
    var achievedAt: Date?
    var stamp: StampStyle?
    var tilt: Double
}

/// 正在写的那一张
struct NoteDraft {
    var kind: NoteKind = .note
    var text = ""
    var style = NoteStyle()
    var frame: PhotoFrame = .polaroid
    var timestamp: TimeStampStyle = .digital
    var image: UIImage?
    var doodle: [DoodleStroke] = []

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canPin: Bool {
        kind == .photo ? image != nil : (!trimmedText.isEmpty || !doodle.isEmpty)
    }

    func content(number: Int) -> ItemContent {
        ItemContent(number: number, kind: kind, text: text, createdAt: Date(), style: style,
                    frame: frame, timestamp: timestamp, image: image, doodle: doodle,
                    achievedAt: nil, stamp: nil, tilt: -1)
    }
}

// MARK: - 墙的版面

enum WallLayout {
    /// 每件东西的宽度占墙宽的比例
    static let itemWidth: Double = 0.44

    static func aspect(kind: NoteKind, frame: PhotoFrame) -> Double {
        guard kind == .photo else { return 1 }
        switch frame {
        case .polaroid: return 1.2
        case .print: return 0.8
        case .film: return 0.74
        }
    }

    static func rect(_ n: Note) -> CGRect {
        CGRect(x: n.x, y: n.y, width: itemWidth, height: itemWidth * aspect(kind: n.kind, frame: n.frame))
    }

    /// 新便签：从上往下找第一个空位
    static func place(kind: NoteKind, frame: PhotoFrame, id: UUID, among notes: [Note]) -> CGPoint {
        let h = itemWidth * aspect(kind: kind, frame: frame)
        var rng = SeededRandom(seed: UInt64(id.uuid.2) << 8 | UInt64(id.uuid.3))
        for row in 0..<300 {
            for col in [0.03, 0.53] {
                let x = col + Double.random(in: -0.015...0.015, using: &rng)
                let y = 0.07 + Double(row) * 0.62 + Double.random(in: -0.015...0.015, using: &rng)
                let box = CGRect(x: max(0, x), y: y, width: itemWidth, height: h).insetBy(dx: 0.01, dy: 0.01)
                if !notes.contains(where: { rect($0).insetBy(dx: 0.01, dy: 0.01).intersects(box) }) {
                    return CGPoint(x: max(0.0, x), y: y)
                }
            }
        }
        return CGPoint(x: 0.03, y: 0.07)
    }

    static func wallHeight(_ notes: [Note]) -> Double {
        (notes.map { Double(rect($0).maxY) }.max() ?? 0.4) + 0.12
    }
}

// MARK: - 照片文件

enum PhotoStore {
    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private static let cache = NSCache<NSString, UIImage>()

    static func save(_ image: UIImage) -> String? {
        let name = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: dir.appendingPathComponent(name), options: [.atomic])
            cache.setObject(image, forKey: name as NSString)
            return name
        } catch {
            return nil
        }
    }

    static func image(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if let hit = cache.object(forKey: name as NSString) { return hit }
        guard let img = UIImage(contentsOfFile: dir.appendingPathComponent(name).path) else { return nil }
        cache.setObject(img, forKey: name as NSString)
        return img
    }

    /// 导入时缩到长边 1600，省空间
    static func downscale(_ image: UIImage, maxSide: CGFloat = 1600) -> UIImage {
        let s = image.size
        let k = min(1, maxSide / max(s.width, s.height))
        guard k < 1 else { return image }
        let size = CGSize(width: s.width * k, height: s.height * k)
        return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

// MARK: - 存储

/// 只追加：新增、盖章、挪位置。没有修改内容，没有删除。
@MainActor
final class WallStore: ObservableObject {
    nonisolated static let maxLength = 40
    /// 一生只有 100 张
    nonisolated static let lifetimeLimit = 100

    @Published private(set) var notes: [Note] = []

    private let fileURL: URL

    var remaining: Int { max(0, Self.lifetimeLimit - notes.count) }
    var achievedCount: Int { notes.filter(\.isAchieved).count }

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("wall.json")
        load()
    }

    @discardableResult
    func pin(_ draft: NoteDraft) -> Note? {
        guard remaining > 0, draft.canPin else { return nil }
        let id = UUID()
        var photoFile: String?
        if draft.kind == .photo, let img = draft.image {
            photoFile = PhotoStore.save(img)
            guard photoFile != nil else { return nil }
        }
        let spot = WallLayout.place(kind: draft.kind, frame: draft.frame, id: id, among: notes)
        let note = Note(id: id,
                        number: notes.count + 1,
                        kind: draft.kind,
                        text: String(draft.trimmedText.prefix(Self.maxLength)),
                        createdAt: Date(),
                        style: draft.style,
                        frame: draft.frame,
                        timestamp: draft.timestamp,
                        photoFile: photoFile,
                        doodle: draft.doodle,
                        achievedAt: nil,
                        stamp: nil,
                        x: spot.x, y: spot.y,
                        z: (notes.map(\.z).max() ?? 0) + 1)
        notes.append(note)
        persist()
        return note
    }

    func markAchieved(_ id: UUID, stamp: StampStyle) {
        guard let i = notes.firstIndex(where: { $0.id == id }), !notes[i].isAchieved else { return }
        notes[i].markAchieved(with: stamp)
        persist()
    }

    /// 拔起图钉换个位置，并放到最上层
    func move(_ id: UUID, to point: CGPoint) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].x = min(1 - WallLayout.itemWidth, max(-0.02, Double(point.x)))
        notes[i].y = max(0.03, Double(point.y))
        notes[i].z = (notes.map(\.z).max() ?? 0) + 1
        persist()
    }

    // MARK: 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let saved = try? decoder.decode([Note].self, from: data) {
            notes = saved
        } else {
            // 文件读不了：先备份，绝不覆盖已经写下的内容
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("wall-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(notes) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

// MARK: - 格言

struct Quote: Equatable {
    let text: String
    let source: String
}

enum Quotes {
    static let all: [Quote] = {
        guard let url = Bundle.main.url(forResource: "quotes", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return [Quote(text: "落于纸上者，方为承诺。", source: "此生清单")]
        }
        return raw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard let t = parts.first, !t.isEmpty else { return nil }
            return Quote(text: t, source: parts.count > 1 ? parts[1] : "此生清单")
        }
    }()

    static func random(excluding old: Quote? = nil) -> Quote {
        var q = all.randomElement() ?? Quote(text: "落于纸上者，方为承诺。", source: "此生清单")
        if all.count > 1, q == old { q = all.randomElement() ?? q }
        return q
    }
}
