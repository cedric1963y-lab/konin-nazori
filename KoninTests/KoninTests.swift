import XCTest
import StoreKit
import StoreKitTest
@testable import KoninNazori

@MainActor
final class KoninTests: XCTestCase {
    func testPurchaseUnlocksEverything() async throws {
        let session = try SKTestSession(configurationFileNamed: "Konin")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true

        let store = UnlockStore()
        await store.refresh()
        XCTAssertFalse(store.unlocked)
        await store.loadProduct()
        if store.product == nil {
            throw XCTSkip("StoreKit test session returned no products when run from xcodebuild (storekitd: app not installed for development). Run this test from Xcode.")
        }
        XCTAssertEqual(store.product?.id, UnlockStore.productID)
        XCTAssertEqual(store.product?.price, 500)
        await store.buy()
        XCTAssertTrue(store.unlocked)

        session.clearTransactions()
        await store.refresh()
        XCTAssertFalse(store.unlocked)
    }

    func testFreeTierAllowsOneNameOnly() {
        let book = EntryBook()
        book.eraseAll()
        XCTAssertTrue(book.mayUse(.husband, .fullName, unlocked: false))
        XCTAssertTrue(book.mayUse(.wife, .fullName, unlocked: false))
        XCTAssertFalse(book.mayUse(.husband, .address, unlocked: false))
        XCTAssertFalse(book.mayUse(.husband, .signature, unlocked: false))
        XCTAssertFalse(book.mayUse(.witness1, .birthday, unlocked: false))
        book.noteTrial(.husband, .fullName, unlocked: false)
        XCTAssertFalse(book.mayUse(.wife, .fullName, unlocked: false))
        XCTAssertTrue(book.mayUse(.husband, .fullName, unlocked: false))
        XCTAssertTrue(book.mayUse(.wife, .address, unlocked: true))
        XCTAssertTrue(book.mayUse(.witness2, .honseki, unlocked: true))
        book.eraseAll()
    }

    func testWritingHelpers() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let d = { (y: Int, m: Int, dd: Int) in c.date(from: DateComponents(year: y, month: m, day: dd))! }
        XCTAssertEqual(FormWriting.japaneseEra(d(1998, 4, 1)), "平成10年4月1日")
        XCTAssertEqual(FormWriting.japaneseEra(d(1989, 1, 7)), "昭和64年1月7日")
        XCTAssertEqual(FormWriting.japaneseEra(d(1989, 1, 8)), "平成元年1月8日")
        XCTAssertEqual(FormWriting.japaneseEra(d(2019, 5, 1)), "令和元年5月1日")
        XCTAssertEqual(FormWriting.japaneseEra(d(2026, 10, 1), includeDay: false), "令和8年10月")
        XCTAssertEqual(FormWriting.rankMark("長男"), "長")
        XCTAssertEqual(FormWriting.rankMark("次男"), "二")
        XCTAssertEqual(FormWriting.rankMark("三女"), "三")
        XCTAssertEqual(FormWriting.kanjiNumber(12), "十二")
        XCTAssertEqual(FormWriting.kanjiNumber(105), "百五")
        let alts = FormWriting.hyphenAlternatives("千代田区千代田1-2-3 メゾン101")
        XCTAssertTrue(alts.contains("千代田区千代田1丁目2番3号 メゾン101"))
        XCTAssertTrue(alts.contains("千代田区千代田一丁目二番地三 メゾン101"))
        XCTAssertEqual(FormWriting.hyphenAlternatives("本町5-7").first, "本町5番地7")
        XCTAssertFalse(FormWriting.hasHyphen("千代田1丁目2番3号"))
    }
}
