import SwiftUI
import UIKit

struct PlanCell {
    var widthMM: Double
    var text: String
    var spread = false
}

struct PlanRow {
    var heightMM: Double
    var cells: [PlanCell]
    var isKana = false
    var wraps = false
}

struct TracePlan {
    var rows: [PlanRow]
    var guideOnly = false
    var isEmpty: Bool { !guideOnly && rows.allSatisfy { $0.cells.allSatisfy { $0.text.isEmpty } } }
}

extension EntryBook {
    /// Free tier: one spouse's name section only. Everything else needs the purchase.
    func mayUse(_ party: Party, _ slot: Slot, unlocked: Bool) -> Bool {
        if unlocked { return true }
        guard party.isSpouse, slot == .fullName else { return false }
        return data.trialParty == nil || data.trialParty == party
    }

    func noteTrial(_ party: Party, _ slot: Slot, unlocked: Bool) {
        if !unlocked, slot == .fullName, party.isSpouse, data.trialParty == nil {
            data.trialParty = party
        }
    }

    func motherLine(_ p: Person) -> String {
        p.parentsMarried ? p.motherGiven : join(p.motherFamily, p.motherGiven)
    }

    private func join(_ a: String, _ b: String) -> String {
        [a, b].filter { !$0.isEmpty }.joined(separator: " ")
    }

    func preview(_ party: Party, _ slot: Slot) -> String? {
        let p = person(party)
        let value: String
        switch slot {
        case .fullName:
            let name = join(p.family, p.given)
            let kana = join(p.familyKana, p.givenKana)
            value = kana.isEmpty ? name : (name.isEmpty ? kana : "\(name) ／ \(kana)")
        case .birthday: value = p.birthday.map { FormWriting.japaneseEra($0) } ?? ""
        case .address: value = p.address
        case .householder: value = p.householder
        case .honseki: value = p.honseki
        case .hittousha: value = p.hittousha
        case .father: value = join(p.fatherFamily, p.fatherGiven)
        case .mother: value = motherLine(p)
        case .rank:
            value = p.rank.isEmpty ? "" : "\(p.rank) → 用紙には「\(FormWriting.rankMark(p.rank))」"
        case .newHonseki: value = data.shared.newHonseki
        case .livingTogether:
            value = data.shared.livingTogether.map { FormWriting.japaneseEra($0, includeDay: false) } ?? ""
        case .phone: value = p.phone
        case .signature: value = ""
        }
        return value.isEmpty ? nil : value
    }

    func plan(_ party: Party, _ slot: Slot) -> TracePlan {
        let p = person(party)
        func line(_ w: Double, _ h: Double, _ t: String) -> TracePlan {
            TracePlan(rows: [PlanRow(heightMM: h, cells: [PlanCell(widthMM: w, text: t)], wraps: true)])
        }
        switch slot {
        case .fullName:
            var rows: [PlanRow] = []
            if showKanaRow {
                rows.append(PlanRow(heightMM: 5, cells: [PlanCell(widthMM: 32, text: p.familyKana, spread: true),
                                                         PlanCell(widthMM: 32, text: p.givenKana, spread: true)],
                                    isKana: true))
            }
            rows.append(PlanRow(heightMM: 11, cells: [PlanCell(widthMM: 32, text: p.family, spread: true),
                                                      PlanCell(widthMM: 32, text: p.given, spread: true)]))
            return TracePlan(rows: rows)
        case .birthday: return line(60, 8, p.birthday.map { FormWriting.japaneseEra($0) } ?? "")
        case .address: return line(65, 8, p.address)
        case .householder: return line(40, 8, p.householder)
        case .honseki: return line(65, 8, p.honseki)
        case .hittousha: return line(40, 8, p.hittousha)
        case .father: return line(45, 8, join(p.fatherFamily, p.fatherGiven))
        case .mother: return line(45, 8, motherLine(p))
        case .rank: return line(9, 8, FormWriting.rankMark(p.rank))
        case .newHonseki: return line(80, 8, data.shared.newHonseki)
        case .livingTogether:
            return line(45, 8, data.shared.livingTogether.map { FormWriting.japaneseEra($0, includeDay: false) } ?? "")
        case .phone: return line(45, 7, p.phone)
        case .signature:
            return TracePlan(rows: [PlanRow(heightMM: 11, cells: [PlanCell(widthMM: 64, text: "")])], guideOnly: true)
        }
    }
}

/// Lays text out at physical size. One point of text height is computed from millimetres.
struct TraceBoard: View {
    let plan: TracePlan
    let tweak: Tweak
    let pointsPerMM: Double
    var showGuides = true

    private var sizeScale: Double { tweak.sizePercent / 100 }
    private var widthScale: Double { tweak.widthPercent / 100 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(expandedRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { i, cell in
                        cellView(cell, row: row)
                            .overlay(alignment: .leading) {
                                if i > 0 && showGuides {
                                    Rectangle().fill(Color.gray.opacity(0.35)).frame(width: 0.6)
                                }
                            }
                    }
                }
                .overlay(alignment: .bottom) {
                    if showGuides { Rectangle().fill(Color.gray.opacity(0.25)).frame(height: 0.6) }
                }
            }
        }
        .overlay {
            if showGuides || plan.guideOnly {
                Rectangle().strokeBorder(Color.gray.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        }
    }

    private struct LaidRow {
        var heightPt: CGFloat
        var cells: [LaidCell]
    }
    private struct LaidCell {
        var widthPt: CGFloat
        var text: String
        var fontSize: CGFloat
        var tracking: CGFloat
    }

    private var fontName: String { tweak.heavy ? Typeface.minchoBold : Typeface.minchoRegular }

    private func measure(_ s: String, _ size: CGFloat) -> CGFloat {
        let f = UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
        return (s as NSString).size(withAttributes: [.font: f]).width
    }

    private var expandedRows: [LaidRow] {
        var out: [LaidRow] = []
        for row in plan.rows {
            let h = CGFloat(row.heightMM * sizeScale * pointsPerMM)
            let base = h * (row.isKana ? 0.8 : 0.7)
            if row.wraps, row.cells.count == 1 {
                let cell = row.cells[0]
                let w = CGFloat(cell.widthMM * sizeScale * widthScale * pointsPerMM)
                let usable = w * 0.97
                let full = measure(cell.text, base)
                if full <= usable || cell.text.isEmpty {
                    out.append(LaidRow(heightPt: h, cells: [LaidCell(widthPt: w, text: cell.text, fontSize: base, tracking: 0)]))
                } else if full * 0.82 <= usable {
                    let size = base * usable / full
                    out.append(LaidRow(heightPt: h, cells: [LaidCell(widthPt: w, text: cell.text, fontSize: size, tracking: 0)]))
                } else {
                    for piece in split(cell.text, size: base, width: usable) {
                        out.append(LaidRow(heightPt: h, cells: [LaidCell(widthPt: w, text: piece, fontSize: base, tracking: 0)]))
                    }
                }
            } else {
                let cells = row.cells.map { cell -> LaidCell in
                    let w = CGFloat(cell.widthMM * sizeScale * widthScale * pointsPerMM)
                    var size = base
                    var tw = measure(cell.text, size)
                    if tw > w * 0.94 { size *= (w * 0.94) / tw; tw = measure(cell.text, size) }
                    var tracking: CGFloat = 0
                    let n = cell.text.count
                    if cell.spread && n >= 2 {
                        tracking = min(size * 0.55, max(0, (w * 0.72 - tw) / CGFloat(n - 1)))
                    }
                    return LaidCell(widthPt: w, text: cell.text, fontSize: size, tracking: tracking)
                }
                out.append(LaidRow(heightPt: h, cells: cells))
            }
        }
        return out
    }

    private func split(_ text: String, size: CGFloat, width: CGFloat) -> [String] {
        var lines: [String] = []
        var current = ""
        for ch in text {
            let candidate = current + String(ch)
            if measure(candidate, size) > width && !current.isEmpty {
                lines.append(current)
                current = String(ch)
            } else {
                current = candidate
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    @ViewBuilder
    private func cellView(_ cell: LaidCell, row: LaidRow) -> some View {
        ZStack {
            if plan.guideOnly {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: row.heightPt / 2))
                    p.addLine(to: CGPoint(x: cell.widthPt, y: row.heightPt / 2))
                }
                .stroke(Color.gray.opacity(0.45), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            }
            Text(cell.text)
                .font(.custom(fontName, fixedSize: cell.fontSize))
                .tracking(cell.tracking)
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .fixedSize()
                .offset(x: cell.tracking / 2)
        }
        .frame(width: cell.widthPt, height: row.heightPt)
    }

    // MARK: sizes for the caption
    static func caption(_ plan: TracePlan, tweak: Tweak) -> String {
        let s = tweak.sizePercent / 100, w = tweak.widthPercent / 100
        guard let tallest = plan.rows.max(by: { $0.heightMM < $1.heightMM }) else { return "" }
        let widths = tallest.cells.map { String(format: "%.0f", $0.widthMM * s * w) }
        let widthText = widths.count == 2 ? "氏 約\(widths[0])mm／名 約\(widths[1])mm" : "幅 約\(widths.first ?? "")mm"
        return "（実寸表示：\(widthText)、高さ 約\(String(format: "%.0f", tallest.heightMM * s))mm）"
    }
}
