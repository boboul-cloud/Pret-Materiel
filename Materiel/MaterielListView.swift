//
//  MaterielListView.swift
//  Materiel
//
//  Created by Robert Oulhen on 10/11/2025.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit

// Fonction helper pour les couleurs de type de personne
private func couleurPourTypePersonne(_ type: TypePersonne?) -> Color {
    switch type {
    case .mecanicien: return .orange
    case .salarie: return .green
    case .alm: return .purple
    case .client, .none: return .blue
    }
}

struct MaterielListView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @State private var showingAddSheet = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    // Bouton réglages
    @State private var showingSettings = false
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    // Gestion des catégories
    @State private var showingCategoriesSheet = false
    @State private var categorieToDelete: String? = nil
    @State private var showingDeleteCategorieAlert = false
    @State private var categorieToRename: String? = nil
    @State private var nouveauNomCategorie = ""
    @State private var showingRenameCategorieAlert = false
    @AppStorage("MaterielListView.searchText") private var searchText = ""
    @AppStorage("MaterielListView.selectedCategorie") private var selectedCategorie = "Tous"
    @AppStorage("MaterielListView.selectedLieuKey") private var selectedLieuKey = "Tous"
    @AppStorage("MaterielListView.selectedStatut") private var selectedStatut = "Tous" // "Tous" ou UUID.uuidString
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "fr", ofType: "lproj")
        let bundle = path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    var categories: [String] {
        let raw = dataManager.materiels
            .map { $0.categorie.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seenLower = Set<String>()
        var uniques: [String] = []
        for cat in raw {
            let key = cat.lowercased()
            if !seenLower.contains(key) {
                seenLower.insert(key)
                uniques.append(cat)
            }
        }
        let tri = uniques.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return ["Tous"] + tri
    }
    
    // Liste filtrée uniquement par la recherche (sert aux compteurs)
    var filteredBySearch: [Materiel] {
        dataManager.materiels.filter { materiel in
            searchText.isEmpty ||
            materiel.nom.localizedCaseInsensitiveContains(searchText) ||
            materiel.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Compteur par catégorie (insensible à la casse), "Tous" = total filtré par recherche
    func countForCategorie(_ categorie: String) -> Int {
        if categorie == "Tous" { return filteredBySearch.count }
        return filteredBySearch.filter { $0.categorie.caseInsensitiveCompare(categorie) == .orderedSame }.count
    }
    
    // Lieux triés par nom pour le menu
    var lieuxSorted: [LieuStockage] {
        dataManager.lieuxStockage.sorted { $0.nom.localizedCaseInsensitiveCompare($1.nom) == .orderedAscending }
    }
    // Options de sélection pour le Picker des lieux: "Tous" + chaque id de lieu sous forme de String
    var lieuIdOptions: [String] {
        ["Tous"] + lieuxSorted.map { $0.id.uuidString }
    }
    // Label affiché pour une option de lieu
    func labelForLieuIdString(_ idString: String) -> String {
        if idString == "Tous" { return localizedString("Tous les lieux") }
        guard let lieu = dataManager.lieuxStockage.first(where: { $0.id.uuidString == idString }) else {
            return "Lieu"
        }
        // Afficher "nom: bâtiment" si le bâtiment existe
        if !lieu.batiment.isEmpty {
            return "\(lieu.nom): \(lieu.batiment)"
        }
        return lieu.nom
    }
    // Compteur pour une option de lieu (en fonction de la recherche seulement)
    func countForLieuIdString(_ idString: String) -> Int {
        if idString == "Tous" { return filteredBySearch.count }
        guard let id = UUID(uuidString: idString) else { return 0 }
        return filteredBySearch.filter { $0.lieuStockageId == id }.count
    }
    // Conversion de la sélection persistée en UUID?
    var selectedLieuId: UUID? {
        selectedLieuKey == "Tous" ? nil : UUID(uuidString: selectedLieuKey)
    }
    
    // Compteur par statut (en fonction de la recherche seulement)
    func countForStatut(_ statut: String) -> Int {
        switch statut {
        case "Disponible":
            return filteredBySearch.filter { dataManager.materielEstDisponible($0.id) }.count
        case "Prêté":
            return filteredBySearch.filter { !dataManager.materielEstDisponible($0.id) }.count
        default:
            return filteredBySearch.count
        }
    }
    
    var materielsFiltrés: [Materiel] {
        dataManager.materiels.filter { materiel in
            let matchSearch = searchText.isEmpty ||
                materiel.nom.localizedCaseInsensitiveContains(searchText) ||
                materiel.description.localizedCaseInsensitiveContains(searchText)
            let matchCategorie = selectedCategorie == "Tous" || materiel.categorie.caseInsensitiveCompare(selectedCategorie) == .orderedSame
            let matchLieu = (selectedLieuId == nil) || (materiel.lieuStockageId == selectedLieuId)
            let matchStatut: Bool
            switch selectedStatut {
            case "Disponible":
                matchStatut = dataManager.materielEstDisponible(materiel.id)
            case "Prêté":
                matchStatut = !dataManager.materielEstDisponible(materiel.id)
            default:
                matchStatut = true
            }
            return matchSearch && matchCategorie && matchLieu && matchStatut
        }
    }
    
    // Vérifie l'existence d'une catégorie (insensible à la casse)
    private func categoriesContiennent(_ value: String) -> Bool {
        categories.first { $0.caseInsensitiveCompare(value) == .orderedSame } != nil
    }
    // Vérifie que la sélection de lieu est toujours valide
    private func lieuxContiennentSelection() -> Bool {
        if selectedLieuKey == "Tous" { return true }
        return dataManager.lieuxStockage.contains { $0.id.uuidString == selectedLieuKey }
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
                
                VStack {
                    List {
                        // Bouton d'ajout proéminent
                        Section {
                        Button(action: {
                            if dataManager.peutAjouterMateriel() {
                                showingAddSheet = true
                            } else {
                                showingLimitAlert = true
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text(LocalizedStringKey("Ajouter un matériel"))
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
                    
                    // Filtres regroupés dans une seule section
                    Section {
                        // Filtre par catégorie
                        if categories.count > 1 {
                            HStack {
                                Picker(LocalizedStringKey("Catégorie"), selection: $selectedCategorie) {
                                    ForEach(categories, id: \.self) { categorie in
                                        if categorie == "Tous" {
                                            Text("\(localizedString("Toutes catégories")) (\(countForCategorie(categorie)))").tag(categorie)
                                        } else {
                                            Text("\(categorie) (\(countForCategorie(categorie)))").tag(categorie)
                                        }
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Spacer()
                                
                                Button {
                                    showingCategoriesSheet = true
                                } label: {
                                    Image(systemName: "folder.badge.gearshape")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        
                        // Filtre par lieu
                        if !lieuxSorted.isEmpty {
                            Picker(LocalizedStringKey("Lieu"), selection: $selectedLieuKey) {
                                ForEach(lieuIdOptions, id: \.self) { idString in
                                    let baseLabel = idString == "Tous" ? localizedString("Tous les lieux") : labelForLieuIdString(idString)
                                    Text("\(baseLabel) (\(countForLieuIdString(idString)))")
                                        .tag(idString)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Filtre par statut
                        Picker(LocalizedStringKey("Statut"), selection: $selectedStatut) {
                            Text("\(localizedString("Tous les matériels")) (\(countForStatut("Tous")))").tag("Tous")
                            Text("\(localizedString("Disponible")) (\(countForStatut("Disponible")))").tag("Disponible")
                            Text("\(localizedString("Prêté")) (\(countForStatut("Prêté")))").tag("Prêté")
                        }
                        .pickerStyle(.menu)
                    }
                    .listRowBackground(Color(.systemGray6))
                    
                    ForEach(materielsFiltrés) { materiel in
                        NavigationLink(destination: MaterielDetailView(materiel: materiel)) {
                            MaterielRowView(materiel: materiel)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        // Toujours demander confirmation avant suppression
                        indexSetToDelete = offsets
                        showingDeleteAlert = true
                    }
                }
                .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher du matériel"))
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            }
            .navigationTitle(LocalizedStringKey("Matériel"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedCategorie = "Tous"
                        selectedLieuKey = "Tous"
                        selectedStatut = "Tous"
                        searchText = ""
                    }) {
                        Label(LocalizedStringKey("Réinitialiser"), systemImage: "arrow.counterclockwise")
                    }
                    .disabled(selectedCategorie == "Tous" && selectedLieuKey == "Tous" && selectedStatut == "Tous" && searchText.isEmpty)
                }
                // Bouton réglages à droite
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AjouterMaterielView()
            }
            // Sheet réglages
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        for index in offsets {
                            let materiel = materielsFiltrés[index]
                            dataManager.supprimerMateriel(materiel)
                        }
                    }
                    indexSetToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    indexSetToDelete = nil
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer ce matériel ? Cette action est irréversible."))
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumSheet = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Limite matériels atteinte"))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
            // Sheet gestion des catégories
            .sheet(isPresented: $showingCategoriesSheet) {
                GestionCategoriesSheet(
                    categorieToDelete: $categorieToDelete,
                    showingDeleteAlert: $showingDeleteCategorieAlert,
                    categorieToRename: $categorieToRename,
                    nouveauNom: $nouveauNomCategorie,
                    showingRenameAlert: $showingRenameCategorieAlert
                )
            }
            // Alerte de suppression de catégorie
            .alert(LocalizedStringKey("Supprimer la catégorie"), isPresented: $showingDeleteCategorieAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let cat = categorieToDelete {
                        dataManager.supprimerCategorie(cat)
                        if selectedCategorie.caseInsensitiveCompare(cat) == .orderedSame {
                            selectedCategorie = "Tous"
                        }
                    }
                    categorieToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    categorieToDelete = nil
                }
            } message: {
                if let cat = categorieToDelete {
                    Text("Êtes-vous sûr de vouloir supprimer la catégorie « \(cat) » ? Les matériels concernés n'auront plus de catégorie.")
                }
            }
            // Alerte de renommage de catégorie
            .alert(LocalizedStringKey("Renommer la catégorie"), isPresented: $showingRenameCategorieAlert) {
                TextField(LocalizedStringKey("Nouveau nom"), text: $nouveauNomCategorie)
                Button(LocalizedStringKey("Renommer")) {
                    if let cat = categorieToRename, !nouveauNomCategorie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        dataManager.renommerCategorie(ancienNom: cat, nouveauNom: nouveauNomCategorie)
                        if selectedCategorie.caseInsensitiveCompare(cat) == .orderedSame {
                            selectedCategorie = nouveauNomCategorie.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    categorieToRename = nil
                    nouveauNomCategorie = ""
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    categorieToRename = nil
                    nouveauNomCategorie = ""
                }
            } message: {
                if let cat = categorieToRename {
                    Text("Entrez le nouveau nom pour la catégorie « \(cat) »")
                }
            }
            .onAppear {
                if !categoriesContiennent(selectedCategorie) { selectedCategorie = "Tous" }
                if !lieuxContiennentSelection() { selectedLieuKey = "Tous" }
            }
            .onChange(of: categories) { _, _ in
                if !categoriesContiennent(selectedCategorie) { selectedCategorie = "Tous" }
            }
            .onChange(of: lieuIdOptions) { _, _ in
                if !lieuxContiennentSelection() { selectedLieuKey = "Tous" }
            }
        }
    }
    
    func supprimerMateriels(at offsets: IndexSet) {
        for index in offsets {
            let materiel = materielsFiltrés[index]
            dataManager.supprimerMateriel(materiel)
        }
    }
}

struct MaterielRowView: View {
    let materiel: Materiel
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Vignette photo
            if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.15))
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 70, height: 70)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(materiel.nom)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    let statut = dataManager.statutMateriel(materiel.id)
                    if statut == "disponible" {
                        Text(LocalizedStringKey("Disponible"))
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    } else if statut == "prete" {
                        Text(LocalizedStringKey("Prêté"))
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    } else if statut == "reparation" {
                        Text(LocalizedStringKey("En réparation"))
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .cornerRadius(4)
                    } else {
                        Text(LocalizedStringKey("Loué"))
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                if !materiel.description.isEmpty {
                    Text(materiel.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if !materiel.categorie.isEmpty {
                        Text(materiel.categorie)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    if let lieuId = materiel.lieuStockageId,
                       let lieu = dataManager.getLieu(id: lieuId) {
                        if !materiel.categorie.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(lieu.batiment.isEmpty ? lieu.nom : "\(lieu.nom): \(lieu.batiment)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(materiel.valeur, format: .currency(code: "EUR"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(minHeight: 70)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        .padding(.vertical, 4)
    }
}

struct AjouterMaterielView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var nom = ""
    @State private var description = ""
    @State private var categorieSelectionnee = ""
    @State private var nouvelleCategorie = ""
    @State private var valeur = ""
    @State private var dateAcquisition = Date()
    @State private var lieuStockageId: UUID?
    @State private var localisation = ""
    @State private var notesMateriel = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    // Nouveaux champs pour la facture
    @State private var factureImageData: Data? = nil
    @State private var factureIsPDF: Bool = false
    @State private var showCameraFacturePicker = false
    @State private var showPhotoLibraryFacturePicker = false
    @State private var showPDFPicker = false
    @State private var numeroFacture = ""
    @State private var vendeur = ""
    @State private var showingAddLieuSheet = false
    
    // Liste des catégories existantes (sans doublons, triées)
    private var categoriesExistantes: [String] {
        let raw = dataManager.materiels
            .map { $0.categorie.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seenLower = Set<String>()
        var uniques: [String] = []
        for cat in raw {
            let key = cat.lowercased()
            if !seenLower.contains(key) {
                seenLower.insert(key)
                uniques.append(cat)
            }
        }
        return uniques.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    // Catégorie finale à utiliser
    private var categorie: String {
        if categorieSelectionnee == "__nouvelle__" {
            return nouvelleCategorie.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return categorieSelectionnee
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Photo")) {
                    VStack(spacing: 12) {
                        if let data = imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            HStack {
                                Spacer()
                                Button(role: .destructive) { imageData = nil } label: {
                                    Label(LocalizedStringKey("Retirer la photo"), systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(height: 140)
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text(LocalizedStringKey("Aucune photo"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
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
                                Label(LocalizedStringKey(imageData == nil ? "Choisir une photo" : "Changer la photo"), systemImage: "photo.fill.on.rectangle.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                Section(LocalizedStringKey("Informations générales")) {
                    TextField(LocalizedStringKey("Nom"), text: $nom)
                    TextField(LocalizedStringKey("Description"), text: $description)
                    
                    // Menu déroulant pour la catégorie
                    Picker(LocalizedStringKey("Catégorie"), selection: $categorieSelectionnee) {
                        Text(LocalizedStringKey("Aucune")).tag("")
                        ForEach(categoriesExistantes, id: \.self) { cat in
                            HStack {
                                Text(cat)
                                if let materiel = dataManager.materiels.first(where: { $0.categorie == cat }), !materiel.description.isEmpty {
                                    Text("- \(materiel.description)")
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }.tag(cat)
                        }
                        Text(LocalizedStringKey("+ Nouvelle catégorie")).tag("__nouvelle__")
                    }
                    
                    // Champ pour nouvelle catégorie si sélectionné
                    if categorieSelectionnee == "__nouvelle__" {
                        TextField(LocalizedStringKey("Nom de la nouvelle catégorie"), text: $nouvelleCategorie)
                    }
                }
                
                Section(LocalizedStringKey("Détails")) {
                    TextField(LocalizedStringKey("Valeur (€)"), text: $valeur)
                        .keyboardType(.decimalPad)
                    DatePicker(LocalizedStringKey("Date d'acquisition"), selection: $dateAcquisition, displayedComponents: .date)
                }
                
                Section(LocalizedStringKey("Lieu de stockage")) {
                    Picker(LocalizedStringKey("Lieu"), selection: $lieuStockageId) {
                        Text(LocalizedStringKey("Aucun")).tag(nil as UUID?)
                        ForEach(dataManager.lieuxStockage) { lieu in
                            Text(lieu.batiment.isEmpty ? lieu.nom : "\(lieu.nom): \(lieu.batiment)").tag(lieu.id as UUID?)
                        }
                    }
                    
                    Button(action: {
                        if dataManager.peutAjouterLieu() {
                            showingAddLieuSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text(LocalizedStringKey("Créer un nouveau lieu"))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(LocalizedStringKey("Emplacement précis")) {
                    TextField(LocalizedStringKey("Localisation"), text: $localisation)
                    Text(LocalizedStringKey("Ex: Placard cuisine, Étagère du haut, Tiroir 3..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notesMateriel)
                        .frame(minHeight: 80)
                }
                
                // Section Facture d'achat
                Section(LocalizedStringKey("Facture d'achat")) {
                    TextField(LocalizedStringKey("Numéro de facture"), text: $numeroFacture)
                    TextField(LocalizedStringKey("Vendeur / Magasin"), text: $vendeur)
                    
                    VStack(spacing: 12) {
                        if let data = factureImageData {
                            if factureIsPDF {
                                // Affichage PDF
                                PDFThumbnailView(data: data)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            } else if let uiImage = UIImage(data: data) {
                                // Affichage Image
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            }
                            HStack {
                                if factureIsPDF {
                                    Label("PDF", systemImage: "doc.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                Spacer()
                                Button(role: .destructive) { 
                                    factureImageData = nil
                                    factureIsPDF = false
                                } label: {
                                    Label(LocalizedStringKey("Retirer la facture"), systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(height: 100)
                                VStack(spacing: 6) {
                                    Image(systemName: "doc.text.image")
                                        .font(.system(size: 28))
                                        .foregroundColor(.secondary)
                                    Text(LocalizedStringKey("Aucune facture"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        HStack(spacing: 8) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button(action: { showCameraFacturePicker = true }) {
                                    Label(LocalizedStringKey("Photo"), systemImage: "camera.fill")
                                }
                                .buttonStyle(.bordered)
                            }
                            Button(action: { showPhotoLibraryFacturePicker = true }) {
                                Label(LocalizedStringKey("Image"), systemImage: "photo")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: { showPDFPicker = true }) {
                                Label("PDF", systemImage: "doc.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Nouveau matériel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !storeManager.hasUnlockedPremium {
                        VStack(spacing: 2) {
                            Text(LocalizedStringKey("Nouveau matériel"))
                                .font(.headline)
                            Text("\(dataManager.totalMaterielsCreated)/\(StoreManager.freeMaterielLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Ajouter")) {
                        ajouterMateriel()
                    }
                    .disabled(nom.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            MaterielImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        imageData = image.jpegData(compressionQuality: 0.7)
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            MaterielImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        imageData = image.jpegData(compressionQuality: 0.7)
                    }
                }
            ), sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCameraFacturePicker) {
            MaterielImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        factureImageData = image.jpegData(compressionQuality: 0.7)
                        factureIsPDF = false
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showPhotoLibraryFacturePicker) {
            MaterielImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        factureImageData = image.jpegData(compressionQuality: 0.7)
                        factureIsPDF = false
                    }
                }
            ), sourceType: .photoLibrary)
        }
        .fileImporter(
            isPresented: $showPDFPicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            factureImageData = data
                            factureIsPDF = true
                        }
                    }
                }
            case .failure(let error):
                print("Erreur import PDF: \(error)")
            }
        }
        .sheet(isPresented: $showingAddLieuSheet) {
            AjouterLieuDepuisMaterielView { nouveauLieuId in
                lieuStockageId = nouveauLieuId
            }
        }
    }
    
    func ajouterMateriel() {
        // Normaliser la valeur : remplacer la virgule par un point pour la conversion
        let valeurNormalisee = valeur.replacingOccurrences(of: ",", with: ".")
        let materiel = Materiel(
            nom: nom,
            description: description,
            categorie: categorie,
            lieuStockageId: lieuStockageId,
            localisation: localisation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : localisation.trimmingCharacters(in: .whitespacesAndNewlines),
            notesMateriel: notesMateriel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notesMateriel.trimmingCharacters(in: .whitespacesAndNewlines),
            dateAcquisition: dateAcquisition,
            valeur: Double(valeurNormalisee) ?? 0.0,
            imageData: imageData,
            factureImageData: factureImageData,
            factureIsPDF: factureIsPDF ? true : nil,
            numeroFacture: numeroFacture.isEmpty ? nil : numeroFacture,
            vendeur: vendeur.isEmpty ? nil : vendeur
        )
        dataManager.ajouterMateriel(materiel)
        dismiss()
    }
}

struct EditMaterielView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    private let original: Materiel
    @State private var nom: String
    @State private var description: String
    @State private var categorie: String
    @State private var valeur: String
    @State private var dateAcquisition: Date
    @State private var lieuStockageId: UUID?
    @State private var localisation: String
    @State private var notesMateriel: String
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    // Champs facture
    @State private var factureImageData: Data? = nil
    @State private var factureIsPDF: Bool = false
    @State private var showCameraFacturePicker = false
    @State private var showPhotoLibraryFacturePicker = false
    @State private var showPDFPicker = false
    @State private var numeroFacture: String
    @State private var vendeur: String
    
    init(materiel: Materiel) {
        self.original = materiel
        _nom = State(initialValue: materiel.nom)
        _description = State(initialValue: materiel.description)
        _categorie = State(initialValue: materiel.categorie)
        _valeur = State(initialValue: String(format: "%.2f", materiel.valeur))
        _dateAcquisition = State(initialValue: materiel.dateAcquisition)
        _lieuStockageId = State(initialValue: materiel.lieuStockageId)
        _localisation = State(initialValue: materiel.localisation ?? "")
        _notesMateriel = State(initialValue: materiel.notesMateriel ?? "")
        _imageData = State(initialValue: materiel.imageData)
        _factureImageData = State(initialValue: materiel.factureImageData)
        _factureIsPDF = State(initialValue: materiel.factureIsPDF ?? false)
        _numeroFacture = State(initialValue: materiel.numeroFacture ?? "")
        _vendeur = State(initialValue: materiel.vendeur ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Photo") {
                    VStack(spacing: 12) {
                        if let data = imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            HStack {
                                Spacer()
                                Button(role: .destructive) { imageData = nil } label: {
                                    Label("Retirer la photo", systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(height: 140)
                                VStack(spacing: 6) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text("Aucune photo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        HStack(spacing: 12) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button(action: { showCameraPicker = true }) {
                                    Label("Prendre une photo", systemImage: "camera.fill")
                                }
                                .buttonStyle(.bordered)
                            }
                            Button(action: { showPhotoLibraryPicker = true }) {
                                Label(imageData == nil ? "Choisir une photo" : "Changer la photo", systemImage: "photo.fill.on.rectangle.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                Section("Informations générales") {
                    TextField("Nom", text: $nom)
                    TextField("Description", text: $description)
                    
                    // Menu déroulant pour la catégorie
                    Picker("Catégorie", selection: $categorie) {
                        Text("Aucune").tag("")
                        ForEach(dataManager.categoriesMateriels, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                        // Option pour nouvelle catégorie si la valeur actuelle n'existe pas
                        if !categorie.isEmpty && !dataManager.categoriesMateriels.contains(where: { $0.caseInsensitiveCompare(categorie) == .orderedSame }) {
                            Text(categorie).tag(categorie)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Champ pour créer une nouvelle catégorie
                    HStack {
                        TextField("Nouvelle catégorie", text: $categorie)
                        if !categorie.isEmpty {
                            Button {
                                categorie = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                
                Section("Détails") {
                    TextField("Valeur (€)", text: $valeur)
                        .keyboardType(.decimalPad)
                    DatePicker("Date d'acquisition", selection: $dateAcquisition, displayedComponents: .date)
                }
                
                Section("Lieu de stockage") {
                    Picker("Lieu", selection: $lieuStockageId) {
                        Text("Aucun").tag(nil as UUID?)
                        ForEach(dataManager.lieuxStockage) { lieu in
                            Text(lieu.batiment.isEmpty ? lieu.nom : "\(lieu.nom): \(lieu.batiment)").tag(lieu.id as UUID?)
                        }
                    }
                }
                
                Section("Emplacement précis") {
                    TextField("Localisation", text: $localisation)
                    Text("Ex: Placard cuisine, Étagère du haut, Tiroir 3...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Notes") {
                    TextEditor(text: $notesMateriel)
                        .frame(minHeight: 80)
                }
                
                // Section Facture d'achat
                Section("Facture d'achat") {
                    TextField("Numéro de facture", text: $numeroFacture)
                    TextField("Vendeur / Magasin", text: $vendeur)
                    
                    VStack(spacing: 12) {
                        if let data = factureImageData {
                            if factureIsPDF {
                                // Affichage PDF
                                PDFThumbnailView(data: data)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            } else if let uiImage = UIImage(data: data) {
                                // Affichage Image
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            }
                            HStack {
                                if factureIsPDF {
                                    Label("PDF", systemImage: "doc.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                Spacer()
                                Button(role: .destructive) { 
                                    factureImageData = nil
                                    factureIsPDF = false
                                } label: {
                                    Label("Retirer la facture", systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(height: 100)
                                VStack(spacing: 6) {
                                    Image(systemName: "doc.text.image")
                                        .font(.system(size: 28))
                                        .foregroundColor(.secondary)
                                    Text("Aucune facture")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        HStack(spacing: 8) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button(action: { showCameraFacturePicker = true }) {
                                    Label("Photo", systemImage: "camera.fill")
                                }
                                .buttonStyle(.bordered)
                            }
                            Button(action: { showPhotoLibraryFacturePicker = true }) {
                                Label("Image", systemImage: "photo")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: { showPDFPicker = true }) {
                                Label("PDF", systemImage: "doc.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Modifier le matériel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { enregistrer() }
                        .disabled(nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            MaterielImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        imageData = image.jpegData(compressionQuality: 0.7)
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            MaterielImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        imageData = image.jpegData(compressionQuality: 0.7)
                    }
                }
            ), sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCameraFacturePicker) {
            MaterielImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        factureImageData = image.jpegData(compressionQuality: 0.7)
                        factureIsPDF = false
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showPhotoLibraryFacturePicker) {
            MaterielImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        factureImageData = image.jpegData(compressionQuality: 0.7)
                        factureIsPDF = false
                    }
                }
            ), sourceType: .photoLibrary)
        }
        .fileImporter(
            isPresented: $showPDFPicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            factureImageData = data
                            factureIsPDF = true
                        }
                    }
                }
            case .failure(let error):
                print("Erreur import PDF: \(error)")
            }
        }
    }
    
    private func enregistrer() {
        let updated = Materiel(
            id: original.id,
            nom: nom,
            description: description,
            categorie: categorie,
            lieuStockageId: lieuStockageId,
            localisation: localisation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : localisation.trimmingCharacters(in: .whitespacesAndNewlines),
            notesMateriel: notesMateriel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notesMateriel.trimmingCharacters(in: .whitespacesAndNewlines),
            dateAcquisition: dateAcquisition,
            valeur: Double(valeur.replacingOccurrences(of: ",", with: ".")) ?? original.valeur,
            imageData: imageData,
            factureImageData: factureImageData,
            factureIsPDF: factureIsPDF ? true : nil,
            numeroFacture: numeroFacture.isEmpty ? nil : numeroFacture,
            vendeur: vendeur.isEmpty ? nil : vendeur
        )
        dataManager.modifierMateriel(updated)
        dismiss()
    }
}

struct MaterielDetailView: View {
    let materiel: Materiel
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditSheet = false
    @State private var showingPretSheet = false
    @State private var showingLocationSheet = false
    @State private var showingReparationSheet = false
    @State private var showingLimitAlert = false
    @State private var showingLocationLimitAlert = false
    @State private var showingReparationLimitAlert = false
    @State private var showPremiumSheet = false
    @State private var shareURL: IdentifiableURL?
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
    
    var prets: [Pret] {
        dataManager.getPretsPourMateriel(materiel.id)
    }
    
    // Toujours lire la version courante depuis le store
    var materielCourant: Materiel {
        dataManager.getMateriel(id: materiel.id) ?? materiel
    }
    
    var body: some View {
        List {
            // Boutons d'action rapide en haut
            if dataManager.materielEstDisponible(materielCourant.id) && !dataManager.materielEstEnLocation(materielCourant.id) {
                Section {
                    HStack(spacing: 12) {
                        Button(action: {
                            if dataManager.peutAjouterPret() {
                                showingPretSheet = true
                            } else {
                                showingLimitAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.forward.circle.fill")
                                Text(LocalizedStringKey("Prêter"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            if dataManager.peutAjouterLocation() {
                                showingLocationSheet = true
                            } else {
                                showingLocationLimitAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "eurosign.circle.fill")
                                Text(LocalizedStringKey("Louer"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            if dataManager.peutAjouterReparation() {
                                showingReparationSheet = true
                            } else {
                                showingReparationLimitAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                Text(LocalizedStringKey("Réparer"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            
            Section("Photo") {
                if let data = materielCourant.imageData, let uiImage = UIImage(data: data) {
                    HStack {
                        Spacer()
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        Spacer()
                    }
                } else {
                    Text("Aucune photo")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Informations") {
                LabeledContent("Nom", value: materielCourant.nom)
                LabeledContent("Description", value: materielCourant.description)
                LabeledContent("Catégorie", value: materielCourant.categorie)
                // Ajout: Lieu dans la section Informations (comme la catégorie)
                LabeledContent("Lieu", value: {
                    if let lieuId = materielCourant.lieuStockageId,
                       let lieu = dataManager.getLieu(id: lieuId) {
                        return lieu.nom
                    } else {
                        return localizedString("Aucun")
                    }
                }())
                // Localisation du lieu (bâtiment)
                if let lieuId = materielCourant.lieuStockageId,
                   let lieu = dataManager.getLieu(id: lieuId),
                   !lieu.batiment.isEmpty {
                    LabeledContent(localizedString("Localisation"), value: lieu.batiment)
                }
                // Emplacement spécifique du matériel
                if let localisation = materielCourant.localisation, !localisation.isEmpty {
                    LabeledContent(localizedString("Emplacement"), value: localisation)
                }
                LabeledContent("Valeur", value: String(format: "%.2f €", materielCourant.valeur))
                LabeledContent("Date d'acquisition", value: materielCourant.dateAcquisition.formatted(date: .long, time: .omitted))
            }
            
            // Notes spécifiques au matériel
            if let notes = materielCourant.notesMateriel, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            // Section Facture d'achat
            Section("Facture d'achat") {
                if let numeroFacture = materielCourant.numeroFacture, !numeroFacture.isEmpty {
                    LabeledContent("N° Facture", value: numeroFacture)
                }
                if let vendeur = materielCourant.vendeur, !vendeur.isEmpty {
                    LabeledContent("Vendeur", value: vendeur)
                }
                if let data = materielCourant.factureImageData {
                    VStack(alignment: .leading, spacing: 8) {
                        if materielCourant.factureIsPDF == true {
                            HStack {
                                Text("Facture PDF")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Label("PDF", systemImage: "doc.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            PDFThumbnailView(data: data)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        } else if let uiImage = UIImage(data: data) {
                            Text("Photo de la facture")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }
                } else if materielCourant.numeroFacture == nil && materielCourant.vendeur == nil {
                    Text("Aucune information de facture")
                        .foregroundColor(.secondary)
                }
            }
            
            // ========== SECTION: MON MATÉRIEL VERS LES AUTRES ==========
            // Header de section
            Section {
                HStack {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .foregroundColor(.blue)
                    Text(localizedString("Mon matériel vers les autres"))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(Color.blue.opacity(0.1))
            
            Section(localizedString("Historique des prêts")) {
                if prets.isEmpty {
                    Text(LocalizedStringKey("Aucun prêt enregistré"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(prets.sorted(by: { $0.dateDebut > $1.dateDebut })) { pret in
                        NavigationLink(destination: PretDetailView(pret: pret)) {
                            VStack(alignment: .leading, spacing: 4) {
                                if let personne = dataManager.getPersonne(id: pret.personneId) {
                                    HStack(spacing: 4) {
                                        Text(personne.nomComplet)
                                            .font(.headline)
                                        // Afficher le chantier si salarié avec un chantier assigné
                                        if personne.typePersonne == .salarie,
                                           let chantierId = personne.chantierId,
                                           let chantier = dataManager.getChantier(id: chantierId) {
                                            Text("(\(chantier.nom))")
                                                .font(.subheadline)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                                HStack {
                                    Text("\(localizedString("Du")) \(formatDate(pret.dateDebut))")
                                    Text("\(localizedString("au")) \(formatDate(pret.dateFin))")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                if pret.estRetourne {
                                    Text("✓ \(localizedString("Retourné"))")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else if pret.estEnRetard {
                                    Text("⚠️ \(localizedString("En retard"))")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else {
                                    Text(localizedString("En cours"))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            
            // Historique des locations (je loue mon matériel à quelqu'un)
            Section(localizedString("Historique des locations")) {
                let locs = dataManager.getLocationsPourMateriel(materielCourant.id)
                if locs.isEmpty {
                    Text(LocalizedStringKey("Aucune location enregistrée"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(locs.sorted(by: { $0.dateDebut > $1.dateDebut })) { location in
                        NavigationLink(destination: LocationDetailView(location: location)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if let personne = dataManager.getPersonne(id: location.locataireId) {
                                        Text(personne.nomComplet)
                                            .font(.headline)
                                    }
                                    Spacer()
                                    Text(String(format: "%.2f €", location.prixTotalReel))
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                HStack {
                                    Text("\(localizedString("Du")) \(formatDate(location.dateDebut))")
                                    Text("\(localizedString("au")) \(formatDate(location.dateFin))")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                HStack {
                                    if location.estTerminee {
                                        Text("✓ \(localizedString("Terminée"))")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else if location.estEnRetard {
                                        Text("⚠️ \(localizedString("En retard"))")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else {
                                        Text(localizedString("En cours"))
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Spacer()
                                    
                                    if location.paiementRecu {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    } else {
                                        Text(localizedString("Non payé"))
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            
            // Historique des réparations
            Section(localizedString("Historique des réparations")) {
                let reparations = dataManager.getReparationsPourMateriel(materielCourant.id)
                if reparations.isEmpty {
                    Text(LocalizedStringKey("Aucune réparation enregistrée"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(reparations.sorted(by: { $0.dateDebut > $1.dateDebut })) { reparation in
                        NavigationLink(destination: ReparationDetailView(reparation: reparation)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if let reparateur = dataManager.getPersonne(id: reparation.reparateurId) {
                                        Text(reparateur.nomComplet)
                                            .font(.headline)
                                    }
                                    Spacer()
                                    if let cout = reparation.coutFinal ?? reparation.coutEstime, cout > 0 {
                                        Text(String(format: "%.2f €", cout))
                                            .font(.subheadline)
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                if !reparation.description.isEmpty {
                                    Text(reparation.description)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                }
                                
                                HStack {
                                    Text("\(localizedString("Début:")) \(formatDate(reparation.dateDebut))")
                                    if let dateFin = reparation.dateFinPrevue {
                                        Text("• \(localizedString("Fin prévue:")) \(formatDate(dateFin))")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                HStack {
                                    if reparation.estTerminee {
                                        Text("✓ \(localizedString("Terminée"))")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else if reparation.estEnRetard {
                                        Text("⚠️ \(localizedString("En retard"))")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else {
                                        Text(localizedString("En cours"))
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Spacer()
                                    
                                    if reparation.paiementRecu {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    } else if (reparation.coutEstime ?? 0) > 0 || (reparation.coutFinal ?? 0) > 0 {
                                        Text(localizedString("Non payé"))
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            
            // ========== SECTION: CE QUE JE LOUE / EMPRUNTE ==========
            // Header de section
            Section {
                HStack {
                    Image(systemName: "arrow.down.backward.circle.fill")
                        .foregroundColor(.purple)
                    Text(localizedString("Ce que je loue / emprunte"))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(Color.purple.opacity(0.1))
            
            // Historique des locations depuis des ALM (Agences Location Matériel) - "Je loue"
            Section(localizedString("Loué depuis une Agence")) {
                // Chercher les MaLocation où le materielLieId correspond au matériel courant
                // et où le loueur est de type ALM
                let mesLocsALM = dataManager.mesLocations.filter { maLocation in
                    // Vérifier que le matériel lié correspond
                    guard maLocation.materielLieId == materielCourant.id else { return false }
                    // Vérifier que le loueur est de type ALM
                    if let loueur = dataManager.getPersonne(id: maLocation.loueurId) {
                        return loueur.typePersonne == .alm
                    }
                    return false
                }
                if mesLocsALM.isEmpty {
                    Text(LocalizedStringKey("Aucune location depuis une agence"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(mesLocsALM.sorted(by: { $0.dateDebut > $1.dateDebut })) { maLocation in
                        NavigationLink(destination: MaLocationDetailView(maLocation: maLocation)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if let loueur = dataManager.getPersonne(id: maLocation.loueurId) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "building.2.fill")
                                                .foregroundColor(.purple)
                                                .font(.caption)
                                            Text(loueur.nomComplet)
                                                .font(.headline)
                                        }
                                    }
                                    Spacer()
                                    Text(String(format: "%.2f €", maLocation.prixTotal))
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                                HStack {
                                    Text("\(localizedString("Du")) \(formatDate(maLocation.dateDebut))")
                                    Text("\(localizedString("au")) \(formatDate(maLocation.dateFin))")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                HStack {
                                    if maLocation.estTerminee {
                                        Text("✓ \(localizedString("Terminée"))")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else if maLocation.estEnRetard {
                                        Text("⚠️ \(localizedString("En retard"))")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else {
                                        Text(localizedString("En cours"))
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Spacer()
                                    
                                    if maLocation.paiementEffectue {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    } else {
                                        Text(localizedString("Non payé"))
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            
            // Historique des emprunts liés à ce matériel
            Section(localizedString("Historique des emprunts")) {
                // Chercher les Emprunt où le materielLieId correspond au matériel courant
                let empruntsLies = dataManager.emprunts.filter { emprunt in
                    // Vérifier que le matériel lié correspond
                    return emprunt.materielLieId == materielCourant.id
                }
                if empruntsLies.isEmpty {
                    Text(LocalizedStringKey("Aucun emprunt enregistré"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(empruntsLies.sorted(by: { $0.dateDebut > $1.dateDebut })) { emprunt in
                        NavigationLink(destination: EmpruntDetailView(emprunt: emprunt)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if let preteur = dataManager.getPersonne(id: emprunt.personneId) {
                                        HStack(spacing: 6) {
                                            // Icône selon le type de personne
                                            Image(systemName: preteur.typePersonne?.icon ?? "person.fill")
                                                .foregroundColor(couleurPourTypePersonne(preteur.typePersonne))
                                                .font(.caption)
                                            Text(preteur.nomComplet)
                                                .font(.headline)
                                        }
                                    }
                                    Spacer()
                                    Text(emprunt.nomObjet)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("\(localizedString("Du")) \(formatDate(emprunt.dateDebut))")
                                    Text("\(localizedString("au")) \(formatDate(emprunt.dateFin))")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                HStack {
                                    if emprunt.estRetourne {
                                        Text("✓ \(localizedString("Retourné"))")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else if emprunt.estEnRetard {
                                        Text("⚠️ \(localizedString("En retard"))")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else {
                                        Text(localizedString("En cours"))
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Détails"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label(LocalizedStringKey("Modifier"), systemImage: "pencil")
                    }
                    Button(action: exporterFiche) {
                        Label("Exporter la fiche", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMaterielView(materiel: materielCourant)
        }
        .sheet(isPresented: $showingPretSheet) {
            AjouterPretPourMaterielView(materiel: materielCourant)
        }
        .sheet(isPresented: $showingLocationSheet) {
            LouerMaterielView(materiel: materielCourant)
        }
        .sheet(isPresented: $showingReparationSheet) {
            AjouterReparationView(materielPreselectionne: materielCourant)
        }
        .sheet(item: $shareURL) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
            Button(LocalizedStringKey("Passer à Premium")) {
                showPremiumSheet = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Limite prêts atteinte"))
        }
        .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLocationLimitAlert) {
            Button(LocalizedStringKey("Passer à Premium")) {
                showPremiumSheet = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Vous avez atteint la limite de locations gratuites. Passez à Premium pour créer des locations illimitées."))
        }
        .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingReparationLimitAlert) {
            Button(LocalizedStringKey("Passer à Premium")) {
                showPremiumSheet = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Vous avez atteint la limite de réparations gratuites. Passez à Premium pour créer des réparations illimitées."))
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumView()
        }
    }
    
    private func exporterFiche() {
        if let url = dataManager.exporterMaterielEnFiche(materielCourant) {
            shareURL = IdentifiableURL(url: url)
        }
    }
}

// MARK: - Image Picker pour Matériel (Caméra)
struct MaterielImagePicker: UIViewControllerRepresentable {
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
        let parent: MaterielImagePicker
        init(_ parent: MaterielImagePicker) { self.parent = parent }
        
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

// MARK: - Ajouter un prêt pour un matériel spécifique
struct AjouterPretPourMaterielView: View {
    let materiel: Materiel
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    @State private var personneId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingAddPerson = false
    @State private var showingPersonneSelection = false

    var peutCreer: Bool { personneId != nil }
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = personneId else { return nil }
        return dataManager.getPersonne(id: id)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Matériel")) {
                    HStack {
                        if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "shippingbox.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 50, height: 50)
                        }
                        VStack(alignment: .leading) {
                            Text(materiel.nom)
                                .font(.headline)
                            Text(materiel.categorie)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Section(LocalizedStringKey("Emprunteur")) {
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
            .navigationTitle(LocalizedStringKey("Nouveau prêt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("Annuler")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(LocalizedStringKey("Créer")) { creerPret() }.disabled(!peutCreer) }
            }
            .alert(LocalizedStringKey("Erreur"), isPresented: $showingAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) {}
            } message: { Text(alertMessage) }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView()
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $personneId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir l'emprunteur"),
                    showAddButton: true,
                    onAddPerson: { showingAddPerson = true }
                )
            }
        }
        .onChange(of: dataManager.personnes.count) { oldValue, newValue in
            if newValue > oldValue { personneId = dataManager.personnes.last?.id }
        }
    }

    private func creerPret() {
        guard let personneId else {
            alertMessage = NSLocalizedString("Veuillez remplir tous les champs obligatoires", comment: "")
            showingAlert = true
            return
        }
        if dateFin < dateDebut {
            alertMessage = NSLocalizedString("La date de fin doit être après la date de début", comment: "")
            showingAlert = true
            return
        }
        let lieuOrigine = materiel.lieuStockageId
        let pret = Pret(materielId: materiel.id, personneId: personneId, lieuId: lieuOrigine, dateDebut: dateDebut, dateFin: dateFin, dateRetourEffectif: nil, notes: notes)
        dataManager.ajouterPret(pret)
        dismiss()
    }
}

// MARK: - PDF Thumbnail View
struct PDFThumbnailView: View {
    let data: Data
    @State private var thumbnail: UIImage?
    @State private var showFullPDF = false
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        showFullPDF = true
                    }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                    VStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("PDF")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .onTapGesture {
                    showFullPDF = true
                }
            }
        }
        .onAppear {
            generateThumbnail()
        }
        .fullScreenCover(isPresented: $showFullPDF) {
            PDFViewerView(data: data)
        }
    }
    
    private func generateThumbnail() {
        guard let document = PDFDocument(data: data),
              let page = document.page(at: 0) else { return }
        
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let thumbnailSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
    }
}

// MARK: - PDF Full Viewer
struct PDFViewerView: View {
    let data: Data
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            PDFKitView(data: data)
                .navigationTitle("Facture PDF")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: PDFDataWrapper(data: data), preview: SharePreview("Facture.pdf", image: Image(systemName: "doc.fill")))
                    }
                }
        }
    }
}

// MARK: - PDFKit SwiftUI Wrapper
struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

// MARK: - PDF Data Wrapper for ShareLink
struct PDFDataWrapper: Transferable {
    let data: Data
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { wrapper in
            wrapper.data
        }
    }
}

// MARK: - Gestion des Catégories Sheet
struct GestionCategoriesSheet: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    @Binding var categorieToDelete: String?
    @Binding var showingDeleteAlert: Bool
    @Binding var categorieToRename: String?
    @Binding var nouveauNom: String
    @Binding var showingRenameAlert: Bool
    
    private func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "fr", ofType: "lproj")
        let bundle = path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    var body: some View {
        NavigationView {
            List {
                if dataManager.categoriesMateriels.isEmpty {
                    Section {
                        Text(LocalizedStringKey("Aucune catégorie"))
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    Section(header: Text(LocalizedStringKey("Catégories"))) {
                        ForEach(dataManager.categoriesMateriels, id: \.self) { categorie in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(categorie)
                                        .font(.headline)
                                    let count = dataManager.materiels.filter { $0.categorie.caseInsensitiveCompare(categorie) == .orderedSame }.count
                                    Text("\(count) \(count == 1 ? localizedString("matériel") : localizedString("matériels"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // La catégorie "Emprunt" est gérée automatiquement, on ne peut pas la modifier
                                if categorie.caseInsensitiveCompare("Emprunt") != .orderedSame {
                                    // Bouton renommer
                                    Button {
                                        categorieToRename = categorie
                                        nouveauNom = categorie
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showingRenameAlert = true
                                        }
                                    } label: {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.trailing, 20)
                                    
                                    // Bouton supprimer
                                    Button {
                                        categorieToDelete = categorie
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showingDeleteAlert = true
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                } else {
                                    // Afficher une indication que c'est automatique
                                    Text(LocalizedStringKey("Auto"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        }
                    }
                    
                    Section(footer: Text(LocalizedStringKey("Supprimer une catégorie retirera la catégorie des matériels concernés sans supprimer les matériels."))) {
                        EmptyView()
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Gérer les catégories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Fermer")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
