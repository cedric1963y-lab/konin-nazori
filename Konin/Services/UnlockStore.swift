import StoreKit
import SwiftUI

@MainActor
final class UnlockStore: ObservableObject {
    static let productID = "jp.hayatosuzuki.koninnazori.premium"

    @Published private(set) var unlocked = false
    @Published private(set) var product: Product?
    @Published var working = false
    @Published var notice: String?

    private var listener: Task<Void, Never>?

    init() {
        listener = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh(); await loadProduct() }
    }

    deinit { listener?.cancel() }

    var priceText: String { product?.displayPrice ?? "¥500" }

    func loadProduct() async {
        if let p = try? await Product.products(for: [Self.productID]).first { product = p }
    }

    func refresh() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let t) = entitlement, t.productID == Self.productID, t.revocationDate == nil {
                owned = true
            }
        }
        unlocked = owned || (LaunchDemo.isOn && !LaunchDemo.has("-free"))
    }

    func buy() async {
        if product == nil { await loadProduct() }
        guard let product else {
            notice = "ストアに接続できませんでした。通信状況を確認して、もう一度お試しください。"
            return
        }
        working = true
        defer { working = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    await refresh()
                    notice = "ありがとうございます。すべての機能が使えるようになりました。"
                } else {
                    notice = "購入を確認できませんでした。"
                }
            case .pending:
                notice = "購入の承認待ちです。承認されると自動で使えるようになります。"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            notice = "購入できませんでした。もう一度お試しください。"
        }
    }

    func restore() async {
        working = true
        defer { working = false }
        do {
            try await AppStore.sync()
        } catch {
            notice = "復元できませんでした。もう一度お試しください。"
            return
        }
        await refresh()
        notice = unlocked ? "購入を復元しました。" : "このApple IDでの購入は見つかりませんでした。"
    }
}
