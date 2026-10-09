import SwiftUI
import PhotosUI

struct ComposeView: View {
    /// 这是第几张
    let number: Int
    /// 写之前还剩几张
    let remaining: Int
    /// 立刻保存。动画还没播完，这一张就已经不可撤回了
    let onPin: (NoteDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    // 上次用的样式，下次接着用
    @AppStorage("style.kind") private var kindRaw = NoteKind.note.rawValue
    @AppStorage("style.paper") private var paperHex = Presets.papers[0].hex
    @AppStorage("style.pattern") private var patternRaw = PaperPattern.plain.rawValue
    @AppStorage("style.shape") private var shapeRaw = PinShape.round.rawValue
    @AppStorage("style.pin") private var pinHex = Presets.pins[0].hex
    @AppStorage("style.frame") private var frameRaw = PhotoFrame.polaroid.rawValue
    @AppStorage("style.timestamp") private var timestampRaw = TimeStampStyle.digital.rawValue

    @State private var text = ""
    @State private var image: UIImage?
    @State private var doodle: [DoodleStroke] = []
    @State private var brush: Brush = .crayon
    @State private var doodleHex = Presets.doodleColors[0].hex
    @State private var pickerItem: PhotosPickerItem?
    @State private var tab: ComposeTab = .paper
    @State private var quote = Quotes.random()

    // 钉上的动画
    @State private var pinState: PinState = .hovering
    @State private var pinning = false
    @State private var pinnedDown = false
    @State private var shakes: CGFloat = 0
    @State private var ripple = false

    private var kind: NoteKind { NoteKind(rawValue: kindRaw) ?? .note }

    private var draft: NoteDraft {
        NoteDraft(kind: kind,
                  text: text,
                  style: NoteStyle(paperHex: paperHex,
                                   pattern: PaperPattern(rawValue: patternRaw) ?? .plain,
                                   pinShape: PinShape(rawValue: shapeRaw) ?? .round,
                                   pinHex: pinHex),
                  frame: PhotoFrame(rawValue: frameRaw) ?? .polaroid,
                  timestamp: TimeStampStyle(rawValue: timestampRaw) ?? .digital,
                  image: image,
                  doodle: doodle)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CorkBackground()
                Color.black.opacity(0.2).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        topBar
                        kindToggle.opacity(pinning ? 0 : 1)
                        editor(width: editorWidth(screen: geo.size.width))
                            .padding(.top, 14)

                        if pinnedDown {
                            (Text("第 \(number) 张已钉上。\n剩余 ")
                             + Text("\(remaining - 1)").fontWeight(.black)
                             + Text(" 张。"))
                                .font(.system(size: 18, design: .serif))
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .foregroundStyle(Color.paperWhite)
                                .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1)
                                .transition(.opacity.combined(with: .offset(y: 6)))
                        } else {
                            tray.opacity(pinning ? 0 : 1)
                        }

                        Spacer(minLength: 8)

                        VStack(spacing: 12) {
                            quoteView
                            HoldToConfirm(title: "长按 3 秒以钉上",
                                          holdingTitle: "确认中…  剩余 \(remaining) → \(remaining - 1)",
                                          duration: 3) {
                                pin()
                            }
                            .disabled(!draft.canPin || remaining <= 0)
                        }
                        .opacity(pinning ? 0 : 1)
                        .allowsHitTesting(!pinning)
                    }
                    .padding(20)
                    .frame(minHeight: geo.size.height)
                    .animation(.easeOut(duration: 0.25), value: pinning)
                }
                .scrollDisabled(tab == .doodle)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .interactiveDismissDisabled(draft.canPin || pinning)
        .onAppear { tab = kind == .photo ? .frame : .paper }
        .onChange(of: text) { _, new in
            if new.count > WallStore.maxLength { text = String(new.prefix(WallStore.maxLength)) }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    image = PhotoStore.downscale(img)
                }
            }
        }
    }

    // MARK: 顶部

    private var topBar: some View {
        HStack {
            Button("取消") { dismiss() }
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Text("第 \(number) / 100 张")
                .font(.system(size: 15, weight: .bold, design: .serif).monospacedDigit())
        }
        .foregroundStyle(Color.paperWhite)
        .opacity(pinning ? 0 : 1)
    }

    private var kindToggle: some View {
        HStack(spacing: 4) {
            ForEach([NoteKind.note, NoteKind.photo], id: \.self) { k in
                Button {
                    kindRaw = k.rawValue
                    tab = k == .photo ? .frame : .paper
                    Haptics.tick()
                } label: {
                    Text(k == .note ? "便签" : "照片")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18).padding(.vertical, 6)
                        .foregroundStyle(kind == k ? Color.ink : Color.paperWhite.opacity(0.75))
                        .background(Capsule().fill(kind == k ? Color.paperWhite : .clear))
                }
                .accessibilityAddTraits(kind == k ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.ink.opacity(0.35)))
    }

    private func editorWidth(screen: CGFloat) -> CGFloat {
        let maxW: CGFloat = kind == .photo && draft.frame == .polaroid ? 290 : 320
        return min(maxW, min(440, screen) - 40)
    }

    // MARK: 便签本身

    private func editor(width w: CGFloat) -> some View {
        let d = draft
        let g = ItemGeometry(kind: d.kind, frame: d.frame, width: w)
        return ZStack {
            ItemView(content: d.content(number: number), width: w, text: $text,
                     pinState: pinState, showDoodle: false) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("选择照片", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.paperWhite)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Color.ink.opacity(0.78)))
                }
            }
            .disabled(pinning || tab == .doodle)

            DoodleCanvasView(strokes: $doodle, brush: brush, colorHex: doodleHex, enabled: tab == .doodle && !pinning)
                .frame(width: g.w, height: g.h)

            // 扎进去时的一圈冲击波
            Circle()
                .strokeBorder(Color.white.opacity(0.75), lineWidth: 2)
                .frame(width: 70, height: 70)
                .scaleEffect(ripple ? 2.4 : 0.2)
                .opacity(ripple ? 0 : (pinnedDown ? 0.9 : 0))
                .position(x: g.w / 2, y: 0)
                .allowsHitTesting(false)
        }
        .frame(width: g.w, height: g.h)
        .modifier(ShakeEffect(shakes: shakes))
        .rotationEffect(.degrees(-1))
        .animation(.easeOut(duration: 0.2), value: d.style)
    }

    // MARK: 样式托盘

    private var tray: some View {
        VStack(spacing: 14) {
            TabStrip(tabs: ComposeTab.tabs(for: kind).map { ($0, $0.rawValue) }, selection: $tab)
            Group {
                switch tab {
                case .paper:
                    ColorRow(presets: Presets.papers, hex: $paperHex)
                case .pattern:
                    HStack(spacing: 12) {
                        ForEach(PaperPattern.allCases) { p in
                            ChoiceChip(selected: patternRaw == p.rawValue, label: p.name, shape: .square) {
                                patternRaw = p.rawValue
                            } content: {
                                NotePaper(style: NoteStyle(paperHex: paperHex, pattern: p))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                case .frame:
                    HStack(spacing: 12) {
                        ForEach(PhotoFrame.allCases) { f in
                            ChoiceChip(selected: frameRaw == f.rawValue, label: f.name, shape: .wide) {
                                frameRaw = f.rawValue
                            } content: {
                                FrameIcon(frame: f)
                            }
                        }
                        if image != nil {
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Text("更换照片").font(.system(size: 13, weight: .medium)).underline()
                                    .foregroundStyle(Color.paperWhite.opacity(0.85))
                            }
                        }
                    }
                case .timestamp:
                    HStack(spacing: 10) {
                        ForEach(TimeStampStyle.allCases) { t in
                            ChoiceChip(selected: timestampRaw == t.rawValue, label: t.name, shape: .wide) {
                                timestampRaw = t.rawValue
                            } content: {
                                timestampSample(t)
                            }
                        }
                    }
                case .doodle:
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            ForEach(Brush.allCases) { b in
                                ChoiceChip(selected: brush == b, label: b.name, shape: .wide) {
                                    brush = b
                                } content: {
                                    Text(b.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.paperWhite)
                                }
                            }
                            TrayTextButton(title: "撤销") { if !doodle.isEmpty { doodle.removeLast() } }
                            TrayTextButton(title: "清空") { doodle.removeAll() }
                        }
                        ColorRow(presets: Presets.doodleColors, hex: $doodleHex)
                    }
                case .shape:
                    HStack(spacing: 12) {
                        ForEach(PinShape.allCases) { s in
                            ChoiceChip(selected: shapeRaw == s.rawValue, label: s.name) {
                                shapeRaw = s.rawValue
                            } content: {
                                ZStack {
                                    Circle().fill(Color.paperWhite.opacity(0.12))
                                    PushPin(shape: s, color: Color(hex: pinHex), size: 28)
                                }
                            }
                        }
                    }
                case .pin:
                    ColorRow(presets: Presets.pins, hex: $pinHex)
                }
            }
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private func timestampSample(_ t: TimeStampStyle) -> some View {
        switch t {
        case .digital: Text("'26 10 09").font(Fonts.lcd(11)).foregroundStyle(Color.lcdOrange)
        case .hand: Text("2026.10.9").font(Fonts.hand(14)).foregroundStyle(Color.paperWhite)
        case .typewriter: Text("OCT 09").font(Fonts.typewriter(11)).foregroundStyle(Color.paperWhite)
        case .none: Text("无").font(.system(size: 12)).foregroundStyle(Color.paperWhite)
        }
    }

    // MARK: 格言

    private var quoteView: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { quote = Quotes.random(excluding: quote) }
        } label: {
            VStack(spacing: 3) {
                Text(quote.text)
                    .font(.system(size: 14, design: .serif))
                    .lineSpacing(4)
                Text("—— \(quote.source)")
                    .font(.system(size: 12, design: .serif))
                    .opacity(0.7)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.paperWhite)
            .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityHint("轻点以更换格言")
    }

    // MARK: 钉上

    private func pin() {
        guard !pinning, draft.canPin else { return }
        onPin(draft)              // 先存，再演
        pinning = true
        hideKeyboard()

        // 图钉先往上一提，再狠狠扎下去
        withAnimation(.easeOut(duration: 0.2)) { pinState = .windUp }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.timingCurve(0.7, 0, 1, 0.6, duration: 0.3)) { pinState = .seated }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Haptics.pin()
            withAnimation(.linear(duration: 0.38)) { shakes += 1 }
            withAnimation(.easeOut(duration: 0.5)) { ripple = true }
            withAnimation(.easeOut(duration: 0.4)) { pinnedDown = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            dismiss()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - 标签页

enum ComposeTab: String, CaseIterable {
    case paper = "纸色", pattern = "纸纹", frame = "相框", timestamp = "时间戳"
    case doodle = "涂鸦", shape = "钉帽", pin = "钉色"

    static func tabs(for kind: NoteKind) -> [ComposeTab] {
        kind == .photo ? [.frame, .timestamp, .doodle, .shape, .pin] : [.paper, .pattern, .doodle, .shape, .pin]
    }
}

/// 相框选项上的小图标
struct FrameIcon: View {
    let frame: PhotoFrame

    var body: some View {
        let sky = Color(red: 0.56, green: 0.65, blue: 0.72)
        switch frame {
        case .polaroid:
            VStack(spacing: 0) {
                sky.frame(width: 18, height: 18).padding([.top, .horizontal], 2)
                Spacer(minLength: 0)
            }
            .frame(width: 22, height: 27)
            .background(Color(red: 0.98, green: 0.98, blue: 0.96))
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        case .print:
            sky.padding(2)
                .frame(width: 30, height: 24)
                .background(Color.white)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        case .film:
            sky.frame(width: 28, height: 12)
                .frame(width: 32, height: 24)
                .background(Color(red: 0.09, green: 0.08, blue: 0.07))
                .overlay(alignment: .top) {
                    HStack(spacing: 2) { ForEach(0..<8, id: \.self) { _ in Rectangle().fill(Color(red: 0.85, green: 0.81, blue: 0.74)).frame(width: 2, height: 2) } }
                        .padding(.top, 2)
                }
                .overlay(alignment: .bottom) {
                    HStack(spacing: 2) { ForEach(0..<8, id: \.self) { _ in Rectangle().fill(Color(red: 0.85, green: 0.81, blue: 0.74)).frame(width: 2, height: 2) } }
                        .padding(.bottom, 2)
                }
        }
    }
}
