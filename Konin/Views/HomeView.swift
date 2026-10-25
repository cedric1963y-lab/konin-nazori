import SwiftUI

struct MainTabs: View {
    @State private var selection = Int(LaunchDemo.value("-tab") ?? "0") ?? 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("記入", systemImage: "pencil.line") }.tag(0)
            NavigationStack { RulerSetupView(isFirstRun: false) {} }
                .tabItem { Label("実寸合わせ", systemImage: "creditcard") }.tag(1)
            NavigationStack { BlurStudioView() }
                .tabItem { Label("ぼかし", systemImage: "circle.dashed") }.tag(2)
            NavigationStack { ChecklistView() }
                .tabItem { Label("チェック", systemImage: "checklist") }.tag(3)
            NavigationStack { SettingsView() }
                .tabItem { Label("設定", systemImage: "gearshape") }.tag(4)
        }
    }
}

struct SlotTarget: Identifiable {
    var party: Party
    var slot: Slot
    var id: String { party.rawValue + slot.rawValue }
}

enum HomeTab: String, CaseIterable {
    case husband = "夫になる人", wife = "妻になる人", witness = "証人"
}

struct HomeView: View {
    @EnvironmentObject var book: EntryBook
    @EnvironmentObject var unlock: UnlockStore

    @State private var tab: HomeTab = LaunchDemo.value("-home") == "witness" ? .witness : .husband
    @State private var editing: SlotTarget?
    @State private var tracing: TraceRequest?
    @State private var pendingTrace: SlotTarget?
    @State private var paywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                EyebrowTitle(latin: "Marriage Registration", title: "婚姻届 なぞり清書")
                    .padding(.top, 8)
                HStack(spacing: 8) {
                    ForEach(HomeTab.allCases, id: \.self) { t in
                        Button { tab = t } label: {
                            Text(t.rawValue).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PillButtonStyle(filled: tab == t))
                    }
                }
                progressCard
                switch tab {
                case .husband: rows(for: .husband)
                case .wife: rows(for: .wife)
                case .witness:
                    Text("証人の欄は、証人ご本人がなぞる用です。署名だけは必ずご本人の字で（目安の枠だけ表示します）。")
                        .font(.system(size: 13)).foregroundStyle(Palette.mist)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    sectionHeader("証人1")
                    rows(for: .witness1)
                    sectionHeader("証人2")
                    rows(for: .witness2)
                }
                if !unlock.unlocked {
                    Button { paywall = true } label: {
                        Text("すべての欄を使う（\(unlock.priceText)・買い切り）")
                    }
                    .buttonStyle(WideButtonStyle())
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(Palette.porcelain.ignoresSafeArea())
        .sheet(item: $editing, onDismiss: {
            if let t = pendingTrace {
                pendingTrace = nil
                startTrace(t.party, t.slot)
            }
        }) { target in
            SlotEditorView(party: target.party, slot: target.slot) {
                pendingTrace = target
                editing = nil
            }
        }
        .fullScreenCover(item: $tracing) { TraceScreen(request: $0) }
        .sheet(isPresented: $paywall) { PaywallView() }
        .onAppear {
            if let s = LaunchDemo.value("-trace"), let slot = Slot(rawValue: s) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { startTrace(.husband, slot) }
            }
            if LaunchDemo.has("-paywall") { paywall = true }
            if let s = LaunchDemo.value("-edit"), let slot = Slot(rawValue: s) {
                editing = SlotTarget(party: .husband, slot: slot)
            }
        }
    }

    private func sectionHeader(_ s: String) -> some View {
        Text(s).font(Typeface.mincho(17, bold: true)).foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
    }

    private var progressCard: some View {
        let parties: [Party] = tab == .husband ? [.husband] : tab == .wife ? [.wife] : [.witness1, .witness2]
        let order = tab == .witness ? Slot.witnessOrder : Slot.spouseOrder
        let total = parties.count * order.count
        let done = parties.reduce(0) { sum, p in sum + order.filter { book.isDone(p, $0) }.count }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("記入の進み具合").font(.system(size: 14)).foregroundStyle(Palette.mist)
                Spacer()
                Text("\(done)").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                + Text(" / \(total) 欄").font(.system(size: 14)).foregroundStyle(Palette.mist)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.hairline)
                    Capsule().fill(Palette.champagne)
                        .frame(width: geo.size.width * CGFloat(done) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 6)
        }
        .softCard()
    }

    @ViewBuilder
    private func rows(for party: Party) -> some View {
        let order = party.isSpouse ? Slot.spouseOrder : Slot.witnessOrder
        ForEach(Array(order.enumerated()), id: \.element) { i, slot in
            SlotRow(number: i + 1, party: party, slot: slot,
                    open: { open(party, slot) }, trace: { startTrace(party, slot) })
        }
    }

    private func open(_ party: Party, _ slot: Slot) {
        guard book.mayUse(party, slot, unlocked: unlock.unlocked) else { paywall = true; return }
        if slot == .signature { startTrace(party, slot); return }
        editing = SlotTarget(party: party, slot: slot)
    }

    private func startTrace(_ party: Party, _ slot: Slot) {
        guard book.mayUse(party, slot, unlocked: unlock.unlocked) else { paywall = true; return }
        let order = party.isSpouse ? Slot.spouseOrder : Slot.witnessOrder
        tracing = TraceRequest(party: party, order: order, start: order.firstIndex(of: slot) ?? 0)
    }
}

struct SlotRow: View {
    let number: Int
    let party: Party
    let slot: Slot
    let open: () -> Void
    let trace: () -> Void

    @EnvironmentObject var book: EntryBook
    @EnvironmentObject var unlock: UnlockStore

    var body: some View {
        let done = book.isDone(party, slot)
        let allowed = book.mayUse(party, slot, unlocked: unlock.unlocked)
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(done ? Palette.champagne : Color.clear)
                Circle().stroke(Palette.champagne, lineWidth: 1.2)
                Text("\(number)").font(Typeface.latin(19))
                    .foregroundStyle(done ? Color.white : Palette.champagne)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                Text(book.preview(party, slot) ?? slot.hint)
                    .font(.system(size: 12.5)).foregroundStyle(Palette.mist).lineLimit(1)
            }
            Spacer(minLength: 4)
            if !allowed {
                Image(systemName: "lock").foregroundStyle(Palette.champagne)
            } else if done {
                Button(action: trace) {
                    Text("✓ なぞり済").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.champagne)
                }
            } else {
                Button(slot == .signature ? "練習" : "なぞる", action: trace)
                    .buttonStyle(PillButtonStyle())
            }
        }
        .softCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }
}
