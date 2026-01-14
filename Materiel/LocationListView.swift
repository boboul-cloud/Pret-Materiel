//
//  LocationListView.swift
//  Materiel
//
//  Vue pour gérer les locations de matériel
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Fonction helper pour les couleurs de type de personne
private func couleurPourTypePersonne(_ type: TypePersonne?) -> Color {
    switch type {
    case .mecanicien: return .orange
    case .salarie: return .green
    case .alm: return .purple
    case .client, .none: return .blue
    }
}

struct LocationListView: View {
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
    
    // Vérifie si une location peut être supprimée (toutes les actions terminées)
    private func locationPeutEtreSupprimee(_ location: Location) -> Bool {
        let retourEffectue = location.dateRetourEffectif != nil
        let paiementOk = location.paiementRecu
        let cautionGeree = location.caution == 0 || location.cautionRendue || location.cautionGardee
        return retourEffectue && paiementOk && cautionGeree
    }
    
    private let statutOptions = ["Tous", "En cours", "En retard", "Terminées"]
    private let paiementOptions = ["Tous", "Payé", "Non payé"]
    private let cautionOptions = ["Tous", "Gardée", "Restituée", "En attente"]
    
    var locationsFiltrees: [Location] {
        var locs = dataManager.locations
        
        // Filtre par statut
        switch filtreStatut {
        case "En cours": locs = locs.filter { $0.estActive && !$0.estEnRetard }
        case "En retard": locs = locs.filter { $0.estEnRetard }
        case "Terminées": locs = locs.filter { $0.estTerminee }
        default: break
        }
        
        // Filtre par paiement
        switch filtrePaiement {
        case "Payé": locs = locs.filter { $0.paiementRecu }
        case "Non payé": locs = locs.filter { !$0.paiementRecu }
        default: break
        }
        
        // Filtre par caution
        switch filtreCaution {
        case "Gardée": locs = locs.filter { $0.cautionGardee }
        case "Restituée": locs = locs.filter { $0.cautionRendue && !$0.cautionGardee }
        case "En attente": locs = locs.filter { !$0.cautionRendue && !$0.cautionGardee && $0.caution > 0 }
        default: break
        }
        
        // Filtre par recherche
        if !searchText.isEmpty {
            locs = locs.filter { location in
                if let materiel = dataManager.getMateriel(id: location.materielId),
                   materiel.nom.localizedCaseInsensitiveContains(searchText) { return true }
                if let personne = dataManager.getPersonne(id: location.locataireId),
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
                    colors: [Color.green.opacity(0.15), Color.teal.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    // Résumé financier
                    if !dataManager.locations.isEmpty {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey("Revenus"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", dataManager.revenuTotalLocations()))
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            Divider().frame(height: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey("En attente"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f €", dataManager.revenuEnAttenteLocations()))
                                    .font(.headline)
                                    .foregroundColor(.orange)
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
                    
                    // Filtres supplémentaires (paiement et caution)
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
                            .background(filtrePaiement != "Tous" ? Color.green.opacity(0.15) : Color(.systemGray6))
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
                                Image(systemName: filtreCaution == "Gardée" ? "lock.fill" : (filtreCaution == "Restituée" ? "arrow.uturn.backward.circle.fill" : (filtreCaution == "En attente" ? "hourglass" : "shield")))
                                    .foregroundColor(filtreCaution == "Gardée" ? .red : (filtreCaution == "Restituée" ? .green : (filtreCaution == "En attente" ? .orange : .primary)))
                                Text(LocalizedStringKey(filtreCaution == "Tous" ? "Caution" : filtreCaution))
                                    .font(.subheadline)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(filtreCaution != "Tous" ? Color.teal.opacity(0.15) : Color(.systemGray6))
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
                    
                    Button {
                        if dataManager.peutAjouterLocation() {
                            showingAddSheet = true
                        } else {
                            showingLimitAlert = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "eurosign.circle.fill")
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
                                colors: [Color.green, Color.teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    List {
                        ForEach(locationsFiltrees) { location in
                            LocationRowView(location: location)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            // Vérifier si toutes les locations à supprimer ont leurs actions terminées
                            let locationsToDelete = offsets.map { locationsFiltrees[$0] }
                            let allCanBeDeleted = locationsToDelete.allSatisfy { locationPeutEtreSupprimee($0) }
                            
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
            .navigationTitle(LocalizedStringKey("Locations"))
            .sheet(isPresented: $showingAddSheet) {
                AjouterLocationView()
            }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        for index in offsets {
                            let location = locationsFiltrees[index]
                            dataManager.supprimerLocation(location)
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
}

// MARK: - Location Detail View
/// Vue de détail pour une location, accessible depuis la fiche personne
struct LocationDetailView: View {
    let location: Location
    @EnvironmentObject var dataManager: DataManager
    @State private var showingConfirmation = false
    @State private var showingSousLocationActifAlert = false
    @State private var showingCautionSheet = false
    @State private var showingReparationSheet = false
    @State private var montantCautionAGarder: String = ""
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
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
        switch location.typeTarif {
        case .jour: return NSLocalizedString("jour(s)", comment: "")
        case .semaine: return NSLocalizedString("semaine(s)", comment: "")
        case .mois: return NSLocalizedString("mois", comment: "")
        case .forfait: return ""
        }
    }
    
    // Lire la version courante depuis le store
    private var locationCourante: Location {
        dataManager.locations.first { $0.id == location.id } ?? location
    }
    
    // Vérifie si la location est actuellement sous-louée à quelqu'un
    private var sousLocationActif: Location? {
        dataManager.locationEstSousLouee(locationCourante.id)
    }
    
    // Nom de la personne à qui la location est sous-louée
    private var nomPersonneSousLocation: String {
        guard let sousLocation = sousLocationActif,
              let personne = dataManager.getPersonne(id: sousLocation.locataireId) else {
            return ""
        }
        return personne.nomComplet
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Carte principale avec infos
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        if let materiel = dataManager.getMateriel(id: locationCourante.materielId) {
                            if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipped()
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3)))
                            } else {
                                Image(systemName: "eurosign.circle")
                                    .font(.system(size: 35))
                                    .foregroundColor(.green)
                                    .frame(width: 70, height: 70)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(materiel.nom)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if locationCourante.estTerminee {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    } else if locationCourante.estEnRetard {
                                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                    } else {
                                        Image(systemName: "clock.fill").foregroundColor(.orange)
                                    }
                                }
                            }
                        } else {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 35))
                                .foregroundColor(.orange)
                                .frame(width: 70, height: 70)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(10)
                            Text(LocalizedStringKey("Matériel inconnu"))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let personne = dataManager.getPersonne(id: locationCourante.locataireId) {
                        Label(personne.nomComplet, systemImage: "person")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    
                    // Prix et paiement
                    HStack {
                        // Afficher le prix réel basé sur la durée effective
                        Text(String(format: "%.2f €", locationCourante.prixTotalReel))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if locationCourante.typeTarif != .forfait {
                            Text("(\(locationCourante.nombreUnitesReelles) \(uniteLabel))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if locationCourante.paiementRecu {
                            Label(LocalizedStringKey("Payé"), systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label(LocalizedStringKey("Non payé"), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if locationCourante.caution > 0 {
                            Spacer()
                            HStack(spacing: 4) {
                                if locationCourante.cautionGardee {
                                    // Afficher le montant retenu (partiel ou total)
                                    let montantGarde = locationCourante.montantCautionGardee > 0 ? locationCourante.montantCautionGardee : locationCourante.caution
                                    if montantGarde < locationCourante.caution {
                                        // Caution partielle retenue
                                        Text("\(String(format: "%.0f", montantGarde))/\(String(format: "%.0f", locationCourante.caution)) €")
                                            .font(.caption)
                                    } else {
                                        // Caution totale
                                        Text("Caution: \(String(format: "%.0f €", locationCourante.caution))")
                                            .font(.caption)
                                    }
                                    Image(systemName: "hand.raised.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else {
                                    Text("Caution: \(String(format: "%.0f €", locationCourante.caution))")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(locationCourante.cautionRendue ? .green : (locationCourante.cautionGardee ? .red : .secondary))
                        }
                    }
                    
                    // Dates
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(localizedString("Du")) \(formatDate(locationCourante.dateDebut))").font(.caption)
                            Text("\(localizedString("au")) \(formatDate(locationCourante.dateFin))").font(.caption)
                        }.foregroundColor(.secondary)
                        Spacer()
                        if locationCourante.estTerminee, let dateRetour = locationCourante.dateRetourEffectif {
                            Text("\(localizedString("Retourné le")) \(formatDate(dateRetour))")
                                .font(.caption).foregroundColor(.green)
                        } else if locationCourante.estEnRetard {
                            Text("\(locationCourante.joursRetard) \(localizedString("jour(s) de retard"))")
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    // Notes
                    if !locationCourante.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "note.text").foregroundColor(.secondary)
                            Text(locationCourante.notes).font(.callout).foregroundColor(.primary)
                        }.padding(.top, 2)
                    }
                    
                    // Indicateur si la location est actuellement sous-louée
                    if let sousLocation = sousLocationActif {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("Sous-loué à"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(nomPersonneSousLocation)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.teal)
                            }
                            Spacer()
                            Text(LocalizedStringKey("jusqu'au \(formatDate(sousLocation.dateFin))"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.teal.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Boutons d'action
                    VStack(spacing: 8) {
                        if !locationCourante.estTerminee {
                            if sousLocationActif != nil {
                                Button {
                                    dataManager.validerRetourSousLocation(locationCourante.id)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.uturn.backward.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(LocalizedStringKey("Récupérer de la sous-location"))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.teal.opacity(0.85), Color.cyan.opacity(0.9)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                                }.buttonStyle(.plain)
                            } else {
                                // Bouton Terminer
                                Button { showingConfirmation = true } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(LocalizedStringKey("Terminer"))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.85), Color.mint.opacity(0.9)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                                }.buttonStyle(.plain)
                                
                                // Bouton Marquer payé
                                if !locationCourante.paiementRecu {
                                    Button {
                                        dataManager.marquerPaiementRecu(locationCourante.id, recu: true)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "eurosign.circle.fill")
                                            Text(LocalizedStringKey("Marquer payé"))
                                        }
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            // Location terminée - afficher seulement le bouton marquer payé si nécessaire
                            if !locationCourante.paiementRecu {
                                Button {
                                    dataManager.marquerPaiementRecu(locationCourante.id, recu: true)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eurosign.circle.fill")
                                        Text(LocalizedStringKey("Marquer payé"))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 4)
                    
                    // Gestion de la caution après retour
                    if locationCourante.estTerminee && locationCourante.caution > 0 && !locationCourante.cautionRendue && !locationCourante.cautionGardee {
                        HStack(spacing: 12) {
                            Button {
                                dataManager.marquerCautionRendue(locationCourante.id, rendue: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                    Text(LocalizedStringKey("Rendre caution"))
                                }
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                montantCautionAGarder = String(format: "%.2f", locationCourante.caution)
                                showingCautionSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.raised.fill")
                                    Text(LocalizedStringKey("Retenir caution"))
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.15), Color.teal.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(LocalizedStringKey("Détail de la location"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(LocalizedStringKey("Terminer cette location ?"), isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button(LocalizedStringKey("Terminer la location")) {
                dataManager.validerRetourLocation(locationCourante.id)
            }
            Button(LocalizedStringKey("Envoyer en réparation")) {
                showingReparationSheet = true
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Que souhaitez-vous faire avec ce matériel ?"))
        }
        .alert(LocalizedStringKey("Retour impossible"), isPresented: $showingSousLocationActifAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) {}
        } message: {
            Text("Votre location est sous-louée à \(nomPersonneSousLocation). Vous ne pouvez pas la terminer tant que la sous-location n'est pas retournée.")
        }
        .sheet(isPresented: $showingCautionSheet) {
            RetenirCautionView(
                location: locationCourante,
                montantAGarder: $montantCautionAGarder,
                onConfirm: { montant in
                    dataManager.garderCaution(locationCourante.id, montant: montant)
                    showingCautionSheet = false
                },
                onCancel: {
                    showingCautionSheet = false
                }
            )
        }
        .sheet(isPresented: $showingReparationSheet) {
            EnvoyerEnReparationLocationView(location: locationCourante)
        }
    }
}

// MARK: - Location Row View

struct LocationRowView: View {
    let location: Location
    @EnvironmentObject var dataManager: DataManager
    @State private var showingConfirmation = false
    @State private var showingDetail = false
    @State private var showingSousLouerSheet = false
    @State private var showingSousLocationActifAlert = false
    @State private var showingReparationSheet = false
    @State private var showingCautionSheet = false
    @State private var montantCautionAGarder: String = ""
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
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
        switch location.typeTarif {
        case .jour: return NSLocalizedString("jour(s)", comment: "")
        case .semaine: return NSLocalizedString("semaine(s)", comment: "")
        case .mois: return NSLocalizedString("mois", comment: "")
        case .forfait: return ""
        }
    }
    
    // Vérifie si la location est actuellement sous-louée à quelqu'un
    private var sousLocationActif: Location? {
        dataManager.locationEstSousLouee(location.id)
    }
    
    // Nom de la personne à qui la location est sous-louée
    private var nomPersonneSousLocation: String {
        guard let sousLocation = sousLocationActif,
              let personne = dataManager.getPersonne(id: sousLocation.locataireId) else {
            return ""
        }
        return personne.nomComplet
    }
    
    var body: some View {
        let debutFormat = formatDate(location.dateDebut)
        let finFormat = formatDate(location.dateFin)
        let joursRetard = location.joursRetard
        
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                if let materiel = dataManager.getMateriel(id: location.materielId) {
                    if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    } else {
                        Image(systemName: "eurosign.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                            .frame(width: 56, height: 56)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(materiel.nom).font(.headline)
                            Spacer()
                            if location.estTerminee {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            } else if location.estEnRetard {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            } else {
                                Image(systemName: "clock.fill").foregroundColor(.orange)
                            }
                        }
                    }
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                        .frame(width: 56, height: 56)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(LocalizedStringKey("Matériel inconnu")).font(.headline).foregroundColor(.orange)
                            Spacer()
                        }
                    }
                }
            }
            
            if let personne = dataManager.getPersonne(id: location.locataireId) {
                Label(personne.nomComplet, systemImage: "person")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            // Prix et paiement
            HStack {
                // Afficher le prix réel basé sur la durée effective
                Text(String(format: "%.2f €", location.prixTotalReel))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Afficher la durée effective
                if location.typeTarif != .forfait {
                    Text("(\(location.nombreUnitesReelles) \(uniteLabel))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if location.paiementRecu {
                    Label(LocalizedStringKey("Payé"), systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label(LocalizedStringKey("Non payé"), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if location.caution > 0 {
                    Spacer()
                    HStack(spacing: 4) {
                        if location.cautionGardee {
                            // Afficher le montant retenu (partiel ou total)
                            let montantGarde = location.montantCautionGardee > 0 ? location.montantCautionGardee : location.caution
                            if montantGarde < location.caution {
                                // Caution partielle
                                Text("\(String(format: "%.0f", montantGarde))/\(String(format: "%.0f", location.caution)) €")
                                    .font(.caption)
                            } else {
                                // Caution totale
                                Text("Caution: \(String(format: "%.0f €", location.caution))")
                                    .font(.caption)
                            }
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Caution: \(String(format: "%.0f €", location.caution))")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(location.cautionRendue ? .green : (location.cautionGardee ? .red : .secondary))
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(localizedString("Du")) \(debutFormat)").font(.caption)
                    Text("\(localizedString("au")) \(finFormat)").font(.caption)
                }.foregroundColor(.secondary)
                Spacer()
                if location.estTerminee, let dateRetour = location.dateRetourEffectif {
                    Text("\(localizedString("Retourné le")) \(formatDate(dateRetour))")
                        .font(.caption).foregroundColor(.green)
                } else if location.estEnRetard {
                    Text("\(joursRetard) \(localizedString("jour(s) de retard"))")
                        .font(.caption).foregroundColor(.red)
                }
            }
            
            if !location.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text").foregroundColor(.secondary)
                    Text(location.notes).font(.callout).foregroundColor(.primary).lineLimit(2)
                }.padding(.top, 2)
            }
            
            // Indicateur si la location est actuellement sous-louée
            if let sousLocation = sousLocationActif {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Sous-loué à"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(nomPersonneSousLocation)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.teal)
                    }
                    Spacer()
                    Text(LocalizedStringKey("jusqu'au \(formatDate(sousLocation.dateFin))"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.teal.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.teal.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Boutons d'action
            VStack(spacing: 8) {
                if !location.estTerminee {
                    // Si la location est sous-louée, afficher le bouton pour valider le retour de la sous-location
                    if sousLocationActif != nil {
                        Button {
                            dataManager.validerRetourSousLocation(location.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(LocalizedStringKey("Récupérer de la sous-location"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.teal.opacity(0.85), Color.cyan.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: .teal.opacity(0.25), radius: 4, x: 0, y: 2)
                        }.buttonStyle(.plain)
                        
                        // Bouton de retour désactivé avec message
                        Button { showingSousLocationActifAlert = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(LocalizedStringKey("Retour impossible"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                        }.buttonStyle(.plain)
                    } else {
                        // Bouton Terminer
                        Button { showingConfirmation = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(LocalizedStringKey("Terminer"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.85), Color.mint.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: .green.opacity(0.25), radius: 4, x: 0, y: 2)
                        }.buttonStyle(.plain)
                        
                        // Bouton Marquer payé - disponible avant ET après retour
                        if !location.paiementRecu {
                            Button {
                                dataManager.marquerPaiementRecu(location.id, recu: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "eurosign.circle.fill")
                                    Text(LocalizedStringKey("Marquer payé"))
                                }
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    // Location terminée - afficher seulement le bouton marquer payé si nécessaire
                    if !location.paiementRecu {
                        Button {
                            dataManager.marquerPaiementRecu(location.id, recu: true)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eurosign.circle.fill")
                                Text(LocalizedStringKey("Marquer payé"))
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 4)
            
            // Gestion de la caution après retour
            if location.estTerminee && location.caution > 0 && !location.cautionRendue && !location.cautionGardee {
                HStack(spacing: 12) {
                    Button {
                        dataManager.marquerCautionRendue(location.id, rendue: true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                            Text(LocalizedStringKey("Rendre caution"))
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        montantCautionAGarder = String(format: "%.2f", location.caution)
                        showingCautionSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                            Text(LocalizedStringKey("Retenir caution"))
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
        )
        .confirmationDialog(LocalizedStringKey("Terminer cette location ?"), isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button(LocalizedStringKey("Valider le retour")) {
                dataManager.validerRetourLocation(location.id)
            }
            Button(LocalizedStringKey("Envoyer en réparation")) { 
                showingReparationSheet = true 
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) { }
        } message: { 
            Text(LocalizedStringKey("Que souhaitez-vous faire avec ce matériel ?")) 
        }
        .alert(LocalizedStringKey("Retour impossible"), isPresented: $showingSousLocationActifAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) {}
        } message: {
            Text("Votre location est sous-louée à \(nomPersonneSousLocation). Vous ne pouvez pas la terminer tant que la sous-location n'est pas retournée.")
        }
        .sheet(isPresented: $showingSousLouerSheet) {
            SousLouerLocationView(locationId: location.id, materielNom: dataManager.getMateriel(id: location.materielId)?.nom ?? "Matériel")
        }
        .sheet(isPresented: $showingReparationSheet) {
            EnvoyerEnReparationLocationView(location: location)
        }
        .sheet(isPresented: $showingCautionSheet) {
            RetenirCautionView(
                location: location,
                montantAGarder: $montantCautionAGarder,
                onConfirm: { montant in
                    dataManager.garderCaution(location.id, montant: montant)
                    showingCautionSheet = false
                },
                onCancel: {
                    showingCautionSheet = false
                }
            )
        }
    }
}

// Vue pour envoyer un matériel en réparation depuis une location
struct EnvoyerEnReparationLocationView: View {
    let location: Location
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var reparateurId: UUID?
    @State private var description = ""
    @State private var dateFinPrevue: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var useDateFinPrevue = false
    @State private var coutEstime = ""
    @State private var estGratuite = false
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingAddReparateur = false
    
    var reparateurs: [Personne] {
        dataManager.getMecaniciens()
    }
    
    var peutCreer: Bool {
        reparateurId != nil && !description.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Matériel concerné
                Section(LocalizedStringKey("Matériel")) {
                    if let materiel = dataManager.getMateriel(id: location.materielId) {
                        HStack {
                            if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                Image(systemName: "shippingbox.fill")
                                    .font(.title)
                                    .foregroundColor(.orange)
                                    .frame(width: 50, height: 50)
                            }
                            VStack(alignment: .leading) {
                                Text(materiel.nom)
                                    .font(.headline)
                                if !materiel.description.isEmpty {
                                    Text(materiel.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section(LocalizedStringKey("Réparateur")) {
                    Picker(LocalizedStringKey("Sélectionner le réparateur"), selection: $reparateurId) {
                        Text(LocalizedStringKey("Choisir...")).tag(nil as UUID?)
                        ForEach(reparateurs) { p in
                            Text(p.nomComplet).tag(p.id as UUID?)
                        }
                    }
                    if reparateurs.isEmpty {
                        Text(LocalizedStringKey("Aucun réparateur enregistré"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Button { showingAddReparateur = true } label: {
                        Label(LocalizedStringKey("Ajouter un réparateur"), systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                
                Section(LocalizedStringKey("Description du problème")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
                
                Section(LocalizedStringKey("Date de fin prévue")) {
                    Toggle(LocalizedStringKey("Définir une date de fin"), isOn: $useDateFinPrevue)
                    if useDateFinPrevue {
                        DatePicker(LocalizedStringKey("Date de fin prévue"), selection: $dateFinPrevue, displayedComponents: .date)
                    }
                }
                
                Section(LocalizedStringKey("Coût")) {
                    Toggle(LocalizedStringKey("Réparation gratuite"), isOn: $estGratuite)
                    
                    if !estGratuite {
                        TextField(LocalizedStringKey("Coût estimé en €"), text: $coutEstime)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Envoyer en réparation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Envoyer")) {
                        envoyerEnReparation()
                    }
                    .disabled(!peutCreer)
                }
            }
            .alert(LocalizedStringKey("Erreur"), isPresented: $showingAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingAddReparateur) {
                AjouterReparateurLocationView()
            }
        }
        .onChange(of: dataManager.personnes.count) { oldValue, newValue in
            if newValue > oldValue {
                if let nouveauReparateur = dataManager.personnes.last,
                   nouveauReparateur.typePersonne == .mecanicien {
                    reparateurId = nouveauReparateur.id
                }
            }
        }
    }
    
    private func envoyerEnReparation() {
        guard let reparateurId = reparateurId else {
            alertMessage = NSLocalizedString("Veuillez sélectionner un réparateur", comment: "")
            showingAlert = true
            return
        }
        
        if description.isEmpty {
            alertMessage = NSLocalizedString("Veuillez décrire le problème", comment: "")
            showingAlert = true
            return
        }
        
        let cout = estGratuite ? nil : Double(coutEstime.replacingOccurrences(of: ",", with: "."))
        
        dataManager.envoyerEnReparationDepuisLocation(
            locationId: location.id,
            reparateurId: reparateurId,
            description: description,
            dateFinPrevue: useDateFinPrevue ? dateFinPrevue : nil,
            coutEstime: cout,
            notes: notes,
            estGratuite: estGratuite
        )
        
        dismiss()
    }
}

// Vue spécialisée pour ajouter un réparateur depuis location
struct AjouterReparateurLocationView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var nom = ""
    @State private var prenom = ""
    @State private var email = ""
    @State private var telephone = ""
    @State private var organisation = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Identité")) {
                    TextField(LocalizedStringKey("Prénom"), text: $prenom)
                    TextField(LocalizedStringKey("Nom"), text: $nom)
                }
                
                Section(LocalizedStringKey("Contact")) {
                    TextField(LocalizedStringKey("Email"), text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField(LocalizedStringKey("Téléphone"), text: $telephone)
                        .keyboardType(.phonePad)
                }
                
                Section(LocalizedStringKey("Entreprise / Atelier")) {
                    TextField(LocalizedStringKey("Organisation"), text: $organisation)
                }
            }
            .navigationTitle(LocalizedStringKey("Nouveau réparateur"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Ajouter")) {
                        let personne = Personne(
                            nom: nom,
                            prenom: prenom,
                            email: email,
                            telephone: telephone,
                            organisation: organisation,
                            typePersonne: .mecanicien
                        )
                        dataManager.ajouterPersonne(personne)
                        dismiss()
                    }
                    .disabled(nom.isEmpty || prenom.isEmpty)
                }
            }
        }
    }
}

// MARK: - Vue pour retenir la caution (partielle ou totale)
struct RetenirCautionView: View {
    let location: Location
    @Binding var montantAGarder: String
    let onConfirm: (Double) -> Void
    let onCancel: () -> Void
    
    @State private var montantRetenu: String = ""
    @FocusState private var isFocused: Bool
    
    private var montantDouble: Double {
        Double(montantRetenu.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var montantRendu: Double {
        max(0, location.caution - montantDouble)
    }
    
    private var montantValide: Bool {
        montantDouble > 0 && montantDouble <= location.caution
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(LocalizedStringKey("Caution totale"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f €", location.caution))
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("Montant à retenir"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("0.00", text: $montantRetenu)
                                    .keyboardType(.decimalPad)
                                    .font(.title2)
                                    .multilineTextAlignment(.trailing)
                                    .focused($isFocused)
                                Text("€")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                        
                        // Boutons rapides pour montants courants
                        HStack(spacing: 8) {
                            ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { ratio in
                                Button {
                                    montantRetenu = String(format: "%.2f", location.caution * ratio)
                                } label: {
                                    Text(ratio == 1.0 ? "100%" : "\(Int(ratio * 100))%")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundColor(.red)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.red)
                            Text(LocalizedStringKey("Montant retenu"))
                            Spacer()
                            Text(String(format: "%.2f €", montantDouble))
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundColor(.green)
                            Text(LocalizedStringKey("Montant restitué"))
                            Spacer()
                            Text(String(format: "%.2f €", montantRendu))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(LocalizedStringKey("Récapitulatif"))
                }
                
                if montantDouble > location.caution {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(LocalizedStringKey("Le montant ne peut pas dépasser la caution"))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Retenir caution"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Confirmer")) {
                        onConfirm(montantDouble)
                    }
                    .disabled(!montantValide)
                }
            }
            .onAppear {
                montantRetenu = montantAGarder
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isFocused = true
                }
            }
        }
    }
}

// MARK: - Ajouter Location View
struct AjouterLocationView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var materielId: UUID?
    @State private var locataireId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var prixUnitaireText: String = ""
    @State private var cautionText: String = ""
    @State private var typeTarif: Location.TypeTarif = .jour
    @State private var notes = ""
    @State private var showingAddPerson = false
    @State private var showingMaterielSelection = false
    @State private var showingPersonneSelection = false
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = locataireId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    private var prixUnitaire: Double {
        Double(prixUnitaireText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var caution: Double {
        Double(cautionText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var nombreUnites: Int {
        let calendar = Calendar.current
        switch typeTarif {
        case .jour:
            let days = calendar.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0
            return max(1, days + 1)
        case .semaine:
            let days = calendar.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0
            return max(1, Int(ceil(Double(days + 1) / 7.0)))
        case .mois:
            let months = calendar.dateComponents([.month], from: dateDebut, to: dateFin).month ?? 0
            return max(1, months + 1)
        case .forfait:
            return 1
        }
    }
    
    private var prixTotal: Double {
        return prixUnitaire * Double(nombreUnites)
    }
    
    private var tarifLabel: LocalizedStringKey {
        switch typeTarif {
        case .jour: return LocalizedStringKey("Prix/jour")
        case .semaine: return LocalizedStringKey("Prix/semaine")
        case .mois: return LocalizedStringKey("Prix/mois")
        case .forfait: return LocalizedStringKey("Prix forfait")
        }
    }
    
    private var uniteLabel: String {
        switch typeTarif {
        case .jour: return NSLocalizedString("jour(s)", comment: "")
        case .semaine: return NSLocalizedString("semaine(s)", comment: "")
        case .mois: return NSLocalizedString("mois", comment: "")
        case .forfait: return ""
        }
    }
    
    var materielDisponibles: [Materiel] {
        dataManager.materiels.filter { materiel in
            !dataManager.materielEstEnLocation(materiel.id) &&
            dataManager.materielEstDisponible(materiel.id)
        }
    }
    
    var peutCreer: Bool {
        materielId != nil && locataireId != nil && prixTotal > 0
    }
    
    // Matériel sélectionné pour affichage
    var materielSelectionne: Materiel? {
        guard let id = materielId else { return nil }
        return dataManager.getMateriel(id: id)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Matériel à louer")) {
                    Button {
                        hideKeyboard()
                        showingMaterielSelection = true
                    } label: {
                        if let materiel = materielSelectionne {
                            HStack(spacing: 12) {
                                // Photo du matériel
                                if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.15))
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 50, height: 50)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(materiel.nom)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if !materiel.categorie.isEmpty {
                                        Text(materiel.categorie)
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
                                Text(LocalizedStringKey("Sélectionner le matériel"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if materielDisponibles.isEmpty {
                        Text(LocalizedStringKey("Aucun matériel disponible"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(LocalizedStringKey("Locataire")) {
                    Button {
                        showingPersonneSelection = true
                    } label: {
                        if let personne = personneSelectionnee {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(couleurPourTypePersonne(personne.typePersonne))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: personne.typePersonne?.icon ?? "person.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .medium))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(personne.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let type = personne.typePersonne {
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
                                Text(LocalizedStringKey("Sélectionner la personne"))
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
                        Text(LocalizedStringKey("Aucune personne enregistrée"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(LocalizedStringKey("Dates")) {
                    DatePicker(LocalizedStringKey("Début"), selection: $dateDebut, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("Fin prévue"), selection: $dateFin, in: dateDebut..., displayedComponents: .date)
                }
                
                Section(LocalizedStringKey("Tarification")) {
                    Picker(LocalizedStringKey("Type de tarif"), selection: $typeTarif) {
                        ForEach(Location.TypeTarif.allCases, id: \.self) { type in
                            Text(LocalizedStringKey(type.rawValue)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text(tarifLabel)
                        Spacer()
                        HStack {
                            TextField("0", text: $prixUnitaireText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("€")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minWidth: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Affichage du calcul
                    if typeTarif != .forfait && prixUnitaire > 0 {
                        HStack {
                            Text(LocalizedStringKey("Durée"))
                            Spacer()
                            Text("\(nombreUnites) \(uniteLabel)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("Prix total"))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.2f €", prixTotal))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Caution"))
                        Spacer()
                        HStack {
                            TextField("0", text: $cautionText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("€")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minWidth: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Nouvelle location"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Créer")) { creerLocation() }
                        .disabled(!peutCreer)
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    locataireId = newPersonneId
                })
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingMaterielSelection) {
                MaterielSelectionView(
                    selectedMaterielId: $materielId,
                    materiels: materielDisponibles,
                    title: LocalizedStringKey("Choisir le matériel")
                )
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $locataireId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir le locataire"),
                    showAddButton: true,
                    onAddPerson: { showingAddPerson = true }
                )
            }
        }
    }
    
    private func creerLocation() {
        guard let materielId = materielId, let locataireId = locataireId else { return }
        
        let location = Location(
            materielId: materielId,
            locataireId: locataireId,
            dateDebut: dateDebut,
            dateFin: dateFin,
            dateRetourEffectif: nil,
            prixTotal: prixTotal,
            caution: caution,
            cautionRendue: false,
            paiementRecu: false,
            typeTarif: typeTarif,
            prixUnitaire: prixUnitaire,
            notes: notes
        )
        
        dataManager.ajouterLocation(location)
        dismiss()
    }
}

// MARK: - Vue pour louer depuis une fiche matériel
struct LouerMaterielView: View {
    let materiel: Materiel
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var locataireId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var prixUnitaireText: String = ""
    @State private var cautionText: String = ""
    @State private var typeTarif: Location.TypeTarif = .jour
    @State private var notes = ""
    @State private var showingAddPerson = false
    @State private var showingPersonneSelection = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = locataireId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    private var prixUnitaire: Double {
        Double(prixUnitaireText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var caution: Double {
        Double(cautionText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var nombreUnites: Int {
        let calendar = Calendar.current
        switch typeTarif {
        case .jour:
            let days = calendar.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0
            return max(1, days + 1)
        case .semaine:
            let days = calendar.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0
            return max(1, Int(ceil(Double(days + 1) / 7.0)))
        case .mois:
            let months = calendar.dateComponents([.month], from: dateDebut, to: dateFin).month ?? 0
            return max(1, months + 1)
        case .forfait:
            return 1
        }
    }
    
    private var prixTotal: Double {
        return prixUnitaire * Double(nombreUnites)
    }
    
    private var tarifLabel: LocalizedStringKey {
        switch typeTarif {
        case .jour: return LocalizedStringKey("Prix/jour")
        case .semaine: return LocalizedStringKey("Prix/semaine")
        case .mois: return LocalizedStringKey("Prix/mois")
        case .forfait: return LocalizedStringKey("Prix forfait")
        }
    }
    
    private var uniteLabel: String {
        switch typeTarif {
        case .jour: return NSLocalizedString("jour(s)", comment: "")
        case .semaine: return NSLocalizedString("semaine(s)", comment: "")
        case .mois: return NSLocalizedString("mois", comment: "")
        case .forfait: return ""
        }
    }
    
    var peutCreer: Bool {
        locataireId != nil && prixTotal > 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "eurosign.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.green)
                        }
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey("Louer ce matériel"))
                                .font(.headline)
                            Text(materiel.nom)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(LocalizedStringKey("Locataire")) {
                    Button {
                        hideKeyboard()
                        showingPersonneSelection = true
                    } label: {
                        if let personne = personneSelectionnee {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(couleurPourTypePersonne(personne.typePersonne))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: personne.typePersonne?.icon ?? "person.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .medium))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(personne.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let type = personne.typePersonne {
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
                                Text(LocalizedStringKey("Sélectionner la personne"))
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
                        Text(LocalizedStringKey("Aucune personne enregistrée"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(LocalizedStringKey("Dates")) {
                    DatePicker(LocalizedStringKey("Début"), selection: $dateDebut, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("Fin prévue"), selection: $dateFin, in: dateDebut..., displayedComponents: .date)
                }
                
                Section(LocalizedStringKey("Tarification")) {
                    Picker(LocalizedStringKey("Type de tarif"), selection: $typeTarif) {
                        ForEach(Location.TypeTarif.allCases, id: \.self) { type in
                            Text(LocalizedStringKey(type.rawValue)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text(tarifLabel)
                        Spacer()
                        HStack {
                            TextField("0", text: $prixUnitaireText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("€")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minWidth: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Affichage du calcul
                    if typeTarif != .forfait && prixUnitaire > 0 {
                        HStack {
                            Text(LocalizedStringKey("Durée"))
                            Spacer()
                            Text("\(nombreUnites) \(uniteLabel)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("Prix total"))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.2f €", prixTotal))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Caution"))
                        Spacer()
                        HStack {
                            TextField("0", text: $cautionText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("€")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minWidth: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(LocalizedStringKey("Nouvelle location"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Louer")) {
                        if dataManager.peutAjouterLocation() {
                            creerLocation()
                        } else {
                            showingLimitAlert = true
                        }
                    }
                    .disabled(!peutCreer)
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    locataireId = newPersonneId
                })
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $locataireId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir le locataire"),
                    showAddButton: true,
                    onAddPerson: { showingAddPerson = true }
                )
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
    
    private func creerLocation() {
        guard let locataireId = locataireId else { return }
        
        let location = Location(
            materielId: materiel.id,
            locataireId: locataireId,
            dateDebut: dateDebut,
            dateFin: dateFin,
            dateRetourEffectif: nil,
            prixTotal: prixTotal,
            caution: caution,
            cautionRendue: false,
            paiementRecu: false,
            typeTarif: typeTarif,
            prixUnitaire: prixUnitaire,
            notes: notes
        )
        
        dataManager.ajouterLocation(location)
        dismiss()
    }
}

// MARK: - Vue pour sous-louer une location à quelqu'un d'autre
struct SousLouerLocationView: View {
    let locationId: UUID
    let materielNom: String
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var locataireId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var prixUnitaireText: String = ""
    @State private var cautionText: String = ""
    @State private var typeTarif: Location.TypeTarif = .jour
    @State private var notes = ""
    @State private var showingAddPerson = false
    @State private var showingPersonneSelection = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = locataireId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    private var prixUnitaire: Double {
        Double(prixUnitaireText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var caution: Double {
        Double(cautionText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var nombreUnites: Int {
        let calendar = Calendar.current
        switch typeTarif {
        case .jour:
            let days = calendar.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0
            return max(1, days + 1)
        case .semaine:
            let days = calendar.dateComponents([.day], from: dateDebut, to: dateFin).day ?? 0
            return max(1, Int(ceil(Double(days + 1) / 7.0)))
        case .mois:
            let months = calendar.dateComponents([.month], from: dateDebut, to: dateFin).month ?? 0
            return max(1, months + 1)
        case .forfait:
            return 1
        }
    }
    
    private var prixTotal: Double {
        return prixUnitaire * Double(nombreUnites)
    }
    
    private var tarifLabel: LocalizedStringKey {
        switch typeTarif {
        case .jour: return LocalizedStringKey("Prix/jour")
        case .semaine: return LocalizedStringKey("Prix/semaine")
        case .mois: return LocalizedStringKey("Prix/mois")
        case .forfait: return LocalizedStringKey("Prix forfait")
        }
    }
    
    private var uniteLabel: String {
        switch typeTarif {
        case .jour: return NSLocalizedString("jour(s)", comment: "")
        case .semaine: return NSLocalizedString("semaine(s)", comment: "")
        case .mois: return NSLocalizedString("mois", comment: "")
        case .forfait: return ""
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 24))
                            .foregroundColor(.teal)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Sous-louer ce matériel"))
                                .font(.headline)
                            Text(materielNom)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(LocalizedStringKey("À qui sous-louer ?")) {
                    Button {
                        hideKeyboard()
                        showingPersonneSelection = true
                    } label: {
                        if let personne = personneSelectionnee {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(couleurPourTypePersonne(personne.typePersonne))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: personne.typePersonne?.icon ?? "person.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .medium))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(personne.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let type = personne.typePersonne {
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
                                Text(LocalizedStringKey("Sélectionner la personne"))
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
                        Text(LocalizedStringKey("Aucune personne enregistrée"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(LocalizedStringKey("Dates")) {
                    DatePicker(LocalizedStringKey("Début"), selection: $dateDebut, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("Fin prévue"), selection: $dateFin, in: dateDebut..., displayedComponents: .date)
                }
                
                Section(LocalizedStringKey("Tarification")) {
                    Picker(LocalizedStringKey("Type de tarif"), selection: $typeTarif) {
                        ForEach(Location.TypeTarif.allCases, id: \.self) { type in
                            Text(LocalizedStringKey(type.rawValue)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text(tarifLabel)
                        Spacer()
                        HStack {
                            TextField("0", text: $prixUnitaireText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("€")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minWidth: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Affichage du calcul
                    if typeTarif != .forfait && prixUnitaire > 0 {
                        HStack {
                            Text(LocalizedStringKey("Durée"))
                            Spacer()
                            Text("\(nombreUnites) \(uniteLabel)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("Prix total"))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.2f €", prixTotal))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Caution"))
                        Spacer()
                        HStack {
                            TextField("0", text: $cautionText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("€")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minWidth: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(LocalizedStringKey("La location ne pourra pas être terminée tant que cette sous-location sera active."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Sous-louer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Louer")) {
                        if let locataireId = locataireId {
                            if dataManager.peutAjouterLocation() {
                                dataManager.creerSousLocationDepuisLocation(
                                    locationId,
                                    locataireId: locataireId,
                                    dateDebut: dateDebut,
                                    dateFin: dateFin,
                                    prixUnitaire: prixUnitaire,
                                    typeTarif: typeTarif,
                                    caution: caution,
                                    notes: notes
                                )
                                dismiss()
                            } else {
                                showingLimitAlert = true
                            }
                        }
                    }
                    .disabled(locataireId == nil || prixUnitaire <= 0)
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    locataireId = newPersonneId
                })
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $locataireId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir le sous-locataire"),
                    showAddButton: true,
                    onAddPerson: { showingAddPerson = true }
                )
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
}

#Preview {
    LocationListView()
        .environmentObject(DataManager())
}

// MARK: - LocationListViewEmbedded (sans NavigationView pour utilisation dans AutreView)
struct LocationListViewEmbedded: View {
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
    
    // Vérifie si une location peut être supprimée (toutes les actions terminées)
    private func locationPeutEtreSupprimee(_ location: Location) -> Bool {
        let retourEffectue = location.dateRetourEffectif != nil
        let paiementOk = location.paiementRecu
        let cautionGeree = location.caution == 0 || location.cautionRendue || location.cautionGardee
        return retourEffectue && paiementOk && cautionGeree
    }
    
    private let statutOptions = ["Tous", "En cours", "En retard", "Terminées"]
    private let paiementOptions = ["Tous", "Payé", "Non payé"]
    private let cautionOptions = ["Tous", "Gardée", "Restituée", "En attente"]
    
    var locationsFiltrees: [Location] {
        var locs = dataManager.locations
        
        // Filtre par statut
        switch filtreStatut {
        case "En cours": locs = locs.filter { $0.estActive && !$0.estEnRetard }
        case "En retard": locs = locs.filter { $0.estEnRetard }
        case "Terminées": locs = locs.filter { $0.estTerminee }
        default: break
        }
        
        // Filtre par paiement
        switch filtrePaiement {
        case "Payé": locs = locs.filter { $0.paiementRecu }
        case "Non payé": locs = locs.filter { !$0.paiementRecu }
        default: break
        }
        
        // Filtre par caution
        switch filtreCaution {
        case "Gardée": locs = locs.filter { $0.cautionGardee }
        case "Restituée": locs = locs.filter { $0.cautionRendue && !$0.cautionGardee }
        case "En attente": locs = locs.filter { !$0.cautionRendue && !$0.cautionGardee && $0.caution > 0 }
        default: break
        }
        
        // Filtre par recherche
        if !searchText.isEmpty {
            locs = locs.filter { location in
                if let materiel = dataManager.getMateriel(id: location.materielId),
                   materiel.nom.localizedCaseInsensitiveContains(searchText) { return true }
                if let personne = dataManager.getPersonne(id: location.locataireId),
                   personne.nomComplet.localizedCaseInsensitiveContains(searchText) { return true }
                return false
            }
        }
        return locs.sorted { $0.dateDebut > $1.dateDebut }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.green.opacity(0.15), Color.teal.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Résumé financier
                if !dataManager.locations.isEmpty {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Revenus"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f €", dataManager.revenuTotalLocations()))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("En attente"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f €", dataManager.revenuEnAttenteLocations()))
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                Picker(LocalizedStringKey("Statut"), selection: $filtreStatut) {
                    ForEach(statutOptions, id: \.self) { statut in
                        Text(LocalizedStringKey(statut))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Filtres supplémentaires (paiement et caution)
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
                        .background(filtrePaiement != "Tous" ? Color.green.opacity(0.15) : Color(.systemGray6))
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
                            Image(systemName: filtreCaution == "Gardée" ? "lock.fill" : (filtreCaution == "Restituée" ? "arrow.uturn.backward.circle.fill" : (filtreCaution == "En attente" ? "hourglass" : "shield")))
                                .foregroundColor(filtreCaution == "Gardée" ? .red : (filtreCaution == "Restituée" ? .green : (filtreCaution == "En attente" ? .orange : .primary)))
                            Text(LocalizedStringKey(filtreCaution == "Tous" ? "Caution" : filtreCaution))
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(filtreCaution != "Tous" ? Color.teal.opacity(0.15) : Color(.systemGray6))
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
                
                Button {
                    if dataManager.peutAjouterLocation() {
                        showingAddSheet = true
                    } else {
                        showingLimitAlert = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "eurosign.circle.fill")
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
                            colors: [Color.green, Color.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                List {
                    ForEach(locationsFiltrees) { location in
                        LocationRowView(location: location)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        // Vérifier si toutes les locations à supprimer ont leurs actions terminées
                        let locationsToDelete = offsets.map { locationsFiltrees[$0] }
                        let allCanBeDeleted = locationsToDelete.allSatisfy { locationPeutEtreSupprimee($0) }
                        
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
        .navigationTitle(LocalizedStringKey("Locations"))
        .sheet(isPresented: $showingAddSheet) {
            AjouterLocationView()
        }
        .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                if let offsets = indexSetToDelete {
                    for index in offsets {
                        let location = locationsFiltrees[index]
                        dataManager.supprimerLocation(location)
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
