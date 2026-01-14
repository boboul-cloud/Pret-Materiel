//
//  ComptabiliteCommercialeView.swift
//  Materiel
//
//  Comptabilité dédiée au module Achat/Vente avec calcul TVA
//

import SwiftUI

struct ComptabiliteCommercialeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeriod: PeriodFilter = .month
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    
    enum PeriodFilter: String, CaseIterable {
        case month = "Mois"
        case year = "Année"
        case total = "Total"
        
        var localizedName: LocalizedStringKey {
            switch self {
            case .month: return LocalizedStringKey("Mois")
            case .year: return LocalizedStringKey("Année")
            case .total: return LocalizedStringKey("Total")
            }
        }
    }
    
    // Transactions filtrées par période
    private var filteredTransactions: [TransactionCommerce] {
        switch selectedPeriod {
        case .month:
            return dataManager.transactionsCommerce.filter {
                $0.mois == selectedMonth && $0.annee == selectedYear
            }
        case .year:
            return dataManager.transactionsCommerce.filter {
                $0.annee == selectedYear
            }
        case .total:
            return dataManager.transactionsCommerce
        }
    }
    
    // Calculs
    private var ventes: [TransactionCommerce] {
        filteredTransactions.filter { $0.typeTransaction == .vente }
    }
    
    private var achats: [TransactionCommerce] {
        filteredTransactions.filter { $0.typeTransaction == .achat }
    }
    
    private var totalVentesHT: Double {
        ventes.reduce(0) { $0 + $1.montantNetHT }
    }
    
    private var totalVentesTTC: Double {
        ventes.reduce(0) { $0 + $1.montantTTC }
    }
    
    private var totalAchatsHT: Double {
        achats.reduce(0) { $0 + $1.montantNetHT }
    }
    
    private var totalAchatsTTC: Double {
        achats.reduce(0) { $0 + $1.montantTTC }
    }
    
    private var tvaCollectee: Double {
        ventes.reduce(0) { $0 + $1.montantTVA }
    }
    
    private var tvaDeductible: Double {
        achats.reduce(0) { $0 + $1.montantTVA }
    }
    
    private var tvaAReverser: Double {
        tvaCollectee - tvaDeductible
    }
    
    private var margeHT: Double {
        totalVentesHT - totalAchatsHT
    }
    
    private var margeTTC: Double {
        totalVentesTTC - totalAchatsTTC
    }
    
    private var margePourcentage: Double {
        guard totalAchatsHT > 0 else { return 0 }
        return (margeHT / totalAchatsHT) * 100
    }
    
    private var totalRemises: Double {
        filteredTransactions.reduce(0) { $0 + $1.montantRemise }
    }
    
    private var transactionsNonPayees: [TransactionCommerce] {
        filteredTransactions.filter { !$0.estPaye }
    }
    
    private var availableYears: [Int] {
        let years = Set(dataManager.transactionsCommerce.map { $0.annee })
        if years.isEmpty {
            return [Calendar.current.component(.year, from: Date())]
        }
        return years.sorted().reversed()
    }
    
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1].capitalized
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.teal.opacity(0.12), Color.green.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Sélecteur de période
                        periodSelector
                        
                        // Résumé principal
                        mainSummaryCard
                        
                        // TVA
                        tvaCard
                        
                        // Détail par type de TVA
                        tvaDetailCard
                        
                        // Remises accordées
                        if totalRemises > 0 {
                            remisesCard
                        }
                        
                        // Transactions non payées
                        if !transactionsNonPayees.isEmpty {
                            unpaidCard
                        }
                        
                        // Statistiques
                        statsCard
                        
                        Spacer(minLength: 30)
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizedStringKey("Comptabilité Commerce"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }
    
    // MARK: - Composants
    
    private var periodSelector: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedPeriod) {
                ForEach(PeriodFilter.allCases, id: \.self) { period in
                    Text(period.localizedName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            
            if selectedPeriod != .total {
                HStack(spacing: 12) {
                    // Année
                    Menu {
                        ForEach(availableYears, id: \.self) { year in
                            Button(action: { selectedYear = year }) {
                                HStack {
                                    Text("\(year)")
                                    if selectedYear == year {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("\(selectedYear)")
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.teal.opacity(0.15))
                        .cornerRadius(8)
                    }
                    
                    if selectedPeriod == .month {
                        Menu {
                            ForEach(1...12, id: \.self) { month in
                                Button(action: { selectedMonth = month }) {
                                    HStack {
                                        Text(monthName(month))
                                        if selectedMonth == month {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.day.timeline.left")
                                Text(monthName(selectedMonth))
                                    .font(.subheadline)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.teal.opacity(0.15))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var mainSummaryCard: some View {
        VStack(spacing: 16) {
            Text(LocalizedStringKey("Résumé"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 0) {
                // Ventes
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text(LocalizedStringKey("Ventes"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(String(format: "%.2f €", totalVentesTTC))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text(String(format: "%.2f € HT", totalVentesHT))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(ventes.count) transactions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 60)
                
                // Achats
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.red)
                        Text(LocalizedStringKey("Achats"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(String(format: "%.2f €", totalAchatsTTC))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text(String(format: "%.2f € HT", totalAchatsHT))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(achats.count) transactions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 60)
                
                // Marge
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(margeHT >= 0 ? .teal : .orange)
                        Text(LocalizedStringKey("Marge"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(String(format: "%.2f €", margeTTC))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(margeHT >= 0 ? .teal : .orange)
                    Text(String(format: "%.2f € HT", margeHT))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", margePourcentage))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var tvaCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "percent")
                    .foregroundColor(.purple)
                Text(LocalizedStringKey("TVA"))
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 0) {
                // TVA Collectée
                VStack(spacing: 4) {
                    Text(LocalizedStringKey("Collectée"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f €", tvaCollectee))
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                
                Image(systemName: "minus")
                    .foregroundColor(.secondary)
                
                // TVA Déductible
                VStack(spacing: 4) {
                    Text(LocalizedStringKey("Déductible"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f €", tvaDeductible))
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)
                
                Image(systemName: "equal")
                    .foregroundColor(.secondary)
                
                // TVA à reverser
                VStack(spacing: 4) {
                    Text(LocalizedStringKey("À reverser"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f €", tvaAReverser))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(tvaAReverser >= 0 ? .purple : .orange)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var tvaDetailCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.indigo)
                Text(LocalizedStringKey("Détail TVA par taux"))
                    .font(.headline)
                Spacer()
            }
            
            ForEach(TauxTVA.allCases, id: \.self) { taux in
                let ventesParTaux = ventes.filter { $0.tauxTVA == taux }
                let achatsParTaux = achats.filter { $0.tauxTVA == taux }
                let tvaVentes = ventesParTaux.reduce(0) { $0 + $1.montantTVA }
                let tvaAchats = achatsParTaux.reduce(0) { $0 + $1.montantTVA }
                
                if !ventesParTaux.isEmpty || !achatsParTaux.isEmpty {
                    HStack {
                        Text(taux.pourcentage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 50, alignment: .leading)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "Coll: %.2f €", tvaVentes))
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(String(format: "Déd: %.2f €", tvaAchats))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Text(String(format: "%.2f €", tvaVentes - tvaAchats))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    
                    if taux != TauxTVA.allCases.last {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var remisesCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.orange)
                Text(LocalizedStringKey("Remises accordées"))
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f €", totalRemises))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            let remisesVentes = ventes.filter { $0.typeRemise != .aucune }
            let remisesAchats = achats.filter { $0.typeRemise != .aucune }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Sur ventes"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f € (%d)", remisesVentes.reduce(0) { $0 + $1.montantRemise }, remisesVentes.count))
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizedStringKey("Sur achats"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f € (%d)", remisesAchats.reduce(0) { $0 + $1.montantRemise }, remisesAchats.count))
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var unpaidCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text(LocalizedStringKey("Non payées"))
                    .font(.headline)
                Spacer()
                Text("\(transactionsNonPayees.count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            
            let ventesNonPayees = transactionsNonPayees.filter { $0.typeTransaction == .vente }
            let achatsNonPayes = transactionsNonPayees.filter { $0.typeTransaction == .achat }
            
            if !ventesNonPayees.isEmpty {
                HStack {
                    Text(LocalizedStringKey("Ventes à encaisser"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f €", ventesNonPayees.reduce(0) { $0 + $1.montantTTC }))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            if !achatsNonPayes.isEmpty {
                HStack {
                    Text(LocalizedStringKey("Achats à payer"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f €", achatsNonPayes.reduce(0) { $0 + $1.montantTTC }))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var statsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text(LocalizedStringKey("Statistiques"))
                    .font(.headline)
                Spacer()
            }
            
            let panierMoyenVente = ventes.isEmpty ? 0 : totalVentesTTC / Double(ventes.count)
            let panierMoyenAchat = achats.isEmpty ? 0 : totalAchatsTTC / Double(achats.count)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItem(title: LocalizedStringKey("Panier moyen vente"), value: String(format: "%.2f €", panierMoyenVente), color: .green)
                StatItem(title: LocalizedStringKey("Panier moyen achat"), value: String(format: "%.2f €", panierMoyenAchat), color: .red)
                StatItem(title: LocalizedStringKey("Articles en stock"), value: "\(dataManager.articlesCommerce.count)", color: .teal)
                StatItem(title: LocalizedStringKey("Stock bas"), value: "\(dataManager.articlesCommerce.filter { $0.stockBas }.count)", color: .orange)
            }
            
            // Modes de paiement
            let modesVentes = Dictionary(grouping: ventes, by: { $0.modePaiement })
            if !modesVentes.isEmpty {
                Divider()
                Text(LocalizedStringKey("Répartition paiements ventes"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(ModePaiement.allCases, id: \.self) { mode in
                    if let transactions = modesVentes[mode] {
                        let total = transactions.reduce(0) { $0 + $1.montantTTC }
                        HStack {
                            Image(systemName: mode.icon)
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text(mode.localizedName)
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.2f € (%d)", total, transactions.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct StatItem: View {
    let title: LocalizedStringKey
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}
