//
//  AchatVenteView.swift
//  Materiel
//
//  Module indépendant de gestion Achat/Vente pour marchés et petits commerces
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Wrapper pour le type de transaction (pour sheet item)
struct TransactionTypeWrapper: Identifiable {
    let id = UUID()
    let type: TypeTransactionCommerce
}

// MARK: - Wrapper pour l'URL d'export
struct ExportURLWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Vue principale Achat/Vente
struct AchatVenteView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var showingAddArticle = false
    @State private var transactionToAdd: TransactionTypeWrapper?
    @State private var showingComptabiliteCommerciale = false
    
    // Export
    @State private var showingExportMenu = false
    @State private var exportURL: ExportURLWrapper?
    @State private var showingExportAlert = false
    @State private var exportAlertMessage = ""
    
    // Import
    @State private var showingImportPicker = false
    @State private var showingImportAlert = false
    @State private var importMessage = ""
    @State private var importSuccess = false
    
    // Gestion fournisseurs
    @State private var showingGestionFournisseurs = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.teal.opacity(0.12), Color.green.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Alerte paiements à venir
                    AlertePaiementsView()
                    
                    // Sélecteur d'onglet
                    Picker("", selection: $selectedTab) {
                        Text(LocalizedStringKey("Articles")).tag(0)
                        Text(LocalizedStringKey("Transactions")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Résumé rapide
                    CommerceResumeView()
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    // Contenu selon l'onglet
                    if selectedTab == 0 {
                        ArticlesListView(showingAddArticle: $showingAddArticle)
                    } else {
                        TransactionsListView(
                            transactionToAdd: $transactionToAdd
                        )
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Commerce"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Bouton export/import
                        Menu {
                            Section(header: Text(LocalizedStringKey("Exporter"))) {
                                Button(action: { exportPDF() }) {
                                    Label(LocalizedStringKey("Exporter en PDF"), systemImage: "doc.richtext")
                                }
                                Button(action: { exportJSON() }) {
                                    Label(LocalizedStringKey("Exporter en JSON"), systemImage: "doc.text")
                                }
                                Button(action: { exportCSV() }) {
                                    Label(LocalizedStringKey("Exporter en CSV"), systemImage: "tablecells")
                                }
                            }
                            
                            Section(header: Text(LocalizedStringKey("Importer"))) {
                                Button(action: { showingImportPicker = true }) {
                                    Label(LocalizedStringKey("Importer JSON"), systemImage: "square.and.arrow.down")
                                }
                            }
                            
                            Section(header: Text(LocalizedStringKey("Gérer"))) {
                                Button(action: { showingGestionFournisseurs = true }) {
                                    Label(LocalizedStringKey("Fournisseurs"), systemImage: "person.2.fill")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundStyle(.teal)
                        }
                        
                        // Bouton comptabilité
                        Button(action: { showingComptabiliteCommerciale = true }) {
                            Image(systemName: "chart.pie.fill")
                                .font(.title3)
                                .foregroundStyle(.teal)
                        }
                        
                        // Bouton ajouter
                        Menu {
                            Button(action: { showingAddArticle = true }) {
                                Label(LocalizedStringKey("Nouvel article"), systemImage: "cube.box.fill")
                            }
                            Divider()
                            Button(action: {
                                transactionToAdd = TransactionTypeWrapper(type: .achat)
                            }) {
                                Label(LocalizedStringKey("Nouvel achat"), systemImage: "arrow.down.circle.fill")
                            }
                            Button(action: {
                                transactionToAdd = TransactionTypeWrapper(type: .vente)
                            }) {
                                Label(LocalizedStringKey("Nouvelle vente"), systemImage: "arrow.up.circle.fill")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.teal)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddArticle) {
                ArticleFormView(mode: .add)
            }
            .sheet(item: $transactionToAdd) { wrapper in
                TransactionFormView(mode: .add, typeTransaction: wrapper.type)
            }
            .sheet(item: $exportURL) { item in
                ShareSheet(activityItems: [item.url])
            }
            .fullScreenCover(isPresented: $showingComptabiliteCommerciale) {
                ComptabiliteCommercialeView()
            }
            .sheet(isPresented: $showingGestionFournisseurs) {
                GestionFournisseursView()
            }
            .alert(LocalizedStringKey("Export"), isPresented: $showingExportAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(exportAlertMessage)
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert(importSuccess ? LocalizedStringKey("Import réussi") : LocalizedStringKey("Erreur d'import"), isPresented: $showingImportAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(importMessage)
            }
        }
    }
    
    // MARK: - Fonctions d'import
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importMessage = "Aucun fichier sélectionné"
                importSuccess = false
                showingImportAlert = true
                return
            }
            importJSONFile(from: url)
            
        case .failure(let error):
            importMessage = "Erreur lors de la sélection: \(error.localizedDescription)"
            importSuccess = false
            showingImportAlert = true
        }
    }
    
    private func importJSONFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importMessage = "Impossible d'accéder au fichier"
            importSuccess = false
            showingImportAlert = true
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let importedData = try decoder.decode(CommerceExportData.self, from: jsonData)
            
            // Importer les articles
            var articlesImported = 0
            var articlesDuplicates = 0
            
            for article in importedData.articles {
                if !dataManager.articlesCommerce.contains(where: { $0.id == article.id }) {
                    dataManager.ajouterArticleCommerce(article)
                    articlesImported += 1
                } else {
                    articlesDuplicates += 1
                }
            }
            
            // Importer les transactions
            var transactionsImported = 0
            var transactionsDuplicates = 0
            
            for transaction in importedData.transactions {
                if !dataManager.transactionsCommerce.contains(where: { $0.id == transaction.id }) {
                    dataManager.ajouterTransactionCommerce(transaction)
                    transactionsImported += 1
                } else {
                    transactionsDuplicates += 1
                }
            }
            
            var message = ""
            if articlesImported > 0 {
                message += "\(articlesImported) article(s) importé(s)"
            }
            if articlesDuplicates > 0 {
                message += message.isEmpty ? "" : "\n"
                message += "\(articlesDuplicates) article(s) déjà existant(s)"
            }
            if transactionsImported > 0 {
                message += message.isEmpty ? "" : "\n"
                message += "\(transactionsImported) transaction(s) importée(s)"
            }
            if transactionsDuplicates > 0 {
                message += message.isEmpty ? "" : "\n"
                message += "\(transactionsDuplicates) transaction(s) déjà existante(s)"
            }
            
            if message.isEmpty {
                message = "Aucune donnée à importer"
            }
            
            importMessage = message
            importSuccess = articlesImported > 0 || transactionsImported > 0
            showingImportAlert = true
            
        } catch {
            importMessage = "Erreur lors de l'import: \(error.localizedDescription)"
            importSuccess = false
            showingImportAlert = true
        }
    }
    
    // MARK: - Fonctions d'export
    
    private func generateFileName(extension ext: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = dateFormatter.string(from: Date())
        return "commerce_\(dateStr).\(ext)"
    }
    
    // MARK: - Export PDF
    private func exportPDF() {
        let pdfData = generatePDFData()
        
        let fileName = generateFileName(extension: "pdf")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: tempURL)
            exportURL = ExportURLWrapper(url: tempURL)
        } catch {
            exportAlertMessage = "Erreur lors de la création du PDF: \(error.localizedDescription)"
            showingExportAlert = true
        }
    }
    
    private func generatePDFData() -> Data {
        let pageWidth: CGFloat = 595.2 // A4 width
        let pageHeight: CGFloat = 841.8 // A4 height
        let margin: CGFloat = 50
        
        let pdfMetaData = [
            kCGPDFContextCreator: "Materiel App",
            kCGPDFContextAuthor: "Materiel",
            kCGPDFContextTitle: "Commerce - Articles & Transactions"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        let dateFormatterShort = DateFormatter()
        dateFormatterShort.dateStyle = .short
        dateFormatterShort.timeStyle = .short
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = margin
            
            // Titre
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let title = "Commerce - Rapport"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.systemTeal
            ]
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 35
            
            // Date d'export
            let subtitleFont = UIFont.systemFont(ofSize: 14)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.gray
            ]
            let exportDateText = "Exporté le \(dateFormatter.string(from: Date()))"
            exportDateText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition += 40
            
            // === SECTION ARTICLES ===
            let headerFont = UIFont.boldSystemFont(ofSize: 18)
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ]
            "ARTICLES (\(dataManager.articlesCommerce.count))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 30
            
            let bodyFont = UIFont.systemFont(ofSize: 11)
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.darkGray
            ]
            let boldFont = UIFont.boldSystemFont(ofSize: 11)
            let boldAttributes: [NSAttributedString.Key: Any] = [
                .font: boldFont,
                .foregroundColor: UIColor.black
            ]
            
            for article in dataManager.articlesCommerce.sorted(by: { $0.nom < $1.nom }) {
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = margin
                }
                
                // Nom de l'article
                article.nom.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: boldAttributes)
                yPosition += 16
                
                // Détails
                let details = "  Catégorie: \(article.categorie) | Réf: \(article.reference.isEmpty ? "-" : article.reference)"
                details.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 14
                
                let prixUnit = article.venteAuPoids ? "/kg" : ""
                let prix = String(format: "  Achat: %.2f€ HT%@ | Vente: %.2f€ TTC%@ | Marge: %.0f%%", article.prixAchatHT, prixUnit, article.prixVenteTTC, prixUnit, article.margePourcentage)
                prix.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 14
                
                let stock: String
                if article.venteAuPoids {
                    stock = String(format: "  Stock: %.2f kg (alerte ≤ %.2f kg)", article.stockEnKg, article.seuilAlerteStockKg)
                } else {
                    stock = "  Stock: \(article.quantiteEnStock) (alerte ≤ \(article.seuilAlerteStock))"
                }
                let stockColor = article.stockEstBas ? UIColor.systemOrange : UIColor.darkGray
                let stockAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: stockColor]
                stock.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: stockAttributes)
                yPosition += 30  // Saut de ligne entre chaque article
            }
            
            // === SECTION TRANSACTIONS ===
            yPosition += 20
            if yPosition > pageHeight - 150 {
                context.beginPage()
                yPosition = margin
            }
            
            "TRANSACTIONS (\(dataManager.transactionsCommerce.count))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 30
            
            let greenAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.systemGreen]
            let redAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.systemRed]
            
            for transaction in dataManager.transactionsCommerce.sorted(by: { $0.dateTransaction > $1.dateTransaction }) {
                if yPosition > pageHeight - 80 {
                    context.beginPage()
                    yPosition = margin
                }
                
                let isVente = transaction.typeTransaction == .vente
                let typeStr = isVente ? "VENTE" : "ACHAT"
                let dateStr = dateFormatterShort.string(from: transaction.dateTransaction)
                let montantStr = String(format: "%.2f€", transaction.montantTTC)
                let prefix = isVente ? "+" : "-"
                
                let line = "\(typeStr) - \(dateStr)"
                line.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: boldAttributes)
                "\(prefix)\(montantStr)".draw(at: CGPoint(x: pageWidth - margin - 80, y: yPosition), withAttributes: isVente ? greenAttributes : redAttributes)
                yPosition += 16
                
                let quantiteStr: String
                if transaction.venteAuPoids {
                    quantiteStr = String(format: "%.2f kg", transaction.poids)
                } else {
                    quantiteStr = "x\(transaction.quantite)"
                }
                let articleLine = "  \(transaction.nomArticle) \(quantiteStr)"
                articleLine.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 14
                
                if !transaction.clientFournisseur.isEmpty {
                    let clientLine = "  \(isVente ? "Client" : "Fournisseur"): \(transaction.clientFournisseur)"
                    clientLine.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 14
                }
                
                if !transaction.estPaye {
                    let nonPaye = "  ⚠ Non payé"
                    let warningAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.systemOrange]
                    nonPaye.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: warningAttributes)
                    yPosition += 14
                }
                
                yPosition += 20  // Saut de ligne entre chaque transaction
            }
            
            // === RÉSUMÉ ===
            yPosition += 20
            if yPosition > pageHeight - 100 {
                context.beginPage()
                yPosition = margin
            }
            
            "RÉSUMÉ".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            let totalVentes = dataManager.transactionsCommerce.filter { $0.typeTransaction == .vente }.reduce(0) { $0 + $1.montantTTC }
            let totalAchats = dataManager.transactionsCommerce.filter { $0.typeTransaction == .achat }.reduce(0) { $0 + $1.montantTTC }
            let benefice = totalVentes - totalAchats
            
            String(format: "Total Ventes: %.2f €", totalVentes).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: greenAttributes)
            yPosition += 18
            String(format: "Total Achats: %.2f €", totalAchats).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: redAttributes)
            yPosition += 18
            
            let beneficeColor = benefice >= 0 ? UIColor.systemBlue : UIColor.systemRed
            let beneficeAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: beneficeColor]
            String(format: "Bénéfice: %.2f €", benefice).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: beneficeAttributes)
        }
        
        return data
    }
    
    // MARK: - Export JSON
    private func exportJSON() {
        let exportData = CommerceExportData(
            dateExport: Date(),
            articles: dataManager.articlesCommerce,
            transactions: dataManager.transactionsCommerce
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(exportData)
            let fileName = generateFileName(extension: "json")
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            exportURL = ExportURLWrapper(url: tempURL)
        } catch {
            exportAlertMessage = "Erreur lors de l'export JSON: \(error.localizedDescription)"
            showingExportAlert = true
        }
    }
    
    // MARK: - Export CSV
    private func exportCSV() {
        // BOM UTF-8 pour que Excel reconnaisse correctement l'encodage
        let bom = "\u{FEFF}"
        var csvContent = bom
        
        // En-tête Articles
        csvContent += "ARTICLES\n"
        csvContent += "Nom;Catégorie;Référence;Prix Achat HT;TVA Achat;Prix Vente HT;TVA Vente;Prix Vente TTC;Marge %;Mode Vente;Stock;Seuil Alerte;Fournisseur\n"
        
        for article in dataManager.articlesCommerce.sorted(by: { $0.nom < $1.nom }) {
            let modeVente = article.venteAuPoids ? "Au poids (kg)" : "À l'unité"
            let stock = article.venteAuPoids ? formatNumber(article.stockEnKg) + " kg" : "\(article.quantiteEnStock)"
            let seuil = article.venteAuPoids ? formatNumber(article.seuilAlerteStockKg) + " kg" : "\(article.seuilAlerteStock)"
            let line = "\"\(escapeCSV(article.nom))\";\"\(escapeCSV(article.categorie))\";\"\(escapeCSV(article.reference))\";\(formatNumber(article.prixAchatHT));\(article.tauxTVAAchat.pourcentage);\(formatNumber(article.prixVenteHT));\(article.tauxTVAVente.pourcentage);\(formatNumber(article.prixVenteTTC));\(formatNumber(article.margePourcentage));\(modeVente);\(stock);\(seuil);\"\(escapeCSV(article.fournisseur))\"\n"
            csvContent += line
        }
        
        // Séparateur
        csvContent += "\n\n"
        
        // En-tête Transactions
        csvContent += "TRANSACTIONS\n"
        csvContent += "Date;Type;Article;Quantité/Poids;Prix Unitaire HT;TVA;Montant TTC;Mode Paiement;Client/Fournisseur;Payé;Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        
        for transaction in dataManager.transactionsCommerce.sorted(by: { $0.dateTransaction > $1.dateTransaction }) {
            let typeStr = transaction.typeTransaction == .vente ? "Vente" : "Achat"
            let paye = transaction.estPaye ? "Oui" : "Non"
            let quantiteOuPoids = transaction.venteAuPoids ? formatNumber(transaction.poids) + " kg" : "\(transaction.quantite)"
            let line = "\(dateFormatter.string(from: transaction.dateTransaction));\(typeStr);\"\(escapeCSV(transaction.nomArticle))\";\(quantiteOuPoids);\(formatNumber(transaction.prixUnitaireHT));\(transaction.tauxTVA.pourcentage);\(formatNumber(transaction.montantTTC));\(transaction.modePaiement.localizedName);\"\(escapeCSV(transaction.clientFournisseur))\";\(paye);\"\(escapeCSV(transaction.notes))\"\n"
            csvContent += line
        }
        
        // Résumé
        csvContent += "\n\nRÉSUMÉ\n"
        let totalVentes = dataManager.transactionsCommerce.filter { $0.typeTransaction == .vente }.reduce(0) { $0 + $1.montantTTC }
        let totalAchats = dataManager.transactionsCommerce.filter { $0.typeTransaction == .achat }.reduce(0) { $0 + $1.montantTTC }
        csvContent += "Total Ventes TTC;\(formatNumber(totalVentes))\n"
        csvContent += "Total Achats TTC;\(formatNumber(totalAchats))\n"
        csvContent += "Bénéfice;\(formatNumber(totalVentes - totalAchats))\n"
        
        let fileName = generateFileName(extension: "csv")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = ExportURLWrapper(url: tempURL)
        } catch {
            exportAlertMessage = "Erreur lors de l'export CSV: \(error.localizedDescription)"
            showingExportAlert = true
        }
    }
    
    private func escapeCSV(_ text: String) -> String {
        return text.replacingOccurrences(of: "\"", with: "\"\"")
    }
    
    private func formatNumber(_ value: Double) -> String {
        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Structure pour export JSON
struct CommerceExportData: Codable {
    let dateExport: Date
    let articles: [ArticleCommerce]
    let transactions: [TransactionCommerce]
}

// MARK: - Alerte paiements à venir
struct AlertePaiementsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var isExpanded = false
    @State private var selectedTransaction: TransactionCommerce?
    
    // Transactions avec paiements dus aujourd'hui ou en retard
    private var transactionsAlerte: [TransactionCommerce] {
        dataManager.transactionsCommerce.filter { transaction in
            guard !transaction.estPaye, let dateReglement = transaction.dateReglement else { return false }
            let calendar = Calendar.current
            let aujourdhui = calendar.startOfDay(for: Date())
            let dateReglementJour = calendar.startOfDay(for: dateReglement)
            // Inclure les paiements en retard OU dus aujourd'hui
            return dateReglementJour <= aujourdhui
        }
        .sorted { ($0.dateReglement ?? Date()) < ($1.dateReglement ?? Date()) }
    }
    
    // Transactions en retard (avant aujourd'hui)
    private var transactionsEnRetard: [TransactionCommerce] {
        transactionsAlerte.filter { $0.paiementEnRetard }
    }
    
    // Transactions dues aujourd'hui
    private var transactionsDuesAujourdhui: [TransactionCommerce] {
        transactionsAlerte.filter { transaction in
            guard let dateReglement = transaction.dateReglement else { return false }
            return Calendar.current.isDateInToday(dateReglement)
        }
    }
    
    var body: some View {
        if !transactionsAlerte.isEmpty {
            VStack(spacing: 0) {
                // Bandeau d'alerte moderne cliquable
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 14) {
                        // Icône avec cercle de fond
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: transactionsEnRetard.isEmpty ? "bell.badge.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .symbolEffect(.pulse, options: .repeating)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            if !transactionsEnRetard.isEmpty {
                                Text(LocalizedStringKey("Paiements en retard"))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            } else {
                                Text(LocalizedStringKey("Paiements du jour"))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            
                            Text(alerteDescription)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        
                        Spacer()
                        
                        // Badge moderne avec le nombre
                        HStack(spacing: 6) {
                            Text("\(transactionsAlerte.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(transactionsEnRetard.isEmpty ? Color.orange : Color.red)
                            
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            // Fond avec dégradé moderne
                            RoundedRectangle(cornerRadius: isExpanded ? 16 : 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: transactionsEnRetard.isEmpty ?
                                            [Color.orange, Color.orange.opacity(0.85), Color.yellow.opacity(0.7)] :
                                            [Color.red, Color.red.opacity(0.85), Color.pink.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Effet de brillance subtil
                            RoundedRectangle(cornerRadius: isExpanded ? 16 : 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.15), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                    )
                    .shadow(color: (transactionsEnRetard.isEmpty ? Color.orange : Color.red).opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, isExpanded ? 0 : 8)
                
                // Liste détaillée (expandable)
                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(transactionsAlerte) { transaction in
                            Button(action: {
                                selectedTransaction = transaction
                            }) {
                                AlertePaiementRowView(transaction: transaction)
                            }
                            .buttonStyle(.plain)
                            
                            if transaction.id != transactionsAlerte.last?.id {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                    ))
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionFormView(mode: .edit, typeTransaction: transaction.typeTransaction, transaction: transaction)
            }
        }
    }
    
    private var alerteDescription: String {
        var parts: [String] = []
        
        if !transactionsEnRetard.isEmpty {
            let count = transactionsEnRetard.count
            let montant = transactionsEnRetard.reduce(0) { $0 + $1.montantTTC }
            parts.append(String(format: NSLocalizedString("%d en retard (%.2f €)", comment: ""), count, montant))
        }
        
        if !transactionsDuesAujourdhui.isEmpty {
            let count = transactionsDuesAujourdhui.count
            let montant = transactionsDuesAujourdhui.reduce(0) { $0 + $1.montantTTC }
            parts.append(String(format: NSLocalizedString("%d aujourd'hui (%.2f €)", comment: ""), count, montant))
        }
        
        return parts.joined(separator: " • ")
    }
}

// MARK: - Ligne d'alerte paiement
struct AlertePaiementRowView: View {
    @EnvironmentObject var dataManager: DataManager
    let transaction: TransactionCommerce
    
    private var joursRestants: Int {
        guard let dateReglement = transaction.dateReglement else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: dateReglement))
        return components.day ?? 0
    }
    
    private var statutText: String {
        if joursRestants < 0 {
            return String(format: NSLocalizedString("%d jour(s) de retard", comment: ""), abs(joursRestants))
        } else if joursRestants == 0 {
            return NSLocalizedString("Aujourd'hui", comment: "")
        } else if joursRestants == 1 {
            return NSLocalizedString("Demain", comment: "")
        } else {
            return String(format: NSLocalizedString("Dans %d jours", comment: ""), joursRestants)
        }
    }
    
    private var statutColor: Color {
        if joursRestants < 0 {
            return .red
        } else if joursRestants == 0 {
            return .orange
        } else {
            return .yellow
        }
    }
    
    private var statutGradient: LinearGradient {
        if joursRestants < 0 {
            return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        } else if joursRestants == 0 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.yellow, .orange.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icône type transaction moderne
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: transaction.typeTransaction == .vente ?
                                [Color.green.opacity(0.2), Color.green.opacity(0.1)] :
                                [Color.red.opacity(0.2), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                
                Image(systemName: transaction.typeTransaction.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(transaction.typeTransaction == .vente ? Color.green : Color.red)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(transaction.nomArticle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    // Client/Fournisseur avec icône
                    if !transaction.clientFournisseur.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                            Text(transaction.clientFournisseur)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    // Séparateur
                    if !transaction.clientFournisseur.isEmpty && transaction.dateReglement != nil {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                    
                    // Date de règlement avec icône
                    if let dateReglement = transaction.dateReglement {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(dateReglement, style: .date)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                // Montant avec style moderne
                Text(String(format: "%.2f €", transaction.montantTTC))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(transaction.typeTransaction == .vente ? Color.green : Color.primary)
                
                // Badge de statut moderne
                Text(statutText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statutGradient)
                            .shadow(color: statutColor.opacity(0.4), radius: 2, x: 0, y: 1)
                    )
            }
            
            // Chevron pour indiquer que c'est cliquable
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Résumé commerce
struct CommerceResumeView: View {
    @EnvironmentObject var dataManager: DataManager
    
    private var ventesAujourdhui: Double {
        let today = Calendar.current.startOfDay(for: Date())
        return dataManager.transactionsCommerce
            .filter { $0.typeTransaction == .vente && Calendar.current.isDate($0.dateTransaction, inSameDayAs: today) }
            .reduce(0) { $0 + $1.montantTTC }
    }
    
    private var achatsAujourdhui: Double {
        let today = Calendar.current.startOfDay(for: Date())
        return dataManager.transactionsCommerce
            .filter { $0.typeTransaction == .achat && Calendar.current.isDate($0.dateTransaction, inSameDayAs: today) }
            .reduce(0) { $0 + $1.montantTTC }
    }
    
    private var articlesStockBas: Int {
        dataManager.articlesCommerce.filter { $0.stockEstBas }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Ventes du jour
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(LocalizedStringKey("Ventes"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(String(format: "%.2f €", ventesAujourdhui))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)
            
            // Achats du jour
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(LocalizedStringKey("Achats"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(String(format: "%.2f €", achatsAujourdhui))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)
            
            // Alertes stock
            if articlesStockBas > 0 {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(LocalizedStringKey("Stock"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(articlesStockBas)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Liste des articles
struct ArticlesListView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var showingAddArticle: Bool
    @State private var searchText = ""
    @State private var selectedCategorie = "Toutes"
    @State private var selectedFournisseur = "Tous"
    @State private var articleToEdit: ArticleCommerce?
    @State private var articleToDelete: ArticleCommerce?
    @State private var showingDeleteAlert = false
    @State private var articleForQuickSale: ArticleCommerce?
    @State private var showingActionSheet = false
    @State private var selectedArticle: ArticleCommerce?
    
    private var categories: [String] {
        var cats = ["Toutes"]
        cats.append(contentsOf: Set(dataManager.articlesCommerce.map { $0.categorie }).sorted())
        return cats
    }
    
    private var fournisseurs: [String] {
        var fours = ["Tous"]
        fours.append(contentsOf: Set(dataManager.articlesCommerce.compactMap { $0.fournisseur.isEmpty ? nil : $0.fournisseur }).sorted())
        return fours
    }
    
    private var filteredArticles: [ArticleCommerce] {
        var articles = dataManager.articlesCommerce
        
        if selectedCategorie != "Toutes" {
            articles = articles.filter { $0.categorie == selectedCategorie }
        }
        
        if selectedFournisseur != "Tous" {
            articles = articles.filter { $0.fournisseur == selectedFournisseur }
        }
        
        if !searchText.isEmpty {
            articles = articles.filter {
                $0.nom.localizedCaseInsensitiveContains(searchText) ||
                $0.reference.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return articles.sorted { $0.nom < $1.nom }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barre de recherche et filtre
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(LocalizedStringKey("Rechercher un article"), text: $searchText)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Menu filtre par catégorie
                Menu {
                    ForEach(categories, id: \.self) { cat in
                        Button(action: { selectedCategorie = cat }) {
                            HStack {
                                Text(cat)
                                if selectedCategorie == cat {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundStyle(selectedCategorie != "Toutes" ? .teal : .gray)
                }
                
                // Menu filtre par fournisseur
                if fournisseurs.count > 1 {
                    Menu {
                        ForEach(fournisseurs, id: \.self) { four in
                            Button(action: { selectedFournisseur = four }) {
                                HStack {
                                    Text(four)
                                    if selectedFournisseur == four {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "person.2.fill")
                            .font(.title2)
                            .foregroundStyle(selectedFournisseur != "Tous" ? .orange : .gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            if filteredArticles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(LocalizedStringKey("Aucun article"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button(action: { showingAddArticle = true }) {
                        Label(LocalizedStringKey("Ajouter un article"), systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.teal)
                            .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(filteredArticles) { article in
                        ArticleRowView(article: article)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedArticle = article
                                showingActionSheet = true
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    articleToDelete = article
                                    showingDeleteAlert = true
                                } label: {
                                    Label(LocalizedStringKey("Supprimer"), systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    articleForQuickSale = article
                                } label: {
                                    Label(LocalizedStringKey("Vendre"), systemImage: "cart.badge.plus")
                                }
                                .tint(.green)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $articleToEdit) { article in
            ArticleFormView(mode: .edit, article: article)
        }
        .sheet(item: $articleForQuickSale) { article in
            QuickSaleView(article: article)
        }
        .confirmationDialog(
            LocalizedStringKey("Que souhaitez-vous faire ?"),
            isPresented: $showingActionSheet,
            titleVisibility: .visible
        ) {
            Button {
                if let article = selectedArticle {
                    articleForQuickSale = article
                }
            } label: {
                Label(LocalizedStringKey("Vendre"), systemImage: "cart.badge.plus")
            }
            
            Button {
                if let article = selectedArticle {
                    articleToEdit = article
                }
            } label: {
                Label(LocalizedStringKey("Consulter / Modifier"), systemImage: "eye")
            }
            
            Button(LocalizedStringKey("Annuler"), role: .cancel) { }
        } message: {
            if let article = selectedArticle {
                Text(article.nom)
            }
        }
        .alert(LocalizedStringKey("Supprimer l'article ?"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Annuler"), role: .cancel) { }
            Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                if let article = articleToDelete {
                    dataManager.supprimerArticleCommerce(article)
                }
            }
        } message: {
            Text(LocalizedStringKey("Cette action est irréversible."))
        }
    }
}

// MARK: - Ligne d'article
struct ArticleRowView: View {
    let article: ArticleCommerce
    
    var body: some View {
        HStack(spacing: 12) {
            // Photo ou icône
            if let photoData = article.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "cube.box.fill")
                        .foregroundColor(.teal)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(article.nom)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(article.categorie)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !article.reference.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(article.reference)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    // Prix de vente
                    Text(String(format: "%.2f € TTC\(article.venteAuPoids ? "/kg" : "")", article.prixVenteTTC))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.teal)
                    
                    // Stock
                    HStack(spacing: 4) {
                        Image(systemName: article.venteAuPoids ? "scalemass.fill" : (article.stockEstBas ? "exclamationmark.triangle.fill" : "cube.fill"))
                            .font(.caption)
                            .foregroundColor(article.stockEstBas ? .orange : .gray)
                        if article.venteAuPoids {
                            Text(String(format: "%.2f kg", article.stockEnKg))
                                .font(.caption)
                                .foregroundColor(article.stockEstBas ? .orange : .gray)
                        } else {
                            Text("\(article.quantiteEnStock)")
                                .font(.caption)
                                .foregroundColor(article.stockEstBas ? .orange : .gray)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Marge
            VStack(alignment: .trailing, spacing: 2) {
                Text(LocalizedStringKey("Marge"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f%%", article.margePourcentage))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(article.margeHT >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Liste des transactions
struct TransactionsListView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var transactionToAdd: TransactionTypeWrapper?
    @State private var filterType: String = "Toutes"
    @State private var filterPaiement: String = "Tous"
    @State private var transactionToEdit: TransactionCommerce?
    @State private var transactionToDelete: TransactionCommerce?
    @State private var showingDeleteAlert = false
    
    private var filteredTransactions: [TransactionCommerce] {
        var transactions = dataManager.transactionsCommerce
        
        // Filtre par type
        if filterType == "Achats" {
            transactions = transactions.filter { $0.typeTransaction == .achat }
        } else if filterType == "Ventes" {
            transactions = transactions.filter { $0.typeTransaction == .vente }
        }
        
        // Filtre par statut de paiement
        if filterPaiement == "Payé" {
            transactions = transactions.filter { $0.estPaye }
        } else if filterPaiement == "Non payé" {
            transactions = transactions.filter { !$0.estPaye }
        }
        
        return transactions.sorted { $0.dateTransaction > $1.dateTransaction }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filtre par type
            Picker("", selection: $filterType) {
                Text(LocalizedStringKey("Toutes")).tag("Toutes")
                Text(LocalizedStringKey("Ventes")).tag("Ventes")
                Text(LocalizedStringKey("Achats")).tag("Achats")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Filtre par statut de paiement
            Picker("", selection: $filterPaiement) {
                Text(LocalizedStringKey("Tous")).tag("Tous")
                Text(LocalizedStringKey("Payé")).tag("Payé")
                Text(LocalizedStringKey("Non payé")).tag("Non payé")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Afficher le total des non payés
            if filterPaiement == "Non payé" && !filteredTransactions.isEmpty {
                let ventesNonPayees = filteredTransactions.filter { $0.typeTransaction == .vente }.reduce(0) { $0 + $1.montantTTC }
                let achatsNonPayes = filteredTransactions.filter { $0.typeTransaction == .achat }.reduce(0) { $0 + $1.montantTTC }
                let soldeNet = ventesNonPayees - achatsNonPayes
                
                // Affichage adapté selon le filtre de type
                if filterType == "Toutes" {
                    HStack(spacing: 8) {
                        // À recevoir (ventes)
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(String(format: "%.2f €", ventesNonPayees))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Text("•").foregroundColor(.secondary)
                        
                        // À payer (achats)
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(String(format: "%.2f €", achatsNonPayes))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                        
                        Text("•").foregroundColor(.secondary)
                        
                        // Solde net
                        HStack(spacing: 4) {
                            Image(systemName: soldeNet >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                                .foregroundColor(soldeNet >= 0 ? .blue : .orange)
                                .font(.caption)
                            Text(String(format: "%.2f €", abs(soldeNet)))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(soldeNet >= 0 ? .blue : .orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 8)
                } else {
                    // Filtre Achats ou Ventes uniquement : affichage simple
                    let totalNonPaye = filteredTransactions.reduce(0) { $0 + $1.montantTTC }
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text(LocalizedStringKey("Total non payé :"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", totalNonPaye))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            
            if filteredTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(LocalizedStringKey("Aucune transaction"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button(action: {
                            transactionToAdd = TransactionTypeWrapper(type: .achat)
                        }) {
                            Label(LocalizedStringKey("Achat"), systemImage: "arrow.down.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        Button(action: {
                            transactionToAdd = TransactionTypeWrapper(type: .vente)
                        }) {
                            Label(LocalizedStringKey("Vente"), systemImage: "arrow.up.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(filteredTransactions) { transaction in
                        TransactionRowView(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                transactionToEdit = transaction
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showingDeleteAlert = true
                                } label: {
                                    Label(LocalizedStringKey("Supprimer"), systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $transactionToEdit) { transaction in
            TransactionFormView(mode: .edit, typeTransaction: transaction.typeTransaction, transaction: transaction)
        }
        .alert(LocalizedStringKey("Supprimer la transaction ?"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Annuler"), role: .cancel) { }
            Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                if let transaction = transactionToDelete {
                    dataManager.supprimerTransactionCommerce(transaction)
                }
            }
        } message: {
            Text(LocalizedStringKey("Cette action est irréversible."))
        }
    }
}

// MARK: - Ligne de transaction
struct TransactionRowView: View {
    let transaction: TransactionCommerce
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône type
            ZStack {
                Circle()
                    .fill(transaction.typeTransaction == .vente ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: transaction.typeTransaction.icon)
                    .foregroundColor(transaction.typeTransaction == .vente ? .green : .red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.nomArticle)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text("x\(transaction.quantite)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !transaction.clientFournisseur.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(transaction.clientFournisseur)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Text(dateFormatter.string(from: transaction.dateTransaction))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%@%.2f €", transaction.typeTransaction == .vente ? "+" : "-", transaction.montantTTC))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.typeTransaction == .vente ? .green : .red)
                
                if transaction.typeRemise != .aucune {
                    Text(LocalizedStringKey("Remise appliquée"))
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                if !transaction.estPaye {
                    Text(LocalizedStringKey("Non payé"))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formulaire Article
struct ArticleFormView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case add, edit
    }
    
    let mode: Mode
    var article: ArticleCommerce?
    
    @State private var nom = ""
    @State private var description = ""
    @State private var categorie = ""
    @State private var categoriePersonnalisee = ""
    @State private var reference = ""
    @State private var prixAchatHT = ""
    @State private var prixAchatTTC = ""
    @State private var tauxTVAAchat: TauxTVA = .tva20
    @State private var prixVenteHT = ""
    @State private var prixVenteTTC = ""
    @State private var tauxTVAVente: TauxTVA = .tva20
    @State private var quantiteEnStock = ""
    @State private var seuilAlerteStock = "5"
    @State private var fournisseur = ""
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var showingNewCategorieAlert = false
    @State private var showingNewFournisseurAlert = false
    @State private var fournisseurPersonnalise = ""
    
    // Vente au poids
    @State private var venteAuPoids = false
    @State private var stockEnKg = ""
    @State private var seuilAlerteStockKg = "1.0"
    
    // Focus pour gérer le calcul HT/TTC uniquement quand on quitte le champ
    enum PrixField {
        case achatHT, achatTTC, venteHT, venteTTC
    }
    @FocusState private var focusedPrixField: PrixField?
    
    // Fonctions de calcul HT <-> TTC
    private func calculerTTCDepuisHT(_ ht: String, tva: TauxTVA) -> String {
        let htValue = Double(ht.replacingOccurrences(of: ",", with: ".")) ?? 0
        let ttc = htValue * (1 + tva.valeur)
        return ttc > 0 ? String(format: "%.2f", ttc) : ""
    }
    
    private func calculerHTDepuisTTC(_ ttc: String, tva: TauxTVA) -> String {
        let ttcValue = Double(ttc.replacingOccurrences(of: ",", with: ".")) ?? 0
        let ht = ttcValue / (1 + tva.valeur)
        return ht > 0 ? String(format: "%.2f", ht) : ""
    }
    
    private var isFormValid: Bool {
        !nom.isEmpty && (!prixVenteHT.isEmpty || !prixVenteTTC.isEmpty)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Photo
                Section {
                    VStack(spacing: 12) {
                        if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Button(role: .destructive) {
                                self.photoData = nil
                            } label: {
                                Label(LocalizedStringKey("Retirer la photo"), systemImage: "trash")
                                    .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .frame(height: 100)
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.teal)
                                    Text(LocalizedStringKey("Photo de l'article"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button(action: { showCameraPicker = true }) {
                                    Label(LocalizedStringKey("Appareil photo"), systemImage: "camera.fill")
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button(action: { showPhotoLibraryPicker = true }) {
                                Label(LocalizedStringKey("Galerie"), systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Informations générales
                Section(header: Text(LocalizedStringKey("Informations"))) {
                    TextField(LocalizedStringKey("Nom de l'article"), text: $nom)
                    TextField(LocalizedStringKey("Référence / SKU"), text: $reference)
                    TextField(LocalizedStringKey("Description"), text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                // Catégorie
                Section(header: Text(LocalizedStringKey("Catégorie"))) {
                    Picker(LocalizedStringKey("Catégorie"), selection: $categorie) {
                        Text(LocalizedStringKey("Sélectionner...")).tag("")
                        ForEach(dataManager.toutesLesCategoriesCommerce, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                        Text(LocalizedStringKey("+ Nouvelle catégorie")).tag("__new__")
                    }
                    .onChange(of: categorie) { _, newValue in
                        if newValue == "__new__" {
                            showingNewCategorieAlert = true
                        }
                    }
                }
                
                // Mode de vente (unité ou poids)
                Section(header: Text(LocalizedStringKey("Mode de vente"))) {
                    Toggle(isOn: $venteAuPoids) {
                        HStack {
                            Image(systemName: venteAuPoids ? "scalemass.fill" : "number.square.fill")
                                .foregroundColor(venteAuPoids ? .orange : .blue)
                            Text(venteAuPoids ? LocalizedStringKey("Vente au poids (kg)") : LocalizedStringKey("Vente à l'unité"))
                        }
                    }
                    .tint(.orange)
                    
                    if venteAuPoids {
                        Text(LocalizedStringKey("Les prix seront calculés au kilogramme"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Prix d'achat
                Section(header: Text(venteAuPoids ? LocalizedStringKey("Prix d'achat (par kg)") : LocalizedStringKey("Prix d'achat"))) {
                    HStack {
                        TextField(LocalizedStringKey("Prix HT"), text: $prixAchatHT)
                            .keyboardType(.decimalPad)
                            .focused($focusedPrixField, equals: .achatHT)
                        Text("€ HT")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker(LocalizedStringKey("TVA Achat"), selection: $tauxTVAAchat) {
                        ForEach(TauxTVA.allCases, id: \.self) { taux in
                            Text(taux.pourcentage).tag(taux)
                        }
                    }
                    .onChange(of: tauxTVAAchat) { _, newTaux in
                        if !prixAchatHT.isEmpty {
                            prixAchatTTC = calculerTTCDepuisHT(prixAchatHT, tva: newTaux)
                        }
                    }
                    
                    HStack {
                        TextField(LocalizedStringKey("Prix TTC"), text: $prixAchatTTC)
                            .keyboardType(.decimalPad)
                            .focused($focusedPrixField, equals: .achatTTC)
                        Text("€ TTC")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Prix de vente
                Section(header: Text(venteAuPoids ? LocalizedStringKey("Prix de vente (par kg)") : LocalizedStringKey("Prix de vente"))) {
                    HStack {
                        TextField(LocalizedStringKey("Prix HT"), text: $prixVenteHT)
                            .keyboardType(.decimalPad)
                            .focused($focusedPrixField, equals: .venteHT)
                        Text("€ HT")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker(LocalizedStringKey("TVA Vente"), selection: $tauxTVAVente) {
                        ForEach(TauxTVA.allCases, id: \.self) { taux in
                            Text(taux.pourcentage).tag(taux)
                        }
                    }
                    .onChange(of: tauxTVAVente) { _, newTaux in
                        if !prixVenteHT.isEmpty {
                            prixVenteTTC = calculerTTCDepuisHT(prixVenteHT, tva: newTaux)
                        }
                    }
                    
                    HStack {
                        TextField(LocalizedStringKey("Prix TTC"), text: $prixVenteTTC)
                            .keyboardType(.decimalPad)
                            .focused($focusedPrixField, equals: .venteTTC)
                        Text("€ TTC")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Marge HT"))
                            .foregroundColor(.secondary)
                        Spacer()
                        let achat = Double(prixAchatHT.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let vente = Double(prixVenteHT.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let marge = vente - achat
                        Text(String(format: "%.2f €", marge))
                            .fontWeight(.semibold)
                            .foregroundColor(marge >= 0 ? .green : .red)
                    }
                }
                
                // Stock
                Section(header: Text(LocalizedStringKey("Stock"))) {
                    if venteAuPoids {
                        // Mode poids
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("Stock en kg"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("0.0", text: $stockEnKg)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                Text("kg")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("Seuil d'alerte (kg)"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("1.0", text: $seuilAlerteStockKg)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                Text("kg")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        // Mode unité
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("Quantité en stock"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Button(action: {
                                let current = Int(quantiteEnStock) ?? 0
                                if current > 0 {
                                    quantiteEnStock = "\(current - 1)"
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            
                            TextField("0", text: $quantiteEnStock)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .frame(minWidth: 80)
                            
                            Button(action: {
                                let current = Int(quantiteEnStock) ?? 0
                                quantiteEnStock = "\(current + 1)"
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("Seuil d'alerte"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Button(action: {
                                let current = Int(seuilAlerteStock) ?? 0
                                if current > 0 {
                                    seuilAlerteStock = "\(current - 1)"
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                            
                            TextField("5", text: $seuilAlerteStock)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .frame(minWidth: 80)
                            
                            Button(action: {
                                let current = Int(seuilAlerteStock) ?? 0
                                seuilAlerteStock = "\(current + 1)"
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    } // fin else mode unité
                }
                
                // Fournisseur
                Section(header: Text(LocalizedStringKey("Fournisseur"))) {
                    Picker(LocalizedStringKey("Fournisseur"), selection: $fournisseur) {
                        Text(LocalizedStringKey("Aucun")).tag("")
                        ForEach(dataManager.tousLesFournisseursCommerce, id: \.self) { f in
                            Text(f).tag(f)
                        }
                        Text(LocalizedStringKey("+ Nouveau fournisseur")).tag("__new__")
                    }
                    .onChange(of: fournisseur) { _, newValue in
                        if newValue == "__new__" {
                            showingNewFournisseurAlert = true
                        }
                    }
                }
                
                // Notes
                Section(header: Text(LocalizedStringKey("Notes"))) {
                    TextField(LocalizedStringKey("Notes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(mode == .add ? LocalizedStringKey("Nouvel article") : LocalizedStringKey("Modifier l'article"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("Enregistrer")) {
                        saveArticle()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(action: {
                            focusedPrixField = nil
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .teal)
                        }
                    }
                }
            }
            .onChange(of: focusedPrixField) { oldField, _ in
                // Calculer le prix correspondant quand on quitte un champ
                switch oldField {
                case .achatHT:
                    if !prixAchatHT.isEmpty {
                        prixAchatTTC = calculerTTCDepuisHT(prixAchatHT, tva: tauxTVAAchat)
                    }
                case .achatTTC:
                    if !prixAchatTTC.isEmpty {
                        prixAchatHT = calculerHTDepuisTTC(prixAchatTTC, tva: tauxTVAAchat)
                    }
                case .venteHT:
                    if !prixVenteHT.isEmpty {
                        prixVenteTTC = calculerTTCDepuisHT(prixVenteHT, tva: tauxTVAVente)
                    }
                case .venteTTC:
                    if !prixVenteTTC.isEmpty {
                        prixVenteHT = calculerHTDepuisTTC(prixVenteTTC, tva: tauxTVAVente)
                    }
                case nil:
                    break
                }
            }
            .onAppear {
                if let article = article {
                    nom = article.nom
                    description = article.description
                    categorie = article.categorie
                    reference = article.reference
                    prixAchatHT = String(format: "%.2f", article.prixAchatHT)
                    tauxTVAAchat = article.tauxTVAAchat
                    prixAchatTTC = String(format: "%.2f", article.prixAchatTTC)
                    prixVenteHT = String(format: "%.2f", article.prixVenteHT)
                    tauxTVAVente = article.tauxTVAVente
                    prixVenteTTC = String(format: "%.2f", article.prixVenteTTC)
                    quantiteEnStock = "\(article.quantiteEnStock)"
                    seuilAlerteStock = "\(article.seuilAlerteStock)"
                    fournisseur = article.fournisseur
                    notes = article.notes
                    photoData = article.photoData
                    // Vente au poids
                    venteAuPoids = article.venteAuPoids
                    stockEnKg = String(format: "%.3f", article.stockEnKg)
                    seuilAlerteStockKg = String(format: "%.3f", article.seuilAlerteStockKg)
                }
            }
            .alert(LocalizedStringKey("Nouvelle catégorie"), isPresented: $showingNewCategorieAlert) {
                TextField(LocalizedStringKey("Nom de la catégorie"), text: $categoriePersonnalisee)
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    categorie = ""
                    categoriePersonnalisee = ""
                }
                Button(LocalizedStringKey("Ajouter")) {
                    if !categoriePersonnalisee.isEmpty {
                        dataManager.ajouterCategorieCommerce(categoriePersonnalisee)
                        categorie = categoriePersonnalisee
                        categoriePersonnalisee = ""
                    } else {
                        categorie = ""
                    }
                }
            }
            .alert(LocalizedStringKey("Nouveau fournisseur"), isPresented: $showingNewFournisseurAlert) {
                TextField(LocalizedStringKey("Nom du fournisseur"), text: $fournisseurPersonnalise)
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    fournisseur = ""
                    fournisseurPersonnalise = ""
                }
                Button(LocalizedStringKey("Ajouter")) {
                    if !fournisseurPersonnalise.isEmpty {
                        dataManager.ajouterFournisseurCommerce(fournisseurPersonnalise)
                        fournisseur = fournisseurPersonnalise
                        fournisseurPersonnalise = ""
                    } else {
                        fournisseur = ""
                    }
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                CommerceImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let image = newImage {
                            photoData = image.jpegData(compressionQuality: 0.7)
                        }
                    }
                ), sourceType: .camera)
            }
            .sheet(isPresented: $showPhotoLibraryPicker) {
                CommerceImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let image = newImage {
                            photoData = image.jpegData(compressionQuality: 0.7)
                        }
                    }
                ), sourceType: .photoLibrary)
            }
        }
    }
    
    private func saveArticle() {
        var newArticle = ArticleCommerce(
            id: article?.id ?? UUID(),
            nom: nom,
            description: description,
            categorie: categorie.isEmpty ? "Autre" : categorie,
            reference: reference,
            prixAchatHT: Double(prixAchatHT.replacingOccurrences(of: ",", with: ".")) ?? 0,
            tauxTVAAchat: tauxTVAAchat,
            prixVenteHT: Double(prixVenteHT.replacingOccurrences(of: ",", with: ".")) ?? 0,
            tauxTVAVente: tauxTVAVente,
            quantiteEnStock: Int(quantiteEnStock) ?? 0,
            seuilAlerteStock: Int(seuilAlerteStock) ?? 5,
            fournisseur: fournisseur,
            dateCreation: article?.dateCreation ?? Date(),
            photoData: photoData,
            notes: notes
        )
        
        // Ajouter les propriétés de vente au poids
        newArticle.venteAuPoids = venteAuPoids
        newArticle.stockEnKg = Double(stockEnKg.replacingOccurrences(of: ",", with: ".")) ?? 0
        newArticle.seuilAlerteStockKg = Double(seuilAlerteStockKg.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        
        if mode == .add {
            dataManager.ajouterArticleCommerce(newArticle)
        } else {
            dataManager.modifierArticleCommerce(newArticle)
        }
        
        dismiss()
    }
}

// MARK: - Formulaire Transaction
struct TransactionFormView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case add, edit
    }
    
    let mode: Mode
    let typeTransaction: TypeTransactionCommerce
    var transaction: TransactionCommerce?
    
    @State private var articleId: UUID?
    @State private var nomArticle = ""
    @State private var quantite = "1"
    @State private var poids = "" // Poids en kg pour articles au poids
    @State private var venteAuPoids = false // Mode vente au poids
    @State private var prixUnitaireHT = ""
    @State private var tauxTVA: TauxTVA = .tva20
    @State private var typeRemise: TypeRemise = .aucune
    @State private var valeurRemise = ""
    @State private var modePaiement: ModePaiement = .especes
    @State private var clientFournisseur = ""
    @State private var dateTransaction = Date()
    @State private var notes = ""
    @State private var estPaye = true
    @State private var dateReglement: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date() // Date de règlement par défaut : 30 jours
    @State private var articleSelectionne: ArticleCommerce?
    @State private var filtreFournisseur: String = "Tous" // Filtre par fournisseur pour les achats
    
    private var montantBrutHT: Double {
        let prix = Double(prixUnitaireHT.replacingOccurrences(of: ",", with: ".")) ?? 0
        if venteAuPoids {
            let poidsValue = Double(poids.replacingOccurrences(of: ",", with: ".")) ?? 0
            return ((prix * poidsValue) * 100).rounded() / 100
        } else {
            let qty = Double(quantite) ?? 1
            return ((prix * qty) * 100).rounded() / 100
        }
    }
    
    private var montantBrutTVA: Double {
        return ((montantBrutHT * tauxTVA.valeur) * 100).rounded() / 100
    }
    
    private var montantBrutTTC: Double {
        return ((montantBrutHT + montantBrutTVA) * 100).rounded() / 100
    }
    
    // Remise appliquée sur le TTC
    private var montantRemise: Double {
        let valeur = Double(valeurRemise.replacingOccurrences(of: ",", with: ".")) ?? 0
        switch typeRemise {
        case .aucune: return 0
        case .pourcentage: return ((montantBrutTTC * (valeur / 100)) * 100).rounded() / 100
        case .montantFixe: return min(valeur, montantBrutTTC)
        }
    }
    
    private var montantTTC: Double {
        return ((montantBrutTTC - montantRemise) * 100).rounded() / 100
    }
    
    // Calcul inversé du HT net après remise TTC
    private var montantNetHT: Double {
        return ((montantTTC / (1 + tauxTVA.valeur)) * 100).rounded() / 100
    }
    
    private var montantTVA: Double {
        return ((montantTTC - montantNetHT) * 100).rounded() / 100
    }
    
    private var isFormValid: Bool {
        if venteAuPoids {
            let poidsValue = Double(poids.replacingOccurrences(of: ",", with: ".")) ?? 0
            return !nomArticle.isEmpty && !prixUnitaireHT.isEmpty && poidsValue > 0
        } else {
            return !nomArticle.isEmpty && !prixUnitaireHT.isEmpty && (Int(quantite) ?? 0) > 0
        }
    }
    
    // Vérifie si c'est une transaction validée (payée) - dans ce cas, seul le mode de paiement est modifiable
    private var isTransactionValidee: Bool {
        mode == .edit && (transaction?.estPaye ?? false)
    }
    
    // Liste des fournisseurs existants (depuis les fournisseurs personnalisés, les articles et les transactions d'achat)
    private var fournisseursExistants: [String] {
        var fournisseurs = Set<String>()
        
        // Fournisseurs personnalisés (créés dans Gestion Fournisseurs)
        for fournisseur in dataManager.fournisseursCommercePersonnalises {
            fournisseurs.insert(fournisseur)
        }
        
        // Fournisseurs des articles
        for article in dataManager.articlesCommerce {
            if !article.fournisseur.isEmpty {
                fournisseurs.insert(article.fournisseur)
            }
        }
        
        // Fournisseurs des transactions d'achat
        for transaction in dataManager.transactionsCommerce where transaction.typeTransaction == .achat {
            if !transaction.clientFournisseur.isEmpty {
                fournisseurs.insert(transaction.clientFournisseur)
            }
        }
        
        // Exclure les fournisseurs de la liste d'exclusion
        return fournisseurs
            .filter { !dataManager.fournisseursCommerceExclus.contains($0) }
            .sorted()
    }
    
    // Liste des fournisseurs pour le filtre (uniquement ceux qui ont des articles)
    private var fournisseursPourFiltre: [String] {
        var fours = ["Tous"]
        let fournisseursArticles = Set(dataManager.articlesCommerce.compactMap { $0.fournisseur.isEmpty ? nil : $0.fournisseur })
            .filter { !dataManager.fournisseursCommerceExclus.contains($0) }
        fours.append(contentsOf: fournisseursArticles.sorted())
        return fours
    }
    
    // Articles filtrés par fournisseur (pour les achats)
    private var articlesFiltres: [ArticleCommerce] {
        if filtreFournisseur == "Tous" {
            return dataManager.articlesCommerce
        } else {
            return dataManager.articlesCommerce.filter { $0.fournisseur == filtreFournisseur }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Type de transaction (info)
                Section {
                    HStack {
                        Image(systemName: typeTransaction.icon)
                            .foregroundColor(typeTransaction == .vente ? .green : .red)
                            .font(.title2)
                        Text(typeTransaction.localizedName)
                            .font(.headline)
                        Spacer()
                    }
                    .listRowBackground(
                        (typeTransaction == .vente ? Color.green : Color.red).opacity(0.1)
                    )
                }
                
                // Sélection article existant ou saisie libre
                Section(header: Text(LocalizedStringKey("Article"))) {
                    if isTransactionValidee {
                        // Transaction validée : affichage en lecture seule
                        HStack {
                            Text(LocalizedStringKey("Article"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(nomArticle)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("Quantité"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(quantite)")
                                .foregroundColor(.primary)
                        }
                        
                        Text(LocalizedStringKey("Transaction validée - Article et quantité non modifiables"))
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                    if !dataManager.articlesCommerce.isEmpty {
                        // Filtre par fournisseur pour les achats
                        if typeTransaction == .achat && fournisseursPourFiltre.count > 2 {
                            Picker(LocalizedStringKey("Filtrer par fournisseur"), selection: $filtreFournisseur) {
                                ForEach(fournisseursPourFiltre, id: \.self) { four in
                                    Text(four == "Tous" ? NSLocalizedString("Tous les fournisseurs", comment: "") : four).tag(four)
                                }
                            }
                            .onChange(of: filtreFournisseur) { _, newValue in
                                // Réinitialiser l'article sélectionné si le fournisseur change
                                if newValue != "Tous" {
                                    if let currentArticle = dataManager.articlesCommerce.first(where: { $0.id == articleId }),
                                       currentArticle.fournisseur != newValue {
                                        articleId = nil
                                        nomArticle = ""
                                        articleSelectionne = nil
                                    }
                                }
                            }
                        }
                        
                        Picker(LocalizedStringKey("Choisir un article"), selection: $articleId) {
                            Text(LocalizedStringKey("Saisie libre")).tag(nil as UUID?)
                            ForEach(typeTransaction == .achat ? articlesFiltres : dataManager.articlesCommerce) { article in
                                HStack {
                                    if article.venteAuPoids {
                                        Image(systemName: "scalemass.fill")
                                    }
                                    Text("\(article.nom) - \(String(format: "%.2f€", typeTransaction == .vente ? article.prixVenteTTC : article.prixAchatTTC))\(article.venteAuPoids ? "/kg" : "")")
                                }
                                    .tag(article.id as UUID?)
                            }
                        }
                        .onChange(of: articleId) { _, newId in
                            if let id = newId, let article = dataManager.articlesCommerce.first(where: { $0.id == id }) {
                                articleSelectionne = article
                                nomArticle = article.nom
                                venteAuPoids = article.venteAuPoids
                                if typeTransaction == .vente {
                                    prixUnitaireHT = String(format: "%.2f", article.prixVenteHT)
                                    tauxTVA = article.tauxTVAVente
                                } else {
                                    prixUnitaireHT = String(format: "%.2f", article.prixAchatHT)
                                    tauxTVA = article.tauxTVAAchat
                                }
                            } else {
                                // Saisie libre : réinitialiser le mode poids
                                venteAuPoids = false
                            }
                        }
                    }
                    
                    TextField(LocalizedStringKey("Nom de l'article"), text: $nomArticle)
                    
                    // Toggle pour vente au poids (seulement si saisie libre)
                    if articleId == nil {
                        Toggle(isOn: $venteAuPoids) {
                            HStack {
                                Image(systemName: venteAuPoids ? "scalemass.fill" : "number.square.fill")
                                    .foregroundColor(venteAuPoids ? .orange : .blue)
                                Text(venteAuPoids ? LocalizedStringKey("Vente au poids (kg)") : LocalizedStringKey("Vente à l'unité"))
                            }
                        }
                        .tint(.orange)
                    } else if venteAuPoids {
                        // Afficher indication si article au poids sélectionné
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundColor(.orange)
                            Text(LocalizedStringKey("Article vendu au poids"))
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                    
                    if venteAuPoids {
                        // Saisie du poids
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("Poids (kg)"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("0.000", text: $poids)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                Text("kg")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        // Saisie de la quantité
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("Quantité"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Button(action: {
                                let current = Int(quantite) ?? 1
                                if current > 1 {
                                    quantite = "\(current - 1)"
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            
                            TextField("1", text: $quantite)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .frame(minWidth: 80)
                            
                            Button(action: {
                                let current = Int(quantite) ?? 1
                                quantite = "\(current + 1)"
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    } // Fin else mode unité
                    } // Fin du else pour vente non validée
                }
                
                // Prix
                Section(header: Text(venteAuPoids ? LocalizedStringKey("Prix (par kg)") : LocalizedStringKey("Prix"))) {
                    if isTransactionValidee {
                        // Transaction validée : affichage en lecture seule
                        HStack {
                            Text(venteAuPoids ? LocalizedStringKey("Prix par kg HT") : LocalizedStringKey("Prix unitaire HT"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(prixUnitaireHT) € HT\(venteAuPoids ? "/kg" : "")")
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("Taux de TVA"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(tauxTVA.pourcentage)
                                .foregroundColor(.primary)
                        }
                    } else {
                    HStack {
                        TextField(venteAuPoids ? LocalizedStringKey("Prix par kg HT") : LocalizedStringKey("Prix unitaire HT"), text: $prixUnitaireHT)
                            .keyboardType(.decimalPad)
                        Text(venteAuPoids ? "€ HT/kg" : "€ HT")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker(LocalizedStringKey("Taux de TVA"), selection: $tauxTVA) {
                        ForEach(TauxTVA.allCases, id: \.self) { taux in
                            Text(taux.pourcentage).tag(taux)
                        }
                    }
                    }
                }
                
                // Remise
                Section(header: Text(LocalizedStringKey("Remise"))) {
                    if isTransactionValidee {
                        // Transaction validée : affichage en lecture seule
                        HStack {
                            Text(LocalizedStringKey("Type de remise"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(typeRemise.localizedName)
                                .foregroundColor(.primary)
                        }
                        
                        if typeRemise != .aucune {
                            HStack {
                                Text(LocalizedStringKey("Valeur"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(valeurRemise) \(typeRemise == .pourcentage ? "%" : "€")")
                                    .foregroundColor(.primary)
                            }
                        }
                    } else {
                    Picker(LocalizedStringKey("Type de remise"), selection: $typeRemise) {
                        ForEach(TypeRemise.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    
                    if typeRemise != .aucune {
                        HStack {
                            TextField(LocalizedStringKey("Valeur"), text: $valeurRemise)
                                .keyboardType(.decimalPad)
                            Text(typeRemise == .pourcentage ? "%" : "€")
                                .foregroundColor(.secondary)
                        }
                    }
                    }
                }
                
                // Récapitulatif
                Section(header: Text(LocalizedStringKey("Récapitulatif"))) {
                    HStack {
                        Text(LocalizedStringKey("Montant brut HT"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", montantBrutHT))
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("TVA"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f € (%@)", montantBrutTVA, tauxTVA.pourcentage))
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Total brut TTC"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", montantBrutTTC))
                    }
                    
                    if typeRemise != .aucune {
                        HStack {
                            Text(LocalizedStringKey("Remise sur TTC"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "-%.2f €", montantRemise))
                                .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("HT après remise"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f €", montantNetHT))
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("TVA après remise"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f €", montantTVA))
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Total TTC"))
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "%.2f €", montantTTC))
                            .fontWeight(.bold)
                            .foregroundColor(typeTransaction == .vente ? .green : .red)
                    }
                }
                
                // Paiement
                Section(header: Text(LocalizedStringKey("Paiement"))) {
                    Picker(LocalizedStringKey("Mode de paiement"), selection: $modePaiement) {
                        ForEach(ModePaiement.allCases, id: \.self) { mode in
                            Label(mode.localizedName, systemImage: mode.icon).tag(mode)
                        }
                    }
                    
                    Toggle(LocalizedStringKey("Payé"), isOn: $estPaye)
                    
                    // Date de règlement si non payé
                    if !estPaye {
                        DatePicker(
                            LocalizedStringKey("Date de règlement"),
                            selection: $dateReglement,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }
                
                // Client / Fournisseur
                Section(header: Text(typeTransaction == .vente ? LocalizedStringKey("Client") : LocalizedStringKey("Fournisseur"))) {
                    if typeTransaction == .achat && !fournisseursExistants.isEmpty {
                        // Pour les achats, proposer les fournisseurs existants
                        Picker(LocalizedStringKey("Fournisseur existant"), selection: Binding(
                            get: { fournisseursExistants.contains(clientFournisseur) ? clientFournisseur : "" },
                            set: { if !$0.isEmpty { clientFournisseur = $0 } }
                        )) {
                            Text(LocalizedStringKey("Nouveau fournisseur")).tag("")
                            ForEach(fournisseursExistants, id: \.self) { fournisseur in
                                Text(fournisseur).tag(fournisseur)
                            }
                        }
                        
                        TextField(LocalizedStringKey("Nom du fournisseur"), text: $clientFournisseur)
                    } else {
                        TextField(typeTransaction == .vente ? LocalizedStringKey("Nom du client") : LocalizedStringKey("Nom du fournisseur"), text: $clientFournisseur)
                    }
                }
                
                // Date
                Section(header: Text(LocalizedStringKey("Date"))) {
                    DatePicker(LocalizedStringKey("Date de transaction"), selection: $dateTransaction, displayedComponents: [.date, .hourAndMinute])
                }
                
                // Notes
                Section(header: Text(LocalizedStringKey("Notes"))) {
                    TextField(LocalizedStringKey("Notes"), text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(mode == .add ?
                (typeTransaction == .vente ? LocalizedStringKey("Nouvelle vente") : LocalizedStringKey("Nouvel achat")) :
                LocalizedStringKey("Modifier"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("Enregistrer")) {
                        saveTransaction()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .teal)
                        }
                    }
                }
            }
            .onAppear {
                if let transaction = transaction {
                    articleId = transaction.articleId
                    nomArticle = transaction.nomArticle
                    quantite = "\(transaction.quantite)"
                    prixUnitaireHT = String(format: "%.2f", transaction.prixUnitaireHT)
                    tauxTVA = transaction.tauxTVA
                    typeRemise = transaction.typeRemise
                    valeurRemise = String(format: "%.2f", transaction.valeurRemise)
                    modePaiement = transaction.modePaiement
                    clientFournisseur = transaction.clientFournisseur
                    dateTransaction = transaction.dateTransaction
                    notes = transaction.notes
                    estPaye = transaction.estPaye
                    // Charger les informations de vente au poids
                    venteAuPoids = transaction.venteAuPoids
                    poids = String(format: "%.3f", transaction.poids)
                    // Charger la date de règlement si elle existe
                    if let dateReglementExistante = transaction.dateReglement {
                        dateReglement = dateReglementExistante
                    }
                }
            }
        }
    }
    
    private func saveTransaction() {
        var newTransaction = TransactionCommerce(
            id: transaction?.id ?? UUID(),
            typeTransaction: typeTransaction,
            articleId: articleId,
            nomArticle: nomArticle,
            quantite: Int(quantite) ?? 1,
            prixUnitaireHT: Double(prixUnitaireHT.replacingOccurrences(of: ",", with: ".")) ?? 0,
            tauxTVA: tauxTVA,
            typeRemise: typeRemise,
            valeurRemise: Double(valeurRemise.replacingOccurrences(of: ",", with: ".")) ?? 0,
            modePaiement: modePaiement,
            clientFournisseur: clientFournisseur,
            dateTransaction: dateTransaction,
            notes: notes,
            estPaye: estPaye
        )
        
        // Ajouter les informations de vente au poids
        newTransaction.venteAuPoids = venteAuPoids
        newTransaction.poids = Double(poids.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        // Ajouter la date de règlement si non payé
        newTransaction.dateReglement = estPaye ? nil : dateReglement
        
        if mode == .add {
            dataManager.ajouterTransactionCommerce(newTransaction)
            // Planifier la notification de rappel si non payé
            if !estPaye {
                dataManager.planifierRappelPaiement(transaction: newTransaction)
            }
            // Mettre à jour le stock si article lié
            if let articleId = articleId {
                if venteAuPoids {
                    let poidsValue = Double(poids.replacingOccurrences(of: ",", with: ".")) ?? 0
                    dataManager.mettreAJourStockArticlePoids(articleId: articleId, poids: poidsValue, estVente: typeTransaction == .vente)
                } else {
                    dataManager.mettreAJourStockArticle(articleId: articleId, quantite: Int(quantite) ?? 1, estVente: typeTransaction == .vente)
                }
            }
        } else {
            dataManager.modifierTransactionCommerce(newTransaction)
            // Mettre à jour la notification
            dataManager.mettreAJourRappelPaiement(transaction: newTransaction)
        }
        
        dismiss()
    }
}

// MARK: - Vue de vente rapide
struct QuickSaleView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    let article: ArticleCommerce
    
    @State private var quantite = "1"
    @State private var poids = "" // Pour articles au poids
    @State private var prixUnitaireHT: String = ""
    @State private var tauxTVA: TauxTVA = .tva20
    @State private var typeRemise: TypeRemise = .aucune
    @State private var valeurRemise = ""
    @State private var modePaiement: ModePaiement = .especes
    @State private var clientNom = ""
    @State private var estPaye = true
    @State private var dateReglement: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    
    private var quantiteInt: Int {
        Int(quantite) ?? 1
    }
    
    private var poidsDouble: Double {
        Double(poids.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    // Prix HT arrondi à 2 décimales
    private var prixHT: Double {
        let ht = Double(prixUnitaireHT.replacingOccurrences(of: ",", with: ".")) ?? article.prixVenteHT
        return (ht * 100).rounded() / 100
    }
    
    // Prix TTC unitaire arrondi (basé sur le TTC de l'article si non modifié)
    private var prixTTCUnitaire: Double {
        // Si le prix HT n'a pas été modifié, utiliser le TTC de l'article directement
        let prixHTSaisi = Double(prixUnitaireHT.replacingOccurrences(of: ",", with: ".")) ?? 0
        let prixHTArticle = (article.prixVenteHT * 100).rounded() / 100
        
        if abs(prixHTSaisi - prixHTArticle) < 0.01 || prixUnitaireHT.isEmpty {
            // Prix non modifié : utiliser le TTC de l'article arrondi
            return (article.prixVenteTTC * 100).rounded() / 100
        } else {
            // Prix modifié : recalculer le TTC
            return (prixHT * (1 + tauxTVA.valeur) * 100).rounded() / 100
        }
    }
    
    private var montantBrutHT: Double {
        if article.venteAuPoids {
            return (prixHT * poidsDouble * 100).rounded() / 100
        } else {
            return (prixHT * Double(quantiteInt) * 100).rounded() / 100
        }
    }
    
    private var montantBrutTVA: Double {
        return ((montantBrutHT * tauxTVA.valeur) * 100).rounded() / 100
    }
    
    private var montantBrutTTC: Double {
        if typeRemise == .aucune {
            // Sans remise : TTC unitaire × quantité ou poids (plus précis)
            if article.venteAuPoids {
                return (prixTTCUnitaire * poidsDouble * 100).rounded() / 100
            } else {
                return (prixTTCUnitaire * Double(quantiteInt) * 100).rounded() / 100
            }
        } else {
            return ((montantBrutHT + montantBrutTVA) * 100).rounded() / 100
        }
    }
    
    // Remise appliquée sur le TTC
    private var montantRemise: Double {
        let valeur = Double(valeurRemise.replacingOccurrences(of: ",", with: ".")) ?? 0
        switch typeRemise {
        case .aucune: return 0
        case .pourcentage: return ((montantBrutTTC * (valeur / 100)) * 100).rounded() / 100
        case .montantFixe: return min(valeur, montantBrutTTC)
        }
    }
    
    private var montantTTC: Double {
        return ((montantBrutTTC - montantRemise) * 100).rounded() / 100
    }
    
    // Calcul inversé du HT net après remise TTC
    private var montantNetHT: Double {
        return ((montantTTC / (1 + tauxTVA.valeur)) * 100).rounded() / 100
    }
    
    private var montantTVA: Double {
        return ((montantTTC - montantNetHT) * 100).rounded() / 100
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Info article
                Section {
                    HStack(spacing: 12) {
                        if let photoData = article.photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.teal.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "cube.box.fill")
                                    .foregroundColor(.teal)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.nom)
                                .font(.headline)
                            Text(String(format: "%.2f € TTC", article.prixVenteTTC))
                                .font(.subheadline)
                                .foregroundColor(.teal)
                            HStack {
                                Image(systemName: article.venteAuPoids ? "scalemass.fill" : "cube.fill")
                                    .font(.caption)
                                if article.venteAuPoids {
                                    Text(String(format: "Stock: %.2f kg", article.stockEnKg))
                                        .font(.caption)
                                } else {
                                    Text("Stock: \(article.quantiteEnStock)")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(article.stockEstBas ? .orange : .secondary)
                        }
                    }
                }
                
                // Quantité ou Poids
                if article.venteAuPoids {
                    Section(header: Text(LocalizedStringKey("Poids (kg)"))) {
                        HStack {
                            TextField("0.000", text: $poids)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            Text("kg")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        if poidsDouble > article.stockEnKg {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(LocalizedStringKey("Stock insuffisant"))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                } else {
                    Section(header: Text(LocalizedStringKey("Quantité"))) {
                        HStack {
                            Button(action: {
                                if quantiteInt > 1 {
                                    quantite = "\(quantiteInt - 1)"
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            
                            TextField("1", text: $quantite)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .frame(minWidth: 80)
                            
                            Button(action: {
                                quantite = "\(quantiteInt + 1)"
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        if quantiteInt > article.quantiteEnStock {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(LocalizedStringKey("Stock insuffisant"))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                // Prix (modifiable)
                Section(header: Text(LocalizedStringKey("Prix"))) {
                    HStack {
                        Text(LocalizedStringKey("Prix unitaire HT"))
                        Spacer()
                        TextField(String(format: "%.2f", article.prixVenteHT), text: $prixUnitaireHT)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker(LocalizedStringKey("TVA"), selection: $tauxTVA) {
                        ForEach(TauxTVA.allCases, id: \.self) { taux in
                            Text(taux.pourcentage).tag(taux)
                        }
                    }
                }
                
                // Remise
                Section(header: Text(LocalizedStringKey("Remise"))) {
                    Picker(LocalizedStringKey("Type"), selection: $typeRemise) {
                        ForEach(TypeRemise.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if typeRemise != .aucune {
                        HStack {
                            TextField("0", text: $valeurRemise)
                                .keyboardType(.decimalPad)
                            Text(typeRemise == .pourcentage ? "%" : "€")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Total
                Section(header: Text(LocalizedStringKey("Total"))) {
                    HStack {
                        Text(LocalizedStringKey("Montant brut HT"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", montantBrutHT))
                    }
                    
                    HStack {
                        Text("TVA (\(tauxTVA.pourcentage))")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", montantBrutTVA))
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Total brut TTC"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", montantBrutTTC))
                    }
                    
                    if typeRemise != .aucune && montantRemise > 0 {
                        HStack {
                            Text(LocalizedStringKey("Remise sur TTC"))
                                .foregroundColor(.orange)
                            Spacer()
                            Text(String(format: "-%.2f €", montantRemise))
                                .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("HT après remise"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f €", montantNetHT))
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("TVA après remise"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f €", montantTVA))
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Total TTC"))
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f €", montantTTC))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                
                // Paiement
                Section(header: Text(LocalizedStringKey("Paiement"))) {
                    Picker(LocalizedStringKey("Mode"), selection: $modePaiement) {
                        ForEach(ModePaiement.allCases, id: \.self) { mode in
                            Label(mode.localizedName, systemImage: mode.icon).tag(mode)
                        }
                    }
                    
                    Toggle(LocalizedStringKey("Payé"), isOn: $estPaye)
                    
                    // Date de règlement si non payé
                    if !estPaye {
                        DatePicker(
                            LocalizedStringKey("Date de règlement"),
                            selection: $dateReglement,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }
                
                // Client (optionnel)
                Section(header: Text(LocalizedStringKey("Client (optionnel)"))) {
                    TextField(LocalizedStringKey("Nom du client"), text: $clientNom)
                }
            }
            .navigationTitle(LocalizedStringKey("Vente rapide"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: validerVente) {
                        Text(LocalizedStringKey("Valider"))
                            .fontWeight(.bold)
                    }
                    .disabled(article.venteAuPoids ? poidsDouble <= 0 : quantiteInt < 1)
                }
            }
            .onAppear {
                prixUnitaireHT = String(format: "%.2f", article.prixVenteHT)
                tauxTVA = article.tauxTVAVente
            }
        }
    }
    
    private func validerVente() {
        var transaction = TransactionCommerce(
            typeTransaction: .vente,
            articleId: article.id,
            nomArticle: article.nom,
            quantite: article.venteAuPoids ? 1 : quantiteInt,
            prixUnitaireHT: prixHT,
            tauxTVA: tauxTVA,
            typeRemise: typeRemise,
            valeurRemise: Double(valeurRemise.replacingOccurrences(of: ",", with: ".")) ?? 0,
            modePaiement: modePaiement,
            clientFournisseur: clientNom,
            dateTransaction: Date(),
            notes: "",
            estPaye: estPaye
        )
        
        // Ajouter les informations de vente au poids
        transaction.venteAuPoids = article.venteAuPoids
        transaction.poids = poidsDouble
        
        // Ajouter la date de règlement si non payé
        transaction.dateReglement = estPaye ? nil : dateReglement
        
        dataManager.ajouterTransactionCommerce(transaction)
        
        // Planifier la notification de rappel si non payé
        if !estPaye {
            dataManager.planifierRappelPaiement(transaction: transaction)
        }
        
        // Mettre à jour le stock
        if article.venteAuPoids {
            dataManager.mettreAJourStockArticlePoids(articleId: article.id, poids: poidsDouble, estVente: true)
        } else {
            dataManager.mettreAJourStockArticle(articleId: article.id, quantite: quantiteInt, estVente: true)
        }
        
        dismiss()
    }
}

// MARK: - Image Picker pour le module Commerce
struct CommerceImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CommerceImagePicker
        init(_ parent: CommerceImagePicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Vue de gestion des fournisseurs
struct GestionFournisseursView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var showingAddFournisseur = false
    @State private var nouveauFournisseur = ""
    @State private var fournisseurToDelete: String?
    @State private var showingDeleteAlert = false
    @State private var isFromPersonnalises = true // Pour savoir d'où vient le fournisseur à supprimer
    
    // Fournisseurs personnalisés (créés manuellement mais PAS encore utilisés)
    private var fournisseursPersonnalises: [String] {
        let fournisseursArticles = Set(dataManager.articlesCommerce.compactMap { $0.fournisseur.isEmpty ? nil : $0.fournisseur })
        let fournisseursTransactions = Set(dataManager.transactionsCommerce.compactMap { $0.clientFournisseur.isEmpty ? nil : ($0.typeTransaction == .achat ? $0.clientFournisseur : nil) })
        let utilises = fournisseursArticles.union(fournisseursTransactions)
        // Retourne seulement les personnalisés qui ne sont PAS utilisés
        return dataManager.fournisseursCommercePersonnalises
            .filter { !utilises.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    // Fournisseurs utilisés dans les articles ou transactions (inclut les personnalisés utilisés)
    private var fournisseursUtilises: [String] {
        let fournisseursArticles = Set(dataManager.articlesCommerce.compactMap { $0.fournisseur.isEmpty ? nil : $0.fournisseur })
        let fournisseursTransactions = Set(dataManager.transactionsCommerce.compactMap { $0.clientFournisseur.isEmpty ? nil : ($0.typeTransaction == .achat ? $0.clientFournisseur : nil) })
        return Array(fournisseursArticles.union(fournisseursTransactions))
            .filter { !dataManager.fournisseursCommerceExclus.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Section fournisseurs personnalisés (supprimables)
                if !fournisseursPersonnalises.isEmpty {
                    Section(header: Text(LocalizedStringKey("Fournisseurs personnalisés"))) {
                        ForEach(fournisseursPersonnalises, id: \.self) { fournisseur in
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.teal)
                                Text(fournisseur)
                                Spacer()
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    fournisseurToDelete = fournisseur
                                    isFromPersonnalises = true
                                    showingDeleteAlert = true
                                } label: {
                                    Label(LocalizedStringKey("Supprimer"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // Section fournisseurs utilisés (supprimables de la liste, restent dans les transactions)
                if !fournisseursUtilises.isEmpty {
                    Section(header: Text(LocalizedStringKey("Fournisseurs utilisés")), footer: Text(LocalizedStringKey("La suppression retire le fournisseur de la liste de sélection. Les transactions existantes conservent le nom du fournisseur."))) {
                        ForEach(fournisseursUtilises, id: \.self) { fournisseur in
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.orange)
                                Text(fournisseur)
                                Spacer()
                                Image(systemName: "link")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    fournisseurToDelete = fournisseur
                                    isFromPersonnalises = false
                                    showingDeleteAlert = true
                                } label: {
                                    Label(LocalizedStringKey("Supprimer"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // Message si aucun fournisseur
                if fournisseursPersonnalises.isEmpty && fournisseursUtilises.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text(LocalizedStringKey("Aucun fournisseur"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Ajoutez des fournisseurs pour les retrouver facilement lors de vos achats."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Fournisseurs"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Fermer")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddFournisseur = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.teal)
                    }
                }
            }
            .alert(LocalizedStringKey("Nouveau fournisseur"), isPresented: $showingAddFournisseur) {
                TextField(LocalizedStringKey("Nom du fournisseur"), text: $nouveauFournisseur)
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    nouveauFournisseur = ""
                }
                Button(LocalizedStringKey("Ajouter")) {
                    if !nouveauFournisseur.isEmpty {
                        dataManager.ajouterFournisseurCommerce(nouveauFournisseur)
                        nouveauFournisseur = ""
                    }
                }
            }
            .alert(LocalizedStringKey("Supprimer le fournisseur ?"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Annuler"), role: .cancel) { }
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let fournisseur = fournisseurToDelete {
                        if isFromPersonnalises {
                            dataManager.supprimerFournisseurCommerce(fournisseur)
                        } else {
                            // Ajouter à une liste d'exclusion pour ne plus l'afficher
                            dataManager.exclureFournisseurCommerce(fournisseur)
                        }
                    }
                }
            } message: {
                if let fournisseur = fournisseurToDelete {
                    if isFromPersonnalises {
                        Text(String(format: NSLocalizedString("Le fournisseur \"%@\" sera supprimé de la liste.", comment: ""), fournisseur))
                    } else {
                        Text(String(format: NSLocalizedString("Le fournisseur \"%@\" sera retiré de la liste de sélection. Les transactions existantes conserveront son nom.", comment: ""), fournisseur))
                    }
                }
            }
        }
    }
}
