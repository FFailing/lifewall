import SwiftUI

struct WallView: View {
    @EnvironmentObject private var store: WallStore
    @State private var composing = false
    @State private var selected: Note?
    @State private var freshID: UUID?
    @State private var countBump = false
    @State private var sharingWall = false
    @State private var wallWidth: CGFloat = 350

    // 拔钉挪位置
    @State private var dragID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var shakes: [UUID: CGFloat] = [:]
    @AppStorage("hint.moved") private var movedOnce = false
    @State private var showHint = false

    var body: some View {
        ZStack(alignment: .bottom) {
            CorkBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 30) {
                        header
                        GeometryReader { geo in
                            wall(width: geo.size.width)
                        }
                        .frame(height: wallHeightPoints)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 44)
                    .padding(.bottom, 130)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .scrollDisabled(dragID != nil)
                .onChange(of: freshID) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
            }

            if showHint {
                Text("长按便签可拔起图钉，拖动以调整位置")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.paperWhite)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(Color.ink.opacity(0.88)))
                    .padding(.bottom, 92)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }

            writeButton
        }
        .overlay(alignment: .topTrailing) {
            Button {
                sharingWall = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.paperWhite)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.ink.opacity(0.42)))
            }
            .padding(.trailing, 14)
            .padding(.top, 6)
            .opacity(store.notes.isEmpty ? 0 : 1)
            .disabled(store.notes.isEmpty)
            .accessibilityLabel("分享清单墙")
        }
        .sheet(isPresented: $composing, onDismiss: landFreshNote) {
            ComposeView(number: store.notes.count + 1, remaining: store.remaining) { draft in
                // 立刻存下。新便签先藏在墙上，等写字面板收起后再落下来
                if let note = store.pin(draft) { freshID = note.id }
            }
        }
        .sheet(item: $selected) { note in
            NoteDetailView(noteID: note.id)
                .environmentObject(store)
        }
        .sheet(isPresented: $sharingWall) {
            ShareImageSheet(title: "此生清单") {
                WallSnapshot.render(notes: store.notes, remaining: store.remaining)
            }
        }
        .task {
            guard !movedOnce, !store.notes.isEmpty else { return }
            try? await Task.sleep(for: .seconds(1))
            withAnimation { showHint = true }
            try? await Task.sleep(for: .seconds(4))
            withAnimation { showHint = false }
        }
    }

    // MARK: 墙

    private var wallHeightPoints: CGFloat {
        store.notes.isEmpty ? 200 : CGFloat(WallLayout.wallHeight(store.notes)) * wallWidth
    }

    private func wall(width W: CGFloat) -> some View {
        let sorted = store.notes.sorted { $0.z < $1.z }
        return ZStack(alignment: .topLeading) {
            if store.notes.isEmpty {
                Text("尚无便签。\n请审慎落笔。")
                    .font(.system(size: 16, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .foregroundStyle(Color.paperWhite.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
            ForEach(sorted) { n in
                wallItem(n, W: W)
            }
        }
        .frame(width: W, height: wallHeightPoints, alignment: .topLeading)
        .onAppear { wallWidth = W }
        .onChange(of: W) { _, new in wallWidth = new }
    }

    private func wallItem(_ n: Note, W: CGFloat) -> some View {
        let w = CGFloat(WallLayout.itemWidth) * W
        let h = w * CGFloat(WallLayout.aspect(kind: n.kind, frame: n.frame))
        let dragging = dragID == n.id
        let hidden = freshID == n.id
        let off = dragging ? dragOffset : .zero
        return ItemView(content: n.content(image: PhotoStore.image(n.photoFile)), width: w,
                        pinState: dragging ? .pulled : .seated)
            .modifier(ShakeEffect(shakes: shakes[n.id] ?? 0))
            .rotationEffect(.degrees(dragging ? n.tilt * 0.3 : n.tilt))
            .scaleEffect(dragging ? 1.05 : (hidden ? 1.35 : 1))
            .shadow(color: .black.opacity(dragging ? 0.25 : 0), radius: dragging ? 14 : 0, x: 6, y: 16)
            .opacity(hidden ? 0 : 1)
            .offset(y: hidden ? -40 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragging)
            .animation(.spring(response: 0.45, dampingFraction: 0.62), value: hidden)
            .id(n.id)
            .contentShape(Rectangle())
            .onTapGesture { selected = n }
            .gesture(moveGesture(n, W: W))
            .position(x: CGFloat(n.x) * W + w / 2 + off.width,
                      y: CGFloat(n.y) * W + h / 2 + off.height)
            .zIndex(dragging ? 10_000 : Double(n.z))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(n.kind == .photo ? "照片" : "便签") No.\(n.number)：\(n.text)\(n.isAchieved ? "，已达成" : "")")
            .accessibilityAddTraits(.isButton)
    }

    /// 长按拔起图钉，然后拖动，松手重新钉上
    private func moveGesture(_ n: Note, W: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.38)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    if dragID != n.id {
                        dragID = n.id
                        Haptics.pull()
                    }
                    dragOffset = drag?.translation ?? .zero
                default:
                    break
                }
            }
            .onEnded { value in
                guard case .second(true, let drag) = value, dragID == n.id else {
                    dragID = nil
                    dragOffset = .zero
                    return
                }
                let t = drag?.translation ?? .zero
                store.move(n.id, to: CGPoint(x: n.x + Double(t.width / W), y: n.y + Double(t.height / W)))
                dragOffset = .zero
                withAnimation(.timingCurve(0.7, 0, 1, 0.6, duration: 0.3)) { dragID = nil }
                movedOnce = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Haptics.pin()
                    withAnimation(.linear(duration: 0.38)) { shakes[n.id, default: 0] += 1 }
                }
            }
    }

    /// 面板收起后：新便签落到墙上，数字跳一下
    private func landFreshNote() {
        guard freshID != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            freshID = nil
            withAnimation(.easeOut(duration: 0.2)) { countBump = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) { countBump = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { Haptics.thunk() }
        }
    }

    // MARK: 顶部

    /// 顶部只有一件事：还剩几张
    private var header: some View {
        VStack(spacing: 10) {
            Text("\(store.remaining)")
                .font(.system(size: 88, weight: .black, design: .serif).monospacedDigit())
                .contentTransition(.numericText(countsDown: true))
                .scaleEffect(countBump ? 1.18 : 1)
                .animation(.snappy, value: store.remaining)
            Text("少即是多")
                .font(.system(size: 14, design: .serif))
                .tracking(1)
                .opacity(0.8)
        }
        .foregroundStyle(Color.paperWhite)
        .shadow(color: Color.black.opacity(0.45), radius: 3, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("此生清单，剩余 \(store.remaining) 张")
    }

    private var writeButton: some View {
        Button {
            composing = true
        } label: {
            Text(store.remaining > 0 ? "落笔" : "100 张已全部写下")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.paperWhite)
                .padding(.horizontal, 34)
                .frame(height: 54)
                .background(Capsule().fill(Color.ink.opacity(store.remaining > 0 ? 1 : 0.7)))
                .shadow(color: Color.black.opacity(0.35), radius: 10, y: 5)
        }
        .disabled(store.remaining == 0)
        .padding(.bottom, 18)
    }
}
