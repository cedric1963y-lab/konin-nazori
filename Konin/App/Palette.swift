import SwiftUI

enum Palette {
    static let porcelain = Color(rgb: 0xFBF7F3)
    static let ink = Color(rgb: 0x2E2A3A)
    static let champagne = Color(rgb: 0xC9A86A)
    static let mist = Color(rgb: 0x857E92)
    static let hairline = Color(rgb: 0xECE3D8)
    static let card = Color.white
}

enum Typeface {
    static let minchoRegular = "ShipporiMincho-Regular"
    static let minchoBold = "ShipporiMincho-Bold"
    static let latin = "CormorantGaramond-Light"

    static func mincho(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? minchoBold : minchoRegular, fixedSize: size)
    }
    static func latin(_ size: CGFloat) -> Font { .custom(latin, fixedSize: size) }
}

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

struct PillButtonStyle: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .foregroundStyle(filled ? Color.white : Palette.ink)
            .background(Capsule().fill(filled ? Palette.ink : Color.white))
            .overlay(Capsule().stroke(filled ? Color.clear : Palette.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct WideButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(Capsule().fill(Palette.ink))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct EyebrowTitle: View {
    let latin: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(latin.uppercased())
                .font(Typeface.latin(15)).tracking(4)
                .foregroundStyle(Palette.champagne)
            Text(title)
                .font(Typeface.mincho(28, bold: true))
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func softCard() -> some View {
        self.padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
            .shadow(color: Palette.ink.opacity(0.05), radius: 10, y: 3)
    }
}
