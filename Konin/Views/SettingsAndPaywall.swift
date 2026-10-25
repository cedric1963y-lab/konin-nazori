import SwiftUI

enum Links {
    static let privacy = URL(string: "https://cedric1963y-lab.github.io/konin-nazori/privacy.html")!
    static let support = URL(string: "https://cedric1963y-lab.github.io/konin-nazori/")!
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

struct PaywallView: View {
    @EnvironmentObject var unlock: UnlockStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("ALL FIELDS").font(Typeface.latin(17)).tracking(5).foregroundStyle(Palette.champagne)
                    .padding(.top, 26)
                Text("婚姻届を最後まで\nなぞって仕上げる").font(Typeface.mincho(26, bold: true))
                    .multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 12) {
                    benefit("夫・妻の13欄すべてをなぞれる")
                    benefit("証人の生年月日・住所・本籍（証人ご本人用）")
                    benefit("署名の練習（枠と中心線だけ）")
                    benefit("届出前チェックリスト")
                    benefit("写真ぼかし（SNSに載せる前に）")
                }
                .softCard()
                Text("買い切り・一度の購入でずっと使えます。広告なし。入力した内容は端末の中だけに保存され、外部には送信しません。")
                    .font(.system(size: 13)).foregroundStyle(Palette.mist).multilineTextAlignment(.center)

                if unlock.unlocked {
                    Label("購入済みです", systemImage: "checkmark.seal.fill").foregroundStyle(Palette.champagne)
                } else {
                    Button {
                        Task { await unlock.buy() }
                    } label: {
                        if unlock.working { ProgressView().tint(.white) } else { Text("\(unlock.priceText)で購入（買い切り）") }
                    }
                    .buttonStyle(WideButtonStyle())
                    .disabled(unlock.working)
                    Button("購入を復元") { Task { await unlock.restore() } }
                        .font(.system(size: 14)).foregroundStyle(Palette.ink)
                }
                if let n = unlock.notice {
                    Text(n).font(.system(size: 13)).foregroundStyle(Palette.champagne).multilineTextAlignment(.center)
                }
                HStack(spacing: 18) {
                    Link("利用規約（EULA）", destination: Links.terms)
                    Link("プライバシーポリシー", destination: Links.privacy)
                }
                .font(.system(size: 12)).foregroundStyle(Palette.mist)
                Button("閉じる") { dismiss() }.font(.system(size: 14)).foregroundStyle(Palette.mist)
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
        .background(Palette.porcelain.ignoresSafeArea())
        .onChange(of: unlock.unlocked) { _, now in if now { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { dismiss() } } }
    }

    private func benefit(_ s: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark").foregroundStyle(Palette.champagne)
            Text(s).font(.system(size: 15)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var book: EntryBook
    @EnvironmentObject var unlock: UnlockStore
    @AppStorage("didFinishIntro") private var didFinishIntro = true
    @State private var paywall = false
    @State private var confirmErase = false

    var body: some View {
        Form {
            Section("全機能（買い切り）") {
                if unlock.unlocked {
                    Label("購入済み", systemImage: "checkmark.seal.fill").foregroundStyle(Palette.champagne)
                } else {
                    Button("すべての欄を使う（\(unlock.priceText)）") { paywall = true }
                }
                Button("購入を復元") { Task { await unlock.restore() } }
                if let n = unlock.notice { Text(n).font(.system(size: 13)).foregroundStyle(Palette.mist) }
            }
            Section {
                Toggle("氏名のフリガナ欄を表示", isOn: $book.showKanaRow)
            } header: { Text("用紙の様式") } footer: {
                Text("2025年5月以降の新しい様式には振り仮名の欄があります。古い様式の用紙を使う場合はオフにしてください。")
            }
            Section("使い方") {
                Button("はじめの説明をもう一度見る") { didFinishIntro = false }
                Text("厚手やカラーのデザイン婚姻届は透けにくいことがあります。普通紙の用紙向けです。画面の上に透明なクリアファイルを1枚はさむと、画面を傷つけにくくなります。")
                    .font(.system(size: 13)).foregroundStyle(Palette.mist)
            }
            Section {
                Text("広告なし・外部への送信なし。入力した内容はこの端末の中だけに保存されます。")
                    .font(.system(size: 13)).foregroundStyle(Palette.mist)
                Link("プライバシーポリシー", destination: Links.privacy)
                Link("サポート・お問い合わせ", destination: Links.support)
                Link("利用規約（EULA）", destination: Links.terms)
                NavigationLink("フォントのライセンス") { LicenseView() }
            } header: { Text("プライバシー") }
            Section {
                Button("入力した内容をすべて消す", role: .destructive) { confirmErase = true }
            }
            Section {
                Text("バージョン \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.system(size: 13)).foregroundStyle(Palette.mist)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.porcelain.ignoresSafeArea())
        .navigationTitle("設定")
        .sheet(isPresented: $paywall) { PaywallView() }
        .confirmationDialog("入力した内容をすべて消しますか？", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("すべて消す", role: .destructive) { book.eraseAll() }
        }
    }
}

struct LicenseView: View {
    private var text: String {
        ["OFL-ShipporiMincho", "OFL-CormorantGaramond"].compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        }.joined(separator: "\n\n――――――――\n\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("このアプリでは、SIL Open Font License 1.1 のフォント「Shippori Mincho（しっぽり明朝）」と「Cormorant Garamond」を使っています。")
                    .font(.system(size: 13))
                Text(text).font(.system(size: 11, design: .monospaced))
            }
            .padding()
        }
        .navigationTitle("フォントのライセンス")
    }
}
