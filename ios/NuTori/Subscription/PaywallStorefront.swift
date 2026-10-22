import Foundation
import NuToriCore

/// 課金画面の、商品を選んで買うところ
enum PaywallStorefront {
    /// StoreKit の `SubscriptionStoreView`
    case storeKit
    #if DEBUG
        /// `SubscriptionStoreView` を出さず、月額を買うボタンを置き、購入者のトークンを渡して StoreKit の口で買う。UI テストだけが使う
        /// （`SubscriptionStoreView` は本物の StoreKit で買い、StoreKit の口の偽物を通らないため）
        case fixed(purchase: (_ appAccountToken: UUID) async -> AppStorePurchaseAttempt)
    #endif
}
