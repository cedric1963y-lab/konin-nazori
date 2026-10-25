import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var book: EntryBook
    @EnvironmentObject var unlock: UnlockStore
    @State private var paywall = false

    private let items: [(id: String, title: String, note: String)] = [
        ("id", "本人確認書類", "運転免許証・マイナンバーカードなど。ふたり分。"),
        ("witness", "証人2人の署名", "18歳以上の2人。署名は証人ご本人の字で。"),
        ("spare", "予備の用紙を1枚", "書き損じたときのために、もう1枚もらっておくと安心。"),
        ("window", "提出先と窓口の時間", "夜間・休日は時間外受付になることがあります。事前に確認を。"),
        ("koseki", "戸籍謄本が要るか確認", "2024年3月から多くの場合は不要になりました。念のため提出先に確認を。"),
        ("pen", "黒のボールペン", "消せるボールペン・鉛筆は使えません。"),
        ("fix", "書き損じの直し方", "二重線で消して、余白に正しく書きます。修正液・修正テープは使いません。"),
        ("surname", "婚姻後の氏と新しい本籍", "ふたりで決めて、記入した内容と合っているか確認。")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                EyebrowTitle(latin: "Checklist", title: "届出前チェックリスト")
                ForEach(items, id: \.id) { item in
                    let on = book.data.checked.contains(item.id)
                    Button {
                        guard unlock.unlocked else { paywall = true; return }
                        if on { book.data.checked.remove(item.id) } else { book.data.checked.insert(item.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22)).foregroundStyle(Palette.champagne)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                                Text(item.note).font(.system(size: 13)).foregroundStyle(Palette.mist)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .softCard()
                    }
                    .buttonStyle(.plain)
                }
                if !unlock.unlocked {
                    Text("チェックを付けるのは、全機能（買い切り）で使えます。")
                        .font(.system(size: 13)).foregroundStyle(Palette.mist)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(Palette.porcelain.ignoresSafeArea())
        .sheet(isPresented: $paywall) { PaywallView() }
    }
}
