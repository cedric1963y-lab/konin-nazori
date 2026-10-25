import SwiftUI

struct IntroPager: View {
    let finish: () -> Void
    @State private var page = 0

    private let pages: [(symbol: String, latin: String, title: String, body: String)] = [
        ("doc.plaintext", "Plain Paper", "普通紙の婚姻届に",
         "役所でもらう用紙や、A3の普通紙に印刷した用紙のように、光が透ける薄い紙向けです。厚手やカラーのデザイン婚姻届は透けにくいことがあります。"),
        ("sun.max", "Real Size", "実寸で、明るく表示",
         "入力した内容を、用紙の欄と同じ大きさで白い画面に表示します。なぞる間は画面を最大の明るさにして、自動ロックも止めます。"),
        ("lock", "Touch Lock", "タッチロックで安心",
         "ペン先や手のひらで画面が動かないように、ロックできます。鍵マークを長押しで解除。画面の上に透明なクリアファイルを1枚はさむと、画面を傷つけにくくなります。")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    let item = pages[i]
                    VStack(spacing: 22) {
                        Spacer()
                        ZStack {
                            Circle().stroke(Palette.champagne, lineWidth: 1).frame(width: 150, height: 150)
                            Circle().stroke(Palette.champagne.opacity(0.4), lineWidth: 1).frame(width: 170, height: 170)
                            Image(systemName: item.symbol).font(.system(size: 54, weight: .thin))
                                .foregroundStyle(Palette.ink)
                        }
                        Text(item.latin.uppercased()).font(Typeface.latin(16)).tracking(4)
                            .foregroundStyle(Palette.champagne)
                        Text(item.title).font(Typeface.mincho(26, bold: true)).foregroundStyle(Palette.ink)
                        Text(item.body).font(.system(size: 15)).foregroundStyle(Palette.mist)
                            .multilineTextAlignment(.center).lineSpacing(5)
                            .padding(.horizontal, 30)
                        Spacer()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < pages.count - 1 ? "次へ" : "実寸合わせへ進む") {
                if page < pages.count - 1 { withAnimation { page += 1 } } else { finish() }
            }
            .buttonStyle(WideButtonStyle())
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
        .background(Palette.porcelain.ignoresSafeArea())
    }
}

struct RulerSetupView: View {
    let isFirstRun: Bool
    let done: () -> Void

    @EnvironmentObject var ruler: RealSizeRuler
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowTitle(latin: "Calibration", title: "実寸合わせ")
            Text(ruler.isKnownModel
                 ? "カードを縦向きに重ねて、ふちが合うように調整。この機種は最初から自動で合っています。"
                 : "カードを縦向きに重ねて、ふちがぴったり合うように大きさを調整してください。")
                .font(.system(size: 13)).foregroundStyle(Palette.mist)

            Spacer(minLength: 0)
            HStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: ruler.pt(3.18), style: .continuous)
                        .fill(Color.white)
                    RoundedRectangle(cornerRadius: ruler.pt(3.18), style: .continuous)
                        .stroke(Palette.champagne, lineWidth: 2)
                    VStack {
                        Spacer()
                        Text("ここにカードを\n縦向きに置く").multilineTextAlignment(.center)
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.champagne)
                            .lineSpacing(6)
                        Spacer()
                        Text("54.0 mm × 85.6 mm（実寸）").font(.system(size: 12)).foregroundStyle(Palette.mist)
                            .padding(.bottom, 10)
                    }
                }
                .frame(width: ruler.pt(54.0), height: ruler.pt(85.6))
                Spacer()
            }
            Spacer(minLength: 0)

            HStack {
                Text("大きさ").font(.system(size: 14)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(ruler.modelName)（\(ruler.isKnownModel ? "自動" : "目安")）\(ruler.correctionLabel)")
                    .font(.system(size: 13)).foregroundStyle(Palette.champagne)
            }
            HStack(spacing: 10) {
                Button { nudge(-0.001) } label: { Image(systemName: "minus") }.buttonStyle(PillButtonStyle(filled: false))
                Slider(value: $ruler.correction, in: 0.9...1.1)
                Button { nudge(0.001) } label: { Image(systemName: "plus") }.buttonStyle(PillButtonStyle(filled: false))
            }
            HStack(spacing: 10) {
                Button("自動に戻す") { ruler.correction = 1.0 }
                    .buttonStyle(PillButtonStyle(filled: false))
                Button(saved ? "保存しました" : "この大きさで決定") {
                    saved = true
                    done()
                }
                .buttonStyle(WideButtonStyle())
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 10)
        .background(Palette.porcelain.ignoresSafeArea())
        .onChange(of: ruler.correction) { _, _ in saved = false }
    }

    private func nudge(_ d: Double) {
        ruler.correction = min(1.1, max(0.9, ruler.correction + d))
    }
}
