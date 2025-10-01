//
//  PaywallService.swift
//  Volcy
//
//  StoreKit 2 subscription management
//

import Foundation
import StoreKit

class PaywallServiceImpl: PaywallService {

    // Product IDs
    private let monthlyProductID = "com.volcy.pro.monthly"
    private let yearlyProductID = "com.volcy.pro.yearly"

    private var updateListenerTask: Task<Void, Error>?
    private var purchasedSubscriptions: Set<String> = []

    init() {
        // Listen for transaction updates
        updateListenerTask = listenForTransactions()

        Task {
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - PaywallService Protocol

    var isProSubscriber: Bool {
        get async {
            await updateSubscriptionStatus()
            return !purchasedSubscriptions.isEmpty
        }
    }

    func checkSubscriptionStatus() async throws -> SubscriptionStatus {
        await updateSubscriptionStatus()
        return purchasedSubscriptions.isEmpty ? .free : .pro
    }

    func purchase(productId: String) async throws -> PurchaseResult {
        // Fetch products
        let products = try await Product.products(for: [monthlyProductID, yearlyProductID])

        guard let product = products.first(where: { $0.id == productId }) else {
            throw PaywallError.productNotFound
        }

        // Attempt purchase
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify transaction
            let transaction = try checkVerified(verification)

            // Update subscription status
            await updateSubscriptionStatus()

            // Finish transaction
            await transaction.finish()

            return .success

        case .userCancelled:
            return .cancelled

        case .pending:
            return .pending

        @unknown default:
            return .failed
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Private Methods

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Update subscription status
                    await self.updateSubscriptionStatus()

                    // Finish transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    private func updateSubscriptionStatus() async {
        var activeSubscriptions: Set<String> = []

        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if subscription is active
                if transaction.productType == .autoRenewable {
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        activeSubscriptions.insert(transaction.productID)
                    }
                }
            } catch {
                print("Failed to verify entitlement: \(error)")
            }
        }

        purchasedSubscriptions = activeSubscriptions
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PaywallError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Feature Gating

extension PaywallServiceImpl {

    func hasAccess(to feature: ProFeature) async -> Bool {
        let isPro = await isProSubscriber

        switch feature {
        case .unlimitedScans:
            return true // Free tier has unlimited scans
        case .clarityScore:
            return true // Free tier has clarity score
        case .oneRegion:
            return true // Free tier has 1 region
        case .fullFace:
            return isPro
        case .elevationVolume:
            return isPro
        case .regimenAB:
            return isPro
        case .pdfExport:
            return isPro
        case .multiProfile:
            return isPro
        }
    }
}

// MARK: - Supporting Types

enum ProFeature {
    case unlimitedScans
    case clarityScore
    case oneRegion
    case fullFace
    case elevationVolume
    case regimenAB
    case pdfExport
    case multiProfile
}

enum PaywallError: LocalizedError {
    case productNotFound
    case failedVerification
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found in App Store"
        case .failedVerification:
            return "Failed to verify purchase"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}

// MARK: - Purchase Result

enum PurchaseResult {
    case success
    case cancelled
    case pending
    case failed
}

enum SubscriptionStatus {
    case free
    case pro
}
