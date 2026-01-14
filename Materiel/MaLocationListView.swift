//
//  MaLocationListView.swift
//  Materiel
//
//  Vue pour gérer "Je loue" - les locations où l'utilisateur est locataire
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Structure pour export/import JSON
struct MaLocationExport: Codable {
    var dateExport: Date
    var totalDepenses: Double
    var cautionsTotales: Double
    var cautionsRecuperees: Double
    var cautionsPerdues: Double
    var mesLocations: [MaLocation]
}

// MARK: - Fonction helper pour les couleurs de type de personne
private func couleurPourTypePersonne(_ type: TypePersonne?) -> Color {
    switch type {
    case .mecanicien: return .orange
    case .salarie: return .green
    case .alm: return .purple
    case .client, .none: return .blue
    }
}

// MARK: - Vue principale liste des MaLocations
struct MaLocationListView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @State private var showingAddSheet = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    @State private var searchText = ""
    @State private var filtreStatut = "Tous"
    @State private var filtrePaiement = "Tous"
    @State private var filtreCaution = "Tous"
    @State private var showingDeleteAlert = false
    @State private var showingDeleteBlockedAlert = false
    @State private var indexSetToDelete: IndexSet?
    @Environment(\.dismiss) private var dismiss
    
    // États pour export/import
    @State private var exportItem: ExportURLWrapper?
    @State private var showingImportPicker = false
    @State private var showingImportAlert = false
    @State private var importMessage = ""
    @State private var importSuccess = false
    
    // Vérifie si une location peut être supprimée (toutes les actions terminées)
    private func maLocationPeutEtreSupprimee(_ maLocation: MaLocation) -> Bool {
        let retourEffectue = maLocation.dateRetourEffectif != nil
        let paiementOk = maLocation.paiementEffectue
        let cautionGeree = maLocation.caution == 0 || maLocation.cautionTraitee
        return retourEffectue && paiementOk && cautionGeree
    }
    
    private let statutOptions = ["Tous", "En cours", "En retard", "Terminées"]
    private let paiementOptions = ["Tous", "Payé", "Non payé"]
    private let cautionOptions = ["Tous", "Récupérée", "Partielle", "En attente"]
    
    var maLocationsFiltrees: [MaLocation] {
        var locs = dataManager.mesLocations
        
        // Filtre par statut
        switch filtreStatut {
        case "En cours": locs = locs.filter { $0.estActive && !$0.estEnRetard }
        case "En retard": locs = locs.filter { $0.estEnRetard }
        case "Terminées": locs = locs.filter { $0.estTerminee }
        default: break
        }
        
        // Filtre par paiement
        switch filtrePaiement {
        case "Payé": locs = locs.filter { $0.paiementEffectue }
        case "Non payé": locs = locs.filter { !$0.paiementEffectue }
        default: break
        }
        
        // Filtre par caution
        switch filtreCaution {
        case "Récupérée": locs = locs.filter { $0.cautionRecuperee }
        case "Partielle": locs = locs.filter { $0.cautionPartiellementRecuperee }
        case "En attente": locs = locs.filter { $0.cautionRestante > 0 }
        default: break
        }
        
        // Filtre par recherche
        if !searchText.isEmpty {
            locs = locs.filter { maLocation in
                if maLocation.nomObjet.localizedCaseInsensitiveContains(searchText) { return true }
                if let personne = dataManager.getPersonne(id: maLocation.loueurId),
                   personne.nomComplet.localizedCaseInsensitiveContains(searchText) { return true }
                return false
            }
        }
        return locs.sorted { $0.dateDebut > $1.dateDebut }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    // Résumé financier
                    if !dataManager.mesLocations.isEmpty {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey("Dépensé"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", dataManager.depensesTotalesMesLocations()))
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            Divider().frame(height: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey("En attente"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", dataManager.depensesEnAttenteMesLocations()))
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            Divider().frame(height: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey("Cautions"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", dataManager.cautionsEnCoursMesLocations()))
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    // Filtre par statut
                    Picker(LocalizedStringKey("Statut"), selection: $filtreStatut) {
                        ForEach(statutOptions, id: \.self) { statut in
                            Text(LocalizedStringKey(statut))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Filtres supplémentaires
                    HStack(spacing: 12) {
                        // Filtre paiement
                        Menu {
                            ForEach(paiementOptions, id: \.self) { option in
                                Button(action: { filtrePaiement = option }) {
                                    HStack {
                                        Text(LocalizedStringKey(option))
                                        if filtrePaiement == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filtrePaiement == "Payé" ? "checkmark.circle.fill" : (filtrePaiement == "Non payé" ? "xmark.circle.fill" : "eurosign.circle"))
                                    .foregroundColor(filtrePaiement == "Payé" ? .green : (filtrePaiement == "Non payé" ? .red : .primary))
                                Text(LocalizedStringKey(filtrePaiement == "Tous" ? "Paiement" : filtrePaiement))
                                    .font(.subheadline)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(filtrePaiement != "Tous" ? Color.purple.opacity(0.15) : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // Filtre caution
                        Menu {
                            ForEach(cautionOptions, id: \.self) { option in
                                Button(action: { filtreCaution = option }) {
                                    HStack {
                                        Text(LocalizedStringKey(option))
                                        if filtreCaution == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filtreCaution == "Récupérée" ? "arrow.uturn.backward.circle.fill" : (filtreCaution == "En attente" ? "hourglass" : "shield"))
                                    .foregroundColor(filtreCaution == "Récupérée" ? .green : (filtreCaution == "En attente" ? .orange : .primary))
                                Text(LocalizedStringKey(filtreCaution == "Tous" ? "Caution" : filtreCaution))
                                    .font(.subheadline)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(filtreCaution != "Tous" ? Color.pink.opacity(0.15) : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        // Bouton reset si filtres actifs
                        if filtrePaiement != "Tous" || filtreCaution != "Tous" {
                            Button(action: {
                                filtrePaiement = "Tous"
                                filtreCaution = "Tous"
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    // Bouton Ajouter
                    Button {
                        if dataManager.peutAjouterMaLocation() {
                            showingAddSheet = true
                        } else {
                            showingLimitAlert = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "cart.badge.plus")
                                .font(.system(size: 20, weight: .semibold))
                            Text(LocalizedStringKey("Ajouter une location"))
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .purple.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Liste
                    if maLocationsFiltrees.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "cart")
                                .font(.system(size: 50))
                                .foregroundColor(.purple.opacity(0.5))
                            Text(LocalizedStringKey("Aucune location"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Ajoutez les objets que vous louez à quelqu'un"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(maLocationsFiltrees) { maLocation in
                                MaLocationRowView(maLocation: maLocation)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                            .onDelete { offsets in
                                // Vérifier si toutes les locations à supprimer ont leurs actions terminées
                                let locationsToDelete = offsets.map { maLocationsFiltrees[$0] }
                                let allCanBeDeleted = locationsToDelete.allSatisfy { maLocationPeutEtreSupprimee($0) }
                                
                                if allCanBeDeleted {
                                    indexSetToDelete = offsets
                                    showingDeleteAlert = true
                                } else {
                                    showingDeleteBlockedAlert = true
                                }
                            }
                        }
                        .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher une location"))
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Je loue"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section(header: Text(LocalizedStringKey("Exporter"))) {
                            Button(action: { exportPDF() }) {
                                Label(LocalizedStringKey("Exporter en PDF"), systemImage: "doc.richtext")
                            }
                            Button(action: { exportJSON() }) {
                                Label(LocalizedStringKey("Exporter en JSON"), systemImage: "doc.text")
                            }
                        }
                        
                        Section(header: Text(LocalizedStringKey("Importer"))) {
                            Button(action: { showingImportPicker = true }) {
                                Label(LocalizedStringKey("Importer JSON"), systemImage: "square.and.arrow.down")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(activityItems: [item.url])
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
            .sheet(isPresented: $showingAddSheet) {
                AjouterMaLocationView()
            }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        for index in offsets {
                            let maLocation = maLocationsFiltrees[index]
                            dataManager.supprimerMaLocation(maLocation)
                        }
                    }
                    indexSetToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    indexSetToDelete = nil
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer cette location ? Cette action est irréversible."))
            }
            .alert(LocalizedStringKey("Suppression impossible"), isPresented: $showingDeleteBlockedAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Vous ne pouvez pas supprimer cette location car toutes les actions ne sont pas terminées (règlement, caution, retour)."))
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumSheet = true
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Vous avez atteint la limite de locations gratuites. Passez à Premium pour créer des locations illimitées."))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
    }
    
    // MARK: - Export PDF
    private func exportPDF() {
        let pdfData = generatePDFData()
        
        let fileName = generateFileName(extension: "pdf")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: tempURL)
            exportItem = ExportURLWrapper(url: tempURL)
        } catch {
            importMessage = "Erreur lors de la création du PDF: \(error.localizedDescription)"
            importSuccess = false
            showingImportAlert = true
        }
    }
    
    private func generatePDFData() -> Data {
        let pageWidth: CGFloat = 595.2 // A4 width in points
        let pageHeight: CGFloat = 841.8 // A4 height in points
        let margin: CGFloat = 50
        
        let pdfMetaData = [
            kCGPDFContextCreator: "Materiel App",
            kCGPDFContextAuthor: "Materiel",
            kCGPDFContextTitle: "Rapport Je loue"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = margin
            
            // Titre
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let title = "Rapport - Je loue"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.systemPurple
            ]
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 35
            
            // Date d'export
            let subtitleFont = UIFont.systemFont(ofSize: 14)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            let exportDateText = "Exporté le \(dateFormatter.string(from: Date()))"
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.gray
            ]
            exportDateText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition += 40
            
            // Résumé financier
            let headerFont = UIFont.boldSystemFont(ofSize: 16)
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ]
            "Résumé financier".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
            let redAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.systemRed]
            let greenAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.systemGreen]
            let orangeAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.systemOrange]
            
            let totalDepenses = dataManager.depensesTotalesMesLocations()
            let cautionsTotales = dataManager.mesLocations.reduce(0) { $0 + $1.caution }
            let cautionsRecuperees = dataManager.mesLocations.reduce(0) { $0 + $1.montantCautionRecuperee }
            let cautionsPerdues = dataManager.mesLocations.reduce(0) { $0 + $1.montantCautionPerdue }
            let cautionsEnCours = dataManager.cautionsEnCoursMesLocations()
            
            "Total dépensé: \(String(format: "%.2f", totalDepenses)) €".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: redAttributes)
            yPosition += 18
            "Cautions versées: \(String(format: "%.2f", cautionsTotales)) €".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
            yPosition += 18
            "Cautions récupérées: \(String(format: "%.2f", cautionsRecuperees)) €".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: greenAttributes)
            yPosition += 18
            "Cautions perdues: \(String(format: "%.2f", cautionsPerdues)) €".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: redAttributes)
            yPosition += 18
            "Cautions en attente: \(String(format: "%.2f", cautionsEnCours)) €".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: orangeAttributes)
            yPosition += 35
            
            // Liste des locations
            "Détail des locations (\(dataManager.mesLocations.count))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            for maLocation in dataManager.mesLocations.sorted(by: { $0.dateDebut > $1.dateDebut }) {
                // Nouvelle page si nécessaire
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = margin
                }
                
                let loueurNom = dataManager.getPersonne(id: maLocation.loueurId)?.nomComplet ?? "Inconnu"
                let dateFormatter2 = DateFormatter()
                dateFormatter2.dateStyle = .short
                
                let statutText = maLocation.estTerminee ? "✓ Terminée" : (maLocation.estEnRetard ? "⚠ En retard" : "• En cours")
                let paiementText = maLocation.paiementEffectue ? "Payé" : "Non payé"
                
                // Nom de l'objet
                let itemFont = UIFont.boldSystemFont(ofSize: 13)
                let itemAttributes: [NSAttributedString.Key: Any] = [.font: itemFont, .foregroundColor: UIColor.black]
                maLocation.nomObjet.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: itemAttributes)
                
                // Statut
                let statutAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: maLocation.estTerminee ? UIColor.systemGreen : (maLocation.estEnRetard ? UIColor.systemRed : UIColor.systemPurple)]
                statutText.draw(at: CGPoint(x: pageWidth - margin - 100, y: yPosition), withAttributes: statutAttrs)
                yPosition += 16
                
                // Loueur
                "Loué à: \(loueurNom)".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 14
                
                // Dates
                let datesText = "Du \(dateFormatter2.string(from: maLocation.dateDebut)) au \(dateFormatter2.string(from: maLocation.dateFin))"
                datesText.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 14
                
                // Prix et paiement
                let prixText = "Prix: \(String(format: "%.2f", maLocation.prixTotalReel)) € - \(paiementText)"
                let prixAttrs = maLocation.paiementEffectue ? greenAttributes : orangeAttributes
                prixText.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: prixAttrs)
                yPosition += 14
                
                // Caution
                if maLocation.caution > 0 {
                    var cautionText = "Caution: \(String(format: "%.2f", maLocation.caution)) €"
                    if maLocation.montantCautionRecuperee > 0 {
                        cautionText += " (récupéré: \(String(format: "%.2f", maLocation.montantCautionRecuperee)) €)"
                    }
                    if maLocation.montantCautionPerdue > 0 {
                        cautionText += " (perdu: \(String(format: "%.2f", maLocation.montantCautionPerdue)) €)"
                    }
                    cautionText.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 14
                }
                
                yPosition += 10
            }
        }
        
        return data
    }
    
    // MARK: - Export JSON
    private func exportJSON() {
        let exportData = MaLocationExport(
            dateExport: Date(),
            totalDepenses: dataManager.depensesTotalesMesLocations(),
            cautionsTotales: dataManager.mesLocations.reduce(0) { $0 + $1.caution },
            cautionsRecuperees: dataManager.mesLocations.reduce(0) { $0 + $1.montantCautionRecuperee },
            cautionsPerdues: dataManager.mesLocations.reduce(0) { $0 + $1.montantCautionPerdue },
            mesLocations: dataManager.mesLocations
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(exportData)
            let fileName = generateFileName(extension: "json")
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            exportItem = ExportURLWrapper(url: tempURL)
        } catch {
            importMessage = "Erreur lors de l'export JSON: \(error.localizedDescription)"
            importSuccess = false
            showingImportAlert = true
        }
    }
    
    private func generateFileName(extension ext: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = dateFormatter.string(from: Date())
        return "je_loue_\(dateStr).\(ext)"
    }
    
    // MARK: - Import JSON
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
            
            let importedData = try decoder.decode(MaLocationExport.self, from: jsonData)
            
            // Importer les locations
            var importedCount = 0
            var duplicateCount = 0
            
            for maLocation in importedData.mesLocations {
                // Vérifier si la location existe déjà (par ID)
                if !dataManager.mesLocations.contains(where: { $0.id == maLocation.id }) {
                    // Vérifier la limite
                    if dataManager.peutAjouterMaLocation() {
                        dataManager.ajouterMaLocation(maLocation)
                        importedCount += 1
                    } else {
                        importMessage = "\(importedCount) location(s) importée(s)\nLimite atteinte - certaines locations n'ont pas été importées"
                        importSuccess = importedCount > 0
                        showingImportAlert = true
                        return
                    }
                } else {
                    duplicateCount += 1
                }
            }
            
            importMessage = "\(importedCount) location(s) importée(s)"
            if duplicateCount > 0 {
                importMessage += "\n\(duplicateCount) doublon(s) ignoré(s)"
            }
            importSuccess = true
            showingImportAlert = true
            
        } catch {
            importMessage = "Erreur lors de l'import: \(error.localizedDescription)"
            importSuccess = false
            showingImportAlert = true
        }
    }
}

// MARK: - Row View pour MaLocation
struct MaLocationRowView: View {
    let maLocation: MaLocation
    @EnvironmentObject var dataManager: DataManager
    @State private var showingDetail = false
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    private var uniteLabel: String {
        switch maLocation.typeTarif {
        case .jour: return NSLocalizedString("jour(s)", comment: "")
        case .semaine: return NSLocalizedString("semaine(s)", comment: "")
        case .mois: return NSLocalizedString("mois", comment: "")
        case .forfait: return ""
        }
    }
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 12) {
                // Image ou icône
                if let data = maLocation.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 55, height: 55)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                        .frame(width: 55, height: 55)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Nom de l'objet
                    Text(maLocation.nomObjet)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Loueur
                    if let personne = dataManager.getPersonne(id: maLocation.loueurId) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text(personne.nomComplet)
                                .font(.caption)
                        }
                        .foregroundColor(couleurPourTypePersonne(personne.typePersonne))
                    }
                    
                    // Dates
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(formatDate(maLocation.dateDebut)) → \(formatDate(maLocation.dateFin))")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Prix
                    Text(String(format: "%.2f €", maLocation.prixTotalReel))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // Statut paiement
                    HStack(spacing: 4) {
                        if maLocation.paiementEffectue {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // Indicateur de statut
                        if maLocation.estTerminee {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if maLocation.estEnRetard {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.purple)
                        }
                    }
                    
                    // Retard
                    if maLocation.estEnRetard {
                        Text("\(maLocation.joursRetard) j")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            MaLocationDetailView(maLocation: maLocation)
        }
    }
}

// MARK: - Vue de détail MaLocation
struct MaLocationDetailView: View {
    let maLocation: MaLocation
    @EnvironmentObject var dataManager: DataManager
    @State private var showingConfirmation = false
    @State private var showingPretSheet = false
    @State private var showingSousLocationSheet = false
    @State private var showingEditSheet = false
    @State private var showingCautionSheet = false
    @State private var montantCautionARecuperer = ""
    @State private var montantCautionPerdue = ""
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @Environment(\.dismiss) private var dismiss
    
    private func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "fr", ofType: "lproj")
        let bundle = path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    private var uniteLabel: String {
        switch maLocation.typeTarif {
        case .jour: return NSLocalizedString("jour(s)", comment: "")
        case .semaine: return NSLocalizedString("semaine(s)", comment: "")
        case .mois: return NSLocalizedString("mois", comment: "")
        case .forfait: return ""
        }
    }
    
    // Lire la version courante
    private var maLocationCourante: MaLocation {
        dataManager.mesLocations.first { $0.id == maLocation.id } ?? maLocation
    }
    
    // Vérifie si actuellement prêté
    private var pretActif: Pret? {
        dataManager.maLocationEstPretee(maLocationCourante.id)
    }
    
    // Vérifie si actuellement sous-loué
    private var sousLocationActif: Location? {
        dataManager.maLocationEstSousLouee(maLocationCourante.id)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Carte principale
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            // Image
                            if let data = maLocationCourante.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 35))
                                    .foregroundColor(.purple)
                                    .frame(width: 80, height: 80)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(maLocationCourante.nomObjet)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if maLocationCourante.estTerminee {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    } else if maLocationCourante.estEnRetard {
                                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                    } else {
                                        Image(systemName: "clock.fill").foregroundColor(.purple)
                                    }
                                }
                                
                                // Loueur
                                if let personne = dataManager.getPersonne(id: maLocationCourante.loueurId) {
                                    Label(personne.nomComplet, systemImage: "person.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Prix et paiement
                        HStack {
                            Text(String(format: "%.2f €", maLocationCourante.prixTotalReel))
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if maLocationCourante.typeTarif != .forfait {
                                Text("(\(maLocationCourante.nombreUnitesReelles) \(uniteLabel))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if maLocationCourante.paiementEffectue {
                                Label(LocalizedStringKey("Payé"), systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Label(LocalizedStringKey("À payer"), systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Caution
                        if maLocationCourante.caution > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Caution: \(String(format: "%.0f €", maLocationCourante.caution))")
                                        .font(.subheadline)
                                    Spacer()
                                    if maLocationCourante.cautionTraitee {
                                        if maLocationCourante.aCautionPerdue {
                                            Label(LocalizedStringKey("Clôturée"), systemImage: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        } else {
                                            Label(LocalizedStringKey("Récupérée"), systemImage: "arrow.uturn.backward.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    } else if maLocationCourante.cautionPartiellementRecuperee {
                                        Label(LocalizedStringKey("Partielle"), systemImage: "arrow.uturn.backward.circle")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    } else {
                                        Label(LocalizedStringKey("En attente"), systemImage: "hourglass")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                // Détails de la caution
                                if maLocationCourante.montantCautionRecuperee > 0 || maLocationCourante.montantCautionPerdue > 0 {
                                    HStack(spacing: 8) {
                                        if maLocationCourante.montantCautionRecuperee > 0 {
                                            Text("\(localizedString("Récupéré")): \(String(format: "%.0f €", maLocationCourante.montantCautionRecuperee))")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        if maLocationCourante.montantCautionPerdue > 0 {
                                            Text("• \(localizedString("Perdu")): \(String(format: "%.0f €", maLocationCourante.montantCautionPerdue))")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        if maLocationCourante.cautionRestante > 0 {
                                            Text("• \(localizedString("Reste")): \(String(format: "%.0f €", maLocationCourante.cautionRestante))")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Dates
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(localizedString("Du")) \(formatDate(maLocationCourante.dateDebut))").font(.caption)
                                Text("\(localizedString("au")) \(formatDate(maLocationCourante.dateFin))").font(.caption)
                            }.foregroundColor(.secondary)
                            Spacer()
                            if maLocationCourante.estTerminee, let dateRetour = maLocationCourante.dateRetourEffectif {
                                Text("\(localizedString("Retourné le")) \(formatDate(dateRetour))")
                                    .font(.caption).foregroundColor(.green)
                            } else if maLocationCourante.estEnRetard {
                                Text("\(maLocationCourante.joursRetard) \(localizedString("jour(s) de retard"))")
                                    .font(.caption).foregroundColor(.red)
                            }
                        }
                        
                        // Notes
                        if !maLocationCourante.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "note.text").foregroundColor(.secondary)
                                Text(maLocationCourante.notes).font(.callout).foregroundColor(.primary)
                            }.padding(.top, 2)
                        }
                        
                        // Indicateur si prêté
                        if let pret = pretActif, let personne = dataManager.getPersonne(id: pret.personneId) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.forward.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("Prêté à"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(personne.nomComplet)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Text("jusqu'au \(formatDate(pret.dateFin))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Indicateur si sous-loué
                        if let location = sousLocationActif, let personne = dataManager.getPersonne(id: location.locataireId) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("Sous-loué à"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(personne.nomComplet)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.teal)
                                }
                                Spacer()
                                Text("jusqu'au \(formatDate(location.dateFin))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color.teal.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                    .padding(.horizontal)
                    
                    // Boutons d'action
                    VStack(spacing: 12) {
                        // Actions sur prêt/sous-location
                        if pretActif != nil {
                            Button(action: { dataManager.validerRetourPretMaLocation(maLocationCourante.id) }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                    Text(LocalizedStringKey("Récupérer du prêt"))
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                        } else if sousLocationActif != nil {
                            Button(action: { dataManager.validerRetourSousLocationMaLocation(maLocationCourante.id) }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                    Text(LocalizedStringKey("Récupérer de la sous-location"))
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.teal)
                                .cornerRadius(10)
                            }
                        }
                        
                        // Actions principales (si pas prêté/sous-loué)
                        if pretActif == nil && sousLocationActif == nil && !maLocationCourante.estTerminee {
                            // Prêter
                            Button(action: { showingPretSheet = true }) {
                                HStack {
                                    Image(systemName: "arrow.up.forward.circle")
                                    Text(LocalizedStringKey("Prêter cet objet"))
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            
                            // Sous-louer
                            Button(action: { showingSousLocationSheet = true }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.swap")
                                    Text(LocalizedStringKey("Sous-louer"))
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.teal)
                                .cornerRadius(10)
                            }
                            
                            // Valider le retour
                            Button(action: { showingConfirmation = true }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(LocalizedStringKey("Valider le retour"))
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(10)
                            }
                        }
                        
                        // Marquer paiement
                        if !maLocationCourante.paiementEffectue {
                            Button(action: { dataManager.marquerPaiementMaLocation(maLocationCourante.id, effectue: true) }) {
                                HStack {
                                    Image(systemName: "eurosign.circle.fill")
                                    Text(LocalizedStringKey("Marquer comme payé"))
                                }
                                .font(.headline)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Gérer caution (si caution > 0 et pas entièrement traitée)
                        if maLocationCourante.caution > 0 && !maLocationCourante.cautionTraitee {
                            Button(action: {
                                showingCautionSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "banknote.fill")
                                    Text(LocalizedStringKey("Gérer la caution"))
                                    Text("(\(String(format: "%.0f €", maLocationCourante.cautionRestante)) \(localizedString("restant")))")
                                        .font(.subheadline)
                                        .foregroundColor(.blue.opacity(0.7))
                                }
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(LocalizedStringKey("Détails"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.purple)
                    }
                }
            }
            .alert(LocalizedStringKey("Confirmer le retour"), isPresented: $showingConfirmation) {
                Button(LocalizedStringKey("Confirmer"), role: .destructive) {
                    dataManager.validerRetourMaLocation(maLocationCourante.id)
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Voulez-vous valider le retour de cet objet ?"))
            }
            .sheet(isPresented: $showingPretSheet) {
                PreterMaLocationView(maLocation: maLocationCourante)
            }
            .sheet(isPresented: $showingSousLocationSheet) {
                SousLouerMaLocationView(maLocation: maLocationCourante)
            }
            .sheet(isPresented: $showingEditSheet) {
                ModifierMaLocationView(maLocation: maLocationCourante)
            }
            .sheet(isPresented: $showingCautionSheet) {
                NavigationView {
                    Form {
                        Section(header: Text(LocalizedStringKey("État de la caution"))) {
                            HStack {
                                Text(LocalizedStringKey("Caution totale"))
                                Spacer()
                                Text(String(format: "%.0f €", maLocationCourante.caution))
                                    .foregroundColor(.secondary)
                            }
                            if maLocationCourante.montantCautionRecuperee > 0 {
                                HStack {
                                    Text(LocalizedStringKey("Déjà récupéré"))
                                    Spacer()
                                    Text(String(format: "%.0f €", maLocationCourante.montantCautionRecuperee))
                                        .foregroundColor(.green)
                                }
                            }
                            if maLocationCourante.montantCautionPerdue > 0 {
                                HStack {
                                    Text(LocalizedStringKey("Déjà perdu"))
                                    Spacer()
                                    Text(String(format: "%.0f €", maLocationCourante.montantCautionPerdue))
                                        .foregroundColor(.red)
                                }
                            }
                            HStack {
                                Text(LocalizedStringKey("Reste à traiter"))
                                Spacer()
                                Text(String(format: "%.0f €", maLocationCourante.cautionRestante))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Section(header: Text(LocalizedStringKey("Montant récupéré"))) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .foregroundColor(.green)
                                TextField(LocalizedStringKey("Montant"), text: $montantCautionARecuperer)
                                    .keyboardType(.decimalPad)
                                Text("€").foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                montantCautionARecuperer = String(format: "%.0f", maLocationCourante.cautionRestante)
                                montantCautionPerdue = ""
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text(LocalizedStringKey("Récupérer la totalité"))
                                }
                                .foregroundColor(.green)
                            }
                        }
                        
                        Section(header: Text(LocalizedStringKey("Montant gardé par le loueur")), footer: Text(LocalizedStringKey("Montant retenu pour dégâts, frais ou pénalités"))) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                TextField(LocalizedStringKey("Montant"), text: $montantCautionPerdue)
                                    .keyboardType(.decimalPad)
                                Text("€").foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                montantCautionPerdue = String(format: "%.0f", maLocationCourante.cautionRestante)
                                montantCautionARecuperer = ""
                            }) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                    Text(LocalizedStringKey("Tout perdu"))
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .navigationTitle(LocalizedStringKey("Gérer la caution"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(LocalizedStringKey("Annuler")) {
                                showingCautionSheet = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(LocalizedStringKey("Valider")) {
                                let montantRecup = Double(montantCautionARecuperer.replacingOccurrences(of: ",", with: ".")) ?? 0
                                let montantPerte = Double(montantCautionPerdue.replacingOccurrences(of: ",", with: ".")) ?? 0
                                let maxDisponible = maLocationCourante.cautionRestante
                                
                                if montantRecup > 0 {
                                    let recupEffectif = min(montantRecup, maxDisponible)
                                    dataManager.marquerCautionRecuperee(maLocationCourante.id, montant: recupEffectif)
                                }
                                if montantPerte > 0 {
                                    let perteEffective = min(montantPerte, maxDisponible - min(montantRecup, maxDisponible))
                                    if perteEffective > 0 {
                                        dataManager.marquerCautionPerdue(maLocationCourante.id, montant: perteEffective)
                                    }
                                }
                                showingCautionSheet = false
                            }
                            .fontWeight(.semibold)
                            .disabled({
                                let r = Double(montantCautionARecuperer.replacingOccurrences(of: ",", with: ".")) ?? 0
                                let p = Double(montantCautionPerdue.replacingOccurrences(of: ",", with: ".")) ?? 0
                                return (r + p) <= 0
                            }())
                        }
                    }
                }
                .onAppear {
                    montantCautionARecuperer = ""
                    montantCautionPerdue = ""
                }
            }
        }
    }
}

// MARK: - Vue pour ajouter une MaLocation
struct AjouterMaLocationView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var nomObjet = ""
    @State private var loueurId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var typeTarif: Location.TypeTarif = .jour
    @State private var prixUnitaire: String = ""
    @State private var caution: String = ""
    @State private var notes = ""
    @State private var showingImagePicker = false
    @State private var showingCameraPicker = false
    @State private var selectedImage: UIImage?
    @State private var showingPersonneCreation = false
    @State private var showingPersonneSelection = false
    
    // Option pour créer un matériel
    @State private var creerMateriel = false
    @State private var categorieMateriel = "Location"
    @State private var lieuStockageId: UUID? = nil
    
    private var categoriesDisponibles: [String] {
        ["Location", "Électronique", "Outils", "Sport", "Véhicule", "Mobilier", "Autre"]
    }
    
    private var prixTotal: Double {
        let prix = Double(prixUnitaire.replacingOccurrences(of: ",", with: ".")) ?? 0
        let jours = max(1, Calendar.current.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0 + 1)
        switch typeTarif {
        case .jour: return prix * Double(jours)
        case .semaine: return prix * Double(max(1, Int(ceil(Double(jours) / 7.0))))
        case .mois: return prix * Double(max(1, Int(ceil(Double(jours) / 30.0))))
        case .forfait: return prix
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Objet
                Section(header: Text(LocalizedStringKey("Objet loué"))) {
                    TextField(LocalizedStringKey("Nom de l'objet"), text: $nomObjet)
                    
                    // Photo - aperçu
                    if let image = selectedImage {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(12)
                            Spacer()
                        }
                    }
                    
                    // Boutons photo
                    HStack(spacing: 12) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button(action: { showingCameraPicker = true }) {
                                Label(LocalizedStringKey("Appareil photo"), systemImage: "camera.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                        }
                        
                        Button(action: { showingImagePicker = true }) {
                            Label(LocalizedStringKey("Galerie"), systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                }
                
                // Section pour créer un matériel
                Section {
                    Toggle(isOn: $creerMateriel) {
                        HStack(spacing: 12) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("Créer dans Matériels"))
                                    .font(.subheadline)
                                Text(LocalizedStringKey("Ajoute aussi cet objet à votre inventaire"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.purple)
                    
                    if creerMateriel {
                        Picker(LocalizedStringKey("Catégorie"), selection: $categorieMateriel) {
                            ForEach(categoriesDisponibles, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        
                        Picker(LocalizedStringKey("Lieu de stockage"), selection: $lieuStockageId) {
                            Text(LocalizedStringKey("Aucun")).tag(nil as UUID?)
                            ForEach(dataManager.lieuxStockage) { lieu in
                                Text(lieu.nom).tag(lieu.id as UUID?)
                            }
                        }
                    }
                }
                
                // Loueur
                Section(header: Text(LocalizedStringKey("Loueur"))) {
                    // Affichage de la personne sélectionnée ou bouton de sélection
                    Button(action: { showingPersonneSelection = true }) {
                        if let id = loueurId, let personne = dataManager.personnes.first(where: { $0.id == id }) {
                            HStack {
                                // Photo de la personne si disponible
                                if let photoData = personne.photoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.purple)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(personne.nomComplet)
                                        .foregroundColor(.primary)
                                    if let type = personne.typePersonne {
                                        Text(type.localizedName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Text(LocalizedStringKey("Sélectionner le loueur"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if dataManager.personnes.isEmpty {
                        Text(LocalizedStringKey("Aucune personne enregistrée")).foregroundColor(.secondary).font(.caption)
                    }
                }
                
                // Dates
                Section(header: Text(LocalizedStringKey("Période"))) {
                    DatePicker(LocalizedStringKey("Date de début"), selection: $dateDebut, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("Date de fin prévue"), selection: $dateFin, displayedComponents: .date)
                }
                
                // Tarification
                Section(header: Text(LocalizedStringKey("Tarification"))) {
                    Picker(LocalizedStringKey("Type de tarif"), selection: $typeTarif) {
                        ForEach(Location.TypeTarif.allCases, id: \.self) { tarif in
                            Text(tarif.localizedName).tag(tarif)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Prix"))
                        Spacer()
                        TextField("0", text: $prixUnitaire)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€ / \(typeTarif.localizedName)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Total estimé"))
                        Spacer()
                        Text(String(format: "%.2f €", prixTotal))
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                }
                
                // Caution
                Section(header: Text(LocalizedStringKey("Caution"))) {
                    HStack {
                        Text(LocalizedStringKey("Montant"))
                        Spacer()
                        TextField("0", text: $caution)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Notes
                Section(header: Text(LocalizedStringKey("Notes"))) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(LocalizedStringKey("Je loue"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("Créer")) {
                        creerMaLocation()
                    }
                    .disabled(nomObjet.isEmpty || loueurId == nil)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCameraPicker) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showingPersonneCreation) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    loueurId = newPersonneId
                })
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $loueurId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir le loueur"),
                    showAddButton: true,
                    onAddPerson: { showingPersonneCreation = true }
                )
            }
        }
    }
    
    private func creerMaLocation() {
        guard let loueur = loueurId else { return }
        
        let prix = Double(prixUnitaire.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cautionMontant = Double(caution.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        var maLocation = MaLocation(
            nomObjet: nomObjet,
            loueurId: loueur,
            dateDebut: dateDebut,
            dateFin: dateFin,
            dateRetourEffectif: nil,
            prixTotal: prixTotal,
            caution: cautionMontant,
            montantCautionRecuperee: 0,
            paiementEffectue: false,
            typeTarif: typeTarif,
            prixUnitaire: prix,
            notes: notes,
            imageData: selectedImage?.jpegData(compressionQuality: 0.7)
        )
        
        // Si l'option "Créer dans Matériels" est cochée, créer le matériel
        if creerMateriel {
            let materiel = Materiel(
                nom: nomObjet,
                description: "Créé depuis une location",
                categorie: categorieMateriel,
                lieuStockageId: lieuStockageId,
                dateAcquisition: dateDebut,
                valeur: prixTotal,
                imageData: selectedImage?.jpegData(compressionQuality: 0.7)
            )
            dataManager.ajouterMateriel(materiel)
            maLocation.materielLieId = materiel.id
        }
        
        dataManager.ajouterMaLocation(maLocation)
        dismiss()
    }
}

// MARK: - Vue pour modifier une MaLocation
struct ModifierMaLocationView: View {
    let maLocation: MaLocation
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var nomObjet: String
    @State private var loueurId: UUID?
    @State private var dateDebut: Date
    @State private var dateFin: Date
    @State private var typeTarif: Location.TypeTarif
    @State private var prixUnitaire: String
    @State private var caution: String
    @State private var notes: String
    @State private var showingImagePicker = false
    @State private var showingCameraPicker = false
    @State private var selectedImage: UIImage?
    
    init(maLocation: MaLocation) {
        self.maLocation = maLocation
        _nomObjet = State(initialValue: maLocation.nomObjet)
        _loueurId = State(initialValue: maLocation.loueurId)
        _dateDebut = State(initialValue: maLocation.dateDebut)
        _dateFin = State(initialValue: maLocation.dateFin)
        _typeTarif = State(initialValue: maLocation.typeTarif)
        _prixUnitaire = State(initialValue: String(format: "%.2f", maLocation.prixUnitaire))
        _caution = State(initialValue: String(format: "%.2f", maLocation.caution))
        _notes = State(initialValue: maLocation.notes)
        if let data = maLocation.imageData, let image = UIImage(data: data) {
            _selectedImage = State(initialValue: image)
        }
    }
    
    private var prixTotal: Double {
        let prix = Double(prixUnitaire.replacingOccurrences(of: ",", with: ".")) ?? 0
        let jours = max(1, Calendar.current.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0 + 1)
        switch typeTarif {
        case .jour: return prix * Double(jours)
        case .semaine: return prix * Double(max(1, Int(ceil(Double(jours) / 7.0))))
        case .mois: return prix * Double(max(1, Int(ceil(Double(jours) / 30.0))))
        case .forfait: return prix
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(LocalizedStringKey("Objet loué"))) {
                    TextField(LocalizedStringKey("Nom de l'objet"), text: $nomObjet)
                    
                    // Affichage de la photo existante
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .clipped()
                            .cornerRadius(8)
                    }
                    
                    // Boutons photo
                    HStack(spacing: 12) {
                        Button(action: { showingCameraPicker = true }) {
                            Label(LocalizedStringKey("Appareil photo"), systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        
                        Button(action: { showingImagePicker = true }) {
                            Label(LocalizedStringKey("Galerie"), systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Loueur"))) {
                    Picker(LocalizedStringKey("À qui je loue"), selection: $loueurId) {
                        Text(LocalizedStringKey("Choisir...")).tag(nil as UUID?)
                        ForEach(dataManager.personnes) { personne in
                            Text(personne.nomComplet).tag(personne.id as UUID?)
                        }
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Période"))) {
                    DatePicker(LocalizedStringKey("Date de début"), selection: $dateDebut, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("Date de fin prévue"), selection: $dateFin, displayedComponents: .date)
                }
                
                Section(header: Text(LocalizedStringKey("Tarification"))) {
                    Picker(LocalizedStringKey("Type de tarif"), selection: $typeTarif) {
                        ForEach(Location.TypeTarif.allCases, id: \.self) { tarif in
                            Text(tarif.localizedName).tag(tarif)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Prix"))
                        Spacer()
                        TextField("0", text: $prixUnitaire)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€ / \(typeTarif.localizedName)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Total estimé"))
                        Spacer()
                        Text(String(format: "%.2f €", prixTotal))
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Caution"))) {
                    HStack {
                        Text(LocalizedStringKey("Montant"))
                        Spacer()
                        TextField("0", text: $caution)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Notes"))) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(LocalizedStringKey("Modifier"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("Enregistrer")) {
                        enregistrerModifications()
                    }
                    .disabled(nomObjet.isEmpty || loueurId == nil)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showingCameraPicker) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
        }
    }
    
    private func enregistrerModifications() {
        guard let loueur = loueurId else { return }
        
        let prix = Double(prixUnitaire.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cautionMontant = Double(caution.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        var updated = maLocation
        updated.nomObjet = nomObjet
        updated.loueurId = loueur
        updated.dateDebut = dateDebut
        updated.dateFin = dateFin
        updated.typeTarif = typeTarif
        updated.prixUnitaire = prix
        updated.prixTotal = prixTotal
        updated.caution = cautionMontant
        updated.notes = notes
        updated.imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        
        dataManager.modifierMaLocation(updated)
        dismiss()
    }
}

// MARK: - Vue pour prêter depuis MaLocation
struct PreterMaLocationView: View {
    let maLocation: MaLocation
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var personneId: UUID?
    @State private var dateFin = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var notes = ""
    @State private var showingPersonneCreation = false
    @State private var showingPersonneSelection = false
    @State private var showingLimitAlert = false
    
    private var personneSelectionnee: Personne? {
        guard let id = personneId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(LocalizedStringKey("Emprunteur"))) {
                    Button {
                        showingPersonneSelection = true
                    } label: {
                        if let personne = personneSelectionnee {
                            HStack(spacing: 12) {
                                // Photo ou cercle coloré
                                if let data = personne.photoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(couleurPourTypePersonne(personne.typePersonne))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: personne.typePersonne?.icon ?? "person.fill")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .medium))
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(personne.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if let chantierId = personne.chantierId,
                                       let chantier = dataManager.getChantier(id: chantierId) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "building.2")
                                                .font(.caption2)
                                            Text(chantier.nom)
                                                .lineLimit(1)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    } else if let type = personne.typePersonne {
                                        Text(LocalizedStringKey(type.rawValue))
                                            .font(.caption)
                                            .foregroundColor(couleurPourTypePersonne(type))
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Text(LocalizedStringKey("Prêter à"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if dataManager.personnes.isEmpty {
                        Text(LocalizedStringKey("Aucune personne enregistrée")).foregroundColor(.secondary).font(.caption)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Période"))) {
                    DatePicker(LocalizedStringKey("Date de fin prévue"), selection: $dateFin, displayedComponents: .date)
                }
                
                Section(header: Text(LocalizedStringKey("Notes"))) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(LocalizedStringKey("Prêter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("Créer")) {
                        creerPret()
                    }
                    .disabled(personneId == nil)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPersonneCreation) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    personneId = newPersonneId
                })
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $personneId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Prêter à"),
                    showAddButton: true,
                    onAddPerson: { showingPersonneCreation = true }
                )
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Vous avez atteint la limite de prêts gratuits."))
            }
        }
    }
    
    private func creerPret() {
        guard let personne = personneId else { return }
        
        if !dataManager.peutAjouterPret() {
            showingLimitAlert = true
            return
        }
        
        dataManager.creerPretDepuisMaLocation(maLocation.id, personneId: personne, dateFin: dateFin, notes: notes)
        dismiss()
    }
}

// MARK: - Vue pour sous-louer depuis MaLocation
struct SousLouerMaLocationView: View {
    let maLocation: MaLocation
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var locataireId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var typeTarif: Location.TypeTarif = .jour
    @State private var prixUnitaire: String = ""
    @State private var caution: String = ""
    @State private var notes = ""
    @State private var showingPersonneCreation = false
    @State private var showingPersonneSelection = false
    @State private var showingLimitAlert = false
    
    private var personneSelectionnee: Personne? {
        guard let id = locataireId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    private var prixTotal: Double {
        let prix = Double(prixUnitaire.replacingOccurrences(of: ",", with: ".")) ?? 0
        let jours = max(1, Calendar.current.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0 + 1)
        switch typeTarif {
        case .jour: return prix * Double(jours)
        case .semaine: return prix * Double(max(1, Int(ceil(Double(jours) / 7.0))))
        case .mois: return prix * Double(max(1, Int(ceil(Double(jours) / 30.0))))
        case .forfait: return prix
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(LocalizedStringKey("Locataire"))) {
                    Button {
                        showingPersonneSelection = true
                    } label: {
                        if let personne = personneSelectionnee {
                            HStack(spacing: 12) {
                                // Photo ou cercle coloré
                                if let data = personne.photoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(couleurPourTypePersonne(personne.typePersonne))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: personne.typePersonne?.icon ?? "person.fill")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .medium))
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(personne.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if let chantierId = personne.chantierId,
                                       let chantier = dataManager.getChantier(id: chantierId) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "building.2")
                                                .font(.caption2)
                                            Text(chantier.nom)
                                                .lineLimit(1)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    } else if let type = personne.typePersonne {
                                        Text(LocalizedStringKey(type.rawValue))
                                            .font(.caption)
                                            .foregroundColor(couleurPourTypePersonne(type))
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Text(LocalizedStringKey("Sous-louer à"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if dataManager.personnes.isEmpty {
                        Text(LocalizedStringKey("Aucune personne enregistrée")).foregroundColor(.secondary).font(.caption)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Période"))) {
                    DatePicker(LocalizedStringKey("Date de début"), selection: $dateDebut, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("Date de fin prévue"), selection: $dateFin, displayedComponents: .date)
                }
                
                Section(header: Text(LocalizedStringKey("Tarification"))) {
                    Picker(LocalizedStringKey("Type de tarif"), selection: $typeTarif) {
                        ForEach(Location.TypeTarif.allCases, id: \.self) { tarif in
                            Text(tarif.localizedName).tag(tarif)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Prix"))
                        Spacer()
                        TextField("0", text: $prixUnitaire)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€ / \(typeTarif.localizedName)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Total estimé"))
                        Spacer()
                        Text(String(format: "%.2f €", prixTotal))
                            .fontWeight(.semibold)
                            .foregroundColor(.teal)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Caution"))) {
                    HStack {
                        Text(LocalizedStringKey("Montant"))
                        Spacer()
                        TextField("0", text: $caution)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Notes"))) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(LocalizedStringKey("Sous-louer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("Créer")) {
                        creerSousLocation()
                    }
                    .disabled(locataireId == nil)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPersonneCreation) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    locataireId = newPersonneId
                })
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $locataireId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Sous-louer à"),
                    showAddButton: true,
                    onAddPerson: { showingPersonneCreation = true }
                )
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Vous avez atteint la limite de locations gratuites."))
            }
        }
    }
    
    private func creerSousLocation() {
        guard let locataire = locataireId else { return }
        
        if !dataManager.peutAjouterLocation() {
            showingLimitAlert = true
            return
        }
        
        let prix = Double(prixUnitaire.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cautionMontant = Double(caution.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        dataManager.creerSousLocationDepuisMaLocation(maLocation.id, locataireId: locataire, dateDebut: dateDebut, dateFin: dateFin, prixUnitaire: prix, typeTarif: typeTarif, caution: cautionMontant, notes: notes)
        dismiss()
    }
}

// MARK: - ImagePicker Helper avec support caméra
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
