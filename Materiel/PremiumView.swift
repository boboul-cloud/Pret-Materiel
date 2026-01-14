//
//  PremiumView.swift
//  Materiel
//
//  Created by Robert Oulhen on 05/12/2025.
//

import SwiftUI
import StoreKit

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreManager.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedProduct: Product?
    @State private var showSuccessAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fond dégradé
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.3),
                        Color.blue.opacity(0.2),
                        Color.indigo.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header avec icône
                        headerSection
                        
                        // Avantages Premium
                        benefitsSection
                        
                        // Options d'achat
                        purchaseOptionsSection
                        
                        // Bouton Restaurer
                        restoreButton
                        
                        // Informations légales
                        legalInfoSection
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizedStringKey("Premium"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert(LocalizedStringKey("Erreur"), isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if showSuccessAnimation {
                    successOverlay
                }
            }
            .task {
                if storeManager.products.isEmpty {
                    await storeManager.loadProducts()
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icône premium animée
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 5)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text(LocalizedStringKey("Passez à Premium"))
                .font(.title)
                .fontWeight(.bold)
            
            Text(LocalizedStringKey("Débloquez toutes les fonctionnalités"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Badge si déjà premium
            if storeManager.hasUnlockedPremium {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text(LocalizedStringKey("Premium actif"))
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.top)
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("Avantages Premium"))
                .font(.headline)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                BenefitRow(
                    icon: "infinity",
                    iconColor: .blue,
                    title: LocalizedStringKey("Matériels illimités"),
                    description: LocalizedStringKey("Ajoutez autant de matériels que vous voulez")
                )
                
                Divider().padding(.leading, 44)
                
                BenefitRow(
                    icon: "arrow.up.arrow.down.circle.fill",
                    iconColor: .green,
                    title: LocalizedStringKey("Prêts illimités"),
                    description: LocalizedStringKey("Gérez tous vos prêts sans limite")
                )
                
                Divider().padding(.leading, 44)
                
                BenefitRow(
                    icon: "arrow.down.circle.fill",
                    iconColor: .orange,
                    title: LocalizedStringKey("Emprunts illimités"),
                    description: LocalizedStringKey("Suivez tous les objets qu'on vous prête")
                )
                
                Divider().padding(.leading, 44)
                
                BenefitRow(
                    icon: "person.2.fill",
                    iconColor: .pink,
                    title: LocalizedStringKey("Personnes illimitées"),
                    description: LocalizedStringKey("Ajoutez tous vos contacts sans restriction")
                )
                
                Divider().padding(.leading, 44)
                
                BenefitRow(
                    icon: "mappin.and.ellipse",
                    iconColor: .teal,
                    title: LocalizedStringKey("Lieux illimités"),
                    description: LocalizedStringKey("Créez autant de lieux de stockage que nécessaire")
                )
                
                Divider().padding(.leading, 44)
                
                BenefitRow(
                    icon: "lock.shield.fill",
                    iconColor: .yellow,
                    title: LocalizedStringKey("Coffre-fort illimité"),
                    description: LocalizedStringKey("Stockez toutes vos preuves de possession")
                )
                
                Divider().padding(.leading, 44)
                
                BenefitRow(
                    icon: "chart.bar.fill",
                    iconColor: .purple,
                    title: LocalizedStringKey("Statistiques détaillées"),
                    description: LocalizedStringKey("Analysez vos prêts et emprunts")
                )
                
                Divider().padding(.leading, 44)
                
                BenefitRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: LocalizedStringKey("Soutenez le développement"),
                    description: LocalizedStringKey("Aidez à améliorer l'application")
                )
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Purchase Options Section
    private var purchaseOptionsSection: some View {
        VStack(spacing: 16) {
            if storeManager.isLoading {
                ProgressView()
                    .padding()
            } else if storeManager.products.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding(.bottom, 8)
                    
                    Text(LocalizedStringKey("Chargement en cours..."))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(LocalizedStringKey("Les produits seront disponibles dans un instant. Veuillez patienter ou réessayer."))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        Task {
                            await storeManager.loadProducts()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(LocalizedStringKey("Réessayer"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            } else {
                // Achat unique Premium
                if let premiumProduct = storeManager.product(for: .premiumUnlock) {
                    Button {
                        guard !storeManager.isPurchased(.premiumUnlock) else { return }
                        Task {
                            await purchaseProduct(premiumProduct)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(premiumProduct.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(LocalizedStringKey("Paiement unique - Accès à vie"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if storeManager.isPurchased(.premiumUnlock) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                            } else {
                                Text(premiumProduct.displayPrice)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [.orange, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(storeManager.isPurchased(.premiumUnlock))
                }
            }
        }
    }
    
    // MARK: - Restore Button
    private var restoreButton: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
                if storeManager.hasUnlockedPremium {
                    showSuccessAnimation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text(LocalizedStringKey("Restaurer les achats"))
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .disabled(storeManager.purchaseState == .loading)
    }
    
    // MARK: - Legal Info Section
    private var legalInfoSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link(LocalizedStringKey("Conditions"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link(LocalizedStringKey("Confidentialité"), destination: URL(string: "https://www.apple.com/privacy/")!)
            }
            .font(.caption2)
        }
        .padding(.top)
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text(LocalizedStringKey("Merci !"))
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(LocalizedStringKey("Vous êtes maintenant Premium"))
                    .foregroundColor(.secondary)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
    }
    
    // MARK: - Purchase Method
    private func purchaseProduct(_ product: Product) async {
        do {
            try await storeManager.purchase(product)
            showSuccessAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } catch StoreError.purchaseCancelled {
            // L'utilisateur a annulé, pas d'erreur à afficher
        } catch StoreError.purchasePending {
            errorMessage = NSLocalizedString("Achat en attente d'approbation parentale.", comment: "")
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Purchase Option Card
struct PurchaseOptionCard: View {
    let product: Product
    let isRecommended: Bool
    let subtitle: LocalizedStringKey
    let isSelected: Bool
    let isPurchased: Bool
    let action: () async -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        Button {
            guard !isPurchased && !isProcessing else { return }
            isProcessing = true
            Task {
                await action()
                isProcessing = false
            }
        } label: {
            VStack(spacing: 0) {
                // Badge recommandé
                if isRecommended {
                    Text(LocalizedStringKey("RECOMMANDÉ"))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .offset(y: -10)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isPurchased {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    } else if isProcessing {
                        ProgressView()
                    } else {
                        VStack(alignment: .trailing) {
                            Text(product.displayPrice)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if product.type == .autoRenewable,
                               let subscription = product.subscription {
                                Text(periodString(subscription.subscriptionPeriod))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isRecommended ? Color.orange : (isSelected ? Color.blue : Color.clear),
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchased)
    }
    
    private func periodString(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .month:
            return period.value == 1 ? "par mois" : "pour \(period.value) mois"
        case .year:
            return period.value == 1 ? "par an" : "pour \(period.value) ans"
        case .week:
            return period.value == 1 ? "par semaine" : "pour \(period.value) semaines"
        case .day:
            return period.value == 1 ? "par jour" : "pour \(period.value) jours"
        @unknown default:
            return ""
        }
    }
}

// MARK: - Premium Required View Modifier
struct PremiumRequiredModifier: ViewModifier {
    @StateObject private var storeManager = StoreManager.shared
    let currentCount: Int
    let limit: Int
    @Binding var showPremiumSheet: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if !storeManager.hasUnlockedPremium && currentCount >= limit {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text(LocalizedStringKey("Limite atteinte"))
                            .font(.headline)
                        
                        Text(LocalizedStringKey("Passez à Premium pour continuer"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            showPremiumSheet = true
                        } label: {
                            Text(LocalizedStringKey("Débloquer"))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
    }
}

extension View {
    func premiumRequired(currentCount: Int, limit: Int, showPremiumSheet: Binding<Bool>) -> some View {
        modifier(PremiumRequiredModifier(currentCount: currentCount, limit: limit, showPremiumSheet: showPremiumSheet))
    }
}

// MARK: - Preview
#Preview {
    PremiumView()
}
