import SwiftUI

struct TraceRequest: Identifiable {
    let id = UUID()
    let party: Party
    let order: [Slot]
    let start: Int
}

struct TraceScreen: View {
    let request: TraceRequest

    @EnvironmentObject var book: EntryBook
    @EnvironmentObject var unlock: UnlockStore
    @EnvironmentObject var ruler: RealSizeRuler
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var index = 0
    @State private var locked = false
    @State private var unlockProgress = false
    @State private var tool: Tool?
    @State private var showGuides = true
    @State private var paywall = false
    @State private var guardian = TracingScreenGuard()

    enum Tool: String { case size, width, position }

    init(request: TraceRequest) {
        self.request = request
        _index = State(initialValue: request.start)
    }

    private var slot: Slot { request.order[index] }
    private var party: Party { request.party }
    private var tweak: Tweak { book.tweak(party, slot) }
    private var plan: TracePlan { book.plan(party, slot) }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 10) {
                Text(slot == .signature ? "署名の練習：目安の枠と中心線だけを表示しています（お手本の字は出しません）"
                                        : TraceBoard.caption(plan, tweak: tweak))
                    .font(.system(size: 12)).foregroundStyle(Color.gray)
                    .opacity(locked ? 0 : 1)
                TraceBoard(plan: plan, tweak: tweak, pointsPerMM: ruler.pointsPerMM, showGuides: showGuides)
                if plan.isEmpty {
                    Text("まだ入力されていません。閉じて、この欄を入力してください。")
                        .font(.system(size: 13)).foregroundStyle(Palette.champagne)
                }
            }
            .offset(x: ruler.pt(tweak.offsetX), y: ruler.pt(tweak.offsetY))

            if !locked { chrome }

            if locked {
                Color.white.opacity(0.001).ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
            }

            HStack {
                lockButton.padding(.leading, 28)
                Spacer()
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onAppear {
            OrientationControl.use(.landscape)
            guardian.engage()
            book.noteTrial(party, slot, unlocked: unlock.unlocked)
            if LaunchDemo.has("-locked") { locked = true }
        }
        .onDisappear {
            guardian.release()
            OrientationControl.use(.portrait)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { guardian.engage() } else { guardian.release() }
        }
        .sheet(isPresented: $paywall) { PaywallView() }
    }

    // MARK: chrome
    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Palette.hairline.opacity(0.6)))
                }
                Text("\(index + 1) / \(request.order.count)　\(slot.title)（\(party.label)）")
                    .font(.system(size: 14)).foregroundStyle(Palette.mist)
                Spacer()
                Label("明るさ最大・実寸\(Int(tweak.sizePercent))%", systemImage: "sun.max")
                    .font(.system(size: 13)).foregroundStyle(Palette.mist)
                Spacer()
                Button(book.isDone(party, slot) ? "✓ なぞり済" : "なぞり済にする") {
                    book.toggleDone(party, slot)
                }
                .buttonStyle(PillButtonStyle(filled: false))
                Button { move(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(PillButtonStyle(filled: false))
                    .disabled(index == 0)
                Button("次の欄 ›") { move(1) }
                    .buttonStyle(PillButtonStyle())
                    .disabled(index + 1 >= request.order.count)
            }
            .padding(.horizontal, 24).padding(.top, 10)
            .foregroundStyle(Palette.ink)

            Spacer()

            HStack {
                Spacer()
                VStack(spacing: 12) {
                    toolButton(tweak.heavy ? "太字" : "細字", active: tweak.heavy) {
                        var t = tweak; t.heavy.toggle(); book.setTweak(t, party, slot)
                    }
                    toolButton("大きさ", active: tool == .size) { tool = tool == .size ? nil : .size }
                    toolButton("幅", active: tool == .width) { tool = tool == .width ? nil : .width }
                    toolButton("位置", active: tool == .position) { tool = tool == .position ? nil : .position }
                    toolButton("枠", active: showGuides) { showGuides.toggle() }
                }
                .padding(.trailing, 26)
            }

            Spacer()

            if let tool { toolPanel(tool).padding(.bottom, 6) }

            Text("用紙を画面に重ねて、透けた字をボールペンでなぞってください。ロック中は画面に触れても動きません（鍵マークを長押しで解除）")
                .font(.system(size: 11)).foregroundStyle(Color.gray)
                .padding(.bottom, 8)
        }
    }

    private func toolButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .medium))
                .frame(width: 50, height: 50)
                .background(Circle().fill(active ? Palette.champagne.opacity(0.35) : Palette.hairline.opacity(0.7)))
                .foregroundStyle(Palette.ink)
        }
    }

    @ViewBuilder
    private func toolPanel(_ tool: Tool) -> some View {
        HStack(spacing: 14) {
            switch tool {
            case .size:
                stepper("大きさ", value: "\(Int(tweak.sizePercent))%") { d in
                    var t = tweak; t.sizePercent = min(160, max(60, t.sizePercent + d)); book.setTweak(t, party, slot)
                }
            case .width:
                stepper("枠の幅", value: "\(Int(tweak.widthPercent))%") { d in
                    var t = tweak; t.widthPercent = min(200, max(50, t.widthPercent + d)); book.setTweak(t, party, slot)
                }
            case .position:
                Text("位置（0.5mmずつ）").font(.system(size: 13)).foregroundStyle(Palette.mist)
                ForEach([("arrow.left", -0.5, 0.0), ("arrow.up", 0.0, -0.5), ("arrow.down", 0.0, 0.5), ("arrow.right", 0.5, 0.0)],
                        id: \.0) { item in
                    Button {
                        var t = tweak; t.offsetX += item.1; t.offsetY += item.2; book.setTweak(t, party, slot)
                    } label: { Image(systemName: item.0) }
                    .buttonStyle(PillButtonStyle(filled: false))
                }
                Text(String(format: "横%+.1f 縦%+.1f mm", tweak.offsetX, tweak.offsetY))
                    .font(.system(size: 12).monospacedDigit()).foregroundStyle(Palette.mist)
            }
            Button("元に戻す") {
                var t = tweak
                switch tool {
                case .size: t.sizePercent = 100
                case .width: t.widthPercent = 100
                case .position: t.offsetX = 0; t.offsetY = 0
                }
                book.setTweak(t, party, slot)
            }
            .font(.system(size: 13)).foregroundStyle(Palette.champagne)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(Capsule().fill(Color.white).shadow(color: .black.opacity(0.08), radius: 8))
    }

    private func stepper(_ title: String, value: String, change: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 13)).foregroundStyle(Palette.mist)
            Button { change(-1) } label: { Image(systemName: "minus") }.buttonStyle(PillButtonStyle(filled: false))
            Text(value).font(.system(size: 15, weight: .semibold).monospacedDigit()).frame(minWidth: 48)
            Button { change(1) } label: { Image(systemName: "plus") }.buttonStyle(PillButtonStyle(filled: false))
        }
    }

    private var lockButton: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Color.white)
                Circle().stroke(Palette.champagne, lineWidth: 1.5)
                Circle().trim(from: 0, to: unlockProgress ? 1 : 0)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: locked ? "lock.fill" : "lock.open")
                    .font(.system(size: 20)).foregroundStyle(Palette.champagne)
            }
            .frame(width: 54, height: 54)
            Text(locked ? "タッチ\nロック中" : "タップで\nロック")
                .font(.system(size: 11)).multilineTextAlignment(.center)
                .foregroundStyle(Palette.mist)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !locked { tool = nil; locked = true }
        }
        .onLongPressGesture(minimumDuration: 1.0, pressing: { pressing in
            guard locked else { return }
            withAnimation(pressing ? .linear(duration: 1.0) : .easeOut(duration: 0.2)) { unlockProgress = pressing }
        }, perform: {
            if locked {
                locked = false
                unlockProgress = false
            }
        })
    }

    private func move(_ delta: Int) {
        let next = index + delta
        guard next >= 0, next < request.order.count else { return }
        if !book.mayUse(party, request.order[next], unlocked: unlock.unlocked) {
            paywall = true
            return
        }
        tool = nil
        index = next
    }
}
