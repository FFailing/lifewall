import SwiftUI

/// 一排文字标签（纸色 / 花纹 / …）
struct TabStrip<T: Hashable>: View {
    let tabs: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 20) {
            ForEach(tabs.indices, id: \.self) { i in
                let tab = tabs[i]
                Button {
                    selection = tab.0
                    Haptics.tick()
                } label: {
                    Text(tab.1)
                        .font(.system(size: 14, weight: .medium))
                        .tracking(1)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle().frame(height: 2).opacity(selection == tab.0 ? 1 : 0)
                        }
                }
                .foregroundStyle(Color.paperWhite.opacity(selection == tab.0 ? 1 : 0.6))
                .accessibilityAddTraits(selection == tab.0 ? .isSelected : [])
            }
        }
    }
}

/// 一个可选的小块
struct ChoiceChip<Content: View>: View {
    let selected: Bool
    let label: String
    var shape: ChipShape = .circle
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    enum ChipShape { case circle, square, wide }

    var body: some View {
        Button {
            action()
            Haptics.tick()
        } label: {
            content()
                .frame(width: shape == .wide ? nil : 38, height: shape == .wide ? 40 : 38)
                .frame(minWidth: shape == .wide ? 52 : nil)
                .padding(.horizontal, shape == .wide ? 10 : 0)
                .background {
                    if shape == .wide {
                        RoundedRectangle(cornerRadius: 8).fill(Color.paperWhite.opacity(0.14))
                    }
                }
                .shadow(color: .black.opacity(shape == .wide ? 0 : 0.25), radius: 2, y: 2)
                .overlay {
                    Group {
                        switch shape {
                        case .circle: Circle().stroke(Color.paperWhite, lineWidth: 2)
                        case .square: RoundedRectangle(cornerRadius: 6).stroke(Color.paperWhite, lineWidth: 2)
                        case .wide: RoundedRectangle(cornerRadius: 11).stroke(Color.paperWhite, lineWidth: 2)
                        }
                    }
                    .padding(-5)
                    .opacity(selected ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 一排预设颜色，最后一个是系统取色器
struct ColorRow: View {
    let presets: [(hex: String, name: String)]
    @Binding var hex: String

    var body: some View {
        HStack(spacing: 12) {
            ForEach(presets.indices, id: \.self) { i in
                let p = presets[i]
                ChoiceChip(selected: sameHex(p.hex, hex), label: p.name) {
                    hex = p.hex
                } content: {
                    Circle().fill(Color(hex: p.hex))
                }
            }
            let isCustom = !presets.contains { sameHex($0.hex, hex) }
            ColorPicker("自定义颜色",
                        selection: Binding(get: { Color(hex: hex) }, set: { hex = $0.hexString }),
                        supportsOpacity: false)
                .labelsHidden()
                .frame(width: 38, height: 38)
                .overlay {
                    Circle().stroke(Color.paperWhite, lineWidth: 2)
                        .padding(-5)
                        .opacity(isCustom ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("自定义颜色")
        }
    }
}

/// 一行小字按钮（撤销、清空、换一张）
struct TrayTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.paperWhite.opacity(0.85))
            .underline()
            .padding(.horizontal, 4)
    }
}
