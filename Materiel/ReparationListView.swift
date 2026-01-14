//
//  ReparationListView.swift
//  Materiel
//
//  Created by Robert Oulhen on 31/12/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ReparationListView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingAddSheet = false
    @State private var showingLimitAlert = false
    @State private var showingPremiumSheet = false
    @State private var searchText = ""
    @State private var filtreStatut = "En cours"
    @State private var filtrePaiement = "Tous"
    @State private var showingDeleteAlert = false
    @State private var reparationToDelete: Reparation?
    @State private var showingNotPaidAlert = false
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private let statutOptions = ["En cours", "Terminées", "Toutes"]
    private let paiementOptions = ["Tous", "Payé", "Non payé"]
    
    var reparationsFiltrees: [Reparation] {
        var liste = dataManager.reparations
        
        switch filtreStatut {
        case "En cours":
            liste = liste.filter { $0.estEnCours }
        case "Terminées":
            liste = liste.filter { $0.estTerminee }
        default:
            break
        }
        
        // Filtre par paiement
        switch filtrePaiement {
        case "Payé":
            liste = liste.filter { $0.paiementRecu }
        case "Non payé":
            liste = liste.filter { !$0.paiementRecu }
        default:
            break
        }
        
        if !searchText.isEmpty {
            liste = liste.filter { reparation in
                if let materiel = dataManager.getMateriel(id: reparation.materielId),
                   materiel.nom.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let reparateur = dataManager.getPersonne(id: reparation.reparateurId),
                   reparateur.nomComplet.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if reparation.description.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }
        
        return liste.sorted { $0.dateDebut > $1.dateDebut }
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
                    // Résumé financier
                    if !dataManager.reparations.isEmpty {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey("Dépenses"))
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
                    
                    // Filtre par paiement
                    HStack(spacing: 12) {
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
                            .background(filtrePaiement != "Tous" ? Color.orange.opacity(0.15) : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        // Bouton reset si filtre actif
                        if filtrePaiement != "Tous" {
                            Button(action: {
                                filtrePaiement = "Tous"
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    // Bouton d'ajout
                    Button(action: {
                        if dataManager.peutAjouterReparation() {
                            showingAddSheet = true
                        } else {
                            showingLimitAlert = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text(LocalizedStringKey("Envoyer en réparation"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            if !storeManager.hasUnlockedPremium {
                                Text("(\(dataManager.reparationsRestantes))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
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
                    
                    if reparationsFiltrees.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Aucune réparation"))
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Les matériels en réparation apparaîtront ici"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                        Spacer()
                    } else {
                        List {
                            ForEach(reparationsFiltrees) { reparation in
                                ReparationRowView(reparation: reparation)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                            .onDelete { offsets in
                                if let index = offsets.first {
                                    let reparation = reparationsFiltrees[index]
                                    if !reparation.paiementRecu && ((reparation.coutEstime ?? 0) > 0 || (reparation.coutFinal ?? 0) > 0) {
                                        showingNotPaidAlert = true
                                    } else {
                                        reparationToDelete = reparation
                                        showingDeleteAlert = true
                                    }
                                }
                            }
                        }
                        .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher une réparation"))
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Réparations"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Fermer")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AjouterReparationView()
            }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let reparation = reparationToDelete {
                        dataManager.supprimerReparation(reparation)
                    }
                    reparationToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    reparationToDelete = nil
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer cette réparation ?"))
            }
            .alert(LocalizedStringKey("Suppression impossible"), isPresented: $showingNotPaidAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Vous devez d'abord marquer cette réparation comme payée avant de pouvoir la supprimer."))
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showingPremiumSheet = true
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Vous avez atteint la limite de réparations gratuites. Passez à Premium pour créer des réparations illimitées."))
            }
            .sheet(isPresented: $showingPremiumSheet) {
                PremiumView()
            }
        }
    }
}

// MARK: - Row View
struct ReparationRowView: View {
    let reparation: Reparation
    @EnvironmentObject var dataManager: DataManager
    @State private var showingRetourSheet = false
    @State private var showingReglementSheet = false
    @State private var showingNotPaidAlert = false
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // En-tête avec photo et nom du matériel
            HStack(alignment: .top, spacing: 12) {
                if let materiel = dataManager.getMateriel(id: reparation.materielId) {
                    if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    } else {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                            .frame(width: 56, height: 56)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(materiel.nom)
                                .font(.headline)
                            Spacer()
                            if reparation.estTerminee {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if reparation.estEnRetard {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "wrench.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Réparateur
                        if let reparateur = dataManager.getPersonne(id: reparation.reparateurId) {
                            Label(reparateur.nomComplet, systemImage: "person.fill")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    // Matériel non trouvé
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                        .frame(width: 56, height: 56)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text(LocalizedStringKey("Matériel inconnu"))
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }
            
            // Description du problème
            if !reparation.description.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    Text(reparation.description)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }
            
            // Dates
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(NSLocalizedString("Début:", comment: "")) \(formatDate(reparation.dateDebut))")
                        .font(.caption)
                    if let dateFin = reparation.dateFinPrevue {
                        Text("\(NSLocalizedString("Fin prévue:", comment: "")) \(formatDate(dateFin))")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                if reparation.estTerminee, let dateRetour = reparation.dateRetour {
                    Text("\(NSLocalizedString("Retour:", comment: "")) \(formatDate(dateRetour))")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if reparation.estEnRetard {
                    Text("\(reparation.joursRetard) \(NSLocalizedString("jour(s) de retard", comment: ""))")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Coûts et paiement
            HStack {
                // Vérifier si la réparation est gratuite
                let estGratuite = reparation.paiementRecu && (reparation.coutFinal ?? -1) == 0 && (reparation.coutEstime ?? 0) == 0
                
                if estGratuite {
                    Label(LocalizedStringKey("Gratuite"), systemImage: "gift.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    if let coutEstime = reparation.coutEstime, coutEstime > 0 {
                        Text("\(NSLocalizedString("Estimé:", comment: "")) \(String(format: "%.2f€", coutEstime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let coutFinal = reparation.coutFinal, coutFinal > 0 {
                        Text("\(NSLocalizedString("Final:", comment: "")) \(String(format: "%.2f€", coutFinal))")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Indicateur de paiement (sauf si gratuite)
                if !estGratuite {
                    if reparation.paiementRecu {
                        Label(LocalizedStringKey("Payé"), systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if (reparation.coutEstime ?? 0) > 0 || (reparation.coutFinal ?? 0) > 0 {
                        Label(LocalizedStringKey("Non payé"), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Notes
            if !reparation.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                    Text(reparation.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Boutons d'action
            VStack(spacing: 8) {
                if reparation.estEnCours {
                    Button { showingRetourSheet = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(LocalizedStringKey("Valider le retour de réparation"))
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
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(role: .destructive) {
                        if !reparation.paiementRecu && ((reparation.coutEstime ?? 0) > 0 || (reparation.coutFinal ?? 0) > 0) {
                            showingNotPaidAlert = true
                        } else {
                            dataManager.supprimerReparation(reparation)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text(LocalizedStringKey("Effacer cette réparation"))
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
                    }
                    .buttonStyle(.plain)
                }
                
                // Bouton Régler - disponible si coût > 0 et pas encore payé
                if !reparation.paiementRecu && ((reparation.coutEstime ?? 0) > 0 || (reparation.coutFinal ?? 0) > 0) {
                    Button {
                        showingReglementSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eurosign.circle.fill")
                            Text(LocalizedStringKey("Régler la réparation"))
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
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        .padding(.vertical, 4)
        .sheet(isPresented: $showingRetourSheet) {
            ValiderRetourReparationView(reparation: reparation)
        }
        .sheet(isPresented: $showingReglementSheet) {
            ReglementReparationView(reparation: reparation)
        }
        .alert(LocalizedStringKey("Suppression impossible"), isPresented: $showingNotPaidAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Vous devez d'abord marquer cette réparation comme payée avant de pouvoir la supprimer."))
        }
    }
}

// MARK: - Valider Retour Réparation
struct ValiderRetourReparationView: View {
    let reparation: Reparation
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Notes de clôture")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Retour réparation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Valider")) {
                        validerRetour()
                    }
                }
            }
        }
    }
    
    private func validerRetour() {
        // Mettre à jour les notes si modifiées
        if !notes.isEmpty {
            var updatedReparation = reparation
            updatedReparation.notes = reparation.notes.isEmpty ? notes : reparation.notes + "\n" + notes
            dataManager.modifierReparation(updatedReparation)
        }
        
        dataManager.validerRetourReparation(reparation.id)
        dismiss()
    }
}

// MARK: - Règlement Réparation
/// Vue pour régler une réparation (paiement)
struct ReglementReparationView: View {
    let reparation: Reparation
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var montantRegle: String = ""
    @State private var notes: String = ""
    
    // Récupère l'état actuel de la réparation depuis DataManager
    var reparationCourante: Reparation {
        dataManager.reparations.first { $0.id == reparation.id } ?? reparation
    }
    
    // Montant à régler (coût final si disponible, sinon coût estimé)
    var montantARegler: Double {
        reparationCourante.coutFinal ?? reparationCourante.coutEstime ?? 0
    }
    
    init(reparation: Reparation) {
        self.reparation = reparation
        let montant = reparation.coutFinal ?? reparation.coutEstime ?? 0
        _montantRegle = State(initialValue: montant > 0 ? String(format: "%.2f", montant) : "")
        _notes = State(initialValue: "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Récapitulatif
                Section(LocalizedStringKey("Récapitulatif")) {
                    if let materiel = dataManager.getMateriel(id: reparationCourante.materielId) {
                        LabeledContent(LocalizedStringKey("Matériel"), value: materiel.nom)
                    }
                    if let reparateur = dataManager.getPersonne(id: reparationCourante.reparateurId) {
                        LabeledContent(LocalizedStringKey("Réparateur"), value: reparateur.nomComplet)
                    }
                    if !reparationCourante.description.isEmpty {
                        LabeledContent(LocalizedStringKey("Description"), value: reparationCourante.description)
                    }
                }
                
                // Montants
                Section(LocalizedStringKey("Montant")) {
                    if let coutEstime = reparationCourante.coutEstime, coutEstime > 0 {
                        HStack {
                            Text(LocalizedStringKey("Coût estimé"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f €", coutEstime))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TextField(LocalizedStringKey("Montant à régler (€)"), text: $montantRegle)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Notes optionnelles
                Section(LocalizedStringKey("Notes (optionnel)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                
                // Bouton Confirmer le paiement
                Section {
                    Button {
                        confirmerReglement()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text(LocalizedStringKey("Confirmer le paiement"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.green)
                }
            }
            .navigationTitle(LocalizedStringKey("Règlement réparation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
            }
        }
    }
    
    private func confirmerReglement() {
        // Mettre à jour le coût final si modifié
        if let montant = Double(montantRegle.replacingOccurrences(of: ",", with: ".")) {
            if let index = dataManager.reparations.firstIndex(where: { $0.id == reparation.id }) {
                dataManager.reparations[index].coutFinal = montant
                if !notes.isEmpty {
                    if dataManager.reparations[index].notes.isEmpty {
                        dataManager.reparations[index].notes = notes
                    } else {
                        dataManager.reparations[index].notes += "\n" + notes
                    }
                }
            }
        }
        
        // Marquer comme payé (cela enregistre aussi dans la comptabilité)
        dataManager.marquerPaiementReparation(reparation.id, recu: true)
        dismiss()
    }
}

// MARK: - Ajouter Réparation
struct AjouterReparationView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    // Matériel pré-sélectionné (optionnel, depuis la fiche matériel)
    var materielPreselectionne: Materiel? = nil
    
    @State private var materielId: UUID?
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
    @State private var showingMaterielSelection = false
    @State private var showingReparateurSelection = false
    @State private var showPremiumSheet = false
    
    // Vérifie si on peut créer une nouvelle réparation
    var canCreateReparation: Bool {
        storeManager.canAddMoreReparation(currentCount: dataManager.totalReparationsCreated)
    }
    
    var materielsDisponibles: [Materiel] {
        dataManager.materiels.filter { dataManager.materielEstDisponible($0.id) }
    }
    
    var reparateurs: [Personne] {
        dataManager.getMecaniciens()
    }
    
    var peutCreer: Bool {
        materielId != nil && reparateurId != nil && !description.isEmpty
    }
    
    // Matériel sélectionné pour affichage
    var materielSelectionne: Materiel? {
        guard let id = materielId else { return nil }
        return dataManager.getMateriel(id: id)
    }
    
    // Réparateur sélectionné pour affichage
    var reparateurSelectionne: Personne? {
        guard let id = reparateurId else { return nil }
        return dataManager.personnes.first(where: { $0.id == id })
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !canCreateReparation {
                    // Vue affichée quand la limite est atteinte
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.orange)
                        
                        Text(LocalizedStringKey("Limite atteinte"))
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(LocalizedStringKey("Vous avez atteint la limite de \(StoreManager.freeReparationLimit) réparations en version gratuite."))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Text(LocalizedStringKey("Passez à Premium pour créer des réparations illimitées et profiter de toutes les fonctionnalités."))
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button {
                            showPremiumSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                Text(LocalizedStringKey("Passer à Premium"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Formulaire normal
                    Form {
                        Section(LocalizedStringKey("Matériel à réparer")) {
                            if let mat = materielPreselectionne {
                                // Matériel pré-sélectionné, affichage avec photo
                                HStack(spacing: 12) {
                                    if let data = mat.imageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.orange.opacity(0.15))
                                            Image(systemName: "wrench.fill")
                                        .foregroundColor(.orange)
                                }
                                .frame(width: 50, height: 50)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mat.nom)
                                    .font(.headline)
                                if !mat.categorie.isEmpty {
                                    Text(mat.categorie)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        // Sélection du matériel via sheet
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
                        
                        if materielsDisponibles.isEmpty {
                            Text(LocalizedStringKey("Aucun matériel disponible"))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section(LocalizedStringKey("Mécanicien")) {
                    Button {
                        hideKeyboard()
                        showingReparateurSelection = true
                    } label: {
                        if let reparateur = reparateurSelectionne {
                            HStack(spacing: 12) {
                                // Photo du réparateur
                                if let photoData = reparateur.photoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reparateur.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let type = reparateur.typePersonne {
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
                                Text(LocalizedStringKey("Sélectionner le mécanicien"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if reparateurs.isEmpty {
                        Text(LocalizedStringKey("Aucun mécanicien enregistré"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
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
                    } // Fin Form
                    .scrollDismissesKeyboard(.interactively)
                } // Fin else
            } // Fin Group
            .navigationTitle(LocalizedStringKey("Nouvelle réparation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Créer")) {
                        creerReparation()
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
                AjouterReparateurView()
            }
            .sheet(isPresented: $showingReparateurSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $reparateurId,
                    personnes: reparateurs,
                    title: LocalizedStringKey("Choisir le mécanicien"),
                    showAddButton: true,
                    onAddPerson: { showingAddReparateur = true }
                )
            }
            .sheet(isPresented: $showingMaterielSelection) {
                MaterielSelectionView(
                    selectedMaterielId: $materielId,
                    materiels: materielsDisponibles,
                    title: LocalizedStringKey("Choisir le matériel")
                )
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
        .onAppear {
            // Pré-sélectionner le matériel si fourni
            if let mat = materielPreselectionne {
                materielId = mat.id
            }
        }
        .onChange(of: dataManager.personnes.count) { oldValue, newValue in
            // Sélectionner le nouveau réparateur s'il vient d'être ajouté
            if newValue > oldValue {
                if let nouveauReparateur = dataManager.personnes.last,
                   nouveauReparateur.typePersonne == .mecanicien {
                    reparateurId = nouveauReparateur.id
                }
            }
        }
    }
    
    private func creerReparation() {
        guard let materielId = materielId, let reparateurId = reparateurId else {
            alertMessage = NSLocalizedString("Veuillez sélectionner un matériel et un réparateur", comment: "")
            showingAlert = true
            return
        }
        
        if description.isEmpty {
            alertMessage = NSLocalizedString("Veuillez décrire le problème", comment: "")
            showingAlert = true
            return
        }
        
        // Si gratuite, coût = nil et paiement déjà considéré comme "réglé"
        let cout: Double? = estGratuite ? nil : Double(coutEstime.replacingOccurrences(of: ",", with: "."))
        
        let reparation = Reparation(
            materielId: materielId,
            reparateurId: reparateurId,
            pretOrigineId: nil,
            locationOrigineId: nil,
            dateDebut: Date(),
            dateFinPrevue: useDateFinPrevue ? dateFinPrevue : nil,
            dateRetour: nil,
            description: description,
            coutEstime: cout,
            coutFinal: estGratuite ? 0 : nil,
            paiementRecu: estGratuite, // Si gratuite, considérée comme réglée
            notes: estGratuite ? (notes.isEmpty ? NSLocalizedString("Réparation gratuite", comment: "") : notes + "\n" + NSLocalizedString("Réparation gratuite", comment: "")) : notes
        )
        
        dataManager.ajouterReparation(reparation)
        dismiss()
    }
}

// MARK: - Ajouter Réparateur (vue spécialisée)
struct AjouterReparateurView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var nom = ""
    @State private var prenom = ""
    @State private var email = ""
    @State private var telephone = ""
    @State private var organisation = ""
    @State private var showPremiumSheet = false
    
    // Vérifie si on peut créer une nouvelle personne (réparateur)
    var canCreatePersonne: Bool {
        storeManager.canAddMorePersonne(currentCount: dataManager.totalPersonnesCreated)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !canCreatePersonne {
                    // Vue affichée quand la limite est atteinte
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 70))
                            .foregroundColor(.orange)
                        
                        Text(LocalizedStringKey("Limite atteinte"))
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(LocalizedStringKey("Vous avez atteint la limite de \(StoreManager.freePersonneLimit) personnes en version gratuite."))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Text(LocalizedStringKey("Passez à Premium pour ajouter des personnes illimitées et profiter de toutes les fonctionnalités."))
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button {
                            showPremiumSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                Text(LocalizedStringKey("Passer à Premium"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Formulaire normal
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
                }
            }
            .navigationTitle(LocalizedStringKey("Nouveau réparateur"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if canCreatePersonne {
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
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
    }
}

// MARK: - Reparation Detail View
/// Vue de détail pour une réparation, accessible depuis la fiche matériel
struct ReparationDetailView: View {
    let reparation: Reparation
    @EnvironmentObject var dataManager: DataManager
    @State private var showingRetourSheet = false
    @State private var showingReglementSheet = false
    @State private var showingNotPaidAlert = false
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
    private var reparationCourante: Reparation {
        dataManager.reparations.first { $0.id == reparation.id } ?? reparation
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Carte principale avec infos
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        if let materiel = dataManager.getMateriel(id: reparationCourante.materielId) {
                            if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipped()
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3)))
                            } else {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 35))
                                    .foregroundColor(.orange)
                                    .frame(width: 70, height: 70)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(materiel.nom)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if reparationCourante.estTerminee {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    } else if reparationCourante.estEnRetard {
                                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                    } else {
                                        Image(systemName: "wrench.fill").foregroundColor(.orange)
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
                    
                    // Réparateur
                    if let reparateur = dataManager.getPersonne(id: reparationCourante.reparateurId) {
                        Label(reparateur.nomComplet, systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    
                    Divider()
                    
                    // Description du problème
                    if !reparationCourante.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Description du problème"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(reparationCourante.description)
                                .font(.body)
                        }
                    }
                    
                    // Dates
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(localizedString("Début:")) \(formatDate(reparationCourante.dateDebut))")
                                .font(.subheadline)
                            Spacer()
                        }
                        if let dateFin = reparationCourante.dateFinPrevue {
                            Text("\(localizedString("Fin prévue:")) \(formatDate(dateFin))")
                                .font(.subheadline)
                        }
                        if reparationCourante.estTerminee, let dateRetour = reparationCourante.dateRetour {
                            Text("\(localizedString("Retour:")) \(formatDate(dateRetour))")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        } else if reparationCourante.estEnRetard {
                            Text("\(reparationCourante.joursRetard) \(localizedString("jour(s) de retard"))")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                    .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Coûts
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Coûts"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Vérifier si la réparation est gratuite (coutFinal == 0 et paiementRecu == true et pas de coutEstime)
                        let estGratuite = reparationCourante.paiementRecu && (reparationCourante.coutFinal ?? -1) == 0 && (reparationCourante.coutEstime ?? 0) == 0
                        
                        if estGratuite {
                            Label(LocalizedStringKey("Gratuite"), systemImage: "gift.fill")
                                .font(.headline)
                                .foregroundColor(.green)
                        } else {
                            HStack {
                                if let coutEstime = reparationCourante.coutEstime, coutEstime > 0 {
                                    VStack(alignment: .leading) {
                                        Text(LocalizedStringKey("Estimé"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.2f €", coutEstime))
                                            .font(.headline)
                                    }
                                }
                                Spacer()
                                if let coutFinal = reparationCourante.coutFinal, coutFinal > 0 {
                                    VStack(alignment: .trailing) {
                                        Text(LocalizedStringKey("Final"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.2f €", coutFinal))
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            // Statut paiement
                            if reparationCourante.paiementRecu {
                                Label(LocalizedStringKey("Payé"), systemImage: "checkmark.seal.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            } else if (reparationCourante.coutEstime ?? 0) > 0 || (reparationCourante.coutFinal ?? 0) > 0 {
                                Label(LocalizedStringKey("Non payé"), systemImage: "clock")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    // Notes
                    if !reparationCourante.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Notes"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(reparationCourante.notes)
                                .font(.body)
                        }
                    }
                    
                    Divider()
                    
                    // Boutons d'action
                    VStack(spacing: 8) {
                        if reparationCourante.estEnCours {
                            Button { showingRetourSheet = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(LocalizedStringKey("Valider le retour de réparation"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.85), Color.mint.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: .green.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Bouton Régler la réparation
                        if !reparationCourante.paiementRecu && ((reparationCourante.coutEstime ?? 0) > 0 || (reparationCourante.coutFinal ?? 0) > 0) {
                            Button {
                                showingReglementSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "eurosign.circle.fill")
                                    Text(LocalizedStringKey("Régler la réparation"))
                                }
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(LocalizedStringKey("Détail réparation"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRetourSheet) {
            ValiderRetourReparationView(reparation: reparationCourante)
        }
        .sheet(isPresented: $showingReglementSheet) {
            ReglementReparationView(reparation: reparationCourante)
        }
        .alert(LocalizedStringKey("Suppression impossible"), isPresented: $showingNotPaidAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Vous devez d'abord marquer cette réparation comme payée avant de pouvoir la supprimer."))
        }
    }
}

#Preview {
    ReparationListView()
        .environmentObject(DataManager.shared)
}
