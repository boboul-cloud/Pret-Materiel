// filepath: /Users/robertoulhen/Documents/Sauvegardes/Materiel/Materiel/EmpruntListView.swift
//
//  EmpruntListView.swift
//  Materiel
//
//  Créé pour afficher uniquement les prêts actifs (emprunts en cours)
//

import SwiftUI
import PhotosUI
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

struct EmpruntListView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @State private var showingAddSheet = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    @State private var searchText = ""
    @State private var filtre = "Tous" // "Tous", "Bientôt", "En retard"
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    private let options = ["Tous", "Bientôt", "En retard"]

    var empruntsFiltres: [Emprunt] {
        var list = dataManager.emprunts.filter { $0.estActif }
        switch filtre {
        case "Bientôt":
            let joursMax = 3
            list = list.filter { e in
                guard !e.estEnRetard else { return false }
                let joursRestants = Calendar.current.dateComponents([.day], from: Date(), to: e.dateFin).day ?? Int.max
                return joursRestants >= 0 && joursRestants <= joursMax
            }
        case "En retard":
            list = list.filter { $0.estEnRetard }
        default:
            break
        }
        if !searchText.isEmpty {
            list = list.filter { e in
                if let p = dataManager.getPersonne(id: e.personneId), p.nomComplet.localizedCaseInsensitiveContains(searchText) { return true }
                if e.nomObjet.localizedCaseInsensitiveContains(searchText) { return true }
                return false
            }
        }
        return list.sorted { $0.dateFin < $1.dateFin }
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    Picker(LocalizedStringKey("Filtre"), selection: $filtre) {
                        ForEach(options, id: \.self) { Text(LocalizedStringKey($0)) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Button(action: {
                    if dataManager.peutAjouterEmprunt() {
                        showingAddSheet = true
                    } else {
                        showingLimitAlert = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text(LocalizedStringKey("Ajouter un emprunt"))
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                List {
                    ForEach(empruntsFiltres) { e in
                        EmpruntRowView(emprunt: e)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        if storeManager.hasUnlockedPremium {
                            // Suppression directe en mode Premium
                            for index in offsets {
                                let e = empruntsFiltres[index]
                                dataManager.supprimerEmprunt(e)
                            }
                        } else {
                            // Alerte de confirmation en version gratuite
                            indexSetToDelete = offsets
                            showingDeleteAlert = true
                        }
                    }
                }
                .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher un emprunt"))
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            }
            .navigationTitle(LocalizedStringKey("Emprunts"))
            .toolbar { }
            .sheet(isPresented: $showingAddSheet) {
                AjouterEmpruntView()
            }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        for index in offsets {
                            let e = empruntsFiltres[index]
                            dataManager.supprimerEmprunt(e)
                        }
                    }
                    indexSetToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    indexSetToDelete = nil
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer cet emprunt ? Cette action est irréversible."))
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumSheet = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Limite emprunts atteinte"))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
    }

    private func supprimerEmprunts(at offsets: IndexSet) {
        for index in offsets {
            let e = empruntsFiltres[index]
            dataManager.supprimerEmprunt(e)
        }
    }
}

struct EmpruntRowView: View {
    let emprunt: Emprunt
    @EnvironmentObject var dataManager: DataManager
    @State private var showConfirm = false
    @State private var showingAffectation = false
    @State private var showingPreterSheet = false
    @State private var showingLouerSheet = false
    @State private var showingReparationSheet = false
    @State private var showingPretActifAlert = false
    @State private var showingLocationActifAlert = false
    @State private var showingReparationActifAlert = false
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
    
    // Vérifie si l'emprunt est actuellement prêté à quelqu'un
    private var pretActif: Pret? {
        dataManager.empruntEstPrete(emprunt.id)
    }
    
    // Nom de la personne à qui l'emprunt est prêté
    private var nomPersonnePret: String {
        guard let pret = pretActif,
              let personne = dataManager.getPersonne(id: pret.personneId) else {
            return ""
        }
        return personne.nomComplet
    }
    
    // Vérifie si l'emprunt est actuellement loué à quelqu'un
    private var locationActif: Location? {
        // Vérifier d'abord via locationActifId (méthode principale)
        if let locationActifId = emprunt.locationActifId,
           let location = dataManager.locations.first(where: { $0.id == locationActifId && $0.estActive }) {
            return location
        }
        // Fallback: vérifier via materielLieId
        guard let materielLieId = emprunt.materielLieId else { return nil }
        return dataManager.locations.first { $0.materielId == materielLieId && $0.estActive }
    }
    
    // Nom de la personne à qui l'emprunt est loué
    private var nomPersonneLocation: String {
        guard let location = locationActif,
              let personne = dataManager.getPersonne(id: location.locataireId) else {
            return ""
        }
        return personne.nomComplet
    }
    
    // Vérifie si l'emprunt est actuellement en réparation
    private var reparationActif: Reparation? {
        dataManager.empruntEnReparation(emprunt.id)
    }
    
    // Nom du réparateur
    private var nomReparateur: String {
        guard let reparation = reparationActif,
              let reparateur = dataManager.getPersonne(id: reparation.reparateurId) else {
            return ""
        }
        return reparateur.nomComplet
    }
    
    // Vérifie si l'emprunt est bloqué (prêté OU loué OU en réparation)
    private var estBloque: Bool {
        pretActif != nil || locationActif != nil || reparationActif != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let data = emprunt.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }
            HStack {
                Text(emprunt.nomObjet).font(.headline)
                Spacer()
                if emprunt.estRetourne {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                } else if emprunt.estEnRetard {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                } else {
                    Image(systemName: "clock.fill").foregroundColor(.orange)
                }
            }
            if let personne = dataManager.getPersonne(id: emprunt.personneId) {
                Label(personne.nomComplet, systemImage: "person")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            } else {
                // Emprunt orphelin - permettre l'affectation
                Button(action: { showingAffectation = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(LocalizedStringKey("Aucune personne - Affecter"))
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(localizedString("Début:")) \(formatDate(emprunt.dateDebut))").font(.caption)
                    Text("\(localizedString("Fin:")) \(formatDate(emprunt.dateFin))").font(.caption)
                }.foregroundColor(.secondary)
                Spacer()
                if emprunt.estRetourne, let dateRetour = emprunt.dateRetourEffectif {
                    Text("\(localizedString("Retourné le")) \(formatDate(dateRetour))").font(.caption).foregroundColor(.green)
                } else if emprunt.estEnRetard {
                    let jours = Calendar.current.dateComponents([.day], from: emprunt.dateFin, to: Date()).day ?? 0
                    Text("\(jours) \(localizedString("jour(s) de retard"))").font(.caption).foregroundColor(.red)
                }
            }
            if !emprunt.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text").foregroundColor(.secondary)
                    Text(emprunt.notes).font(.callout).lineLimit(3)
                }.padding(.top, 2)
            }
            
            // Indicateur si l'emprunt est actuellement prêté
            if let pret = pretActif {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Prêté à"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(nomPersonnePret)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    Text(LocalizedStringKey("jusqu'au \(formatDate(pret.dateFin))"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Indicateur si l'emprunt est actuellement loué
            if let location = locationActif {
                HStack(spacing: 8) {
                    Image(systemName: "eurosign.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Loué à"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(nomPersonneLocation)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(LocalizedStringKey("jusqu'au \(formatDate(location.dateFin))"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f €", location.prixTotalReel))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Indicateur si l'emprunt est actuellement en réparation
            if let reparation = reparationActif {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("En réparation"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(nomReparateur)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let dateFin = reparation.dateFinPrevue {
                            Text(LocalizedStringKey("Retour prévu le \(formatDate(dateFin))"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let cout = reparation.coutEstime {
                            Text(String(format: "%.2f €", cout))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            
            if !emprunt.estRetourne {
                // Si l'emprunt est prêté, afficher le bouton pour valider le retour du prêt
                if pretActif != nil {
                    Button {
                        dataManager.validerRetourPretEmprunt(emprunt.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(LocalizedStringKey("Récupérer du prêt"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.85), Color.indigo.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: .purple.opacity(0.25), radius: 4, x: 0, y: 2)
                    }.buttonStyle(.plain)
                    
                    // Bouton de retour désactivé avec message
                    Button { showingPretActifAlert = true } label: {
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
                } else if locationActif != nil {
                    // Si l'emprunt est loué, afficher le bouton pour terminer la location
                    Button {
                        dataManager.validerRetourLocationEmprunt(emprunt.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(LocalizedStringKey("Récupérer de la location"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.85), Color.teal.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: .green.opacity(0.25), radius: 4, x: 0, y: 2)
                    }.buttonStyle(.plain)
                    
                    // Bouton de retour désactivé avec message
                    Button { showingLocationActifAlert = true } label: {
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
                } else if reparationActif != nil {
                    // Si l'emprunt est en réparation, afficher le bouton pour récupérer de la réparation
                    Button {
                        dataManager.validerRetourReparationEmprunt(emprunt.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(LocalizedStringKey("Récupérer de la réparation"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.85), Color.yellow.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: .orange.opacity(0.25), radius: 4, x: 0, y: 2)
                    }.buttonStyle(.plain)
                    
                    // Bouton de retour désactivé avec message
                    Button { showingReparationActifAlert = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(LocalizedStringKey("Actions bloquées"))
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
                    // Boutons normaux : Prêter, Louer et Valider le retour
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Button { showingPreterSheet = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.forward.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(LocalizedStringKey("Prêter"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.85), Color.cyan.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: .blue.opacity(0.25), radius: 4, x: 0, y: 2)
                            }.buttonStyle(.plain)
                            
                            Button { showingLouerSheet = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "eurosign.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(LocalizedStringKey("Louer"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.85), Color.teal.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: .green.opacity(0.25), radius: 4, x: 0, y: 2)
                            }.buttonStyle(.plain)
                            
                            Button { showingReparationSheet = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(LocalizedStringKey("Réparer"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.85), Color.yellow.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: .orange.opacity(0.25), radius: 4, x: 0, y: 2)
                            }.buttonStyle(.plain)
                        }
                        
                        Button { showConfirm = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(LocalizedStringKey("Retour"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.85), Color.red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: .orange.opacity(0.25), radius: 4, x: 0, y: 2)
                        }.buttonStyle(.plain)
                    }
                }
            } else {
                Button(role: .destructive) { dataManager.supprimerEmprunt(emprunt) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text(LocalizedStringKey("Effacer cet emprunt"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                            .background(Color.red.opacity(0.08).cornerRadius(10))
                    )
                }.buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        .padding(.vertical, 4)
        .confirmationDialog(LocalizedStringKey("Confirmer le retour"), isPresented: $showConfirm) {
            Button(LocalizedStringKey("Valider le retour")) { dataManager.validerRetourEmprunt(emprunt.id) }
            Button(LocalizedStringKey("Annuler"), role: .cancel) {}
        } message: { Text(LocalizedStringKey("Voulez-vous valider le retour de cet objet emprunté ?")) }
        .alert(LocalizedStringKey("Retour impossible"), isPresented: $showingPretActifAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) {}
        } message: {
            Text("Votre emprunt est prêté à \(nomPersonnePret). Vous ne pouvez pas le restituer tant que le prêt n'est pas retourné.")
        }
        .sheet(isPresented: $showingAffectation) {
            AffecterEmpruntView(emprunt: emprunt)
        }
        .sheet(isPresented: $showingPreterSheet) {
            PreterEmpruntView(empruntId: emprunt.id, nomObjet: emprunt.nomObjet)
        }
        .sheet(isPresented: $showingLouerSheet) {
            LouerEmpruntView(empruntId: emprunt.id, nomObjet: emprunt.nomObjet)
        }
        .alert(LocalizedStringKey("Retour impossible"), isPresented: $showingLocationActifAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) {}
        } message: {
            Text("Votre emprunt est loué à \(nomPersonneLocation). Vous ne pouvez pas le restituer tant que la location n'est pas retournée.")
        }
        .sheet(isPresented: $showingReparationSheet) {
            EnvoyerEmpruntEnReparationView(empruntId: emprunt.id, nomObjet: emprunt.nomObjet)
        }
        .alert(LocalizedStringKey("Actions bloquées"), isPresented: $showingReparationActifAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) {}
        } message: {
            Text("Votre emprunt est en réparation chez \(nomReparateur). Vous ne pouvez pas le prêter, louer ou restituer tant que la réparation n'est pas terminée.")
        }
    }
}

// Vue pour affecter un emprunt orphelin à une personne
struct AffecterEmpruntView: View {
    let emprunt: Emprunt
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedPersonneId: UUID?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text(emprunt.nomObjet)
                        .font(.headline)
                } header: {
                    Text(LocalizedStringKey("Emprunt à affecter"))
                }
                
                Section {
                    ForEach(dataManager.personnes) { personne in
                        Button(action: {
                            selectedPersonneId = personne.id
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(personne.nomComplet)
                                        .foregroundColor(.primary)
                                    if !personne.organisation.isEmpty {
                                        Text(personne.organisation)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedPersonneId == personne.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("Choisir une personne"))
                }
            }
            .navigationTitle(LocalizedStringKey("Affecter l'emprunt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Affecter")) {
                        if let personneId = selectedPersonneId {
                            dataManager.reaffecterEmprunt(emprunt, nouvellePersonneId: personneId)
                            dismiss()
                        }
                    }
                    .disabled(selectedPersonneId == nil)
                }
            }
        }
    }
}

struct AjouterEmpruntView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var nomObjet = ""
    @State private var personneId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var showingAddPerson = false
    @State private var showingPersonneSelection = false
    // Ajout pour photo
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    // Option pour créer un matériel
    @State private var creerMateriel = false
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = personneId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    @State private var categorieMateriel = "Emprunt"
    @State private var lieuStockageId: UUID? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Objet")) {
                    TextField(LocalizedStringKey("Nom de l'objet"), text: $nomObjet)
                    if let data = imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
                            .padding(.top, 4)
                        HStack {
                            Spacer()
                            Button(role: .destructive) { imageData = nil } label: {
                                Label(LocalizedStringKey("Retirer la photo"), systemImage: "trash")
                            }
                            .font(.caption)
                        }
                    }
                    HStack(spacing: 12) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button(action: { showCameraPicker = true }) {
                                Label(LocalizedStringKey("Prendre une photo"), systemImage: "camera.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                        Button(action: { showPhotoLibraryPicker = true }) {
                            Label(LocalizedStringKey(imageData == nil ? "Ajouter une photo" : "Changer la photo"), systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Section pour créer un matériel
                Section {
                    Toggle(isOn: $creerMateriel) {
                        HStack(spacing: 12) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("Créer dans Matériels"))
                                    .font(.subheadline)
                                Text(LocalizedStringKey("Ajoute aussi cet objet à votre inventaire"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.blue)
                    
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
                
                Section(LocalizedStringKey("Prêteur")) {
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
                        Text(LocalizedStringKey("Aucune personne enregistrée")).foregroundColor(.secondary).font(.caption)
                    }
                }
                Section(LocalizedStringKey("Dates")) {
                    DatePicker(LocalizedStringKey("Date de début"), selection: $dateDebut, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("Date de fin prévue"), selection: $dateFin, displayedComponents: .date)
                }
                Section(LocalizedStringKey("Notes")) { TextEditor(text: $notes).frame(minHeight: 80) }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Nouvel emprunt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !storeManager.hasUnlockedPremium {
                        VStack(spacing: 2) {
                            Text(LocalizedStringKey("Nouvel emprunt"))
                                .font(.headline)
                            Text("\(dataManager.totalEmpruntsCreated)/\(StoreManager.freeEmpruntLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("Annuler")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Créer")) { creerEmprunt() }
                        .disabled(!peutCreer)
                }
            }
            // Feuille de création de personne
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    personneId = newPersonneId
                })
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $personneId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir le prêteur"),
                    showAddButton: true,
                    onAddPerson: { showingAddPerson = true }
                )
            }
            .sheet(isPresented: $showCameraPicker) {
                EmpruntImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let image = newImage {
                            imageData = image.jpegData(compressionQuality: 0.7)
                        }
                    }
                ), sourceType: .camera)
            }
            .sheet(isPresented: $showPhotoLibraryPicker) {
                EmpruntImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let image = newImage {
                            imageData = image.jpegData(compressionQuality: 0.7)
                        }
                    }
                ), sourceType: .photoLibrary)
            }
        }
    }

    private var peutCreer: Bool { !nomObjet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && personneId != nil }
    
    private var categoriesDisponibles: [String] {
        ["Emprunt", "Électronique", "Outils", "Sport", "Cuisine", "Mobilier", "Autre"]
    }

    private func creerEmprunt() {
        guard let personneId else {
            print("[DEBUG] creerEmprunt: personneId est nil")
            return
        }
        if dateFin < dateDebut {
            print("[DEBUG] creerEmprunt: dateFin < dateDebut")
            return
        }
        
        print("[DEBUG] creerEmprunt: Création avec personneId=\(personneId), nomObjet=\(nomObjet)")
        
        // Créer l'emprunt
        var emprunt = Emprunt(nomObjet: nomObjet, personneId: personneId, dateDebut: dateDebut, dateFin: dateFin, dateRetourEffectif: nil, notes: notes, imageData: imageData)
        
        // Si l'option "Créer dans Matériels" est cochée, créer le matériel
        if creerMateriel {
            let materiel = Materiel(
                nom: nomObjet,
                description: "Créé depuis un emprunt",
                categorie: categorieMateriel,
                lieuStockageId: lieuStockageId,
                dateAcquisition: dateDebut,
                valeur: 0,
                imageData: imageData
            )
            dataManager.ajouterMateriel(materiel)
            emprunt.materielLieId = materiel.id
        }
        
        print("[DEBUG] creerEmprunt: Appel dataManager.ajouterEmprunt")
        dataManager.ajouterEmprunt(emprunt)
        print("[DEBUG] creerEmprunt: Emprunt ajouté, dismiss()")
        dismiss()
    }
}

// MARK: - Vue pour prêter un emprunt à quelqu'un d'autre
struct PreterEmpruntView: View {
    let empruntId: UUID
    let nomObjet: String
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var personneId: UUID?
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var showingAddPerson = false
    @State private var showingPersonneSelection = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = personneId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    // Récupérer l'emprunt pour accéder à sa photo
    private var emprunt: Emprunt? {
        dataManager.emprunts.first(where: { $0.id == empruntId })
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        // Afficher la photo de l'emprunt si elle existe
                        if let emprunt = emprunt, let imageData = emprunt.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.3), lineWidth: 1))
                        } else {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 24))
                                .foregroundColor(.purple)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Prêter cet emprunt"))
                                .font(.headline)
                            Text(nomObjet)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(LocalizedStringKey("À qui prêter ?")) {
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
                
                Section(LocalizedStringKey("Date de retour prévue")) {
                    DatePicker(LocalizedStringKey("Retour prévu le"), selection: $dateFin, displayedComponents: .date)
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(LocalizedStringKey("L'emprunt ne pourra pas être restitué tant que ce prêt sera actif."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Prêter l'emprunt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Prêter")) {
                        if let personneId = personneId {
                            if dataManager.peutAjouterPret() {
                                dataManager.creerPretDepuisEmprunt(empruntId, personneId: personneId, dateFin: dateFin, notes: notes)
                                dismiss()
                            } else {
                                showingLimitAlert = true
                            }
                        }
                    }
                    .disabled(personneId == nil)
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    personneId = newPersonneId
                })
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $personneId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir la personne"),
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
                Text(LocalizedStringKey("Vous avez atteint la limite de prêts gratuits. Passez à Premium pour créer des prêts illimités."))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
    }
}

// MARK: - Vue pour louer un emprunt à quelqu'un d'autre
struct LouerEmpruntView: View {
    let empruntId: UUID
    let nomObjet: String
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    @State private var personneId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var prixUnitaireText: String = ""
    @State private var cautionText: String = ""
    @State private var typeTarif: Location.TypeTarif = .jour
    @State private var notes = ""
    @State private var showingAddPerson = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    
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
    
    // Récupérer l'emprunt pour accéder à sa photo
    private var emprunt: Emprunt? {
        dataManager.emprunts.first(where: { $0.id == empruntId })
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        // Afficher la photo de l'emprunt si elle existe
                        if let emprunt = emprunt, let imageData = emprunt.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
                        } else {
                            Image(systemName: "eurosign.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Louer cet emprunt"))
                                .font(.headline)
                            Text(nomObjet)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(LocalizedStringKey("Locataire")) {
                    Picker(LocalizedStringKey("Sélectionner la personne"), selection: $personneId) {
                        Text(LocalizedStringKey("Choisir...")).tag(nil as UUID?)
                        ForEach(dataManager.personnes) { personne in
                            Text(personne.nomComplet).tag(personne.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    if dataManager.personnes.isEmpty {
                        Text(LocalizedStringKey("Aucune personne enregistrée"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Button { showingAddPerson = true } label: {
                        Label(LocalizedStringKey("Ajouter une personne"), systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.bordered)
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
                        Text(LocalizedStringKey("L'emprunt ne pourra pas être restitué tant que cette location sera active."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Louer l'emprunt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Louer")) {
                        if let personneId = personneId {
                            if dataManager.peutAjouterLocation() {
                                dataManager.creerLocationDepuisEmprunt(empruntId, personneId: personneId, dateDebut: dateDebut, dateFin: dateFin, prixTotal: prixTotal, prixUnitaire: prixUnitaire, typeTarif: typeTarif, caution: caution, notes: notes)
                                dismiss()
                            } else {
                                showingLimitAlert = true
                            }
                        }
                    }
                    .disabled(personneId == nil || prixTotal <= 0)
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView(onPersonneCreated: { newPersonneId in
                    personneId = newPersonneId
                })
                .environmentObject(dataManager)
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

// MARK: - Vue pour envoyer un emprunt en réparation
struct EnvoyerEmpruntEnReparationView: View {
    let empruntId: UUID
    let nomObjet: String
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var reparateurId: UUID?
    @State private var description = ""
    @State private var dateFinPrevue: Date? = nil
    @State private var useDateFinPrevue = false
    @State private var coutEstimeText = ""
    @State private var estGratuite = false
    @State private var notes = ""
    @State private var showingAddReparateur = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    
    private var coutEstime: Double? {
        guard !coutEstimeText.isEmpty else { return nil }
        return Double(coutEstimeText.replacingOccurrences(of: ",", with: "."))
    }
    
    // Récupérer l'emprunt pour accéder à sa photo
    private var emprunt: Emprunt? {
        dataManager.emprunts.first(where: { $0.id == empruntId })
    }
    
    // Réparateurs disponibles
    private var reparateurs: [Personne] {
        dataManager.getMecaniciens()
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        // Afficher la photo de l'emprunt si elle existe
                        if let emprunt = emprunt, let imageData = emprunt.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        } else {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Envoyer en réparation"))
                                .font(.headline)
                            Text(nomObjet)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(LocalizedStringKey("Réparateur")) {
                    Picker(LocalizedStringKey("Sélectionner le réparateur"), selection: $reparateurId) {
                        Text(LocalizedStringKey("Choisir...")).tag(nil as UUID?)
                        ForEach(reparateurs) { reparateur in
                            Text(reparateur.nomComplet).tag(reparateur.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    if reparateurs.isEmpty {
                        Text(LocalizedStringKey("Aucun réparateur enregistré. Créez une personne de type 'Réparateur'."))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Button { showingAddReparateur = true } label: {
                        Label(LocalizedStringKey("Ajouter un réparateur"), systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.bordered)
                }
                
                Section(LocalizedStringKey("Description du problème")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
                
                Section(LocalizedStringKey("Délai")) {
                    Toggle(LocalizedStringKey("Date de retour prévue"), isOn: $useDateFinPrevue)
                    if useDateFinPrevue {
                        DatePicker(LocalizedStringKey("Retour prévu le"), selection: Binding(
                            get: { dateFinPrevue ?? Date() },
                            set: { dateFinPrevue = $0 }
                        ), in: Date()..., displayedComponents: .date)
                    }
                }
                
                Section(LocalizedStringKey("Coût")) {
                    Toggle(LocalizedStringKey("Réparation gratuite"), isOn: $estGratuite)
                    
                    if !estGratuite {
                        HStack {
                            Text(LocalizedStringKey("Coût estimé"))
                            Spacer()
                            HStack {
                                TextField("0", text: $coutEstimeText)
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
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text(LocalizedStringKey("L'emprunt ne pourra pas être prêté, loué ou restitué tant que la réparation sera en cours."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Réparer l'emprunt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Envoyer")) {
                        if let reparateurId = reparateurId {
                            if dataManager.peutAjouterReparation() {
                                dataManager.envoyerEmpruntEnReparation(
                                    empruntId,
                                    reparateurId: reparateurId,
                                    description: description,
                                    dateFinPrevue: useDateFinPrevue ? dateFinPrevue : nil,
                                    coutEstime: estGratuite ? nil : coutEstime,
                                    notes: notes,
                                    estGratuite: estGratuite
                                )
                                dismiss()
                            } else {
                                showingLimitAlert = true
                            }
                        }
                    }
                    .disabled(reparateurId == nil || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingAddReparateur) {
                AjouterPersonneView(onPersonneCreated: { newId in
                    reparateurId = newId
                }, defaultTypePersonne: .mecanicien)
                .environmentObject(dataManager)
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumSheet = true
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Vous avez atteint la limite de réparations gratuites. Passez à Premium pour créer des réparations illimitées."))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
    }
}

// MARK: - Emprunt Detail View
/// Vue de détail pour un emprunt, accessible depuis la fiche personne
struct EmpruntDetailView: View {
    let emprunt: Emprunt
    @EnvironmentObject var dataManager: DataManager
    @State private var showConfirm = false
    @State private var showingAffectation = false
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
    
    // Lire la version courante depuis le store
    private var empruntCourant: Emprunt {
        dataManager.emprunts.first { $0.id == emprunt.id } ?? emprunt
    }
    
    // Vérifie si l'emprunt est actuellement prêté à quelqu'un
    private var pretActif: Pret? {
        dataManager.empruntEstPrete(empruntCourant.id)
    }
    
    // Nom de la personne à qui l'emprunt est prêté
    private var nomPersonnePret: String {
        guard let pret = pretActif,
              let personne = dataManager.getPersonne(id: pret.personneId) else {
            return ""
        }
        return personne.nomComplet
    }
    
    // Vérifie si l'emprunt est actuellement loué à quelqu'un (via son matériel lié)
    private var locationActif: Location? {
        guard let materielLieId = empruntCourant.materielLieId else { return nil }
        return dataManager.locations.first { $0.materielId == materielLieId && $0.estActive }
    }
    
    // Nom de la personne à qui l'emprunt est loué
    private var nomPersonneLocation: String {
        guard let location = locationActif,
              let personne = dataManager.getPersonne(id: location.locataireId) else {
            return ""
        }
        return personne.nomComplet
    }
    
    // Vérifie si l'emprunt est bloqué (prêté OU loué)
    private var estBloque: Bool {
        pretActif != nil || locationActif != nil
    }
    
    private var joursRetard: Int {
        Calendar.current.dateComponents([.day], from: empruntCourant.dateFin, to: Date()).day ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Carte principale avec infos
                VStack(alignment: .leading, spacing: 12) {
                    // Image de l'objet
                    if let data = empruntCourant.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipped()
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3)))
                    }
                    
                    HStack {
                        Text(empruntCourant.nomObjet)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        if empruntCourant.estRetourne {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        } else if empruntCourant.estEnRetard {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        } else {
                            Image(systemName: "clock.fill").foregroundColor(.orange)
                        }
                    }
                    
                    if let personne = dataManager.getPersonne(id: empruntCourant.personneId) {
                        Label(personne.nomComplet, systemImage: "person")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    } else {
                        // Emprunt orphelin - permettre l'affectation
                        Button(action: { showingAffectation = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(LocalizedStringKey("Aucune personne - Affecter"))
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Dates
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(localizedString("Début:")) \(formatDate(empruntCourant.dateDebut))").font(.caption)
                            Text("\(localizedString("Fin:")) \(formatDate(empruntCourant.dateFin))").font(.caption)
                        }.foregroundColor(.secondary)
                        Spacer()
                        if empruntCourant.estRetourne, let dateRetour = empruntCourant.dateRetourEffectif {
                            Text("\(localizedString("Retourné le")) \(formatDate(dateRetour))")
                                .font(.caption).foregroundColor(.green)
                        } else if empruntCourant.estEnRetard {
                            Text("\(joursRetard) \(localizedString("jour(s) de retard"))")
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    // Notes
                    if !empruntCourant.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "note.text").foregroundColor(.secondary)
                            Text(empruntCourant.notes).font(.callout).foregroundColor(.primary)
                        }.padding(.top, 2)
                    }
                    
                    // Indicateur si l'emprunt est actuellement prêté
                    if let pret = pretActif {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("Prêté à"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(nomPersonnePret)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                            }
                            Spacer()
                            Text(LocalizedStringKey("jusqu'au \(formatDate(pret.dateFin))"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Indicateur si l'emprunt est actuellement loué
                    if let location = locationActif {
                        HStack(spacing: 8) {
                            Image(systemName: "eurosign.arrow.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("Loué à"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(nomPersonneLocation)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            Text(LocalizedStringKey("jusqu'au \(formatDate(location.dateFin))"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Bouton de retour (si pas bloqué)
                    if !empruntCourant.estRetourne && !estBloque {
                        Button { showConfirm = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(LocalizedStringKey("Valider le retour"))
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
                    } else if estBloque && !empruntCourant.estRetourne {
                        // Message expliquant pourquoi le retour est bloqué
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                            Text(LocalizedStringKey("Retour bloqué"))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
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
                colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(LocalizedStringKey("Détail de l'emprunt"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(LocalizedStringKey("Valider le retour ?"), isPresented: $showConfirm, titleVisibility: .visible) {
            Button(LocalizedStringKey("Confirmer le retour")) {
                dataManager.validerRetourEmprunt(empruntCourant.id)
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) { }
        }
        .sheet(isPresented: $showingAffectation) {
            AffecterPersonneEmpruntView(emprunt: empruntCourant)
        }
    }
}

// MARK: - Affecter une personne à un emprunt orphelin
struct AffecterPersonneEmpruntView: View {
    let emprunt: Emprunt
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var personneId: UUID?
    @State private var showingAddPerson = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Sélectionner une personne")) {
                    Picker(LocalizedStringKey("Personne"), selection: $personneId) {
                        Text(LocalizedStringKey("Choisir...")).tag(nil as UUID?)
                        ForEach(dataManager.personnes) { personne in
                            Text(personne.nomComplet).tag(personne.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Button { showingAddPerson = true } label: {
                        Label(LocalizedStringKey("Ajouter une personne"), systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle(LocalizedStringKey("Affecter l'emprunt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Affecter")) {
                        if let personneId = personneId {
                            var updatedEmprunt = emprunt
                            updatedEmprunt.personneId = personneId
                            dataManager.modifierEmprunt(updatedEmprunt)
                            dismiss()
                        }
                    }
                    .disabled(personneId == nil)
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView(onPersonneCreated: { newId in
                    personneId = newId
                })
                .environmentObject(dataManager)
            }
        }
    }
}