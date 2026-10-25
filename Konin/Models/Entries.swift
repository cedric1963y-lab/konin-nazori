import Foundation
import SwiftUI

enum Party: String, Codable, CaseIterable, Identifiable {
    case husband, wife, witness1, witness2
    var id: String { rawValue }
    var label: String {
        switch self {
        case .husband: return "夫になる人"
        case .wife: return "妻になる人"
        case .witness1: return "証人1"
        case .witness2: return "証人2"
        }
    }
    var isSpouse: Bool { self == .husband || self == .wife }
}

/// The 13 sections traced for each spouse, plus the 4 used for witnesses.
enum Slot: String, Codable, CaseIterable, Identifiable {
    case fullName, birthday, address, householder, honseki, hittousha
    case father, mother, rank, newHonseki, livingTogether, phone, signature
    var id: String { rawValue }

    static let spouseOrder: [Slot] = [.fullName, .birthday, .address, .householder, .honseki, .hittousha,
                                      .father, .mother, .rank, .newHonseki, .livingTogether, .phone, .signature]
    static let witnessOrder: [Slot] = [.signature, .birthday, .address, .honseki]

    var title: String {
        switch self {
        case .fullName: return "氏名・フリガナ"
        case .birthday: return "生年月日"
        case .address: return "住所"
        case .householder: return "世帯主の氏名"
        case .honseki: return "本籍"
        case .hittousha: return "筆頭者の氏名"
        case .father: return "父の氏名"
        case .mother: return "母の氏名"
        case .rank: return "続き柄"
        case .newHonseki: return "婚姻後の新しい本籍"
        case .livingTogether: return "同居を始めたとき"
        case .phone: return "連絡先（電話）"
        case .signature: return "署名"
        }
    }

    var hint: String {
        switch self {
        case .fullName: return "戸籍どおりの字で入力"
        case .birthday: return "西暦で入れると和暦に変換"
        case .address: return "番地・号まで省略せずに"
        case .householder: return "住民票の世帯主"
        case .honseki: return "戸籍謄本どおりに入力"
        case .hittousha: return "戸籍の最初に書かれている人"
        case .father: return "父の氏名"
        case .mother: return "父母が婚姻中なら名だけ"
        case .rank: return "「二男」→「二」に自動チェック"
        case .newHonseki: return "ふたりで1つ・両方のタブで共通"
        case .livingTogether: return "式か同居の早いほう"
        case .phone: return "日中つながる番号"
        case .signature: return "ご本人の字で。目安の枠だけ表示"
        }
    }

    /// Sections whose value is shared by both spouses (written once on the form).
    var isShared: Bool { self == .newHonseki || self == .livingTogether }
}

struct Person: Codable, Equatable {
    var family = ""
    var given = ""
    var familyKana = ""
    var givenKana = ""
    var birthday: Date?
    var address = ""
    var householder = ""
    var honseki = ""
    var hittousha = ""
    var fatherFamily = ""
    var fatherGiven = ""
    var motherFamily = ""
    var motherGiven = ""
    var parentsMarried = true
    var rank = ""
    var phone = ""
}

struct Shared: Codable, Equatable {
    var newHonseki = ""
    var useHusbandSurname = true
    var livingTogether: Date?
}

struct Tweak: Codable, Equatable {
    var sizePercent: Double = 100
    var widthPercent: Double = 100
    var offsetX: Double = 0   // mm
    var offsetY: Double = 0   // mm
    var heavy = false
}

struct BookData: Codable {
    var people: [String: Person] = [:]
    var shared = Shared()
    var tweaks: [String: Tweak] = [:]
    var done: Set<String> = []
    var checked: Set<String> = []
    var trialParty: Party?
}

@MainActor
final class EntryBook: ObservableObject {
    @Published var data: BookData { didSet { persist() } }
    @Published var showKanaRow: Bool = UserDefaults.standard.object(forKey: "showKanaRow") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showKanaRow, forKey: "showKanaRow") }
    }

    private static let key = "konin.book.v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(BookData.self, from: raw) {
            data = decoded
        } else {
            data = BookData()
        }
    }

    private func persist() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: Self.key)
        }
    }

    func person(_ p: Party) -> Person { data.people[p.rawValue] ?? Person() }
    func binding(_ p: Party) -> Binding<Person> {
        Binding(get: { self.person(p) }, set: { self.data.people[p.rawValue] = $0 })
    }
    var sharedBinding: Binding<Shared> {
        Binding(get: { self.data.shared }, set: { self.data.shared = $0 })
    }

    func key(_ party: Party, _ slot: Slot) -> String {
        slot.isShared ? "shared.\(slot.rawValue)" : "\(party.rawValue).\(slot.rawValue)"
    }
    func isDone(_ party: Party, _ slot: Slot) -> Bool { data.done.contains(key(party, slot)) }
    func toggleDone(_ party: Party, _ slot: Slot) {
        let k = key(party, slot)
        if data.done.contains(k) { data.done.remove(k) } else { data.done.insert(k) }
    }
    func tweak(_ party: Party, _ slot: Slot) -> Tweak { data.tweaks[key(party, slot)] ?? Tweak() }
    func setTweak(_ t: Tweak, _ party: Party, _ slot: Slot) { data.tweaks[key(party, slot)] = t }

    func eraseAll() {
        data = BookData()
    }

    func fillSample() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d))!
        }
        var h = Person()
        h.family = "山田"; h.given = "太郎"; h.familyKana = "ヤマダ"; h.givenKana = "タロウ"
        h.birthday = day(1998, 4, 1)
        h.address = "東京都千代田区千代田1丁目2番3号"
        h.householder = "山田 太郎"
        h.honseki = "東京都千代田区千代田一丁目1番地"
        h.hittousha = "山田 一郎"
        h.fatherFamily = "山田"; h.fatherGiven = "一郎"; h.motherFamily = "山田"; h.motherGiven = "和子"
        h.rank = "長男"; h.phone = "090-0000-0000"
        var w = Person()
        w.family = "山田"; w.given = "花子"; w.familyKana = "ヤマダ"; w.givenKana = "ハナコ"
        w.birthday = day(1999, 11, 22)
        w.address = "東京都千代田区千代田4丁目5番6号"
        w.householder = "山田 花子"
        w.honseki = "神奈川県横浜市中区本町二丁目3番地"
        w.hittousha = "山田 次郎"
        w.fatherFamily = "山田"; w.fatherGiven = "次郎"; w.motherFamily = "山田"; w.motherGiven = "幸子"
        w.rank = "二女"; w.phone = "080-0000-0000"
        var d = BookData()
        d.people = [Party.husband.rawValue: h, Party.wife.rawValue: w]
        d.shared = Shared(newHonseki: "東京都千代田区千代田一丁目1番地", useHusbandSurname: true,
                          livingTogether: day(2026, 10, 1))
        d.done = ["husband.fullName", "husband.birthday", "husband.address",
                  "husband.householder", "husband.honseki", "husband.hittousha"]
        d.checked = ["id", "witness"]
        if LaunchDemo.has("-hyphen") {
            d.people[Party.husband.rawValue]?.address = "東京都千代田区千代田1-2-3"
        }
        data = d
    }
}
