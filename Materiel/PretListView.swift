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

struct PretListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSheet = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    @State private var searchText = ""
    @State private var filtreStatut = "Tous"
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?

    private let statutOptions = ["Tous", "En cours", "En retard", "Retournés"]

    var pretsFiltres: [Pret] {
        var prets = dataManager.prets
        switch filtreStatut {
        case "En cours": prets = prets.filter { $0.estActif && !$0.estEnRetard }
        case "En retard": prets = prets.filter { $0.estEnRetard }
        case "Retournés": prets = prets.filter { $0.estRetourne }
        default: break
        }
        if !searchText.isEmpty {
            prets = prets.filter { pret in
                if let materiel = dataManager.getMateriel(id: pret.materielId), materiel.nom.localizedCaseInsensitiveContains(searchText) { return true }
                if let personne = dataManager.getPersonne(id: pret.personneId), personne.nomComplet.localizedCaseInsensitiveContains(searchText) { return true }
                return false
            }
        }
        return prets.sorted { $0.dateDebut > $1.dateDebut }
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
                    Picker(LocalizedStringKey("Statut"), selection: $filtreStatut) {
                        ForEach(statutOptions, id: \.self) { statut in
                            Text(LocalizedStringKey(statut))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                Button {
                    if dataManager.peutAjouterPret() {
                        showingAddSheet = true
                    } else {
                        showingLimitAlert = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text(LocalizedStringKey("Ajouter un prêt"))
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
                .padding(.horizontal, 16)
                .padding(.top, 8)

                List {
                    ForEach(pretsFiltres) { pret in
                        PretRowView(pret: pret)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        indexSetToDelete = offsets
                        showingDeleteAlert = true
                    }
                }
                .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher un prêt"))
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            }
            .navigationTitle(LocalizedStringKey("Prêts"))
            .toolbar { }
            .sheet(isPresented: $showingAddSheet) { AjouterPretView() }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumSheet = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Limite prêts atteinte"))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        for index in offsets {
                            let pret = pretsFiltres[index]
                            dataManager.supprimerPret(pret)
                        }
                    }
                    indexSetToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    indexSetToDelete = nil
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer ce prêt ? Cette action est irréversible."))
            }
        }
    }
}

struct PretRowView: View {
    let pret: Pret
    @EnvironmentObject var dataManager: DataManager
    @State private var showingConfirmation = false
    @State private var showingReaffectation = false
    @State private var showingReparationSheet = false
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
    
    // Vérifie si le prêt est orphelin (personne n'existe plus)
    private var estOrphelin: Bool {
        dataManager.getPersonne(id: pret.personneId) == nil
    }

    var body: some View {
        // Pré-calcul pour alléger l'inférence du compilateur
        let debutFormat = formatDate(pret.dateDebut)
        let finFormat = formatDate(pret.dateFin)
        let dateRetourFormat = pret.dateRetourEffectif != nil ? formatDate(pret.dateRetourEffectif!) : nil
        let joursRetard = Calendar.current.dateComponents([.day], from: pret.dateFin, to: Date()).day ?? 0
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                if let materiel = dataManager.getMateriel(id: pret.materielId) {
                    if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    } else {
                        Image(systemName: "cube.box")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                            .frame(width: 56, height: 56)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(materiel.nom).font(.headline)
                            Spacer()
                            if pret.estRetourne {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            } else if pret.estEnRetard {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            } else {
                                Image(systemName: "clock.fill").foregroundColor(.orange)
                            }
                        }
                    }
                } else {
                    // Matériel non trouvé - afficher un placeholder
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
                            if pret.estRetourne {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            } else if pret.estEnRetard {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            } else {
                                Image(systemName: "clock.fill").foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            if let personne = dataManager.getPersonne(id: pret.personneId) {
                Label(personne.nomComplet, systemImage: "person")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            } else {
                // Prêt orphelin - afficher alerte et bouton pour affecter
                Button(action: { showingReaffectation = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(LocalizedStringKey("Aucune personne - Affecter"))
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(localizedString("Début:")) \(debutFormat)").font(.caption)
                    Text("\(localizedString("Fin:")) \(finFormat)").font(.caption)
                }.foregroundColor(.secondary)
                Spacer()
                if pret.estRetourne, let dateRetourFormat {
                    Text("\(localizedString("Retourné le")) \(dateRetourFormat)").font(.caption).foregroundColor(.green)
                } else if pret.estEnRetard {
                    Text("\(joursRetard) \(localizedString("jour(s) de retard"))").font(.caption).foregroundColor(.red)
                }
            }
            if !pret.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text").foregroundColor(.secondary)
                    Text(pret.notes).font(.callout).foregroundColor(.primary).lineLimit(3)
                }.padding(.top, 2)
            }
            if !pret.estRetourne {
                Button { showingConfirmation = true } label: {
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
            } else {
                Button(role: .destructive) { dataManager.supprimerPret(pret) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text(LocalizedStringKey("Effacer ce prêt"))
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
        .confirmationDialog(LocalizedStringKey("Confirmer le retour"), isPresented: $showingConfirmation) {
            Button(LocalizedStringKey("Valider le retour")) { dataManager.validerRetour(pret.id) }
            Button(LocalizedStringKey("Envoyer en réparation")) { showingReparationSheet = true }
            Button(LocalizedStringKey("Annuler"), role: .cancel) {}
        } message: { Text(LocalizedStringKey("Que souhaitez-vous faire avec ce matériel ?")) }
        .sheet(isPresented: $showingReaffectation) {
            SelectionPersonnePretView(pretId: pret.id)
        }
        .sheet(isPresented: $showingReparationSheet) {
            EnvoyerEnReparationView(pret: pret)
        }
    }
}

// Vue pour envoyer un matériel en réparation depuis un prêt
struct EnvoyerEnReparationView: View {
    let pret: Pret
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
                // Info sur le matériel concerné
                Section(LocalizedStringKey("Matériel concerné")) {
                    if let materiel = dataManager.getMateriel(id: pret.materielId) {
                        HStack {
                            if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                Image(systemName: "cube.box")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, height: 50)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            VStack(alignment: .leading) {
                                Text(materiel.nom)
                                    .font(.headline)
                                if !materiel.categorie.isEmpty {
                                    Text(materiel.categorie)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        Text(LocalizedStringKey("Matériel inconnu"))
                            .foregroundColor(.orange)
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
                AjouterReparateurRapideView()
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
        
        dataManager.envoyerEnReparation(
            pretId: pret.id,
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

// Vue rapide pour ajouter un réparateur depuis le prêt
struct AjouterReparateurRapideView: View {
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
            .scrollDismissesKeyboard(.interactively)
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

// Vue de sélection de personne pour réaffecter un prêt
struct SelectionPersonnePretView: View {
    let pretId: UUID
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var personnesFiltrees: [Personne] {
        if searchText.isEmpty {
            return dataManager.personnes
        }
        return dataManager.personnes.filter { personne in
            personne.nom.localizedCaseInsensitiveContains(searchText) ||
            personne.prenom.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if dataManager.personnes.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "person.slash")
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Aucune personne enregistrée"))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    ForEach(personnesFiltrees) { personne in
                        Button(action: {
                            if let pret = dataManager.prets.first(where: { $0.id == pretId }) {
                                dataManager.reaffecterPret(pret, nouvellePersonneId: personne.id)
                            }
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(personne.nomComplet)
                                        .font(.headline)
                                    if !personne.organisation.isEmpty {
                                        Text(personne.organisation)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher une personne"))
            .navigationTitle(LocalizedStringKey("Affecter une personne"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
            }
        }
    }
}

struct AjouterPretView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var materielId: UUID?
    @State private var personneId: UUID?
    @State private var dateDebut = Date()
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingAddPerson = false
    @State private var showingMaterielSelection = false
    @State private var showingPersonneSelection = false

    var materielsDisponibles: [Materiel] { dataManager.materiels.filter { dataManager.materielEstDisponible($0.id) } }
    var peutCreer: Bool { materielId != nil && personneId != nil }
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = personneId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    // Matériel sélectionné pour affichage
    var materielSelectionne: Materiel? {
        guard let id = materielId else { return nil }
        return dataManager.getMateriel(id: id)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Matériel")) {
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
                        Text(LocalizedStringKey("Aucun matériel disponible")).foregroundColor(.secondary).font(.caption)
                    }
                }
                Section(LocalizedStringKey("Emprunteur")) {
                    Button {
                        hideKeyboard()
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
                                    
                                    // Afficher le chantier pour les salariés
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
                ToolbarItem(placement: .principal) {
                    if !storeManager.hasUnlockedPremium {
                        VStack(spacing: 2) {
                            Text(LocalizedStringKey("Nouveau prêt"))
                                .font(.headline)
                            Text("\(dataManager.totalPretsCreated)/\(StoreManager.freePretLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("Annuler")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(LocalizedStringKey("Créer")) { creerPret() }.disabled(!peutCreer) }
            }
            .alert(LocalizedStringKey("Erreur"), isPresented: $showingAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) {}
            } message: { Text(alertMessage) }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView()
            }
            .sheet(isPresented: $showingMaterielSelection) {
                MaterielSelectionView(
                    selectedMaterielId: $materielId,
                    materiels: materielsDisponibles,
                    title: LocalizedStringKey("Choisir le matériel")
                )
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
        guard let materielId, let personneId else {
            alertMessage = NSLocalizedString("Veuillez remplir tous les champs obligatoires", comment: "")
            showingAlert = true
            return
        }
        if dateFin < dateDebut {
            alertMessage = NSLocalizedString("La date de fin doit être après la date de début", comment: "")
            showingAlert = true
            return
        }
        let lieuOrigine = dataManager.getMateriel(id: materielId)?.lieuStockageId
        let pret = Pret(materielId: materielId, personneId: personneId, lieuId: lieuOrigine, dateDebut: dateDebut, dateFin: dateFin, dateRetourEffectif: nil, notes: notes)
        dataManager.ajouterPret(pret)
        dismiss()
    }
}

// MARK: - Pret Detail View
/// Vue de détail pour un prêt, accessible depuis la fiche personne
struct PretDetailView: View {
    let pret: Pret
    @EnvironmentObject var dataManager: DataManager
    @State private var showingConfirmation = false
    @State private var showingReaffectation = false
    @State private var showingReparationSheet = false
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
    private var pretCourant: Pret {
        dataManager.prets.first { $0.id == pret.id } ?? pret
    }
    
    private var joursRetard: Int {
        Calendar.current.dateComponents([.day], from: pretCourant.dateFin, to: Date()).day ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Carte principale avec infos
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        if let materiel = dataManager.getMateriel(id: pretCourant.materielId) {
                            if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipped()
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3)))
                            } else {
                                Image(systemName: "cube.box")
                                    .font(.system(size: 35))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, height: 70)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(materiel.nom)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if pretCourant.estRetourne {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    } else if pretCourant.estEnRetard {
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
                    
                    if let personne = dataManager.getPersonne(id: pretCourant.personneId) {
                        Label(personne.nomComplet, systemImage: "person")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    } else {
                        // Prêt orphelin - permettre l'affectation
                        Button(action: { showingReaffectation = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(LocalizedStringKey("Aucune personne - Affecter"))
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                Spacer()
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Dates
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(localizedString("Début:")) \(formatDate(pretCourant.dateDebut))").font(.caption)
                            Text("\(localizedString("Fin:")) \(formatDate(pretCourant.dateFin))").font(.caption)
                        }.foregroundColor(.secondary)
                        Spacer()
                        if pretCourant.estRetourne, let dateRetour = pretCourant.dateRetourEffectif {
                            Text("\(localizedString("Retourné le")) \(formatDate(dateRetour))")
                                .font(.caption).foregroundColor(.green)
                        } else if pretCourant.estEnRetard {
                            Text("\(joursRetard) \(localizedString("jour(s) de retard"))")
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    // Notes
                    if !pretCourant.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "note.text").foregroundColor(.secondary)
                            Text(pretCourant.notes).font(.callout).foregroundColor(.primary)
                        }.padding(.top, 2)
                    }
                    
                    // Bouton d'action
                    if !pretCourant.estRetourne {
                        Button { showingConfirmation = true } label: {
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
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(LocalizedStringKey("Détail du prêt"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(LocalizedStringKey("Valider le retour ?"), isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button(LocalizedStringKey("Confirmer le retour")) {
                dataManager.validerRetour(pretCourant.id)
            }
            Button(LocalizedStringKey("Envoyer en réparation")) {
                showingReparationSheet = true
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Que souhaitez-vous faire avec ce matériel ?"))
        }
        .sheet(isPresented: $showingReaffectation) {
            ReaffecterPretView(pret: pretCourant)
        }
        .sheet(isPresented: $showingReparationSheet) {
            EnvoyerEnReparationView(pret: pretCourant)
        }
    }
}

// MARK: - Réaffecter un prêt orphelin
struct ReaffecterPretView: View {
    let pret: Pret
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var personneId: UUID?
    @State private var showingAddPerson = false
    @State private var showingPersonneSelection = false
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = personneId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Sélectionner une personne")) {
                    Button {
                        hideKeyboard()
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
                                    
                                    // Afficher le chantier pour les salariés
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
            }
            .navigationTitle(LocalizedStringKey("Affecter le prêt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Affecter")) {
                        if let personneId = personneId {
                            var updatedPret = pret
                            updatedPret.personneId = personneId
                            dataManager.modifierPret(updatedPret)
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
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $personneId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir la personne"),
                    showAddButton: true,
                    onAddPerson: { showingAddPerson = true }
                )
            }
        }
    }
}

// MARK: - Vue de sélection de matériel avec photos
struct MaterielSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @Binding var selectedMaterielId: UUID?
    let materiels: [Materiel]
    let title: LocalizedStringKey
    
    @State private var searchText = ""
    
    var materielsFiltres: [Materiel] {
        if searchText.isEmpty {
            return materiels
        }
        return materiels.filter { materiel in
            materiel.nom.localizedCaseInsensitiveContains(searchText) ||
            materiel.description.localizedCaseInsensitiveContains(searchText) ||
            materiel.categorie.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if materielsFiltres.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(LocalizedStringKey("Aucun matériel disponible"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(materielsFiltres) { materiel in
                        Button {
                            selectedMaterielId = materiel.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                // Photo du matériel
                                if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                        )
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.15))
                                        Image(systemName: "photo")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 60, height: 60)
                                }
                                
                                // Informations du matériel
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(materiel.nom)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if !materiel.description.isEmpty {
                                        Text(materiel.description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        if !materiel.categorie.isEmpty {
                                            Text(materiel.categorie)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        
                                        Text(String(format: "%.2f €", materiel.valeur))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Indicateur de sélection
                                if selectedMaterielId == materiel.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher du matériel"))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PersonneSelectionView
struct PersonneSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPersonneId: UUID?
    let personnes: [Personne]
    let title: LocalizedStringKey
    var showAddButton: Bool = true
    var onAddPerson: (() -> Void)? = nil
    
    @State private var searchText = ""
    
    var personnesFiltrees: [Personne] {
        if searchText.isEmpty {
            return personnes
        }
        return personnes.filter { personne in
            personne.nomComplet.localizedCaseInsensitiveContains(searchText) ||
            personne.organisation.localizedCaseInsensitiveContains(searchText) ||
            personne.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if showAddButton {
                    Button {
                        dismiss()
                        onAddPerson?()
                    } label: {
                        Label(LocalizedStringKey("Ajouter une personne"), systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .listRowBackground(Color.clear)
                }
                
                if personnesFiltrees.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(LocalizedStringKey("Aucune personne disponible"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(personnesFiltrees) { personne in
                        Button {
                            selectedPersonneId = personne.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                // Photo ou cercle coloré selon le type
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
                                                .font(.system(size: 18, weight: .medium))
                                        )
                                }
                                
                                // Informations de la personne
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(personne.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    // Afficher le chantier pour les salariés
                                    if let chantierId = personne.chantierId,
                                       let chantier = dataManager.getChantier(id: chantierId) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "building.2")
                                                .font(.caption2)
                                            Text(chantier.nom)
                                                .lineLimit(1)
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                    } else if !personne.organisation.isEmpty {
                                        Text(personne.organisation)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    if let type = personne.typePersonne {
                                        Text(LocalizedStringKey(type.rawValue))
                                            .font(.caption)
                                            .foregroundColor(couleurPourTypePersonne(type))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(couleurPourTypePersonne(type).opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Spacer()
                                
                                // Indicateur de sélection
                                if selectedPersonneId == personne.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher une personne"))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
