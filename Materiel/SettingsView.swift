// filepath: /Users/robertoulhen/Desktop/Materiel_essai/Materiel/SettingsView.swift
import SwiftUI
import CoreText
import UniformTypeIdentifiers
import StoreKit
import PDFKit
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Qualité d'image pour l'export
enum ImageExportQuality: String, CaseIterable, Identifiable {
    case original = "original"
    case high = "high"       // 80% qualité, max 2000px
    case medium = "medium"   // 60% qualité, max 1200px
    case low = "low"         // 40% qualité, max 800px
    
    var id: String { rawValue }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .original: return LocalizedStringKey("Originale (iPhone)")
        case .high: return LocalizedStringKey("Haute (2000px)")
        case .medium: return LocalizedStringKey("Moyenne (1200px)")
        case .low: return LocalizedStringKey("Basse (800px)")
        }
    }
    
    var description: LocalizedStringKey {
        switch self {
        case .original: return LocalizedStringKey("Qualité maximale, fichiers volumineux")
        case .high: return LocalizedStringKey("Excellente qualité, taille réduite")
        case .medium: return LocalizedStringKey("Bonne qualité, fichiers légers")
        case .low: return LocalizedStringKey("Qualité acceptable, très léger")
        }
    }
    
    var maxDimension: CGFloat {
        switch self {
        case .original: return 0 // Pas de redimensionnement
        case .high: return 2000
        case .medium: return 1200
        case .low: return 800
        }
    }
    
    var compressionQuality: CGFloat {
        switch self {
        case .original: return 1.0
        case .high: return 0.8
        case .medium: return 0.6
        case .low: return 0.4
        }
    }
    
    var icon: String {
        switch self {
        case .original: return "photo.fill"
        case .high: return "photo"
        case .medium: return "photo.circle"
        case .low: return "photo.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .original: return .purple
        case .high: return .blue
        case .medium: return .green
        case .low: return .orange
        }
    }
}

struct SettingsView: View {
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @AppStorage("App.ImageExportQuality") private var imageExportQuality: String = ImageExportQuality.medium.rawValue
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @State private var showSaveConfirmation = false
    @State private var showPremiumSheet = false
    
    // Réglages notifications
    @AppStorage("App.NotificationsPret") private var notificationsPretActivees: Bool = true
    @AppStorage("App.NotificationsEmprunt") private var notificationsEmpruntActivees: Bool = true
    @AppStorage("App.RappelsRetard") private var rappelsRetardActives: Bool = true
    @AppStorage("App.RappelPretDelai") private var rappelPretDelai: Int = 2
    
    // Helper function pour la localisation avec la langue sélectionnée
    private func localizedString(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    @State private var exportType: ExportType = .all
    @State private var shareURL: IdentifiableURL?
    @State private var pdfData: Data?
    @State private var exclureRetournes = false
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false

    // Propriétés computed pour la compression
    private var selectedQuality: ImageExportQuality {
        ImageExportQuality(rawValue: imageExportQuality) ?? .medium
    }
    
    private var estimatedSize: String {
        switch selectedQuality {
        case .original: return "~5 MB"
        case .high: return "~2 MB"
        case .medium: return "~800 KB"
        case .low: return "~300 KB"
        }
    }
    
    private func qualityShortName(_ quality: ImageExportQuality) -> LocalizedStringKey {
        switch quality {
        case .original: return LocalizedStringKey("Original")
        case .high: return LocalizedStringKey("Haute")
        case .medium: return LocalizedStringKey("Moyenne")
        case .low: return LocalizedStringKey("Basse")
        }
    }

    enum ExportType: String, CaseIterable {
        case all = "Tout"
        case materiels = "Matériels"
        case prets = "Prêts"
        case emprunts = "Emprunts"
        case locations = "Locations"
        case reparations = "Réparations"
        case personnes = "Personnes"
        case lieux = "Lieux"
        case chantiers = "Chantiers"
        
        var icon: String {
            switch self {
            case .all: return "square.stack.3d.up.fill"
            case .materiels: return "shippingbox.fill"
            case .prets: return "arrow.up.forward.circle.fill"
            case .emprunts: return "arrow.down.backward.circle.fill"
            case .locations: return "eurosign.circle.fill"
            case .reparations: return "wrench.and.screwdriver.fill"
            case .personnes: return "person.2.fill"
            case .lieux: return "location.fill"
            case .chantiers: return "building.2.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .purple
            case .materiels: return .blue
            case .prets: return .green
            case .emprunts: return .orange
            case .locations: return .yellow
            case .reparations: return .red
            case .personnes: return .pink
            case .lieux: return .teal
            case .chantiers: return .orange
            }
        }
    }

    private let languages: [(code: String, name: String, flag: String)] = [
        ("fr", "Français", "🇫🇷"),
        ("en", "English", "🇬🇧"),
        ("es", "Español", "🇪🇸"),
        ("de", "Deutsch", "🇩🇪"),
        ("it", "Italiano", "🇮🇹"),
        ("pt", "Português", "🇵🇹"),
        ("nl", "Nederlands", "🇳🇱")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Section Premium avec tableau des limites
                        premiumSection
                        
                        // Section Langue - Design moderne avec drapeaux
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "globe")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("Langue de l'application"))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(LocalizedStringKey("Choisissez votre langue préférée"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Grille de drapeaux
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(languages, id: \.code) { lang in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            appLanguage = lang.code
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Text(lang.flag)
                                                .font(.system(size: 28))
                                            Text(lang.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(appLanguage == lang.code ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(appLanguage == lang.code ?
                                                      AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)) :
                                                      AnyShapeStyle(Color(.systemBackground).opacity(0.8)))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(appLanguage == lang.code ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                        .shadow(color: appLanguage == lang.code ? .purple.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Indicateur de langue actuelle
                            if let currentLang = languages.first(where: { $0.code == appLanguage }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("\(currentLang.flag) \(currentLang.name)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
                        // Section Sauvegarde locale
                        VStack(alignment: .leading, spacing: 12) {
                            Label(LocalizedStringKey("Sauvegarde locale"), systemImage: "internaldrive")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Button {
                                dataManager.sauvegarderDonnees()
                                withAnimation { showSaveConfirmation = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showSaveConfirmation = false }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "tray.and.arrow.down.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(LocalizedStringKey("Sauvegarder maintenant"))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: .purple.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            
                            if showSaveConfirmation {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(LocalizedStringKey("Données sauvegardées"))
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                                .transition(.opacity.combined(with: .scale))
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            // Bouton partager sauvegarde PDF
                            Button {
                                shareBackupPDF()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.and.arrow.up.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey("Partager la sauvegarde"))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(LocalizedStringKey("Export PDF complet"))
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                    Spacer()
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green, Color.teal],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: .green.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section Compression des images - Design moderne
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(selectedQuality.color.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "photo.badge.arrow.down.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(selectedQuality.color)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("Image compression"))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(LocalizedStringKey("Optimise la taille des exports"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Grille 4 cartes horizontales
                            HStack(spacing: 8) {
                                ForEach(ImageExportQuality.allCases) { quality in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            imageExportQuality = quality.rawValue
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: quality.icon)
                                                .font(.system(size: 20, weight: .medium))
                                            Text(qualityShortName(quality))
                                                .font(.system(size: 11, weight: .medium))
                                        }
                                        .foregroundColor(imageExportQuality == quality.rawValue ? .white : quality.color)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(imageExportQuality == quality.rawValue ?
                                                      AnyShapeStyle(quality.color) :
                                                      AnyShapeStyle(quality.color.opacity(0.1)))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(imageExportQuality == quality.rawValue ? Color.clear : quality.color.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Indicateur description + taille
                            HStack(spacing: 8) {
                                Image(systemName: selectedQuality.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(selectedQuality.color)
                                Text(selectedQuality.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(estimatedSize)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedQuality.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedQuality.color.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
                        // Section Catalogue PDF (fiches avec photos)
                        VStack(alignment: .leading, spacing: 16) {
                            Label(LocalizedStringKey("Catalogue PDF"), systemImage: "doc.richtext")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(LocalizedStringKey("Exporter en fiches lisibles avec photos"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button {
                                if let url = dataManager.exporterTousMaterielsPDF() {
                                    shareURL = IdentifiableURL(url: url)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.text.image")
                                        .font(.system(size: 18))
                                    Text(LocalizedStringKey("Catalogue Matériels (PDF)"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color.red.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section Export
                        VStack(alignment: .leading, spacing: 16) {
                            Label(LocalizedStringKey("Exporter les données"), systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(LocalizedStringKey("Choisissez les données à exporter"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Grille de sélection du type d'export
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(ExportType.allCases, id: \.self) { type in
                                    Button {
                                        exportType = type
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 14))
                                            Text(LocalizedStringKey(type.rawValue))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(exportType == type ? .white : type.color)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            exportType == type ?
                                            AnyShapeStyle(LinearGradient(colors: [type.color, type.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing)) :
                                            AnyShapeStyle(type.color.opacity(0.15))
                                        )
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Option pour exclure les retournés
                            if exportType == .all || exportType == .prets || exportType == .emprunts || exportType == .locations || exportType == .reparations {
                                Toggle(isOn: $exclureRetournes) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.green)
                                        Text(LocalizedStringKey("Exclure les terminés"))
                                            .font(.subheadline)
                                    }
                                }
                                .tint(.green)
                                .padding(.vertical, 4)
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            // Bouton Partager unique
                            Button {
                                shareExport()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.up.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey("Partager l'export PDF"))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(LocalizedStringKey("Email, Fichiers, AirDrop..."))
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: .purple.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section Import/Export JSON
                        VStack(alignment: .leading, spacing: 16) {
                            Label(LocalizedStringKey("Sauvegarde JSON"), systemImage: "doc.badge.arrow.up")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(LocalizedStringKey("Utilise la sélection ci-dessus"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Button {
                                    if let url = dataManager.exporterDonneesJSON(
                                        materiels: exportType == .all || exportType == .materiels,
                                        personnes: exportType == .all || exportType == .personnes,
                                        lieux: exportType == .all || exportType == .lieux,
                                        prets: exportType == .all || exportType == .prets,
                                        emprunts: exportType == .all || exportType == .emprunts,
                                        locations: exportType == .all || exportType == .locations,
                                        reparations: exportType == .all || exportType == .reparations,
                                        chantiers: exportType == .all || exportType == .chantiers,
                                        exclureRetournes: exclureRetournes
                                    ) {
                                        shareURL = IdentifiableURL(url: url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.up.doc")
                                        Text(LocalizedStringKey("Export JSON"))
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    showImportPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.down.doc")
                                        Text(LocalizedStringKey("Import JSON"))
                                            .font(.caption)
                                    }
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Statistiques
                        VStack(alignment: .leading, spacing: 12) {
                            Label(LocalizedStringKey("Statistiques"), systemImage: "chart.bar.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                StatCard(title: localizedString("Matériels"), count: dataManager.materiels.count, color: .blue, icon: "shippingbox.fill")
                                StatCard(title: localizedString("Prêts actifs"), count: dataManager.prets.filter { $0.estActif }.count, color: .green, icon: "arrow.up.forward")
                                StatCard(title: localizedString("Emprunts actifs"), count: dataManager.emprunts.filter { $0.estActif }.count, color: .orange, icon: "arrow.down.backward")
                                StatCard(title: localizedString("Locations actives"), count: dataManager.locations.filter { $0.estActive }.count, color: .teal, icon: "eurosign.circle.fill")
                                StatCard(title: localizedString("Réparations en cours"), count: dataManager.reparations.filter { $0.estEnCours }.count, color: .red, icon: "wrench.and.screwdriver.fill")
                                StatCard(title: localizedString("Personnes"), count: dataManager.personnes.count, color: .pink, icon: "person.2.fill")
                                StatCard(title: localizedString("Lieux"), count: dataManager.lieuxStockage.count, color: .cyan, icon: "location.fill")
                                StatCard(title: localizedString("Total prêts"), count: dataManager.prets.count, color: .purple, icon: "archivebox.fill")
                                StatCard(title: localizedString("Total locations"), count: dataManager.locations.count, color: .mint, icon: "creditcard.fill")
                                StatCard(title: localizedString("Total réparations"), count: dataManager.reparations.count, color: .orange, icon: "wrench.fill")
                            }
                            
                            // Statistiques financières des réparations
                            if !dataManager.reparations.isEmpty {
                                Divider().padding(.vertical, 4)
                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(LocalizedStringKey("Dépenses réparations"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.2f €", dataManager.depensesTotalesReparations()))
                                            .font(.headline)
                                            .foregroundColor(.red)
                                    }
                                    Divider().frame(height: 30)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(LocalizedStringKey("En attente"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.2f €", dataManager.depensesEnAttenteReparations()))
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section Notifications de rappel
                        notificationsSection
                        
                        // Section À propos
                        VStack(alignment: .leading, spacing: 12) {
                            Label(LocalizedStringKey("À propos"), systemImage: "info.circle")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text(LocalizedStringKey("Version"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizedStringKey("Réglages"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(item: $shareURL) { item in
                ShareSheet(activityItems: [item.url])
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json, .data, .text, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        print("[SettingsView] Fichier sélectionné: \(url.path)")
                        
                        // Accéder au fichier en mode sécurisé
                        let accessing = url.startAccessingSecurityScopedResource()
                        print("[SettingsView] Accès sécurisé: \(accessing)")
                        
                        let success = dataManager.importerMateriels(from: url)
                        
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                        
                        if success {
                            showImportSuccess = true
                        } else {
                            showImportError = true
                        }
                    }
                case .failure(let error):
                    print("[SettingsView] Erreur sélection fichier: \(error)")
                    showImportError = true
                }
            }
            .alert(LocalizedStringKey("Import réussi"), isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Les données ont été importées avec succès"))
            }
            .alert(LocalizedStringKey("Erreur d'import"), isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Impossible d'importer le fichier"))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
        .onChange(of: appLanguage) {
            dismiss()
        }
    }
    
    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Rappels automatiques"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(LocalizedStringKey("Notifications pour les prêts et emprunts"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Toggle notifications prêts
            HStack {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                Toggle(isOn: $notificationsPretActivees) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Rappels de prêts"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(LocalizedStringKey("Recevoir un rappel avant la date de retour"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: notificationsPretActivees) { _, newValue in
                    if newValue {
                        dataManager.replanifierToutesLesNotificationsPret()
                    } else {
                        // Annuler toutes les notifications de prêt
                        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                            let pretIds = requests.filter { $0.identifier.hasPrefix("pret_") }.map { $0.identifier }
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pretIds)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            
            // Toggle notifications emprunts
            HStack {
                Image(systemName: "arrow.down.backward.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
                Toggle(isOn: $notificationsEmpruntActivees) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Rappels d'emprunts"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(LocalizedStringKey("Recevoir un rappel avant de devoir rendre"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: notificationsEmpruntActivees) { _, newValue in
                    if newValue {
                        dataManager.replanifierToutesLesNotificationsEmprunt()
                    } else {
                        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                            let empruntIds = requests.filter { $0.identifier.hasPrefix("emprunt_") }.map { $0.identifier }
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: empruntIds)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // Toggle rappels de retard
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))
                Toggle(isOn: $rappelsRetardActives) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Alertes de retard"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(LocalizedStringKey("Notification si le retour n'est pas effectué"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: rappelsRetardActives) { _, _ in
                    dataManager.replanifierToutesLesNotificationsPret()
                    dataManager.replanifierToutesLesNotificationsEmprunt()
                }
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // Sélecteur délai de rappel
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 20))
                    Text(LocalizedStringKey("Rappel avant échéance"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 8) {
                    ForEach([1, 2, 3, 7], id: \.self) { jours in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                rappelPretDelai = jours
                            }
                            // Replanifier avec le nouveau délai
                            dataManager.replanifierToutesLesNotificationsPret()
                            dataManager.replanifierToutesLesNotificationsEmprunt()
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(jours)")
                                    .font(.system(size: 18, weight: .bold))
                                Text(jours == 1 ? LocalizedStringKey("jour") : LocalizedStringKey("jours"))
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(rappelPretDelai == jours ? .white : .purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(rappelPretDelai == jours ?
                                          AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)) :
                                          AnyShapeStyle(Color.purple.opacity(0.1)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(rappelPretDelai == jours ? Color.clear : Color.purple.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(LocalizedStringKey("Recevoir un rappel X jours avant la date de retour prévue"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Premium Section
    private var premiumSection: some View {
        Button {
            showPremiumSheet = true
        } label: {
            VStack(spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: storeManager.hasUnlockedPremium ? [.green, .green.opacity(0.7)] : [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: storeManager.hasUnlockedPremium ? "checkmark.seal.fill" : "crown.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Premium"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if storeManager.hasUnlockedPremium {
                            Text(LocalizedStringKey("Premium actif"))
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text(LocalizedStringKey("Débloquez toutes les fonctionnalités"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !storeManager.hasUnlockedPremium {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Barre de progression pour la version gratuite
                if !storeManager.hasUnlockedPremium {
                    VStack(spacing: 8) {
                        // Matériels
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(LocalizedStringKey("Matériels"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(dataManager.totalMaterielsCreated) / CGFloat(StoreManager.freeMaterielLimit) * geometry.size.width, geometry.size.width))
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(dataManager.totalMaterielsCreated)/\(StoreManager.freeMaterielLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        
                        // Prêts
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.forward.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(LocalizedStringKey("Prêts"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.green, .teal],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(dataManager.totalPretsCreated) / CGFloat(StoreManager.freePretLimit) * geometry.size.width, geometry.size.width))
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(dataManager.totalPretsCreated)/\(StoreManager.freePretLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        
                        // Emprunts
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text(LocalizedStringKey("Emprunts"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, .red],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(dataManager.totalEmpruntsCreated) / CGFloat(StoreManager.freeEmpruntLimit) * geometry.size.width, geometry.size.width))
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(dataManager.totalEmpruntsCreated)/\(StoreManager.freeEmpruntLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        
                        // Locations
                        HStack(spacing: 8) {
                            Image(systemName: "eurosign.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(LocalizedStringKey("Locations"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(dataManager.totalLocationsCreated) / CGFloat(StoreManager.freeLocationLimit) * geometry.size.width, geometry.size.width))
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(dataManager.totalLocationsCreated)/\(StoreManager.freeLocationLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        
                        // Personnes
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.pink)
                            
                            Text(LocalizedStringKey("Personnes"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.pink, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(dataManager.totalPersonnesCreated) / CGFloat(StoreManager.freePersonneLimit) * geometry.size.width, geometry.size.width))
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(dataManager.totalPersonnesCreated)/\(StoreManager.freePersonneLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        
                        // Lieux
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundColor(.teal)
                            
                            Text(LocalizedStringKey("Lieux"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.teal, .cyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(dataManager.totalLieuxCreated) / CGFloat(StoreManager.freeLieuLimit) * geometry.size.width, geometry.size.width))
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(dataManager.totalLieuxCreated)/\(StoreManager.freeLieuLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        
                        // Coffre-fort
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            
                            Text(LocalizedStringKey("Coffre-fort"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.yellow, .orange],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(dataManager.totalCoffreItemsCreated) / CGFloat(StoreManager.freeCoffreLimit) * geometry.size.width, geometry.size.width))
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(dataManager.totalCoffreItemsCreated)/\(StoreManager.freeCoffreLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        
                        // Réparations
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Text(LocalizedStringKey("Réparations"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .leading)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.red, .orange],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(dataManager.totalReparationsCreated) / CGFloat(StoreManager.freeReparationLimit) * geometry.size.width, geometry.size.width))
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(dataManager.totalReparationsCreated)/\(StoreManager.freeReparationLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                storeManager.hasUnlockedPremium ?
                                LinearGradient(colors: [.green, .green.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Export Functions
    
    private func shouldExport(_ type: ExportType) -> Bool {
        return exportType == .all || exportType == type
    }
    
    private func generatePDFContent() -> String {
        var content = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: appLanguage)
        
        let title: String
        switch exportType {
        case .all:
            title = "Export complet des données"
        case .materiels:
            title = "Liste des matériels"
        case .prets:
            title = "Liste des prêts"
        case .emprunts:
            title = "Liste des emprunts"
        case .locations:
            title = "Liste des locations"
        case .personnes:
            title = "Liste des personnes"
        case .lieux:
            title = "Liste des lieux de stockage"
        case .reparations:
            title = "Liste des réparations"
        case .chantiers:
            title = "Liste des chantiers"
        }
        
        content += "\(title)\n"
        content += "Généré le \(dateFormatter.string(from: Date()))\n"
        content += String(repeating: "=", count: 50) + "\n\n"
        
        // LIEUX
        if shouldExport(.lieux) {
            content += "📍 LIEUX DE STOCKAGE (\(dataManager.lieuxStockage.count))\n"
            content += String(repeating: "-", count: 40) + "\n"
            if dataManager.lieuxStockage.isEmpty {
                content += "  Aucun lieu enregistré\n"
            } else {
                for l in dataManager.lieuxStockage {
                    content += "• \(l.nom)\n"
                    if !l.adresse.isEmpty { content += "  Adresse: \(l.adresse)\n" }
                    if !l.adresseComplete.isEmpty { content += "  Détails: \(l.adresseComplete)\n" }
                    if !l.notes.isEmpty { content += "  Notes: \(l.notes)\n" }
                    let materielsLieu = dataManager.materiels.filter { $0.lieuStockageId == l.id }
                    content += "  Matériels stockés: \(materielsLieu.count)\n"
                    if !materielsLieu.isEmpty {
                        for m in materielsLieu {
                            var detail = "    ‣ \(m.nom)"
                            if !m.categorie.isEmpty {
                                detail += " (\(m.categorie))"
                            }
                            content += detail + "\n"
                        }
                    }
                    content += "\n"  // Saut de ligne entre chaque lieu
                }
            }
            content += "\n"
        }
        
        // PERSONNES
        if shouldExport(.personnes) {
            content += "👥 PERSONNES (\(dataManager.personnes.count))\n"
            content += String(repeating: "-", count: 40) + "\n"
            if dataManager.personnes.isEmpty {
                content += "  Aucune personne enregistrée\n"
            } else {
                for p in dataManager.personnes {
                    content += "• \(p.nomComplet)\n"
                    if !p.email.isEmpty { content += "  Email: \(p.email)\n" }
                    if !p.telephone.isEmpty { content += "  Tél: \(p.telephone)\n" }
                    if !p.organisation.isEmpty { content += "  Organisation: \(p.organisation)\n" }
                    content += "\n"
                }
            }
            content += "\n"
        }
        
        // MATÉRIELS
        if shouldExport(.materiels) {
            content += "📦 MATÉRIELS (\(dataManager.materiels.count))\n"
            content += String(repeating: "-", count: 40) + "\n"
            if dataManager.materiels.isEmpty {
                content += "  Aucun matériel enregistré\n"
            } else {
                for m in dataManager.materiels {
                    content += "• \(m.nom)\n"
                    if !m.description.isEmpty { content += "  Description: \(m.description)\n" }
                    if !m.categorie.isEmpty { content += "  Catégorie: \(m.categorie)\n" }
                    content += "  Valeur: \(String(format: "%.2f", m.valeur)) €\n"
                    if let lieuId = m.lieuStockageId, let lieu = dataManager.getLieu(id: lieuId) {
                        content += "  Lieu: \(lieu.nom)\n"
                    }
                    // Informations de facture
                    if let numeroFacture = m.numeroFacture, !numeroFacture.isEmpty {
                        content += "  N° Facture: \(numeroFacture)\n"
                    }
                    if let vendeur = m.vendeur, !vendeur.isEmpty {
                        content += "  Vendeur: \(vendeur)\n"
                    }
                    if m.factureImageData != nil {
                        if m.factureIsPDF == true {
                            content += "  📄 Facture PDF jointe\n"
                        } else {
                            content += "  🖼️ Photo facture jointe\n"
                        }
                    }
                    content += "\n"
                }
            }
            content += "\n"
        }
        
        // PRÊTS
        if shouldExport(.prets) {
            let pretsFiltres = exclureRetournes ? dataManager.prets.filter { !$0.estRetourne } : dataManager.prets
            let label = exclureRetournes ? "PRÊTS EN COURS" : "PRÊTS"
            content += "➡️ \(label) (\(pretsFiltres.count))\n"
            content += String(repeating: "-", count: 40) + "\n"
            if pretsFiltres.isEmpty {
                content += exclureRetournes ? "  Aucun prêt en cours\n" : "  Aucun prêt enregistré\n"
            } else {
                for p in pretsFiltres {
                    let materielNom = dataManager.getMateriel(id: p.materielId)?.nom ?? "Matériel inconnu"
                    let personneNom = dataManager.getPersonne(id: p.personneId)?.nomComplet ?? "Personne inconnue"
                    content += "• \(materielNom) → \(personneNom)\n"
                    content += "  Du \(dateFormatter.string(from: p.dateDebut)) au \(dateFormatter.string(from: p.dateFin))\n"
                    if p.estRetourne, let dateRetour = p.dateRetourEffectif {
                        content += "  ✅ Retourné le \(dateFormatter.string(from: dateRetour))\n"
                    } else if p.estEnRetard {
                        content += "  ⚠️ EN RETARD (\(p.joursRetard) jours)\n"
                    } else {
                        content += "  🕐 En cours\n"
                    }
                    if !p.notes.isEmpty { content += "  Notes: \(p.notes)\n" }
                    content += "\n"
                }
            }
            content += "\n"
        }
        
        // EMPRUNTS
        if shouldExport(.emprunts) {
            let empruntsFiltres = exclureRetournes ? dataManager.emprunts.filter { !$0.estRetourne } : dataManager.emprunts
            let label = exclureRetournes ? "EMPRUNTS EN COURS" : "EMPRUNTS"
            content += "⬅️ \(label) (\(empruntsFiltres.count))\n"
            content += String(repeating: "-", count: 40) + "\n"
            if empruntsFiltres.isEmpty {
                content += exclureRetournes ? "  Aucun emprunt en cours\n" : "  Aucun emprunt enregistré\n"
            } else {
                for e in empruntsFiltres {
                    let personneNom = dataManager.getPersonne(id: e.personneId)?.nomComplet ?? "Personne inconnue"
                    content += "• \(e.nomObjet) ← \(personneNom)\n"
                    content += "  Du \(dateFormatter.string(from: e.dateDebut)) au \(dateFormatter.string(from: e.dateFin))\n"
                    if e.estRetourne, let dateRetour = e.dateRetourEffectif {
                        content += "  ✅ Retourné le \(dateFormatter.string(from: dateRetour))\n"
                    } else if e.estEnRetard {
                        content += "  ⚠️ EN RETARD (\(e.joursRetard) jours)\n"
                    } else {
                        content += "  🕐 En cours\n"
                    }
                    if !e.notes.isEmpty { content += "  Notes: \(e.notes)\n" }
                    content += "\n"
                }
            }
            content += "\n"
        }
        
        // LOCATIONS
        if shouldExport(.locations) {
            let locationsFiltres = exclureRetournes ? dataManager.locations.filter { !$0.estTerminee } : dataManager.locations
            let label = exclureRetournes ? "LOCATIONS EN COURS" : "LOCATIONS"
            content += "💶 \(label) (\(locationsFiltres.count))\n"
            content += String(repeating: "-", count: 40) + "\n"
            if locationsFiltres.isEmpty {
                content += exclureRetournes ? "  Aucune location en cours\n" : "  Aucune location enregistrée\n"
            } else {
                for loc in locationsFiltres {
                    let materielNom = dataManager.getMateriel(id: loc.materielId)?.nom ?? "Matériel inconnu"
                    let locataireNom = dataManager.getPersonne(id: loc.locataireId)?.nomComplet ?? "Personne inconnue"
                    content += "• \(materielNom) → \(locataireNom)\n"
                    content += "  Du \(dateFormatter.string(from: loc.dateDebut)) au \(dateFormatter.string(from: loc.dateFin))\n"
                    content += "  Prix: \(String(format: "%.2f", loc.prixTotal)) € (\(loc.typeTarif.localizedName))\n"
                    if loc.caution > 0 {
                        content += "  Caution prévue: \(String(format: "%.2f", loc.caution)) €"
                        if loc.estTerminee {
                            if loc.cautionRendue {
                                content += " ✅ Rendue"
                            } else if loc.cautionGardee {
                                let montantGarde = loc.montantCautionGardee > 0 ? loc.montantCautionGardee : loc.caution
                                content += " ❌ Gardée"
                                if montantGarde < loc.caution {
                                    content += "\n  Caution retenue: \(String(format: "%.2f", montantGarde)) € (partielle)"
                                } else {
                                    content += "\n  Caution retenue: \(String(format: "%.2f", montantGarde)) €"
                                }
                            } else {
                                content += " ⏳ En attente"
                            }
                        }
                        content += "\n"
                    }
                    content += "  Paiement: \(loc.paiementRecu ? "✅ Reçu" : "⏳ En attente")\n"
                    if loc.estTerminee, let dateRetour = loc.dateRetourEffectif {
                        content += "  ✅ Terminée le \(dateFormatter.string(from: dateRetour))\n"
                    } else if loc.estEnRetard {
                        content += "  ⚠️ EN RETARD (\(loc.joursRetard) jours)\n"
                    } else {
                        content += "  🕐 En cours\n"
                    }
                    if !loc.notes.isEmpty { content += "  Notes: \(loc.notes)\n" }
                    content += "\n"
                }
            }
            content += "\n"
        }
        
        // RÉPARATIONS
        if shouldExport(.reparations) {
            let reparationsFiltres = exclureRetournes ? dataManager.reparations.filter { !$0.estTerminee } : dataManager.reparations
            let label = exclureRetournes ? "RÉPARATIONS EN COURS" : "RÉPARATIONS"
            content += "🔧 \(label) (\(reparationsFiltres.count))\n"
            content += String(repeating: "-", count: 40) + "\n"
            if reparationsFiltres.isEmpty {
                content += exclureRetournes ? "  Aucune réparation en cours\n" : "  Aucune réparation enregistrée\n"
            } else {
                for rep in reparationsFiltres {
                    let materielNom = dataManager.getMateriel(id: rep.materielId)?.nom ?? "Matériel inconnu"
                    let reparateurNom = dataManager.getPersonne(id: rep.reparateurId)?.nomComplet ?? "Réparateur inconnu"
                    content += "• \(materielNom) → \(reparateurNom)\n"
                    content += "  Début: \(dateFormatter.string(from: rep.dateDebut))\n"
                    if let dateFin = rep.dateFinPrevue {
                        content += "  Fin prévue: \(dateFormatter.string(from: dateFin))\n"
                    }
                    if !rep.description.isEmpty { content += "  Problème: \(rep.description)\n" }
                    if let coutEstime = rep.coutEstime {
                        content += "  Coût estimé: \(String(format: "%.2f", coutEstime)) €\n"
                    }
                    if let coutFinal = rep.coutFinal {
                        content += "  Coût final: \(String(format: "%.2f", coutFinal)) €\n"
                    }
                    content += "  Paiement: \(rep.paiementRecu ? "✅ Reçu" : "⏳ En attente")\n"
                    if rep.estTerminee, let dateRetour = rep.dateRetour {
                        content += "  ✅ Terminée le \(dateFormatter.string(from: dateRetour))\n"
                    } else if rep.estEnRetard {
                        content += "  ⚠️ EN RETARD (\(rep.joursRetard) jours)\n"
                    } else {
                        content += "  🕐 En cours (\(rep.joursEnReparation) jours)\n"
                    }
                    if !rep.notes.isEmpty { content += "  Notes: \(rep.notes)\n" }
                    content += "\n"
                }
            }
            content += "\n"
        }
        
        // CHANTIERS
        if shouldExport(.chantiers) {
            content += "🏗️ CHANTIERS (\(dataManager.chantiers.count))\n"
            content += String(repeating: "-", count: 40) + "\n"
            if dataManager.chantiers.isEmpty {
                content += "  Aucun chantier enregistré\n"
            } else {
                for chantier in dataManager.chantiers {
                    let salaries = dataManager.salariesPourChantier(chantier.id)
                    let status: String
                    switch chantier.statut {
                    case "En préparation":
                        status = "◐ En préparation"
                    case "Actif":
                        status = "● Actif"
                    default:
                        status = "○ Terminé"
                    }
                    content += "• \(chantier.nom) - \(status)\n"
                    if !chantier.adresse.isEmpty { content += "  Adresse: \(chantier.adresse)\n" }
                    if !chantier.description.isEmpty { content += "  Description: \(chantier.description)\n" }
                    if !chantier.periode.isEmpty { content += "  Période: \(chantier.periode)\n" }
                    
                    // Contact du chantier
                    if let contactId = chantier.contactId, let contact = dataManager.getPersonne(id: contactId) {
                        var contactInfo = "  👤 Contact: \(contact.nomComplet)"
                        if !contact.telephone.isEmpty { contactInfo += " (☎ \(contact.telephone))" }
                        if !contact.email.isEmpty { contactInfo += " - \(contact.email)" }
                        content += contactInfo + "\n"
                    }
                    
                    if !chantier.notes.isEmpty { content += "  Notes: \(chantier.notes)\n" }
                    if salaries.isEmpty {
                        content += "  Salariés: Aucun\n"
                    } else {
                        content += "  Salariés (\(salaries.count)):\n"
                        for salarie in salaries {
                            var salarieInfo = "    - \(salarie.nomComplet)"
                            if !salarie.telephone.isEmpty { salarieInfo += " (☎ \(salarie.telephone))" }
                            content += salarieInfo + "\n"
                        }
                    }
                    content += "\n"
                }
            }
            content += "\n"
        }
        
        return content
    }
    
    private func createPDF(from content: String) -> Data {
        let pageWidth: CGFloat = 595.2  // A4
        let pageHeight: CGFloat = 841.8 // A4
        let margin: CGFloat = 40
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let textRect = CGRect(x: margin, y: margin, width: pageWidth - 2 * margin, height: pageHeight - 2 * margin)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 2
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: content, attributes: attributes)
        
        let data = renderer.pdfData { context in
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            var currentRange = CFRange(location: 0, length: 0)
            var currentPage = 0
            let totalLength = attributedString.length
            
            repeat {
                context.beginPage()
                currentPage += 1
                
                // Créer le path pour le texte
                let framePath = CGPath(rect: textRect, transform: nil)
                
                // Créer le frame pour cette page
                let frame = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)
                
                // Obtenir le contexte graphique et le retourner (le système de coordonnées PDF est inversé)
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageHeight)
                cgContext.scaleBy(x: 1.0, y: -1.0)
                
                // Dessiner le frame
                CTFrameDraw(frame, cgContext)
                
                cgContext.restoreGState()
                
                // Calculer la plage visible dans ce frame
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                currentRange = CFRange(location: visibleRange.location + visibleRange.length, length: 0)
                
            } while currentRange.location < totalLength
        }
        
        return data
    }
    
    // MARK: - Création PDF élaboré avec images
    private func createElaboratePDF() -> Data {
        let pageWidth: CGFloat = 595.2  // A4
        let pageHeight: CGFloat = 841.8 // A4
        let margin: CGFloat = 40
        let imageMaxWidth: CGFloat = pageWidth - 2 * margin
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: appLanguage)
        
        let data = renderer.pdfData { context in
            var yPosition: CGFloat = margin
            
            // Fonction helper pour commencer une nouvelle page
            func startNewPage() {
                context.beginPage()
                yPosition = margin
            }
            
            // Fonction helper pour vérifier si on a besoin d'une nouvelle page
            func checkNewPage(neededHeight: CGFloat) {
                if yPosition + neededHeight > pageHeight - margin {
                    startNewPage()
                }
            }
            
            // Fonction helper pour dessiner du texte
            func drawText(_ text: String, fontSize: CGFloat = 11, bold: Bool = false, color: UIColor = .black) {
                let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                let textSize = attributedString.boundingRect(with: CGSize(width: imageMaxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                
                checkNewPage(neededHeight: textSize.height + 5)
                attributedString.draw(in: CGRect(x: margin, y: yPosition, width: imageMaxWidth, height: textSize.height))
                yPosition += textSize.height + 3
            }
            
            // Fonction helper pour dessiner une image
            func drawImage(_ image: UIImage, maxWidth: CGFloat = 200, maxHeight: CGFloat = 150) {
                let aspectRatio = image.size.width / image.size.height
                var drawWidth = min(maxWidth, image.size.width)
                var drawHeight = drawWidth / aspectRatio
                
                if drawHeight > maxHeight {
                    drawHeight = maxHeight
                    drawWidth = drawHeight * aspectRatio
                }
                
                checkNewPage(neededHeight: drawHeight + 10)
                
                let imageRect = CGRect(x: margin + 20, y: yPosition, width: drawWidth, height: drawHeight)
                image.draw(in: imageRect)
                yPosition += drawHeight + 10
            }
            
            // Fonction helper pour dessiner une facture (image) en haute qualité
            func drawInvoiceImage(_ image: UIImage) {
                // Utiliser la méthode haute qualité pour les factures
                let highQualityImage = image.preparedForInvoiceExport()
                let maxWidth: CGFloat = imageMaxWidth // Pleine largeur
                let maxHeight: CGFloat = 400 // Plus grande pour lisibilité
                
                let aspectRatio = highQualityImage.size.width / highQualityImage.size.height
                var drawWidth = min(maxWidth, highQualityImage.size.width)
                var drawHeight = drawWidth / aspectRatio
                
                if drawHeight > maxHeight {
                    drawHeight = maxHeight
                    drawWidth = drawHeight * aspectRatio
                }
                
                checkNewPage(neededHeight: drawHeight + 15)
                
                // Centrer la facture
                let xPos = margin + (imageMaxWidth - drawWidth) / 2
                
                // Cadre autour de la facture
                let frameRect = CGRect(x: xPos - 2, y: yPosition - 2, width: drawWidth + 4, height: drawHeight + 4)
                UIColor.systemGray5.setFill()
                UIBezierPath(roundedRect: frameRect, cornerRadius: 3).fill()
                UIColor.systemGray4.setStroke()
                let framePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 3)
                framePath.lineWidth = 0.5
                framePath.stroke()
                
                let imageRect = CGRect(x: xPos, y: yPosition, width: drawWidth, height: drawHeight)
                highQualityImage.draw(in: imageRect)
                yPosition += drawHeight + 15
            }
            
            // Fonction pour extraire une miniature d'un PDF
            func drawPDFThumbnail(_ pdfData: Data, maxWidth: CGFloat = 200, maxHeight: CGFloat = 150) {
                guard let document = PDFDocument(data: pdfData),
                      let page = document.page(at: 0) else { return }
                
                let pageRect = page.bounds(for: .mediaBox)
                let scale = min(maxWidth / pageRect.width, maxHeight / pageRect.height)
                let drawWidth = pageRect.width * scale
                let drawHeight = pageRect.height * scale
                
                checkNewPage(neededHeight: drawHeight + 10)
                
                let thumbnail = page.thumbnail(of: CGSize(width: drawWidth, height: drawHeight), for: .mediaBox)
                let imageRect = CGRect(x: margin + 20, y: yPosition, width: drawWidth, height: drawHeight)
                thumbnail.draw(in: imageRect)
                yPosition += drawHeight + 10
            }
            
            // Fonction pour dessiner un PDF de facture en haute qualité
            func drawInvoicePDF(_ pdfData: Data) {
                guard let document = PDFDocument(data: pdfData),
                      let page = document.page(at: 0) else { return }
                
                let pageRect = page.bounds(for: .mediaBox)
                let maxWidth: CGFloat = imageMaxWidth // Pleine largeur
                let maxHeight: CGFloat = 450 // Grande taille pour lisibilité
                
                // Calculer l'échelle pour la haute qualité
                let scale = min(maxWidth / pageRect.width, maxHeight / pageRect.height)
                let drawWidth = pageRect.width * scale
                let drawHeight = pageRect.height * scale
                
                checkNewPage(neededHeight: drawHeight + 15)
                
                // Générer une miniature haute résolution (3x pour la qualité)
                let highResScale: CGFloat = 3.0
                let thumbnail = page.thumbnail(of: CGSize(width: pageRect.width * highResScale, height: pageRect.height * highResScale), for: .mediaBox)
                
                // Centrer le PDF
                let xPos = margin + (imageMaxWidth - drawWidth) / 2
                
                // Cadre autour du PDF
                let frameRect = CGRect(x: xPos - 2, y: yPosition - 2, width: drawWidth + 4, height: drawHeight + 4)
                UIColor.systemGray5.setFill()
                UIBezierPath(roundedRect: frameRect, cornerRadius: 3).fill()
                UIColor.systemGray4.setStroke()
                let framePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 3)
                framePath.lineWidth = 0.5
                framePath.stroke()
                
                let imageRect = CGRect(x: xPos, y: yPosition, width: drawWidth, height: drawHeight)
                thumbnail.draw(in: imageRect)
                yPosition += drawHeight + 15
            }
            
            // Fonction pour dessiner une ligne de séparation
            func drawSeparator() {
                checkNewPage(neededHeight: 15)
                let cgContext = context.cgContext
                cgContext.setStrokeColor(UIColor.lightGray.cgColor)
                cgContext.setLineWidth(0.5)
                cgContext.move(to: CGPoint(x: margin, y: yPosition))
                cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
                cgContext.strokePath()
                yPosition += 15
            }
            
            // Commencer le PDF
            startNewPage()
            
            // Titre
            let title: String
            switch exportType {
            case .all: title = "Export complet des données"
            case .materiels: title = "Liste des matériels"
            case .prets: title = "Liste des prêts"
            case .emprunts: title = "Liste des emprunts"
            case .locations: title = "Liste des locations"
            case .personnes: title = "Liste des personnes"
            case .lieux: title = "Liste des lieux de stockage"
            case .reparations: title = "Liste des réparations"
            case .chantiers: title = "Liste des chantiers"
            }
            
            drawText(title, fontSize: 18, bold: true)
            drawText("Généré le \(dateFormatter.string(from: Date()))", fontSize: 10, color: .gray)
            yPosition += 10
            drawSeparator()
            
            // LIEUX
            if shouldExport(.lieux) {
                drawText("📍 LIEUX DE STOCKAGE (\(dataManager.lieuxStockage.count))", fontSize: 14, bold: true, color: UIColor.systemTeal)
                if dataManager.lieuxStockage.isEmpty {
                    drawText("  Aucun lieu enregistré", color: .gray)
                } else {
                    for l in dataManager.lieuxStockage {
                        drawText("• \(l.nom)", bold: true)
                        if !l.adresse.isEmpty { drawText("  Adresse: \(l.adresse)") }
                        if !l.adresseComplete.isEmpty { drawText("  Détails: \(l.adresseComplete)") }
                        if !l.notes.isEmpty { drawText("  Notes: \(l.notes)") }
                        let materielsLieu = dataManager.materiels.filter { $0.lieuStockageId == l.id }
                        drawText("  Matériels stockés: \(materielsLieu.count)")
                        if !materielsLieu.isEmpty {
                            for m in materielsLieu {
                                var detail = "    ‣ \(m.nom)"
                                if !m.categorie.isEmpty {
                                    detail += " (\(m.categorie))"
                                }
                                drawText(detail, color: .darkGray)
                            }
                        }
                        yPosition += 10  // Saut de ligne entre chaque lieu
                    }
                }
                yPosition += 10
                drawSeparator()
            }
            
            // PERSONNES
            if shouldExport(.personnes) {
                drawText("👥 PERSONNES (\(dataManager.personnes.count))", fontSize: 14, bold: true, color: UIColor.systemPink)
                if dataManager.personnes.isEmpty {
                    drawText("  Aucune personne enregistrée", color: .gray)
                } else {
                    for p in dataManager.personnes {
                        drawText("• \(p.nomComplet)", bold: true)
                        if !p.email.isEmpty { drawText("  Email: \(p.email)") }
                        if !p.telephone.isEmpty { drawText("  Tél: \(p.telephone)") }
                        if !p.organisation.isEmpty { drawText("  Organisation: \(p.organisation)") }
                    }
                }
                yPosition += 10
                drawSeparator()
            }
            
            // MATÉRIELS avec factures
            if shouldExport(.materiels) {
                drawText("📦 MATÉRIELS (\(dataManager.materiels.count))", fontSize: 14, bold: true, color: UIColor.systemBlue)
                if dataManager.materiels.isEmpty {
                    drawText("  Aucun matériel enregistré", color: .gray)
                } else {
                    for m in dataManager.materiels {
                        drawText("• \(m.nom)", bold: true)
                        if !m.description.isEmpty { drawText("  Description: \(m.description)") }
                        if !m.categorie.isEmpty { drawText("  Catégorie: \(m.categorie)") }
                        drawText("  Valeur: \(String(format: "%.2f", m.valeur)) €")
                        if let lieuId = m.lieuStockageId, let lieu = dataManager.getLieu(id: lieuId) {
                            drawText("  Lieu: \(lieu.nom)")
                        }
                        
                        // Photo du matériel
                        if let imageData = m.imageData, let image = UIImage(data: imageData) {
                            drawText("  Photo:", color: .darkGray)
                            drawImage(image)
                        }
                        
                        // Informations de facture
                        if let numeroFacture = m.numeroFacture, !numeroFacture.isEmpty {
                            drawText("  N° Facture: \(numeroFacture)")
                        }
                        if let vendeur = m.vendeur, !vendeur.isEmpty {
                            drawText("  Vendeur: \(vendeur)")
                        }
                        
                        // Image ou PDF de la facture - Haute qualité
                        if let factureData = m.factureImageData {
                            if m.factureIsPDF == true {
                                drawText("  📄 Facture PDF:", color: .darkGray)
                                drawInvoicePDF(factureData)
                            } else if let factureImage = UIImage(data: factureData) {
                                drawText("  🧾 Facture:", color: .darkGray)
                                drawInvoiceImage(factureImage)
                            }
                        }
                        yPosition += 5
                    }
                }
                yPosition += 10
                drawSeparator()
            }
            
            // PRÊTS
            if shouldExport(.prets) {
                let pretsFiltres = exclureRetournes ? dataManager.prets.filter { !$0.estRetourne } : dataManager.prets
                let label = exclureRetournes ? "PRÊTS EN COURS" : "PRÊTS"
                drawText("➡️ \(label) (\(pretsFiltres.count))", fontSize: 14, bold: true, color: UIColor.systemGreen)
                if pretsFiltres.isEmpty {
                    drawText(exclureRetournes ? "  Aucun prêt en cours" : "  Aucun prêt enregistré", color: .gray)
                } else {
                    for p in pretsFiltres {
                        let materielNom = dataManager.getMateriel(id: p.materielId)?.nom ?? "Matériel inconnu"
                        let personneNom = dataManager.getPersonne(id: p.personneId)?.nomComplet ?? "Personne inconnue"
                        drawText("• \(materielNom) → \(personneNom)", bold: true)
                        drawText("  Du \(dateFormatter.string(from: p.dateDebut)) au \(dateFormatter.string(from: p.dateFin))")
                        if p.estRetourne, let dateRetour = p.dateRetourEffectif {
                            drawText("  ✅ Retourné le \(dateFormatter.string(from: dateRetour))", color: UIColor.systemGreen)
                        } else if p.estEnRetard {
                            drawText("  ⚠️ EN RETARD (\(p.joursRetard) jours)", color: UIColor.systemRed)
                        } else {
                            drawText("  🕐 En cours", color: UIColor.systemOrange)
                        }
                        if !p.notes.isEmpty { drawText("  Notes: \(p.notes)") }
                    }
                }
                yPosition += 10
                drawSeparator()
            }
            
            // EMPRUNTS
            if shouldExport(.emprunts) {
                let empruntsFiltres = exclureRetournes ? dataManager.emprunts.filter { !$0.estRetourne } : dataManager.emprunts
                let label = exclureRetournes ? "EMPRUNTS EN COURS" : "EMPRUNTS"
                drawText("⬅️ \(label) (\(empruntsFiltres.count))", fontSize: 14, bold: true, color: UIColor.systemOrange)
                if empruntsFiltres.isEmpty {
                    drawText(exclureRetournes ? "  Aucun emprunt en cours" : "  Aucun emprunt enregistré", color: .gray)
                } else {
                    for e in empruntsFiltres {
                        let personneNom = dataManager.getPersonne(id: e.personneId)?.nomComplet ?? "Personne inconnue"
                        drawText("• \(e.nomObjet) ← \(personneNom)", bold: true)
                        drawText("  Du \(dateFormatter.string(from: e.dateDebut)) au \(dateFormatter.string(from: e.dateFin))")
                        if e.estRetourne, let dateRetour = e.dateRetourEffectif {
                            drawText("  ✅ Retourné le \(dateFormatter.string(from: dateRetour))", color: UIColor.systemGreen)
                        } else if e.estEnRetard {
                            drawText("  ⚠️ EN RETARD (\(e.joursRetard) jours)", color: UIColor.systemRed)
                        } else {
                            drawText("  🕐 En cours", color: UIColor.systemOrange)
                        }
                        if !e.notes.isEmpty { drawText("  Notes: \(e.notes)") }
                        
                        // Photo de l'emprunt
                        if let imageData = e.imageData, let image = UIImage(data: imageData) {
                            drawText("  Photo:", color: .darkGray)
                            drawImage(image, maxWidth: 150, maxHeight: 100)
                        }
                    }
                }
                yPosition += 10
                drawSeparator()
            }
            
            // LOCATIONS
            if shouldExport(.locations) {
                let locationsFiltres = exclureRetournes ? dataManager.locations.filter { !$0.estTerminee } : dataManager.locations
                let label = exclureRetournes ? "LOCATIONS EN COURS" : "LOCATIONS"
                drawText("💶 \(label) (\(locationsFiltres.count))", fontSize: 14, bold: true, color: UIColor.systemYellow)
                if locationsFiltres.isEmpty {
                    drawText(exclureRetournes ? "  Aucune location en cours" : "  Aucune location enregistrée", color: .gray)
                } else {
                    for loc in locationsFiltres {
                        let materielNom = dataManager.getMateriel(id: loc.materielId)?.nom ?? "Matériel inconnu"
                        let locataireNom = dataManager.getPersonne(id: loc.locataireId)?.nomComplet ?? "Personne inconnue"
                        drawText("• \(materielNom) → \(locataireNom)", bold: true)
                        drawText("  Du \(dateFormatter.string(from: loc.dateDebut)) au \(dateFormatter.string(from: loc.dateFin))")
                        drawText("  Prix: \(String(format: "%.2f", loc.prixTotal)) € (\(loc.typeTarif.localizedName))")
                        if loc.caution > 0 {
                            var cautionText = "  Caution prévue: \(String(format: "%.2f", loc.caution)) €"
                            if loc.estTerminee {
                                if loc.cautionRendue {
                                    cautionText += " ✅ Rendue"
                                } else if loc.cautionGardee {
                                    let montantGarde = loc.montantCautionGardee > 0 ? loc.montantCautionGardee : loc.caution
                                    cautionText += " ❌ Gardée"
                                    drawText(cautionText)
                                    if montantGarde < loc.caution {
                                        drawText("  Caution retenue: \(String(format: "%.2f", montantGarde)) € (partielle)", color: UIColor.systemRed)
                                    } else {
                                        drawText("  Caution retenue: \(String(format: "%.2f", montantGarde)) €", color: UIColor.systemRed)
                                    }
                                    cautionText = "" // Éviter double affichage
                                } else {
                                    cautionText += " ⏳ En attente"
                                }
                            }
                            if !cautionText.isEmpty {
                                drawText(cautionText)
                            }
                        }
                        drawText("  Paiement: \(loc.paiementRecu ? "✅ Reçu" : "⏳ En attente")")
                        if loc.estTerminee, let dateRetour = loc.dateRetourEffectif {
                            drawText("  ✅ Terminée le \(dateFormatter.string(from: dateRetour))", color: UIColor.systemGreen)
                        } else if loc.estEnRetard {
                            drawText("  ⚠️ EN RETARD (\(loc.joursRetard) jours)", color: UIColor.systemRed)
                        } else {
                            drawText("  🕐 En cours", color: UIColor.systemOrange)
                        }
                        if !loc.notes.isEmpty { drawText("  Notes: \(loc.notes)") }
                    }
                }
                yPosition += 10
                drawSeparator()
            }
            
            // RÉPARATIONS
            if shouldExport(.reparations) {
                let reparationsFiltres = exclureRetournes ? dataManager.reparations.filter { !$0.estTerminee } : dataManager.reparations
                let label = exclureRetournes ? "RÉPARATIONS EN COURS" : "RÉPARATIONS"
                drawText("🔧 \(label) (\(reparationsFiltres.count))", fontSize: 14, bold: true, color: UIColor.systemRed)
                if reparationsFiltres.isEmpty {
                    drawText(exclureRetournes ? "  Aucune réparation en cours" : "  Aucune réparation enregistrée", color: .gray)
                } else {
                    for rep in reparationsFiltres {
                        let materielNom = dataManager.getMateriel(id: rep.materielId)?.nom ?? "Matériel inconnu"
                        let reparateurNom = dataManager.getPersonne(id: rep.reparateurId)?.nomComplet ?? "Réparateur inconnu"
                        drawText("• \(materielNom) → \(reparateurNom)", bold: true)
                        drawText("  Début: \(dateFormatter.string(from: rep.dateDebut))")
                        if let dateFin = rep.dateFinPrevue {
                            drawText("  Fin prévue: \(dateFormatter.string(from: dateFin))")
                        }
                        if !rep.description.isEmpty { drawText("  Problème: \(rep.description)") }
                        if let coutEstime = rep.coutEstime {
                            drawText("  Coût estimé: \(String(format: "%.2f", coutEstime)) €")
                        }
                        if let coutFinal = rep.coutFinal {
                            drawText("  Coût final: \(String(format: "%.2f", coutFinal)) €")
                        }
                        drawText("  Paiement: \(rep.paiementRecu ? "✅ Reçu" : "⏳ En attente")")
                        if rep.estTerminee, let dateRetour = rep.dateRetour {
                            drawText("  ✅ Terminée le \(dateFormatter.string(from: dateRetour))", color: UIColor.systemGreen)
                        } else if rep.estEnRetard {
                            drawText("  ⚠️ EN RETARD (\(rep.joursRetard) jours)", color: UIColor.systemRed)
                        } else {
                            drawText("  🕐 En cours (\(rep.joursEnReparation) jours)", color: UIColor.systemOrange)
                        }
                        if !rep.notes.isEmpty { drawText("  Notes: \(rep.notes)") }
                    }
                }
                yPosition += 10
                drawSeparator()
            }
            
            // CHANTIERS
            if shouldExport(.chantiers) {
                drawText("🏗️ CHANTIERS (\(dataManager.chantiers.count))", fontSize: 14, bold: true, color: UIColor.orange)
                if dataManager.chantiers.isEmpty {
                    drawText("  Aucun chantier enregistré", color: .gray)
                } else {
                    for chantier in dataManager.chantiers {
                        let salaries = dataManager.salariesPourChantier(chantier.id)
                        let status: String
                        switch chantier.statut {
                        case "En préparation":
                            status = "◐ En préparation"
                        case "Actif":
                            status = "● Actif"
                        default:
                            status = "○ Terminé"
                        }
                        drawText("• \(chantier.nom) - \(status)", bold: true)
                        if !chantier.adresse.isEmpty { drawText("  Adresse: \(chantier.adresse)") }
                        if !chantier.description.isEmpty { drawText("  Description: \(chantier.description)") }
                        if !chantier.periode.isEmpty { drawText("  Période: \(chantier.periode)") }
                        
                        // Contact du chantier
                        if let contactId = chantier.contactId, let contact = dataManager.getPersonne(id: contactId) {
                            var contactInfo = "  👤 Contact: \(contact.nomComplet)"
                            if !contact.telephone.isEmpty { contactInfo += " (☎ \(contact.telephone))" }
                            if !contact.email.isEmpty { contactInfo += " - \(contact.email)" }
                            drawText(contactInfo)
                        }
                        
                        if !chantier.notes.isEmpty { drawText("  Notes: \(chantier.notes)") }
                        if salaries.isEmpty {
                            drawText("  Salariés: Aucun", color: .gray)
                        } else {
                            drawText("  Salariés (\(salaries.count)):")
                            for salarie in salaries {
                                var salarieInfo = "    - \(salarie.nomComplet)"
                                if !salarie.telephone.isEmpty { salarieInfo += " (☎ \(salarie.telephone))" }
                                drawText(salarieInfo)
                            }
                        }
                    }
                }
            }
        }
        
        return data
    }
    
    // MARK: - Partager la sauvegarde locale en PDF
    private func shareBackupPDF() {
        // Export complet de toutes les données en PDF haute qualité
        let previousExportType = exportType
        exportType = .all
        let data = createElaboratePDF()
        exportType = previousExportType
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "Sauvegarde_Complete_\(dateString).pdf"
        
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let fileURL = cachePath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            shareURL = IdentifiableURL(url: fileURL)
        } catch {
            print("Erreur création fichier sauvegarde PDF: \(error)")
        }
    }
    
    private func shareExport() {
        // Utiliser le PDF élaboré avec images
        let data = createElaboratePDF()
        
        // Créer un nom de fichier lisible
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "Export_\(exportType.rawValue)_\(dateString).pdf"
        
        // Utiliser le dossier cache
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let fileURL = cachePath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            // Utiliser sheet(item:) qui est plus fiable
            shareURL = IdentifiableURL(url: fileURL)
        } catch {
            print("Erreur création fichier: \(error)")
        }
    }
}

// MARK: - Identifiable URL wrapper
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Forcer le mode clair pour l'affichage des PDF
        controller.overrideUserInterfaceStyle = .light
        
        // Exclure certaines activités non pertinentes
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        // Callback quand l'activité est terminée
        controller.completionWithItemsHandler = { _, _, _, _ in
            // Ne rien faire de spécial
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(DataManager())
}
