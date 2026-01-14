//
//  ComptabiliteView.swift
//  Materiel
//
//  Vue pour consulter l'historique comptable des locations et réparations
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Structure pour export/import JSON
struct ComptabiliteExport: Codable {
    var dateExport: Date
    var periodeDebut: Date?
    var periodeFin: Date?
    var totalRevenus: Double
    var totalDepenses: Double
    var beneficeNet: Double
    var operations: [OperationComptable]
}

struct ComptabiliteView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeriod: PeriodFilter = .total
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var operationToDelete: OperationComptable?
    
    // États pour export/import
    @State private var showingExportOptions = false
    @State private var showingImportPicker = false
    @State private var exportItem: ExportURLWrapper?
    @State private var showingImportAlert = false
    @State private var importMessage = ""
    @State private var importSuccess = false
    
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
    
    private var filteredOperations: [OperationComptable] {
        switch selectedPeriod {
        case .month:
            return dataManager.getOperationsParMoisAnnee(mois: selectedMonth, annee: selectedYear)
        case .year:
            return dataManager.getOperationsParAnnee(annee: selectedYear)
        case .total:
            return dataManager.getToutesOperations()
        }
    }
    
    private var totalRevenus: Double {
        dataManager.totalRevenusComptabilite(operations: filteredOperations)
    }
    
    private var totalDepenses: Double {
        dataManager.totalDepensesComptabilite(operations: filteredOperations)
    }
    
    private var beneficeNet: Double {
        dataManager.beneficeNetComptabilite(operations: filteredOperations)
    }
    
    private var availableYears: [Int] {
        let years = dataManager.getAnneesDisponibles()
        if years.isEmpty {
            return [Calendar.current.component(.year, from: Date())]
        }
        return years
    }
    
    private var availableMonths: [Int] {
        dataManager.getMoisDisponibles(annee: selectedYear)
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
                    colors: [Color.indigo.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Sélecteur de période
                    Picker(LocalizedStringKey("Période"), selection: $selectedPeriod) {
                        ForEach(PeriodFilter.allCases, id: \.self) { period in
                            Text(period.localizedName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Sélecteurs année/mois si nécessaire
                    if selectedPeriod != .total {
                        HStack(spacing: 12) {
                            // Sélecteur d'année
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
                                .background(Color.indigo.opacity(0.15))
                                .cornerRadius(8)
                            }
                            
                            // Sélecteur de mois (si période = mois)
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
                                    .background(Color.indigo.opacity(0.15))
                                    .cornerRadius(8)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    // Résumé financier
                    VStack(spacing: 16) {
                        HStack(spacing: 0) {
                            // Revenus
                            VStack(spacing: 4) {
                                Text(LocalizedStringKey("Revenus"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", totalRevenus))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 40)
                            
                            // Dépenses
                            VStack(spacing: 4) {
                                Text(LocalizedStringKey("Dépenses"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", totalDepenses))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 40)
                            
                            // Bénéfice
                            VStack(spacing: 4) {
                                Text(LocalizedStringKey("Bénéfice"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", beneficeNet))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(beneficeNet >= 0 ? .blue : .orange)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // Liste des opérations
                    if filteredOperations.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(LocalizedStringKey("Aucune opération"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Les opérations comptables apparaîtront ici"))
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(groupedOperations, id: \.key) { group in
                                Section(header: Text(group.key)) {
                                    ForEach(group.operations) { operation in
                                        OperationRowView(operation: operation)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    operationToDelete = operation
                                                    showingDeleteAlert = true
                                                } label: {
                                                    Label(LocalizedStringKey("Supprimer"), systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Comptabilité"))
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
                            .foregroundColor(.indigo)
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
            .alert(LocalizedStringKey("Supprimer cette opération ?"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    operationToDelete = nil
                }
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let operation = operationToDelete {
                        dataManager.supprimerOperationComptable(operation)
                        operationToDelete = nil
                    }
                }
            } message: {
                Text(LocalizedStringKey("Cette opération sera définitivement supprimée de l'historique comptable. Cette action est irréversible."))
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
            kCGPDFContextTitle: "Rapport Comptabilité"
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
            let title = "Rapport Comptabilité"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.systemIndigo
            ]
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 35
            
            // Période
            let subtitleFont = UIFont.systemFont(ofSize: 14)
            let periodText = getPeriodDescription()
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.gray
            ]
            periodText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition += 20
            
            // Date d'export
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            let exportDateText = "Exporté le \(dateFormatter.string(from: Date()))"
            exportDateText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition += 40
            
            // Résumé financier
            let headerFont = UIFont.boldSystemFont(ofSize: 16)
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ]
            "Résumé Financier".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let greenAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.systemGreen
            ]
            let redAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.systemRed
            ]
            let blueAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.systemBlue
            ]
            
            String(format: "Revenus: %.2f €", totalRevenus).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: greenAttributes)
            yPosition += 18
            String(format: "Dépenses: %.2f €", totalDepenses).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: redAttributes)
            yPosition += 18
            String(format: "Bénéfice net: %.2f €", beneficeNet).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: blueAttributes)
            yPosition += 35
            
            // Liste des opérations
            "Détail des opérations".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.darkGray
            ]
            
            let dateFormatterShort = DateFormatter()
            dateFormatterShort.dateStyle = .short
            
            for operation in filteredOperations.sorted(by: { $0.date > $1.date }) {
                // Vérifier si on a besoin d'une nouvelle page
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = margin
                }
                
                let dateStr = dateFormatterShort.string(from: operation.date)
                let typeStr = operation.typeOperation.localizedName
                let montantStr = String(format: "%.2f €", operation.montant)
                let prefix = operation.typeOperation.isRevenu ? "+" : "-"
                
                let line = "\(dateStr) - \(typeStr): \(prefix)\(montantStr)"
                let attrs = operation.typeOperation.isRevenu ? greenAttributes : redAttributes
                line.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: attrs)
                yPosition += 15
                
                if let materielNom = operation.materielNom {
                    "   Matériel: \(materielNom)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 15
                }
                if let personneNom = operation.personneNom {
                    "   Personne: \(personneNom)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 15
                }
                yPosition += 5
            }
        }
        
        return data
    }
    
    private func getPeriodDescription() -> String {
        switch selectedPeriod {
        case .month:
            return "Période: \(monthName(selectedMonth)) \(selectedYear)"
        case .year:
            return "Période: Année \(selectedYear)"
        case .total:
            return "Période: Historique complet"
        }
    }
    
    private func generateFileName(extension ext: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = dateFormatter.string(from: Date())
        return "comptabilite_\(dateStr).\(ext)"
    }
    
    // MARK: - Export JSON
    private func exportJSON() {
        let exportData = ComptabiliteExport(
            dateExport: Date(),
            periodeDebut: getPeriodicStartDate(),
            periodeFin: getPeriodicEndDate(),
            totalRevenus: totalRevenus,
            totalDepenses: totalDepenses,
            beneficeNet: beneficeNet,
            operations: filteredOperations
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
    
    private func getPeriodicStartDate() -> Date? {
        switch selectedPeriod {
        case .month:
            var components = DateComponents()
            components.year = selectedYear
            components.month = selectedMonth
            components.day = 1
            return Calendar.current.date(from: components)
        case .year:
            var components = DateComponents()
            components.year = selectedYear
            components.month = 1
            components.day = 1
            return Calendar.current.date(from: components)
        case .total:
            return nil
        }
    }
    
    private func getPeriodicEndDate() -> Date? {
        switch selectedPeriod {
        case .month:
            var components = DateComponents()
            components.year = selectedYear
            components.month = selectedMonth + 1
            components.day = 0 // Dernier jour du mois
            return Calendar.current.date(from: components)
        case .year:
            var components = DateComponents()
            components.year = selectedYear
            components.month = 12
            components.day = 31
            return Calendar.current.date(from: components)
        case .total:
            return nil
        }
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
            
            let importedData = try decoder.decode(ComptabiliteExport.self, from: jsonData)
            
            // Importer les opérations
            var importedCount = 0
            var duplicateCount = 0
            
            for operation in importedData.operations {
                // Vérifier si l'opération existe déjà (par ID)
                let existingOperations = dataManager.getToutesOperations()
                if !existingOperations.contains(where: { $0.id == operation.id }) {
                    dataManager.ajouterOperationComptable(operation)
                    importedCount += 1
                } else {
                    duplicateCount += 1
                }
            }
            
            importMessage = "\(importedCount) opération(s) importée(s)"
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
    
    // Grouper les opérations par date
    private var groupedOperations: [(key: String, operations: [OperationComptable])] {
        let grouped = Dictionary(grouping: filteredOperations) { operation -> String in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale.current
            return formatter.string(from: operation.date)
        }
        return grouped.map { (key: $0.key, operations: $0.value) }
            .sorted { $0.operations.first?.date ?? Date() > $1.operations.first?.date ?? Date() }
    }
}

// MARK: - Vue de ligne d'opération
struct OperationRowView: View {
    let operation: OperationComptable
    
    private var iconName: String {
        switch operation.typeOperation {
        case .locationRevenu: return "eurosign.circle.fill"
        case .locationCaution: return "shield.fill"
        case .reparationDepense: return "wrench.and.screwdriver.fill"
        case .maLocationDepense: return "cart.fill"
        case .maLocationCautionPerdue: return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch operation.typeOperation {
        case .locationRevenu: return .green
        case .locationCaution: return .orange
        case .reparationDepense: return .red
        case .maLocationDepense: return .purple
        case .maLocationCautionPerdue: return .red
        }
    }
    
    private var montantColor: Color {
        operation.typeOperation.isRevenu ? .green : .red
    }
    
    private var montantPrefix: String {
        operation.typeOperation.isRevenu ? "+" : "-"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)
            
            // Informations
            VStack(alignment: .leading, spacing: 2) {
                Text(operation.typeOperation.localizedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let materielNom = operation.materielNom {
                    Text(materielNom)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let personneNom = operation.personneNom {
                    Text(personneNom)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Montant
            Text("\(montantPrefix)\(String(format: "%.2f", operation.montant)) €")
                .font(.headline)
                .foregroundColor(montantColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ComptabiliteView()
        .environmentObject(DataManager())
}
