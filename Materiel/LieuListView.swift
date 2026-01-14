//
//  LieuListView.swift
//  Materiel
//
//  Created by Robert Oulhen on 10/11/2025.
//

import SwiftUI

struct LieuListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSheet = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    
    var lieuxFiltres: [LieuStockage] {
        if searchText.isEmpty {
            return dataManager.lieuxStockage
        }
        return dataManager.lieuxStockage.filter { lieu in
            lieu.nom.localizedCaseInsensitiveContains(searchText) ||
            lieu.adresse.localizedCaseInsensitiveContains(searchText) ||
            lieu.batiment.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                List {
                    // Bouton d'ajout proéminent en tête
                    Section {
                    Button(action: {
                        if dataManager.peutAjouterLieu() {
                            searchText = ""
                            showingAddSheet = true
                        } else {
                            showingLimitAlert = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text(LocalizedStringKey("Ajouter un lieu"))
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
                
                ForEach(lieuxFiltres) { lieu in
                    NavigationLink(destination: LieuDetailView(lieu: lieu)) {
                        LieuRowView(lieu: lieu)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    indexSetToDelete = offsets
                    showingDeleteAlert = true
                }
            }
            .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher un lieu"))
            .navigationTitle(LocalizedStringKey("Lieux de stockage"))
            .toolbar { }
            .sheet(isPresented: $showingAddSheet) { AjouterLieuView() }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumSheet = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Limite lieux atteinte"))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        for index in offsets {
                            let lieu = lieuxFiltres[index]
                            dataManager.supprimerLieu(lieu)
                        }
                    }
                    indexSetToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    indexSetToDelete = nil
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer ce lieu ? Cette action est irréversible."))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            }
        }
    }
}

struct LieuRowView: View {
    let lieu: LieuStockage
    @EnvironmentObject var dataManager: DataManager
    
    var nombreMateriels: Int {
        dataManager.materiels.filter { $0.lieuStockageId == lieu.id }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lieu.nom)
                .font(.headline)
            if !lieu.adresseComplete.isEmpty {
                Text(lieu.adresseComplete)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack {
                Label(lieu.adresse, systemImage: "location")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                // Compteur en bulle à droite
                (Text("\(nombreMateriels) ") + Text(LocalizedStringKey("matériel(s)")))
                    .font(.caption2).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.blue.opacity(0.15))
                    )
                    .overlay(
                        Capsule().stroke(Color.blue.opacity(0.3))
                    )
                    .foregroundColor(.blue)
            }
            // Supprimé: aperçu des objets en bulles
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        .padding(.vertical, 4)
    }
}

struct AjouterLieuView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var nom = ""
    @State private var adresse = ""
    @State private var batiment = ""
    
    private var nomTrimmed: String { nom.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var adresseTrimmed: String { adresse.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var batimentTrimmed: String { batiment.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Identification")) {
                    TextField(LocalizedStringKey("Nom du lieu"), text: $nom)
                    TextField(LocalizedStringKey("Adresse"), text: $adresse)
                    TextField(LocalizedStringKey("Bâtiment"), text: $batiment)
                    Text(LocalizedStringKey("Ex: Garage, Cave, Grenier, Bureau..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(LocalizedStringKey("Nouveau lieu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Ajouter")) { ajouterLieu() }
                    .disabled(nomTrimmed.isEmpty)
                }
            }
        }
    }
    
    func ajouterLieu() {
        let lieu = LieuStockage(
            nom: nomTrimmed,
            adresse: adresseTrimmed,
            batiment: batimentTrimmed,
            etage: "",
            salle: "",
            notes: ""
        )
        dataManager.ajouterLieu(lieu)
        dismiss()
    }
}

// Vue pour créer un lieu depuis le formulaire de création de matériel
struct AjouterLieuDepuisMaterielView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var onLieuCreated: (UUID) -> Void
    
    @State private var nom = ""
    @State private var adresse = ""
    @State private var batiment = ""
    
    private var nomTrimmed: String { nom.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var adresseTrimmed: String { adresse.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var batimentTrimmed: String { batiment.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Identification")) {
                    TextField(LocalizedStringKey("Nom du lieu"), text: $nom)
                    TextField(LocalizedStringKey("Adresse"), text: $adresse)
                    TextField(LocalizedStringKey("Bâtiment"), text: $batiment)
                    Text(LocalizedStringKey("Ex: Garage, Cave, Grenier, Bureau..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(LocalizedStringKey("Nouveau lieu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Ajouter")) { ajouterLieu() }
                    .disabled(nomTrimmed.isEmpty)
                }
            }
        }
    }
    
    func ajouterLieu() {
        let lieu = LieuStockage(
            nom: nomTrimmed,
            adresse: adresseTrimmed,
            batiment: batimentTrimmed,
            etage: "",
            salle: "",
            notes: ""
        )
        dataManager.ajouterLieu(lieu)
        onLieuCreated(lieu.id)
        dismiss()
    }
}

struct EditLieuView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    private let original: LieuStockage
    @State private var nom: String
    @State private var adresse: String
    @State private var batiment: String
    
    init(lieu: LieuStockage) {
        self.original = lieu
        _nom = State(initialValue: lieu.nom)
        _adresse = State(initialValue: lieu.adresse)
        _batiment = State(initialValue: lieu.batiment)
    }
    
    private var nomTrimmed: String { nom.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var adresseTrimmed: String { adresse.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var batimentTrimmed: String { batiment.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Identification")) {
                    TextField(LocalizedStringKey("Nom du lieu"), text: $nom)
                    TextField(LocalizedStringKey("Adresse"), text: $adresse)
                    TextField(LocalizedStringKey("Bâtiment"), text: $batiment)
                    Text(LocalizedStringKey("Ex: Garage, Cave, Grenier, Bureau..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Modifier le lieu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Enregistrer")) { enregistrer() }
                        .disabled(nomTrimmed.isEmpty)
                }
            }
        }
    }
    
    private func enregistrer() {
        let updated = LieuStockage(
            id: original.id,
            nom: nomTrimmed,
            adresse: adresseTrimmed,
            batiment: batimentTrimmed,
            etage: "",
            salle: "",
            notes: ""
        )
        dataManager.modifierLieu(updated)
        dismiss()
    }
}

struct LieuDetailView: View {
    let lieu: LieuStockage
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditSheet = false
    
    var materielsStockes: [Materiel] {
        dataManager.materiels.filter { $0.lieuStockageId == lieu.id }
    }
    
    // Toujours lire la version courante
    var lieuCourant: LieuStockage {
        dataManager.getLieu(id: lieu.id) ?? lieu
    }
    
    // Helpers de couleur pour les bulles
    private func hueForString(_ s: String) -> Double {
        var hash: UInt64 = 1469598103934665603 // FNV-1a offset
        for u in s.unicodeScalars { hash = (hash ^ UInt64(u.value)) &* 1099511628211 }
        return Double(hash % 360) / 360.0
    }
    private func tagColor(for key: String) -> Color {
        let h = hueForString(key)
        return Color(hue: h, saturation: 0.6, brightness: 0.95)
    }
    
    var body: some View {
        List {
            Section(LocalizedStringKey("Informations")) {
                LabeledContent(LocalizedStringKey("Nom du lieu"), value: lieuCourant.nom)
                LabeledContent(LocalizedStringKey("Adresse"), value: lieuCourant.adresse)
                if !lieuCourant.batiment.isEmpty {
                    LabeledContent(LocalizedStringKey("Localisation"), value: lieuCourant.batiment)
                }
                if !lieuCourant.etage.isEmpty {
                    LabeledContent(LocalizedStringKey("Étage"), value: lieuCourant.etage)
                }
                if !lieuCourant.salle.isEmpty {
                    LabeledContent(LocalizedStringKey("Salle"), value: lieuCourant.salle)
                }
                if !lieuCourant.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Notes"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lieuCourant.notes)
                    }
                }
            }
            
            Section(header: HStack {
                Text(LocalizedStringKey("Matériel stocké"))
                Text("(\(materielsStockes.count))")
            }) {
                if materielsStockes.isEmpty {
                    Text(LocalizedStringKey("Aucun matériel stocké ici"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(materielsStockes) { materiel in
                        NavigationLink(destination: MaterielDetailView(materiel: materiel)) {
                            VStack(alignment: .leading, spacing: 6) {
                                // Bulle colorée pour le nom
                                let key = materiel.categorie.isEmpty ? materiel.nom : materiel.categorie
                                let color = tagColor(for: key)
                                Text(materiel.nom)
                                    .font(.subheadline).bold()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(color.opacity(0.15))
                                    )
                                    .overlay(
                                        Capsule().stroke(color.opacity(0.3))
                                    )
                                    .foregroundColor(color)
                                // Catégorie en dessous si présente
                                if !materiel.categorie.isEmpty {
                                    Text(materiel.categorie)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Détails"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(LocalizedStringKey("Modifier")) { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditLieuView(lieu: lieuCourant)
        }
    }
}
