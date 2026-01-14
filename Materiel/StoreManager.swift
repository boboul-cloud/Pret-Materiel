//
//  StoreManager.swift
//  Materiel
//
//  Created by Robert Oulhen on 05/12/2025.
//

import Foundation
import StoreKit
import Combine

// MARK: - Product Identifiers
enum ProductID: String, CaseIterable {
    // Achat unique Premium (Non-Consumable)
    case premiumUnlock = "com.materiel.premium.unlock"
}

// MARK: - Purchase State
enum PurchaseState: Equatable {
    case idle
    case loading
    case purchasing
    case purchased
    case failed(String)
    case deferred
}

// MARK: - Store Error
enum StoreError: LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseCancelled
    case purchasePending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return NSLocalizedString("La vérification de l'achat a échoué.", comment: "Store error")
        case .productNotFound:
            return NSLocalizedString("Produit non trouvé.", comment: "Store error")
        case .purchaseCancelled:
            return NSLocalizedString("Achat annulé.", comment: "Store error")
        case .purchasePending:
            return NSLocalizedString("Achat en attente d'approbation.", comment: "Store error")
        case .unknown:
            return NSLocalizedString("Une erreur inconnue s'est produite.", comment: "Store error")
        }
    }
}

// MARK: - Store Manager
@MainActor
class StoreManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var isLoading = false
    
    // État Premium - false par défaut, devient true après achat
    @Published private(set) var hasUnlockedPremium = false
    
    // MARK: - Private Properties
    private var updateListenerTask: Task<Void, Error>?
    private let userDefaults = UserDefaults.standard
    private let premiumKey = "com.materiel.isPremium"
    
    // MARK: - Singleton (optionnel, peut aussi être utilisé via @StateObject)
    static let shared = StoreManager()
    
    // MARK: - Initialization
    init() {
        // Restaurer l'état Premium depuis le cache local
        hasUnlockedPremium = userDefaults.bool(forKey: premiumKey)
        
        // Écouter les mises à jour de transactions
        updateListenerTask = listenForTransactions()
        
        // Charger les produits et vérifier les achats
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Récupérer tous les identifiants de produits
            let productIDs = ProductID.allCases.map { $0.rawValue }
            
            print("🔍 Tentative de chargement des produits avec IDs:")
            for id in productIDs {
                print("   - \(id)")
            }
            
            // Charger les produits depuis l'App Store
            let storeProducts = try await Product.products(for: Set(productIDs))
            
            // Trier les produits par prix
            products = storeProducts.sorted { $0.price < $1.price }
            
            print("✅ Produits chargés: \(products.count)")
            for product in products {
                print("  - \(product.id): \(product.displayName) - \(product.displayPrice)")
            }
            
            if products.isEmpty {
                print("⚠️ Aucun produit trouvé. Vérifiez:")
                print("   1. Le fichier Products.storekit est sélectionné dans Edit Scheme > Run > Options > StoreKit Configuration")
                print("   2. Les Product IDs correspondent exactement")
            }
        } catch {
            print("❌ Erreur lors du chargement des produits: \(error)")
            print("   Description: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Purchase Product
    func purchase(_ product: Product) async throws {
        purchaseState = .purchasing
        
        do {
            // Lancer l'achat
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Vérifier la transaction
                let transaction = try checkVerified(verification)
                
                // Mettre à jour les achats
                await updatePurchasedProducts()
                
                // Finaliser la transaction
                await transaction.finish()
                
                purchaseState = .purchased
                print("✅ Achat réussi: \(product.displayName)")
                
            case .userCancelled:
                purchaseState = .idle
                throw StoreError.purchaseCancelled
                
            case .pending:
                purchaseState = .deferred
                throw StoreError.purchasePending
                
            @unknown default:
                purchaseState = .failed("Erreur inconnue")
                throw StoreError.unknown
            }
        } catch let error as StoreError {
            if case .purchaseCancelled = error {
                purchaseState = .idle
            } else {
                purchaseState = .failed(error.localizedDescription)
            }
            throw error
        } catch {
            purchaseState = .failed(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        purchaseState = .loading
        
        do {
            // Synchroniser avec l'App Store
            try await AppStore.sync()
            
            // Mettre à jour les produits achetés
            await updatePurchasedProducts()
            
            purchaseState = hasUnlockedPremium ? .purchased : .idle
            print("✅ Restauration terminée")
        } catch {
            purchaseState = .failed(error.localizedDescription)
            print("❌ Erreur lors de la restauration: \(error)")
        }
    }
    
    // MARK: - Update Purchased Products
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        var isPremium = false
        
        // Vérifier les achats actuels (entitlements)
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // Ajouter à la liste des produits achetés
            purchasedIDs.insert(transaction.productID)
            
            // Vérifier si c'est un produit premium
            if transaction.productID == ProductID.premiumUnlock.rawValue {
                isPremium = true
            }
        }
        
        // Mettre à jour l'état
        purchasedProductIDs = purchasedIDs
        hasUnlockedPremium = isPremium
        
        // Sauvegarder dans UserDefaults (cache)
        userDefaults.set(isPremium, forKey: premiumKey)
        
        print("📦 Produits achetés: \(purchasedIDs)")
        print("⭐ Premium débloqué: \(isPremium)")
    }
    
    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Écouter les mises à jour de transactions
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Mettre à jour les achats sur le main thread
                    await self.updatePurchasedProducts()
                    
                    // Finaliser la transaction
                    await transaction.finish()
                } catch {
                    print("❌ Transaction non vérifiée: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verify Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Helper Methods
    
    /// Vérifie si un produit spécifique est acheté
    func isPurchased(_ productID: ProductID) -> Bool {
        return purchasedProductIDs.contains(productID.rawValue)
    }
    
    /// Récupère un produit par son ID
    func product(for id: ProductID) -> Product? {
        return products.first { $0.id == id.rawValue }
    }
    
    /// Récupère les produits par type
    func products(ofType type: Product.ProductType) -> [Product] {
        return products.filter { $0.type == type }
    }
    
    /// Produit Premium (achat unique)
    var premiumProduct: Product? {
        products.first { $0.type == .nonConsumable }
    }
    
    // MARK: - Reset (pour debug uniquement)
    #if DEBUG
    func resetPurchases() {
        purchasedProductIDs.removeAll()
        hasUnlockedPremium = false
        userDefaults.set(false, forKey: premiumKey)
        print("🔄 Achats réinitialisés (debug)")
    }
    #endif
}

// MARK: - Premium Features Check Extension
extension StoreManager {
    
    /// Limite gratuite pour le nombre de matériels
    static let freeMaterielLimit = 10
    
    /// Limite gratuite pour le nombre de prêts
    static let freePretLimit = 10
    
    /// Limite gratuite pour le nombre d'emprunts
    static let freeEmpruntLimit = 5
    
    /// Limite gratuite pour le nombre de personnes
    static let freePersonneLimit = 5
    
    /// Limite gratuite pour le nombre de lieux
    static let freeLieuLimit = 5
    
    /// Limite gratuite pour le nombre d'éléments dans le coffre-fort
    static let freeCoffreLimit = 5
    
    /// Limite gratuite pour le nombre de locations
    static let freeLocationLimit = 5
    
    /// Limite gratuite pour le nombre de réparations
    static let freeReparationLimit = 5
    
    /// Limite gratuite pour le nombre de "Je loue" (MaLocation)
    static let freeMaLocationLimit = 5
    
    /// Vérifie si l'utilisateur peut ajouter plus de matériels
    func canAddMoreMateriel(currentCount: Int) -> Bool {
        return hasUnlockedPremium || currentCount < Self.freeMaterielLimit
    }
    
    /// Vérifie si l'utilisateur peut ajouter plus de prêts
    func canAddMorePret(currentCount: Int) -> Bool {
        return hasUnlockedPremium || currentCount < Self.freePretLimit
    }
    
    /// Vérifie si l'utilisateur peut ajouter plus d'emprunts
    func canAddMoreEmprunt(currentCount: Int) -> Bool {
        return hasUnlockedPremium || currentCount < Self.freeEmpruntLimit
    }
    
    /// Vérifie si l'utilisateur peut ajouter plus de personnes
    func canAddMorePersonne(currentCount: Int) -> Bool {
        return hasUnlockedPremium || currentCount < Self.freePersonneLimit
    }
    
    /// Vérifie si l'utilisateur peut ajouter plus d'éléments au coffre-fort
    func canAddMoreCoffreItem(currentCount: Int) -> Bool {
        return hasUnlockedPremium || currentCount < Self.freeCoffreLimit
    }
    
    /// Vérifie si l'utilisateur peut ajouter plus de locations
    func canAddMoreLocation(currentCount: Int) -> Bool {
        return hasUnlockedPremium || currentCount < Self.freeLocationLimit
    }
    
    /// Vérifie si l'utilisateur peut ajouter plus de réparations
    func canAddMoreReparation(currentCount: Int) -> Bool {
        return hasUnlockedPremium || currentCount < Self.freeReparationLimit
    }
    
    /// Vérifie si l'utilisateur peut ajouter plus de "Je loue" (MaLocation)
    func canAddMoreMaLocation(currentCount: Int) -> Bool {
        return hasUnlockedPremium || currentCount < Self.freeMaLocationLimit
    }
    
    /// Nombre de matériels restants en version gratuite
    func remainingFreeMateriel(currentCount: Int) -> Int {
        return max(0, Self.freeMaterielLimit - currentCount)
    }
    
    /// Nombre de prêts restants en version gratuite
    func remainingFreePret(currentCount: Int) -> Int {
        return max(0, Self.freePretLimit - currentCount)
    }
    
    /// Nombre d'emprunts restants en version gratuite
    func remainingFreeEmprunt(currentCount: Int) -> Int {
        return max(0, Self.freeEmpruntLimit - currentCount)
    }
    
    /// Nombre de personnes restantes en version gratuite
    func remainingFreePersonne(currentCount: Int) -> Int {
        return max(0, Self.freePersonneLimit - currentCount)
    }
    
    /// Nombre d'éléments coffre restants en version gratuite
    func remainingFreeCoffreItem(currentCount: Int) -> Int {
        return max(0, Self.freeCoffreLimit - currentCount)
    }
    
    /// Nombre de locations restantes en version gratuite
    func remainingFreeLocation(currentCount: Int) -> Int {
        return max(0, Self.freeLocationLimit - currentCount)
    }
    
    /// Nombre de réparations restantes en version gratuite
    func remainingFreeReparation(currentCount: Int) -> Int {
        return max(0, Self.freeReparationLimit - currentCount)
    }
    
    /// Nombre de "Je loue" (MaLocation) restantes en version gratuite
    func remainingFreeMaLocation(currentCount: Int) -> Int {
        return max(0, Self.freeMaLocationLimit - currentCount)
    }
}
