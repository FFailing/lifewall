import SwiftUI

struct NoteDetailView: View {
    let noteID: UUID

    @EnvironmentObject private var store: WallStore
    @Environment(\.dismiss) private var dismiss

    // 印章样式（记住上次的选择）
    @AppStorage("stamp.shape") private var stampShapeRaw = StampShape.round.rawValue
    @AppStorage("stamp.color") private var stampHex = Presets.inks[0].hex
    @AppStorage("stamp.text2") private var stampText = "达成"
    @AppStorage("stamp.ornament") private var ornamentRaw = StampOrnament.flowers.rawValue
    @State private var showStampTray = false
    @State private var stampTab: StampTab = .shape
    @State private var customText = ""

    // 盖章动画：印迹从半空「啪」地盖下去
    @State private var stamping = false
    @State private var stampDrop = false
    @State private var shakes: CGFloat = 0

    @State private var sharingCard = false

    private var note: Note? { store.notes.first { $0.id == noteID } }

    private var stampStyle: StampStyle {
        StampStyle(shape: StampShape(rawValue: stampShapeRaw) ?? .round, colorHex: stampHex, text: stampText,
                   ornament: StampOrnament(rawValue: ornamentRaw) ?? .flowers)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CorkBackground()
                Color.black.opacity(0.2).ignoresSafeArea()

                if let note {
                    ScrollView {
                        VStack(spacing: 22) {
                            HStack {
                                Text("No.\(note.number)")
                                    .font(.system(size: 15, weight: .bold, design: .serif))
                                Spacer()
                                Button("关闭") { dismiss() }
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundStyle(Color.paperWhite)

                            bigItem(note, width: itemWidth(note, screen: geo.size.width))
                                .padding(.top, 18)

                            facts(for: note)

                            Spacer(minLength: 8)

                            actions(note)
                        }
                        .padding(20)
                        .frame(minHeight: geo.size.height)
                    }
                }
            }
        }
        .sheet(isPresented: $sharingCard) {
            if let note {
                ShareImageSheet(title: "纪念卡") {
                    ShareCard.render(note: note)
                }
            }
        }
        .onAppear {
            if !StampStyle.texts.contains(stampText) { customText = stampText }
        }
    }

    private func itemWidth(_ n: Note, screen: CGFloat) -> CGFloat {
        let maxW: CGFloat = n.kind == .photo && n.frame == .polaroid ? 290 : 330
        return min(maxW, min(440, screen) - 56)
    }

    // MARK: 大图

    private func bigItem(_ n: Note, width w: CGFloat) -> some View {
        ItemView(content: n.content(image: PhotoStore.image(n.photoFile)), width: w, stampDrop: stampDrop)
            .modifier(ShakeEffect(shakes: shakes))
            .rotationEffect(.degrees(n.tilt * 0.5))
    }

    // MARK: 操作区

    @ViewBuilder
    private func actions(_ n: Note) -> some View {
        VStack(spacing: 12) {
            if !n.isAchieved {
                if showStampTray { stampTray.transition(.opacity.combined(with: .move(edge: .bottom))) }
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showStampTray.toggle() }
                        Haptics.tick()
                    } label: {
                        StampMark(style: stampStyle, date: Date(), width: 40)
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.paperWhite.opacity(0.92)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.paperWhite, lineWidth: showStampTray ? 2 : 0).padding(-3))
                            .clipped()
                    }
                    .accessibilityLabel("选择印章样式")

                    HoldToConfirm(title: "长按盖章，确认达成",
                                  holdingTitle: "盖章后不可撤销",
                                  duration: 1.5,
                                  fill: stampStyle.color) {
                        stamp(n)
                    }
                }
                .opacity(stamping ? 0 : 1)
                .allowsHitTesting(!stamping)
            }

            shareButton(primary: n.isAchieved)
        }
    }

    private var stampTray: some View {
        VStack(spacing: 14) {
            TabStrip(tabs: [(StampTab.shape, "印形"), (.ornament, "纹样"), (.color, "印色"), (.text, "印文")], selection: $stampTab)
            Group {
                switch stampTab {
                case .shape:
                    HStack(spacing: 8) {
                        ForEach(StampShape.allCases) { s in
                            stampChip(stampStyle.with { $0.shape = s }, selected: stampShapeRaw == s.rawValue, label: s.name) { stampShapeRaw = s.rawValue }
                        }
                    }
                case .ornament:
                    HStack(spacing: 8) {
                        ForEach(StampOrnament.allCases) { o in
                            stampChip(stampStyle.with { $0.ornament = o }, selected: ornamentRaw == o.rawValue, label: o.name) { ornamentRaw = o.rawValue }
                        }
                    }
                case .color:
                    ColorRow(presets: Presets.inks, hex: $stampHex)
                case .text:
                    VStack(spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StampStyle.texts, id: \.self) { t in
                                    ChoiceChip(selected: stampText == t, label: t, shape: .wide) {
                                        stampText = t
                                        customText = ""
                                    } content: {
                                        Text(t).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.paperWhite)
                                    }
                                }
                            }
                            .padding(.horizontal, 6).padding(.vertical, 6)
                        }
                        TextField("", text: $customText, prompt: Text("自定义印文（至多 \(StampStyle.maxChars) 字）").foregroundStyle(Color.paperWhite.opacity(0.55)))
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.paperWhite)
                            .frame(width: 200, height: 38)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.paperWhite.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                            .onChange(of: customText) { _, v in
                                let t = String(v.trimmingCharacters(in: .whitespaces).prefix(StampStyle.maxChars))
                                if t != v { customText = t }
                                stampText = t.isEmpty ? "达成" : t
                            }
                    }
                }
            }
            .frame(minHeight: 44)
        }
    }

    private func stampChip(_ st: StampStyle, selected: Bool, label: String, action: @escaping () -> Void) -> some View {
        ChoiceChip(selected: selected, label: label, shape: .square, action: action) {
            StampMark(style: st, date: Date(), width: 44)
                .frame(width: 52, height: 46)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.paperWhite))
        }
    }

    private func shareButton(primary: Bool) -> some View {
        Button {
            sharingCard = true
        } label: {
            Label("分享纪念卡", systemImage: "square.and.arrow.up")
                .font(.system(size: primary ? 17 : 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: primary ? 56 : 50)
                .foregroundStyle(primary ? Color.ink : Color.paperWhite)
                .background(Capsule().fill(primary ? Color.paperWhite : Color.clear))
                .overlay(Capsule().strokeBorder(Color.paperWhite.opacity(0.8), lineWidth: 1.5))
        }
    }

    // MARK: 盖章

    private func stamp(_ n: Note) {
        stamping = true
        withAnimation(.easeOut(duration: 0.2)) { showStampTray = false }
        // 印迹先出现在半空，再盖下去
        stampDrop = true
        store.markAchieved(n.id, stamp: stampStyle)      // 先存，再演
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.5, 0, 0.6, 1, duration: 0.3)) { stampDrop = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Haptics.stamp()
            withAnimation(.linear(duration: 0.38)) { shakes += 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            stamping = false
            Haptics.success()
        }
    }

    private func facts(for note: Note) -> some View {
        let start = DateText.short(note.createdAt)
        let line: String
        if let done = note.achievedAt {
            line = "\(start) – \(DateText.short(done)) · 历时 \(DateText.days(from: note.createdAt, to: done)) 天"
        } else {
            let since = DateText.days(from: note.createdAt)
            line = since == 0 ? "钉上于 \(start) · 今日" : "钉上于 \(start) · 已历 \(since) 天"
        }
        return Text(line)
            .font(.system(size: 15, design: .serif).monospacedDigit())
            .foregroundStyle(Color.paperWhite.opacity(0.92))
            .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1)
    }
}

enum StampTab: Hashable { case shape, ornament, color, text }
