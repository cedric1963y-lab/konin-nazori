import Foundation

/// Writing helpers for the marriage registration form.
enum FormWriting {
    private static var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private static let eras: [(name: String, y: Int, m: Int, d: Int)] = [
        ("令和", 2019, 5, 1), ("平成", 1989, 1, 8), ("昭和", 1926, 12, 25),
        ("大正", 1912, 7, 30), ("明治", 1868, 1, 25)
    ]

    /// 1998-04-01 -> 平成10年4月1日 (no abbreviations such as H10)
    static func japaneseEra(_ date: Date, includeDay: Bool = true) -> String {
        let c = tokyo.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 2000, m = c.month ?? 1, d = c.day ?? 1
        let stamp = y * 10000 + m * 100 + d
        for e in eras where stamp >= e.y * 10000 + e.m * 100 + e.d {
            let n = y - e.y + 1
            let yearText = n == 1 ? "元" : String(n)
            return includeDay ? "\(e.name)\(yearText)年\(m)月\(d)日" : "\(e.name)\(yearText)年\(m)月"
        }
        return includeDay ? "\(y)年\(m)月\(d)日" : "\(y)年\(m)月"
    }

    static func western(_ date: Date) -> String {
        let c = tokyo.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)年\(c.month ?? 0)月\(c.day ?? 0)日"
    }

    // MARK: 続き柄
    static let sonChoices = ["長男", "二男", "三男", "四男", "五男", "六男"]
    static let daughterChoices = ["長女", "二女", "三女", "四女", "五女", "六女"]

    /// 長男 -> 長, 次男/二男 -> 二. The 男/女 part is printed on the form.
    static func rankMark(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard let first = t.first else { return "" }
        if first == "次" { return "二" }
        return String(first)
    }

    // MARK: Kana
    static func toKatakana(_ s: String) -> String { s.applyingTransform(.hiraganaToKatakana, reverse: false) ?? s }
    static func toHiragana(_ s: String) -> String { s.applyingTransform(.hiraganaToKatakana, reverse: true) ?? s }

    // MARK: 住所・本籍 hyphen suggestions
    static func kanjiNumber(_ n: Int) -> String {
        let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        if n == 0 { return "〇" }
        var out = ""
        var rest = n
        for (unit, mark) in [(1000, "千"), (100, "百"), (10, "十")] {
            let q = rest / unit
            if q > 0 { out += (q == 1 ? "" : digits[q]) + mark }
            rest %= unit
        }
        return out + digits[rest]
    }

    private static func halfWidthDigits(_ s: String) -> String {
        s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s
    }

    /// Finds "1-2-3" style numbers and proposes hyphen-free ways of writing them.
    static func hyphenAlternatives(_ text: String) -> [String] {
        let pattern = "([0-9０-９]+)(?:[-−－ー‐―]([0-9０-９]+))(?:[-−－ー‐―]([0-9０-９]+))?"
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let whole = Range(m.range, in: text) else { return [] }
        let head = String(text[..<whole.lowerBound])
        let tail = String(text[whole.upperBound...])
        var nums: [Int] = []
        for i in 1...3 {
            if let r = Range(m.range(at: i), in: text), let v = Int(halfWidthDigits(String(text[r]))) { nums.append(v) }
        }
        let k = nums.map(kanjiNumber)
        var list: [String] = []
        if nums.count == 3 {
            list = ["\(nums[0])丁目\(nums[1])番\(nums[2])号",
                    "\(nums[0])丁目\(nums[1])番地\(nums[2])",
                    "\(k[0])丁目\(nums[1])番\(nums[2])号",
                    "\(k[0])丁目\(k[1])番地\(k[2])"]
        } else if nums.count == 2 {
            list = ["\(nums[0])番地\(nums[1])",
                    "\(nums[0])番\(nums[1])号",
                    "\(nums[0])丁目\(nums[1])番",
                    "\(k[0])番地\(k[1])"]
        }
        return list.map { head + $0 + tail }
    }

    static func hasHyphen(_ s: String) -> Bool {
        s.range(of: "[0-9０-９][-−－ー‐―][0-9０-９]", options: .regularExpression) != nil
    }
}
