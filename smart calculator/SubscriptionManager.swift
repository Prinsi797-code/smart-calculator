import Foundation
import Combine
import StoreKit

// MARK: - Product IDs
enum SubscriptionProductID: String, CaseIterable {
    case weekly  = "com.hevin.calculator.weekly"
    case monthly = "com.hevin.calculator.monthly"
    case yearly  = "com.hevin.calculator.yearly"

    var displayName: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }
    var badge: String? {
        switch self {
        case .yearly:  return "Best value"
        default:       return nil
        }
    }
    var tagline: String {
        switch self {
        case .weekly:  return "Per week"
        case .monthly: return "Per month"
        case .yearly:  return "Best annual deal"
        }
    }
    var discountBadge: String {
        switch self {
        case .yearly:  return "80% OFF"
        case .monthly: return "76% OFF"
        case .weekly:  return "39% OFF"
        }
    }
    var discountLabel: String {
        switch self {
        case .yearly:  return "80% OFF"
        case .monthly: return "76% OFF  Recommend"
        case .weekly:  return "39% OFF  Most Popular"
        }
    }
}

// MARK: - SubscriptionManager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil
    @Published var activeProductID: String? = nil

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadAndVerify() }
    }

    deinit { updateListenerTask?.cancel() }

    // MARK: - Load Products + Verify
    func loadAndVerify() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(
                for: SubscriptionProductID.allCases.map(\.rawValue)
            )
            let order: [String] = [
                SubscriptionProductID.yearly.rawValue,
                SubscriptionProductID.monthly.rawValue,
                SubscriptionProductID.weekly.rawValue
            ]
            products = storeProducts.sorted {
                (order.firstIndex(of: $0.id) ?? 99) < (order.firstIndex(of: $1.id) ?? 99)
            }
        } catch {
            print("❌ Failed to load products: \(error)")
        }

        await verifySubscription()
    }

    // MARK: - Verify active subscription
    func verifySubscription() async {
        var hasActive = false
        var foundID: String? = nil

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                let validIDs = SubscriptionProductID.allCases.map(\.rawValue)
                if validIDs.contains(transaction.productID) {
                    // Check expiry
                    if let expiry = transaction.expirationDate {
                        if expiry > Date() {
                            hasActive = true
                            foundID = transaction.productID
                            break
                        }
                    } else {
                        hasActive = true
                        foundID = transaction.productID
                        break
                    }
                }
            }
        }

        isPremium = hasActive
        activeProductID = foundID
        print(hasActive
              ? "✅ Premium active: \(foundID ?? "unknown")"
              : "ℹ️ No active subscription")
    }

    // MARK: - Purchase
    // ✅ KEY FIX: After verified transaction, DIRECTLY set isPremium + activeProductID
    // Do NOT wait for verifySubscription() — sandbox entitlements can be slow
    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Finish the transaction immediately
                    await transaction.finish()
                    print("✅ Purchase successful: \(transaction.productID)")

                    // ✅ Directly activate — don't rely on entitlements refresh
                    isPremium = true
                    activeProductID = transaction.productID

                    // Also verify in background to sync properly
                    await verifySubscription()

                case .unverified(_, let error):
                    purchaseError = "Purchase could not be verified: \(error.localizedDescription)"
                    print("❌ Unverified: \(error)")
                }

            case .userCancelled:
                print("ℹ️ User cancelled purchase")

            case .pending:
                print("⏳ Purchase pending (Ask to Buy)")

            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            print("❌ Purchase failed: \(error)")
        }
    }

    // MARK: - Restore
    func restore() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await verifySubscription()
            if !isPremium {
                purchaseError = "No active subscription found to restore."
            } else {
                print("✅ Restore successful: \(activeProductID ?? "unknown")")
            }
        } catch {
            purchaseError = error.localizedDescription
            print("❌ Restore failed: \(error)")
        }
    }

    // MARK: - Background Transaction Listener (renewals, refunds)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.verifySubscription()
                }
            }
        }
    }

    // MARK: - Ad Gating
    var shouldShowAds: Bool { !isPremium }
}
