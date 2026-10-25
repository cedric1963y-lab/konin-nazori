import SwiftUI

struct SlotEditorView: View {
    let party: Party
    let slot: Slot
    let onTrace: () -> Void

    @EnvironmentObject var book: EntryBook
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                inputs
                checks
                Section {
                    Button("この欄をなぞる") { onTrace() }
                        .buttonStyle(WideButtonStyle())
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.porcelain)
            .navigationTitle("\(slot.title)（\(party.label)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } }
            }
        }
    }

    private var p: Binding<Person> { book.binding(party) }
    private var shared: Binding<Shared> { book.sharedBinding }

    private var birthdayBinding: Binding<Date> {
        Binding(get: { p.wrappedValue.birthday ?? defaultBirthday }, set: { p.wrappedValue.birthday = $0 })
    }
    private var defaultBirthday: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 1995, month: 1, day: 1)) ?? Date()
    }
    private var livingBinding: Binding<Date> {
        Binding(get: { shared.wrappedValue.livingTogether ?? Date() }, set: { shared.wrappedValue.livingTogether = $0 })
    }

    @ViewBuilder
    private var inputs: some View {
        switch slot {
        case .fullName:
            Section("氏名") {
                TextField("氏（例：山田）", text: p.family)
                TextField("名（例：太郎）", text: p.given)
            }
            Section("フリガナ") {
                TextField("氏（例：ヤマダ）", text: p.familyKana)
                TextField("名（例：タロウ）", text: p.givenKana)
            }
        case .birthday:
            Section("生年月日（西暦で選ぶ）") {
                DatePicker("生年月日", selection: birthdayBinding, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .environment(\.calendar, Calendar(identifier: .gregorian))
            }
        case .address:
            Section("住所（住民票どおり）") { TextField("例：東京都千代田区千代田1丁目2番3号", text: p.address, axis: .vertical) }
        case .householder:
            Section("世帯主の氏名") {
                TextField("例：山田 太郎", text: p.householder)
                Button("自分の氏名を入れる") { p.wrappedValue.householder = selfName }
            }
        case .honseki:
            Section("本籍（戸籍謄本どおり）") { TextField("例：東京都千代田区千代田一丁目1番地", text: p.honseki, axis: .vertical) }
        case .hittousha:
            Section("筆頭者の氏名") {
                TextField("例：山田 一郎", text: p.hittousha)
                Button("父の氏名を入れる") {
                    p.wrappedValue.hittousha = [p.wrappedValue.fatherFamily, p.wrappedValue.fatherGiven]
                        .filter { !$0.isEmpty }.joined(separator: " ")
                }
                Button("自分の氏名を入れる") { p.wrappedValue.hittousha = selfName }
            }
        case .father:
            Section("父の氏名") {
                TextField("氏", text: p.fatherFamily)
                TextField("名", text: p.fatherGiven)
            }
        case .mother:
            Section("母の氏名") {
                Toggle("父母は今も婚姻中", isOn: p.parentsMarried)
                TextField("氏", text: p.motherFamily).disabled(p.wrappedValue.parentsMarried)
                    .foregroundStyle(p.wrappedValue.parentsMarried ? Palette.mist : Palette.ink)
                TextField("名", text: p.motherGiven)
            }
        case .rank:
            Section("父母との続き柄") {
                Picker("続き柄", selection: p.rank) {
                    Text("選ぶ").tag("")
                    ForEach(party == .wife ? FormWriting.daughterChoices : FormWriting.sonChoices, id: \.self) {
                        Text($0).tag($0)
                    }
                }
            }
        case .newHonseki:
            Section("婚姻後の夫婦の氏") {
                Picker("氏", selection: shared.useHusbandSurname) {
                    Text("夫の氏").tag(true)
                    Text("妻の氏").tag(false)
                }
                .pickerStyle(.segmented)
            }
            Section("新しい本籍（ふたりで共通）") {
                TextField("例：東京都千代田区千代田一丁目1番地", text: shared.newHonseki, axis: .vertical)
                Button("夫の本籍と同じにする") { shared.wrappedValue.newHonseki = book.person(.husband).honseki }
                Button("妻の本籍と同じにする") { shared.wrappedValue.newHonseki = book.person(.wife).honseki }
            }
        case .livingTogether:
            Section("同居を始めたとき（ふたりで共通）") {
                Toggle("まだ同居も結婚式もしていない", isOn: Binding(
                    get: { shared.wrappedValue.livingTogether == nil },
                    set: { shared.wrappedValue.livingTogether = $0 ? nil : Date() }))
                if shared.wrappedValue.livingTogether != nil {
                    DatePicker("年月", selection: livingBinding, displayedComponents: .date)
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                }
            }
        case .phone:
            Section("連絡先（電話）") { TextField("例：090-0000-0000", text: p.phone).keyboardType(.phonePad) }
        case .signature:
            Section {
                Text("署名は、ご本人が自分の字で書く欄です。このアプリでは字のお手本は出さず、大きさと位置の目安になる枠と中心線だけを表示します。白い紙を重ねて練習してください。")
                    .font(.system(size: 14))
            }
        }
    }

    private var selfName: String {
        [p.wrappedValue.family, p.wrappedValue.given].filter { !$0.isEmpty }.joined(separator: " ")
    }

    @ViewBuilder
    private var checks: some View {
        Section {
            switch slot {
            case .fullName:
                tip("戸籍に登録されている字（旧字体など）のとおりに入力してください。")
                tip("2025年5月以降の新しい様式には、氏名の振り仮名欄があります。古い様式なら設定でフリガナ欄を消せます。")
                Toggle("フリガナ欄を表示", isOn: $book.showKanaRow)
                let kana = p.wrappedValue.familyKana + p.wrappedValue.givenKana
                if kana.range(of: "\\p{Hiragana}", options: .regularExpression) != nil {
                    Button("フリガナをカタカナにする") {
                        p.wrappedValue.familyKana = FormWriting.toKatakana(p.wrappedValue.familyKana)
                        p.wrappedValue.givenKana = FormWriting.toKatakana(p.wrappedValue.givenKana)
                    }
                } else if !kana.isEmpty {
                    Button("ふりがなをひらがなにする（用紙が「よみかた」の場合）") {
                        p.wrappedValue.familyKana = FormWriting.toHiragana(p.wrappedValue.familyKana)
                        p.wrappedValue.givenKana = FormWriting.toHiragana(p.wrappedValue.givenKana)
                    }
                }
            case .birthday:
                if let b = p.wrappedValue.birthday {
                    result("用紙には", FormWriting.japaneseEra(b))
                }
                tip("西暦で選ぶと和暦に変換します。「H10」「S63」のような略字は使いません。")
            case .address, .honseki:
                let text = slot == .address ? p.wrappedValue.address : p.wrappedValue.honseki
                hyphenSuggestions(text) { new in
                    if slot == .address { p.wrappedValue.address = new } else { p.wrappedValue.honseki = new }
                }
                tip(slot == .address ? "住民票の書き方どおりか確認してください（「丁目」「番」「号」を省略しない）。"
                                     : "本籍は戸籍謄本（全部事項証明書）の書き方どおりに。漢数字かどうかも合わせます。")
            case .newHonseki:
                hyphenSuggestions(shared.wrappedValue.newHonseki) { shared.wrappedValue.newHonseki = $0 }
                tip("新しい本籍は、日本国内の実在する地番ならどこでも選べます。")
            case .mother:
                tip(p.wrappedValue.parentsMarried
                    ? "父母が婚姻中のときは、母の欄は名だけを書きます（自治体の記載例どおり）。"
                    : "父母が離婚している場合などは、母の氏と名の両方を書きます。")
            case .rank:
                if !p.wrappedValue.rank.isEmpty {
                    result("用紙には", "「\(FormWriting.rankMark(p.wrappedValue.rank))」（\(party == .wife ? "女" : "男")は印刷済み）")
                }
                tip("次男は「二男」、次女は「二女」と書きます。")
            case .livingTogether:
                if let d = shared.wrappedValue.livingTogether {
                    result("用紙には", FormWriting.japaneseEra(d, includeDay: false))
                }
                tip("結婚式を挙げたときか、同居を始めたときの、早いほうを書きます。どちらもまだなら空欄のままでOK。")
            case .householder:
                tip("住民票に書かれている世帯主の氏名を書きます。")
            case .hittousha:
                tip("戸籍謄本のいちばん最初に書かれている人です。")
            case .father:
                tip("亡くなっている場合も氏名を書きます。")
            case .phone:
                tip("書類に不備があったとき、役所から連絡が来る番号です。")
            case .signature:
                tip("届出人の署名と証人の署名は、必ずご本人の字で書きます。")
            }
        } header: {
            Label("書き方チェック", systemImage: "checkmark.seal")
        }
    }

    @ViewBuilder
    private func hyphenSuggestions(_ text: String, apply: @escaping (String) -> Void) -> some View {
        if FormWriting.hasHyphen(text) {
            Text("「-」（ハイフン）は使わずに書きます。書類のとおりの候補を選んでください：")
                .font(.system(size: 13)).foregroundStyle(Palette.mist)
            ForEach(FormWriting.hyphenAlternatives(text), id: \.self) { alt in
                Button(alt) { apply(alt) }.font(.system(size: 14))
            }
        }
    }

    private func tip(_ s: String) -> some View {
        Text(s).font(.system(size: 13)).foregroundStyle(Palette.mist)
    }

    private func result(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Palette.mist)
            Spacer()
            Text(value).font(Typeface.mincho(18, bold: true)).foregroundStyle(Palette.ink)
        }
    }
}
