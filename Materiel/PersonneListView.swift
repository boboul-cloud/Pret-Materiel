//  PersonneListView.swift
//  Materiel
//
//  Created by Robert Oulhen on 10/11/2025.
//

import SwiftUI
import ContactsUI
import UniformTypeIdentifiers
#if canImport(MessageUI)
import MessageUI
#endif

// Helper pour la couleur selon le type de personne
private func couleurPourTypePersonne(_ type: TypePersonne?) -> Color {
    switch type {
    case .mecanicien: return .orange
    case .salarie: return .green
    case .alm: return .purple
    case .client: return .blue
    case nil: return .gray
    }
}

// Helper global pour la localisation
fileprivate func localizedString(_ key: String, language: String) -> String {
    guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return NSLocalizedString(key, comment: "")
    }
    return NSLocalizedString(key, bundle: bundle, comment: "")
}

// Helper pour formater les dates selon la langue
fileprivate func formatDate(_ date: Date, language: String, style: DateFormatter.Style = .medium) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = style
    formatter.timeStyle = .none
    formatter.locale = Locale(identifier: language)
    return formatter.string(from: date)
}

struct PersonneListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    @State private var filtreType = "Tous"
    
    private let typeOptions = ["Tous", "Clients", "Mécaniciens", "Salariés", "ALM"]
    
    var personnesFiltrees: [Personne] {
        var liste = dataManager.personnes
        
        // Filtrer par type
        switch filtreType {
        case "Clients":
            liste = liste.filter { $0.typePersonne == .client || $0.typePersonne == nil }
        case "Mécaniciens":
            liste = liste.filter { $0.typePersonne == .mecanicien }
        case "Salariés":
            liste = liste.filter { $0.typePersonne == .salarie }
        case "ALM":
            liste = liste.filter { $0.typePersonne == .alm }
        default:
            break
        }
        
        // Filtrer par recherche
        if !searchText.isEmpty {
            liste = liste.filter { personne in
                personne.nom.localizedCaseInsensitiveContains(searchText) ||
                personne.prenom.localizedCaseInsensitiveContains(searchText) ||
                personne.email.localizedCaseInsensitiveContains(searchText) ||
                personne.organisation.localizedCaseInsensitiveContains(searchText)
            }
        }
        return liste
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
                
                VStack(spacing: 0) {
                    // Bouton Ajouter (en dehors de la List)
                    Button(action: { showingAddSheet = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text(LocalizedStringKey("Ajouter une personne"))
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
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    
                    List {
                        // Filtre type de personne
                        Picker(LocalizedStringKey("Type de personne"), selection: $filtreType) {
                            Text(LocalizedStringKey("Tous")).tag("Tous")
                            Text(LocalizedStringKey("Clients")).tag("Clients")
                            Text(LocalizedStringKey("Mécaniciens")).tag("Mécaniciens")
                            Text(LocalizedStringKey("Salariés")).tag("Salariés")
                            Text(LocalizedStringKey("ALM")).tag("ALM")
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    
                        ForEach(personnesFiltrees) { personne in
                            NavigationLink(destination: PersonneDetailView(personne: personne)) {
                                PersonneRowView(personne: personne)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            indexSetToDelete = offsets
                            showingDeleteAlert = true
                        }
                    }
                    .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher une personne"))
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .navigationTitle(LocalizedStringKey("Personnes"))
            .toolbar {
                // Menu filtre par type de personne dans la toolbar
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { filtreType = "Tous" }) {
                            Label {
                                Text(LocalizedStringKey("Tous"))
                            } icon: {
                                Image(systemName: filtreType == "Tous" ? "checkmark.circle.fill" : "person.3.fill")
                            }
                        }
                        Button(action: { filtreType = "Clients" }) {
                            Label {
                                Text(LocalizedStringKey("Clients"))
                            } icon: {
                                Image(systemName: filtreType == "Clients" ? "checkmark.circle.fill" : "person.fill")
                            }
                        }
                        Button(action: { filtreType = "Mécaniciens" }) {
                            Label {
                                Text(LocalizedStringKey("Mécaniciens"))
                            } icon: {
                                Image(systemName: filtreType == "Mécaniciens" ? "checkmark.circle.fill" : "wrench.and.screwdriver.fill")
                            }
                        }
                        Button(action: { filtreType = "Salariés" }) {
                            Label {
                                Text(LocalizedStringKey("Salariés"))
                            } icon: {
                                Image(systemName: filtreType == "Salariés" ? "checkmark.circle.fill" : "person.badge.clock.fill")
                            }
                        }
                        Button(action: { filtreType = "ALM" }) {
                            Label {
                                Text(LocalizedStringKey("ALM"))
                            } icon: {
                                Image(systemName: filtreType == "ALM" ? "checkmark.circle.fill" : "building.2.fill")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            Text(LocalizedStringKey(filtreType))
                                .font(.subheadline)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AjouterPersonneView()
            }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        for index in offsets {
                            let personne = personnesFiltrees[index]
                            dataManager.supprimerPersonne(personne)
                        }
                    }
                    indexSetToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    indexSetToDelete = nil
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer cette personne ? Cette action est irréversible."))
            }
        }
    }
}

struct PersonneRowView: View {
    let personne: Personne
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.openURL) private var openURL
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
#if canImport(MessageUI)
    @State private var showingMailComposer = false
    @State private var showingMailComposerLocation = false
    @State private var mailErrorAlert = false
#endif
    
    // Génération dynamique du corps du mail pour les prêts et locations actifs
    private func corpsEmailRetour(personne: Personne) -> String {
        let pretsActifs = dataManager.getPretsPourPersonne(personne.id).filter { $0.estActif }
        let locationsActives = dataManager.getLocationsPourPersonne(personne.id).filter { $0.estActive }
        var lignes: [String] = []
        
        // Section Prêts
        if !pretsActifs.isEmpty {
            lignes.append(localizedString("Voici le récapitulatif des matériels empruntés:", language: appLanguage))
            for pret in pretsActifs.sorted(by: { $0.dateFin < $1.dateFin }) {
                if let mat = dataManager.getMateriel(id: pret.materielId) {
                    let dateFin = formatDate(pret.dateFin, language: appLanguage)
                    if pret.estEnRetard {
                        lignes.append("- \(mat.nom) (\(localizedString("RETARD: retour prévu", language: appLanguage)) \(dateFin), \(localizedString("retard de", language: appLanguage)) \(pret.joursRetard) \(localizedString("jour(s) de retard", language: appLanguage)))")
                    } else {
                        lignes.append("- \(mat.nom) (\(localizedString("retour prévu:", language: appLanguage)) \(dateFin))")
                    }
                }
            }
            lignes.append("")
        }
        
        // Section Locations
        if !locationsActives.isEmpty {
            lignes.append(localizedString("Voici le récapitulatif des locations en cours:", language: appLanguage))
            for location in locationsActives.sorted(by: { $0.dateFin < $1.dateFin }) {
                if let mat = dataManager.getMateriel(id: location.materielId) {
                    let dateFin = formatDate(location.dateFin, language: appLanguage)
                    let prix = String(format: "%.2f€", location.prixTotalReel)
                    if location.estEnRetard {
                        lignes.append("- \(mat.nom) (\(prix)) - \(localizedString("RETARD: retour prévu", language: appLanguage)) \(dateFin), \(localizedString("retard de", language: appLanguage)) \(location.joursRetard) \(localizedString("jour(s) de retard", language: appLanguage))")
                    } else {
                        lignes.append("- \(mat.nom) (\(prix)) - \(localizedString("retour prévu:", language: appLanguage)) \(dateFin)")
                    }
                    if !location.paiementRecu {
                        lignes.append("  ⚠️ \(localizedString("Paiement en attente", language: appLanguage))")
                    }
                    if location.caution > 0 && !location.cautionRendue && !location.cautionGardee {
                        lignes.append("  💰 \(localizedString("Caution:", language: appLanguage)) \(String(format: "%.2f€", location.caution))")
                    }
                }
            }
            lignes.append("")
        }
        
        // Message si aucun prêt ni location
        if pretsActifs.isEmpty && locationsActives.isEmpty {
            lignes.append(localizedString("Aucun matériel emprunté ou loué en cours.", language: appLanguage))
            lignes.append("")
        }
        
        lignes.append(localizedString("Merci de procéder au retour ou de nous informer d'un prolongement.", language: appLanguage))
        lignes.append("")
        lignes.append(localizedString("Cordialement,", language: appLanguage))
        lignes.append(localizedString("L'équipe gestion de matériel", language: appLanguage))
        return "\(localizedString("Bonjour", language: appLanguage)) \(personne.prenom),\n\n" + lignes.joined(separator: "\n")
    }
    
    private func telURL(_ number: String) -> URL? {
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard !cleaned.isEmpty else { return nil }
        return URL(string: "tel://\(cleaned)")
    }
    // Nouvelle version: inclut sujet et corps encodés
    private func mailtoURL(_ email: String, subject: String, body: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet.urlQueryAllowed
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "mailto:\(trimmed)?subject=\(encodedSubject)&body=\(encodedBody)")
    }
    
    var pretsActifs: Int {
        dataManager.getPretsPourPersonne(personne.id).filter { $0.estActif }.count
    }
    var empruntsActifs: Int {
        dataManager.getEmpruntsPourPersonne(personne.id).filter { $0.estActif }.count
    }
    var locationsActives: Int {
        dataManager.getLocationsPourPersonne(personne.id).filter { $0.estActive }.count
    }
    var reparationsEnCours: Int {
        dataManager.getReparationsPourReparateur(personne.id).filter { $0.estEnCours }.count
    }
    
    // Locations de matériels en cours pour les ALM (où cette personne est le loueur)
    var mesLocationsALMActives: Int {
        dataManager.getMesLocationsPourPersonne(personne.id).filter { $0.estActive }.count
    }
    
    // Réparations terminées mais non payées (réparateur non rémunéré)
    var reparationsImpayees: [Reparation] {
        dataManager.getReparationsPourReparateur(personne.id).filter { $0.estTerminee && !$0.paiementRecu }
    }
    
    var montantReparationsImpayees: Double {
        reparationsImpayees.reduce(0) { $0 + ($1.coutFinal ?? $1.coutEstime ?? 0) }
    }
    
    // Locations impayées (terminées mais non payées)
    var locationsImpayees: [Location] {
        dataManager.getLocationsPourPersonne(personne.id).filter { $0.estTerminee && !$0.paiementRecu }
    }
    
    var montantImpaye: Double {
        locationsImpayees.reduce(0) { $0 + $1.prixTotalReel }
    }
    
    // Cautions non traitées (location terminée avec caution ni rendue ni gardée)
    var cautionsNonTraitees: [Location] {
        dataManager.getLocationsPourPersonne(personne.id).filter { $0.estTerminee && $0.caution > 0 && !$0.cautionRendue && !$0.cautionGardee }
    }
    
    var montantCautionsNonTraitees: Double {
        cautionsNonTraitees.reduce(0) { $0 + $1.caution }
    }
    
    // Génération dynamique du sujet du mail selon les prêts et/ou locations
    private func sujetEmail(personne: Personne) -> String {
        let hasPrets = pretsActifs > 0
        let hasLocations = locationsActives > 0
        
        if hasPrets && hasLocations {
            return localizedString("Rappel prêts et locations", language: appLanguage)
        } else if hasLocations {
            return localizedString("Rappel location", language: appLanguage)
        } else {
            return localizedString("Retour du matériel emprunté", language: appLanguage)
        }
    }
    
    // Génération dynamique du corps du mail pour les locations actives
    private func corpsEmailLocation(personne: Personne) -> String {
        let actives = dataManager.getLocationsPourPersonne(personne.id).filter { $0.estActive }
        var lignes: [String] = []
        if actives.isEmpty {
            lignes.append(localizedString("Aucune location en cours.", language: appLanguage))
        } else {
            lignes.append(localizedString("Voici le récapitulatif des locations en cours:", language: appLanguage))
            for location in actives.sorted(by: { $0.dateFin < $1.dateFin }) {
                if let mat = dataManager.getMateriel(id: location.materielId) {
                    let dateFin = formatDate(location.dateFin, language: appLanguage)
                    let prix = String(format: "%.2f€", location.prixTotalReel)
                    if location.estEnRetard {
                        lignes.append("- \(mat.nom) (\(prix)) - \(localizedString("RETARD: retour prévu", language: appLanguage)) \(dateFin), \(localizedString("retard de", language: appLanguage)) \(location.joursRetard) \(localizedString("jour(s) de retard", language: appLanguage))")
                    } else {
                        lignes.append("- \(mat.nom) (\(prix)) - \(localizedString("retour prévu:", language: appLanguage)) \(dateFin)")
                    }
                    if !location.paiementRecu {
                        lignes.append("  ⚠️ \(localizedString("Paiement en attente", language: appLanguage))")
                    }
                    if location.caution > 0 && !location.cautionRendue && !location.cautionGardee {
                        lignes.append("  💰 \(localizedString("Caution:", language: appLanguage)) \(String(format: "%.2f€", location.caution))")
                    }
                }
            }
        }
        lignes.append("")
        lignes.append(localizedString("Merci de procéder au retour ou de nous informer d'un prolongement.", language: appLanguage))
        lignes.append("")
        lignes.append(localizedString("Cordialement,", language: appLanguage))
        lignes.append(localizedString("L'équipe gestion de matériel", language: appLanguage))
        return "\(localizedString("Bonjour", language: appLanguage)) \(personne.prenom),\n\n" + lignes.joined(separator: "\n")
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Photo de la personne
            if let data = personne.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(couleurPourTypePersonne(personne.typePersonne))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: personne.typePersonne?.icon ?? "person.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .medium))
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(personne.nomComplet)
                    .font(.headline)
                if let type = personne.typePersonne {
                    let typeColor: Color = {
                        switch type {
                        case .mecanicien: return .orange
                        case .salarie: return .green
                        case .alm: return .purple
                        case .client: return .blue
                        }
                    }()
                    HStack(spacing: 3) {
                        Image(systemName: type.icon)
                            .font(.caption2)
                        Text(LocalizedStringKey(type.rawValue))
                            .font(.caption2)
                    }
                    .foregroundColor(typeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .cornerRadius(6)
                }
                // Badge locations impayées
                if !locationsImpayees.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(String(format: "%.2f€", montantImpaye))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(6)
                }
                // Badge réparations non payées (mécanicien non rémunéré)
                if personne.typePersonne == .mecanicien && !reparationsImpayees.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.caption2)
                        Text(String(format: "%.2f€", montantReparationsImpayees))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(6)
                }
                // Badge cautions non traitées
                if !cautionsNonTraitees.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "banknote")
                            .font(.caption2)
                        Text(String(format: "%.2f€", montantCautionsNonTraitees))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple)
                    .cornerRadius(6)
                }
            }
            if !personne.organisation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(personne.organisation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            // Ligne mail + téléphone
            HStack(spacing: 12) {
                if !personne.email.isEmpty {
#if canImport(MessageUI)
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showingMailComposer = true
                        } else if let url = mailtoURL(personne.email, subject: sujetEmail(personne: personne), body: corpsEmailRetour(personne: personne)) { openURL(url) } else { mailErrorAlert = true }
                    } label: {
                        HStack(spacing: 4) { Image(systemName: "envelope"); Text(personne.email).lineLimit(1) }
                    }
                    .font(.caption)
                    .sheet(isPresented: $showingMailComposer) {
                        MailComposeView(
                            recipients: [personne.email],
                            subject: sujetEmail(personne: personne),
                            body: corpsEmailRetour(personne: personne),
                            onResult: { result in if result == .sent { dataManager.mettreAJourDernierEmail(personneId: personne.id) } }
                        )
                    }
#else
                    if let url = mailtoURL(personne.email, subject: sujetEmail(personne: personne), body: corpsEmailRetour(personne: personne)) {
                        Button { openURL(url) } label: { HStack(spacing: 4) { Image(systemName: "envelope"); Text(personne.email).lineLimit(1) } }.font(.caption)
                    } else { Text(personne.email).font(.caption).foregroundColor(.secondary) }
#endif
                } else {
                    Text(LocalizedStringKey("Pas d'email"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let url = telURL(personne.telephone), !personne.telephone.isEmpty {
                    Button(action: { openURL(url) }) {
                        HStack(spacing: 4) { Image(systemName: "phone"); Text(personne.telephone).lineLimit(1) }
                    }
                    .font(.caption)
                } else {
                    Text(LocalizedStringKey("Pas de téléphone"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            // Ligne prêts actifs
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundColor(pretsActifs > 0 ? .orange : .secondary)
                Text("\(localizedString("Prêts actifs:", language: appLanguage)) \(pretsActifs)")
                    .font(.caption)
                    .foregroundColor(pretsActifs > 0 ? .orange : .secondary)
            }
            // Ligne emprunts actifs
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(empruntsActifs > 0 ? .purple : .secondary)
                Text("\(localizedString("Emprunts actifs:", language: appLanguage)) \(empruntsActifs)")
                    .font(.caption)
                    .foregroundColor(empruntsActifs > 0 ? .purple : .secondary)
            }
            // Ligne locations actives
            HStack(spacing: 6) {
                Image(systemName: "eurosign.circle")
                    .foregroundColor(locationsActives > 0 ? .green : .secondary)
                Text("\(localizedString("Locations actives:", language: appLanguage)) \(locationsActives)")
                    .font(.caption)
                    .foregroundColor(locationsActives > 0 ? .green : .secondary)
                
                // Bouton mail pour les locations
                if locationsActives > 0 && !personne.email.isEmpty {
                    Spacer()
#if canImport(MessageUI)
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showingMailComposerLocation = true
                        } else if let url = mailtoURL(personne.email, subject: localizedString("Rappel location", language: appLanguage), body: corpsEmailLocation(personne: personne)) {
                            openURL(url)
                        } else {
                            mailErrorAlert = true
                        }
                    } label: {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
#else
                    if let url = mailtoURL(personne.email, subject: localizedString("Rappel location", language: appLanguage), body: corpsEmailLocation(personne: personne)) {
                        Button { openURL(url) } label: {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                    }
#endif
                }
            }
            // Ligne réparations en cours (uniquement pour les mécaniciens)
            if personne.typePersonne == .mecanicien {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(reparationsEnCours > 0 ? .orange : .secondary)
                    Text("\(localizedString("Réparations en cours:", language: appLanguage)) \(reparationsEnCours)")
                        .font(.caption)
                        .foregroundColor(reparationsEnCours > 0 ? .orange : .secondary)
                }
            }
            // Ligne locations matériels en cours (uniquement pour les ALM)
            if personne.typePersonne == .alm {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(mesLocationsALMActives > 0 ? .purple : .secondary)
                    Text("\(localizedString("Locations Matériels en cours:", language: appLanguage)) \(mesLocationsALMActives)")
                        .font(.caption)
                        .foregroundColor(mesLocationsALMActives > 0 ? .purple : .secondary)
                }
            }
            } // Fin VStack intérieur
        } // Fin HStack principal
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.vertical, 2)
#if canImport(MessageUI)
        .sheet(isPresented: $showingMailComposerLocation) {
            MailComposeView(
                recipients: [personne.email],
                subject: localizedString("Rappel location", language: appLanguage),
                body: corpsEmailLocation(personne: personne),
                onResult: { result in if result == .sent { dataManager.mettreAJourDernierEmail(personneId: personne.id) } }
            )
        }
#endif
        .alert(LocalizedStringKey("Impossible d'ouvrir Mail"), isPresented: $mailErrorAlert) { Button(LocalizedStringKey("OK"), role: .cancel) {} } message: { Text(LocalizedStringKey("Aucun compte Mail configuré.")) }
        .contextMenu {
            if !personne.email.isEmpty {
                Button(LocalizedStringKey("Copier l'adresse")) {
#if canImport(UIKit)
                    UIPasteboard.general.string = personne.email
#endif
                }
            }
            if !personne.telephone.isEmpty {
                Button(LocalizedStringKey("Copier le téléphone")) {
#if canImport(UIKit)
                    UIPasteboard.general.string = personne.telephone
#endif
                }
            }
        }
    }
}

// MARK: - Contact Picker Wrapper
struct ContactPickerView: UIViewControllerRepresentable {
    @Binding var selectedContact: CNContact?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // La sheet se ferme automatiquement
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            // Récupérer le contact complet avec toutes les propriétés nécessaires
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]
            
            let store = CNContactStore()
            
            do {
                let fullContact = try store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keysToFetch)
                parent.selectedContact = fullContact
            } catch {
                // Si échec, utiliser le contact tel quel
                parent.selectedContact = contact
            }
            // La sheet se ferme automatiquement après la sélection
        }
    }
}

struct AjouterPersonneView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    // Callback optionnel pour retourner l'ID de la personne créée
    var onPersonneCreated: ((UUID) -> Void)?
    
    // Type de personne par défaut (optionnel)
    var defaultTypePersonne: TypePersonne? = nil
    
    // Chantier par défaut (optionnel, pour pré-sélectionner un chantier)
    var defaultChantierId: UUID? = nil
    
    @State private var nom = ""
    @State private var prenom = ""
    @State private var email = ""
    @State private var telephone = ""
    @State private var organisation = ""
    @State private var typePersonne: TypePersonne? = .client
    @State private var chantierId: UUID? = nil
    @State private var showingAddChantier = false
    @State private var showingContactPicker = false
    @State private var selectedContact: CNContact?
    @State private var hasInitializedType = false
    @State private var hasInitializedChantier = false
    @State private var showPremiumSheet = false
    
    // Photo de la personne
    @State private var photoData: Data? = nil
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    
    // Vérifie si on peut créer une nouvelle personne
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
                        // Bouton pour importer depuis les contacts
                        Section {
                            Button(action: { showingContactPicker = true }) {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey("Importer depuis Contacts"))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(LocalizedStringKey("Remplir automatiquement depuis vos contacts"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                
                        // Section Photo
                        Section(LocalizedStringKey("Photo")) {
                    VStack(spacing: 12) {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            HStack {
                                Spacer()
                                Button(role: .destructive) { photoData = nil } label: {
                                    Label(LocalizedStringKey("Retirer la photo"), systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(width: 120, height: 120)
                                VStack(spacing: 6) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 40))
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
                                    Label(LocalizedStringKey("Prendre"), systemImage: "camera.fill")
                                }
                                .buttonStyle(.bordered)
                            }
                            Button(action: { showPhotoLibraryPicker = true }) {
                                Label(LocalizedStringKey(photoData == nil ? "Choisir" : "Changer"), systemImage: "photo.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Section(LocalizedStringKey("Identité")) {
                    TextField(LocalizedStringKey("Prénom"), text: $prenom)
                    TextField(LocalizedStringKey("Nom"), text: $nom)
                }
                
                Section(LocalizedStringKey("Type de personne")) {
                    Picker(LocalizedStringKey("Type"), selection: $typePersonne) {
                        Label(LocalizedStringKey("Client"), systemImage: "person.fill")
                            .tag(TypePersonne?.some(.client))
                        Label(LocalizedStringKey("Mécanicien"), systemImage: "wrench.and.screwdriver.fill")
                            .tag(TypePersonne?.some(.mecanicien))
                        Label(LocalizedStringKey("Salarié"), systemImage: "person.badge.clock.fill")
                            .tag(TypePersonne?.some(.salarie))
                        Label(LocalizedStringKey("Agence Location Matériel"), systemImage: "building.2.fill")
                            .tag(TypePersonne?.some(.alm))
                    }
                    .pickerStyle(.menu)
                }
                
                // Section Chantier (visible uniquement pour les salariés)
                if typePersonne == .salarie {
                    Section(LocalizedStringKey("Chantier")) {
                        Picker(LocalizedStringKey("Chantier assigné"), selection: $chantierId) {
                            Text(LocalizedStringKey("Aucun chantier")).tag(UUID?.none)
                            ForEach(dataManager.chantiers.filter { $0.estActif }) { chantier in
                                Text(chantier.nom).tag(UUID?.some(chantier.id))
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Button(action: { showingAddChantier = true }) {
                            Label(LocalizedStringKey("Ajouter un chantier"), systemImage: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(LocalizedStringKey("Contact")) {
                    TextField(LocalizedStringKey("Email"), text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField(LocalizedStringKey("Téléphone"), text: $telephone)
                        .keyboardType(.phonePad)
                }
                
                Section(LocalizedStringKey("Organisation")) {
                    TextField(LocalizedStringKey("Organisation"), text: $organisation)
                }
                    } // Fin Form
                    .scrollDismissesKeyboard(.interactively)
                } // Fin else
            } // Fin Group
            .navigationTitle(LocalizedStringKey("Nouvelle personne"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !storeManager.hasUnlockedPremium {
                        VStack(spacing: 2) {
                            Text(LocalizedStringKey("Nouvelle personne"))
                                .font(.headline)
                            Text("\(dataManager.totalPersonnesCreated)/\(StoreManager.freePersonneLimit)")
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
                        ajouterPersonne()
                    }
                    .disabled(nom.isEmpty || prenom.isEmpty)
                }
            }
            .sheet(isPresented: $showingContactPicker, onDismiss: {
                // Traiter le contact après la fermeture de la sheet
                if let contact = selectedContact {
                    importerContact(contact)
                    selectedContact = nil
                }
            }) {
                ContactPickerView(selectedContact: $selectedContact)
            }
            .onAppear {
                // Initialiser le type de personne par défaut une seule fois
                if !hasInitializedType, let defaultType = defaultTypePersonne {
                    typePersonne = defaultType
                    hasInitializedType = true
                }
                // Initialiser le chantier par défaut une seule fois
                if !hasInitializedChantier, let defaultChantier = defaultChantierId {
                    chantierId = defaultChantier
                    hasInitializedChantier = true
                }
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
            .sheet(isPresented: $showingAddChantier) {
                AjouterChantierView { nouveauChantierId in
                    chantierId = nouveauChantierId
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                PersonneImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let image = newImage {
                            photoData = image.jpegData(compressionQuality: 0.7)
                        }
                    }
                ), sourceType: .camera)
            }
            .sheet(isPresented: $showPhotoLibraryPicker) {
                PersonneImagePicker(image: Binding(
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
    
    func importerContact(_ contact: CNContact) {
        // Nom et prénom
        nom = contact.familyName
        prenom = contact.givenName
        
        // Email (prendre le premier disponible)
        if let emailAddress = contact.emailAddresses.first {
            email = emailAddress.value as String
        }
        
        // Téléphone (prendre le premier disponible)
        if let phoneNumber = contact.phoneNumbers.first {
            telephone = phoneNumber.value.stringValue
        }
        
        // Organisation
        organisation = contact.organizationName
    }
    
    func ajouterPersonne() {
        let personne = Personne(
            nom: nom,
            prenom: prenom,
            email: email,
            telephone: telephone,
            organisation: organisation,
            typePersonne: typePersonne,
            chantierId: typePersonne == .salarie ? chantierId : nil,
            photoData: photoData
        )
        dataManager.ajouterPersonne(personne)
        onPersonneCreated?(personne.id)
        dismiss()
    }
}

struct PersonneDetailView: View {
    let personne: Personne
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.openURL) private var openURL
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var showingEditSheet = false
#if canImport(MessageUI)
    @State private var showingMailComposer = false
    @State private var mailErrorAlert = false
#endif
    
    private func telURL(_ number: String) -> URL? {
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard !cleaned.isEmpty else { return nil }
        return URL(string: "tel://\(cleaned)")
    }
    // Mise à jour: subject + body pour fallback
    private func mailtoURL(_ email: String, subject: String, body: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet.urlQueryAllowed
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "mailto:\(trimmed)?subject=\(encodedSubject)&body=\(encodedBody)")
    }
    private func corpsEmailRetourDetail(personne: Personne) -> String {
        let pretsActifs = dataManager.getPretsPourPersonne(personne.id).filter { $0.estActif }
        let locationsActives = dataManager.getLocationsPourPersonne(personne.id).filter { $0.estActive }
        var lignes: [String] = []
        
        // Section Prêts
        if !pretsActifs.isEmpty {
            lignes.append(localizedString("Récapitulatif des emprunts actifs:", language: appLanguage))
            for pret in pretsActifs.sorted(by: { $0.dateFin < $1.dateFin }) {
                if let mat = dataManager.getMateriel(id: pret.materielId) {
                    let dateFin = formatDate(pret.dateFin, language: appLanguage)
                    if pret.estEnRetard {
                        lignes.append("- \(mat.nom) (\(localizedString("RETARD: retour prévu", language: appLanguage)) \(dateFin), \(localizedString("retard de", language: appLanguage)) \(pret.joursRetard) \(localizedString("jour(s) de retard", language: appLanguage)))")
                    } else {
                        lignes.append("- \(mat.nom) (\(localizedString("retour prévu:", language: appLanguage)) \(dateFin))")
                    }
                }
            }
            lignes.append("")
        }
        
        // Section Locations
        if !locationsActives.isEmpty {
            lignes.append(localizedString("Voici le récapitulatif des locations en cours:", language: appLanguage))
            for location in locationsActives.sorted(by: { $0.dateFin < $1.dateFin }) {
                if let mat = dataManager.getMateriel(id: location.materielId) {
                    let dateFin = formatDate(location.dateFin, language: appLanguage)
                    let prix = String(format: "%.2f€", location.prixTotalReel)
                    if location.estEnRetard {
                        lignes.append("- \(mat.nom) (\(prix)) - \(localizedString("RETARD: retour prévu", language: appLanguage)) \(dateFin), \(localizedString("retard de", language: appLanguage)) \(location.joursRetard) \(localizedString("jour(s) de retard", language: appLanguage))")
                    } else {
                        lignes.append("- \(mat.nom) (\(prix)) - \(localizedString("retour prévu:", language: appLanguage)) \(dateFin)")
                    }
                    if !location.paiementRecu {
                        lignes.append("  ⚠️ \(localizedString("Paiement en attente", language: appLanguage))")
                    }
                    if location.caution > 0 && !location.cautionRendue && !location.cautionGardee {
                        lignes.append("  💰 \(localizedString("Caution:", language: appLanguage)) \(String(format: "%.2f€", location.caution))")
                    }
                }
            }
            lignes.append("")
        }
        
        // Message si aucun prêt ni location
        if pretsActifs.isEmpty && locationsActives.isEmpty {
            lignes.append(localizedString("Aucun matériel emprunté ou loué en cours.", language: appLanguage))
            lignes.append("")
        }
        
        lignes.append(localizedString("Merci de préparer le retour ou nous indiquer tout besoin de prolongation.", language: appLanguage))
        lignes.append("")
        lignes.append(localizedString("Cordialement,", language: appLanguage))
        lignes.append(localizedString("L'équipe gestion de matériel", language: appLanguage))
        return "\(localizedString("Bonjour", language: appLanguage)) \(personne.prenom),\n\n" + lignes.joined(separator: "\n")
    }
    
    var prets: [Pret] {
        dataManager.getPretsPourPersonne(personne.id)
    }
    
    var pretsActifs: [Pret] {
        prets.filter { $0.estActif }
    }
    // Ajout: emprunts pour cette personne
    var emprunts: [Emprunt] {
        dataManager.getEmpruntsPourPersonne(personne.id)
    }
    var empruntsActifs: [Emprunt] {
        emprunts.filter { $0.estActif }
    }
    // Ajout: locations pour cette personne
    var locations: [Location] {
        dataManager.getLocationsPourPersonne(personne.id)
    }
    var locationsActives: [Location] {
        locations.filter { $0.estActive }
    }
    // Locations terminées mais non payées (impayés)
    var locationsImpayees: [Location] {
        locations.filter { $0.estTerminee && !$0.paiementRecu }
    }
    // Montant total des impayés
    var montantImpaye: Double {
        locationsImpayees.reduce(0) { $0 + $1.prixTotalReel }
    }
    // Cautions non traitées (location terminée avec caution ni rendue ni gardée)
    var cautionsNonTraitees: [Location] {
        locations.filter { $0.estTerminee && $0.caution > 0 && !$0.cautionRendue && !$0.cautionGardee }
    }
    // Montant total des cautions non traitées
    var montantCautionsNonTraitees: Double {
        cautionsNonTraitees.reduce(0) { $0 + $1.caution }
    }
    // Ajout: réparations pour ce réparateur
    var reparations: [Reparation] {
        dataManager.getReparationsPourReparateur(personne.id)
    }
    var reparationsEnCours: [Reparation] {
        reparations.filter { $0.estEnCours }
    }
    // Réparations terminées mais non payées (réparateur non rémunéré)
    var reparationsImpayees: [Reparation] {
        reparations.filter { $0.estTerminee && !$0.paiementRecu }
    }
    // Montant total des réparations impayées
    var montantReparationsImpayees: Double {
        reparationsImpayees.reduce(0) { $0 + ($1.coutFinal ?? $1.coutEstime ?? 0) }
    }
    // Ajout: MaLocations pour cette personne ALM (où cette personne est le loueur)
    var mesLocationsALM: [MaLocation] {
        dataManager.getMesLocationsPourPersonne(personne.id)
    }
    var mesLocationsALMActives: [MaLocation] {
        mesLocationsALM.filter { $0.estActive }
    }
    // Toujours lire la version courante depuis le store pour refléter les modifications
    var personneCourante: Personne {
        dataManager.getPersonne(id: personne.id) ?? personne
    }
    
    // Génération dynamique du sujet du mail selon les prêts et/ou locations
    private func sujetEmailDetail() -> String {
        let hasPrets = !pretsActifs.isEmpty
        let hasLocations = !locationsActives.isEmpty
        
        if hasPrets && hasLocations {
            return localizedString("Rappel prêts et locations", language: appLanguage)
        } else if hasLocations {
            return localizedString("Rappel location", language: appLanguage)
        } else {
            return localizedString("Retour du matériel emprunté", language: appLanguage)
        }
    }
    
    // Génération dynamique du corps du mail pour les locations actives
    private func corpsEmailLocationDetail(personne: Personne) -> String {
        let actives = dataManager.getLocationsPourPersonne(personne.id).filter { $0.estActive }
        var lignes: [String] = []
        if actives.isEmpty {
            lignes.append(localizedString("Aucune location en cours.", language: appLanguage))
        } else {
            lignes.append(localizedString("Voici le récapitulatif des locations en cours:", language: appLanguage))
            for location in actives.sorted(by: { $0.dateFin < $1.dateFin }) {
                if let mat = dataManager.getMateriel(id: location.materielId) {
                    let dateFin = formatDate(location.dateFin, language: appLanguage)
                    let prix = String(format: "%.2f€", location.prixTotalReel)
                    if location.estEnRetard {
                        lignes.append("- \(mat.nom) (\(prix)) - \(localizedString("RETARD: retour prévu", language: appLanguage)) \(dateFin), \(localizedString("retard de", language: appLanguage)) \(location.joursRetard) \(localizedString("jour(s) de retard", language: appLanguage))")
                    } else {
                        lignes.append("- \(mat.nom) (\(prix)) - \(localizedString("retour prévu:", language: appLanguage)) \(dateFin)")
                    }
                    if !location.paiementRecu {
                        lignes.append("  ⚠️ \(localizedString("Paiement en attente", language: appLanguage))")
                    }
                    if location.caution > 0 && !location.cautionRendue && !location.cautionGardee {
                        lignes.append("  💰 \(localizedString("Caution:", language: appLanguage)) \(String(format: "%.2f€", location.caution))")
                    }
                }
            }
        }
        lignes.append("")
        lignes.append(localizedString("Merci de procéder au retour ou de nous informer d'un prolongement.", language: appLanguage))
        lignes.append("")
        lignes.append(localizedString("Cordialement,", language: appLanguage))
        lignes.append(localizedString("L'équipe gestion de matériel", language: appLanguage))
        return "\(localizedString("Bonjour", language: appLanguage)) \(personne.prenom),\n\n" + lignes.joined(separator: "\n")
    }
    
    // Génération du corps du mail pour les rappels de paiement (impayés)
    private func corpsEmailImpayeDetail(personne: Personne) -> String {
        let impayees = dataManager.getLocationsPourPersonne(personne.id).filter { $0.estTerminee && !$0.paiementRecu }
        var lignes: [String] = []
        
        if impayees.isEmpty {
            lignes.append(localizedString("Aucun paiement en attente.", language: appLanguage))
        } else {
            lignes.append(localizedString("Nous vous contactons concernant les locations suivantes dont le paiement n'a pas encore été reçu:", language: appLanguage))
            lignes.append("")
            
            var totalImpaye: Double = 0
            for location in impayees.sorted(by: { $0.dateFin > $1.dateFin }) {
                if let mat = dataManager.getMateriel(id: location.materielId) {
                    let dateRetour = location.dateRetourEffectif != nil ? formatDate(location.dateRetourEffectif!, language: appLanguage) : formatDate(location.dateFin, language: appLanguage)
                    let prix = location.prixTotalReel
                    totalImpaye += prix
                    lignes.append("- \(mat.nom)")
                    lignes.append("  📅 \(localizedString("Retourné le:", language: appLanguage)) \(dateRetour)")
                    lignes.append("  💰 \(localizedString("Montant dû:", language: appLanguage)) \(String(format: "%.2f€", prix))")
                    lignes.append("")
                }
            }
            
            lignes.append("━━━━━━━━━━━━━━━━━━━━━━")
            lignes.append("\(localizedString("Total à régler:", language: appLanguage)) \(String(format: "%.2f€", totalImpaye))")
            lignes.append("")
        }
        
        lignes.append(localizedString("Merci de procéder au règlement dans les meilleurs délais.", language: appLanguage))
        lignes.append("")
        lignes.append(localizedString("Cordialement,", language: appLanguage))
        lignes.append(localizedString("L'équipe gestion de matériel", language: appLanguage))
        return "\(localizedString("Bonjour", language: appLanguage)) \(personne.prenom),\n\n" + lignes.joined(separator: "\n")
    }
    
    var body: some View {
        List {
            Section(LocalizedStringKey("Informations")) {
                LabeledContent(LocalizedStringKey("Nom complet"), value: personneCourante.nomComplet)
                HStack {
                    Text(LocalizedStringKey("Email"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !personneCourante.email.isEmpty {
#if canImport(MessageUI)
                        Button {
                            if MFMailComposeViewController.canSendMail() {
                                showingMailComposer = true
                            } else if let url = mailtoURL(personneCourante.email, subject: sujetEmailDetail(), body: corpsEmailRetourDetail(personne: personneCourante)) { openURL(url) } else { mailErrorAlert = true }
                        } label: {
                            HStack(spacing: 6) { Image(systemName: "envelope"); Text(personneCourante.email) }
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingMailComposer) {
                            MailComposeView(
                                recipients: [personneCourante.email],
                                subject: sujetEmailDetail(),
                                body: corpsEmailRetourDetail(personne: personneCourante),
                                onResult: { result in
                                    if result == .sent { dataManager.mettreAJourDernierEmail(personneId: personneCourante.id) }
                                }
                            )
                        }
                        .alert(LocalizedStringKey("Impossible d'ouvrir Mail"), isPresented: $mailErrorAlert) { Button("OK", role: .cancel) {} } message: { Text(LocalizedStringKey("Aucun compte Mail configuré.")) }
                        .contextMenu {
                            Button(LocalizedStringKey("Copier l'adresse")) {
#if canImport(UIKit)
                                UIPasteboard.general.string = personneCourante.email
#endif
                            }
                        }
#else
                        if let url = mailtoURL(personneCourante.email, subject: sujetEmailDetail(), body: corpsEmailRetourDetail(personne: personneCourante)) {
                            Button { openURL(url) } label: { HStack(spacing: 6) { Image(systemName: "envelope"); Text(personneCourante.email) } }.buttonStyle(.plain)
                                .contextMenu {
                                    Button(LocalizedStringKey("Copier l'adresse")) {
#if canImport(UIKit)
                                        UIPasteboard.general.string = personneCourante.email
#endif
                                    }
                                }
                        } else { Text(personneCourante.email).foregroundColor(.secondary) }
#endif
                    }
                }
                HStack {
                    Text(LocalizedStringKey("Téléphone")).font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    if let url = telURL(personneCourante.telephone) {
                        Button(action: { openURL(url) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone")
                                Text(personneCourante.telephone)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(personneCourante.telephone).foregroundColor(.secondary)
                    }
                }
                LabeledContent(LocalizedStringKey("Organisation"), value: personneCourante.organisation)
                if let date = personneCourante.dateDernierEmail {
                    LabeledContent(LocalizedStringKey("Dernier email"), value: formatDate(date, language: appLanguage))
                }
            }
            
            // Section Chantier (visible uniquement pour les salariés)
            if personneCourante.typePersonne == .salarie {
                Section(LocalizedStringKey("Chantier assigné")) {
                    if let chantierId = personneCourante.chantierId,
                       let chantier = dataManager.getChantier(id: chantierId) {
                        NavigationLink(destination: ChantierDetailView(chantier: chantier)) {
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chantier.nom)
                                        .font(.headline)
                                    if !chantier.adresse.isEmpty {
                                        Text(chantier.adresse)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(LocalizedStringKey(chantier.statut))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(chantier.statut == "Actif" ? Color.green : (chantier.statut == "En préparation" ? Color.blue : Color.gray))
                                    .cornerRadius(4)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "hammer")
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Aucun chantier assigné"))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
            }
            
            // ═══════════════════════════════════════════════════════════════════
            // SECTION: MATÉRIELS QUI SORTENT (Prêts + Locations + Réparations mécanicien)
            // ═══════════════════════════════════════════════════════════════════
            Section {
                // Calcul du total pour cette section
                let totalSortie = pretsActifs.count + locationsActives.count + (personneCourante.typePersonne == .mecanicien ? reparationsEnCours.count : 0)
                
                if totalSortie == 0 {
                    Text(LocalizedStringKey("Aucun matériel en sortie"))
                        .foregroundColor(.secondary)
                } else {
                    // Prêts en cours
                    if !pretsActifs.isEmpty {
                        HStack {
                            Image(systemName: "arrow.up.forward.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("\(localizedString("Prêts en cours", language: appLanguage)) (\(pretsActifs.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Spacer()
                            NavigationLink(destination: PretListePersonneView(personneId: personne.id)) {
                                Text(LocalizedStringKey("Voir tout"))
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                        
                        ForEach(pretsActifs) { pret in
                            NavigationLink(destination: PretDetailView(pret: pret)) {
                                PretRowCompactView(pret: pret)
                            }
                        }
                    }
                    
                    // Locations en cours
                    if !locationsActives.isEmpty {
                        if !pretsActifs.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        
                        HStack {
                            Image(systemName: "eurosign.circle.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("\(localizedString("Locations en cours", language: appLanguage)) (\(locationsActives.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                            Spacer()
                            NavigationLink(destination: LocationListePersonneView(personneId: personne.id)) {
                                Text(LocalizedStringKey("Voir tout"))
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                        
                        ForEach(locationsActives.sorted(by: { $0.dateFin < $1.dateFin })) { location in
                            NavigationLink(destination: LocationDetailView(location: location)) {
                                LocationRowCompactView(location: location)
                            }
                        }
                        
                        // Bouton pour envoyer un mail de rappel locations
                        if !personneCourante.email.isEmpty {
                            Button(action: {
#if canImport(MessageUI)
                                if MFMailComposeViewController.canSendMail() {
                                    showingMailComposer = true
                                } else if let url = mailtoURL(personneCourante.email, subject: localizedString("Rappel location", language: appLanguage), body: corpsEmailLocationDetail(personne: personneCourante)) {
                                    openURL(url)
                                } else {
                                    mailErrorAlert = true
                                }
#else
                                if let url = mailtoURL(personneCourante.email, subject: localizedString("Rappel location", language: appLanguage), body: corpsEmailLocationDetail(personne: personneCourante)) {
                                    openURL(url)
                                }
#endif
                            }) {
                                Label(localizedString("Envoyer un rappel", language: appLanguage), systemImage: "envelope.fill")
                            }
                            .foregroundColor(.green)
                        }
                    }
                    
                    // Réparations en cours (pour mécaniciens - le matériel SORT vers le mécanicien)
                    if personneCourante.typePersonne == .mecanicien && !reparationsEnCours.isEmpty {
                        if !pretsActifs.isEmpty || !locationsActives.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(localizedString("Réparations en cours", language: appLanguage)) (\(reparationsEnCours.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Spacer()
                            NavigationLink(destination: ReparationListeReparateurView(reparateurId: personne.id)) {
                                Text(LocalizedStringKey("Voir tout"))
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                        
                        ForEach(reparationsEnCours.sorted(by: { $0.dateDebut > $1.dateDebut })) { reparation in
                            NavigationLink(destination: ReparationDetailFromPersonneView(reparation: reparation)) {
                                ReparationRowCompactView(reparation: reparation)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "arrow.up.right.square.fill")
                        .foregroundColor(.red)
                    Text(LocalizedStringKey("Matériels qui sortent"))
                        .fontWeight(.semibold)
                }
            }
            
            // ═══════════════════════════════════════════════════════════════════
            // SECTION: MATÉRIELS QUI RENTRENT (Emprunts + MaLocation ALM)
            // ═══════════════════════════════════════════════════════════════════
            Section {
                // Calcul du total pour cette section
                let totalEntree = empruntsActifs.count + (personneCourante.typePersonne == .alm ? mesLocationsALMActives.count : 0)
                
                if totalEntree == 0 {
                    Text(LocalizedStringKey("Aucun matériel en entrée"))
                        .foregroundColor(.secondary)
                } else {
                    // Emprunts en cours
                    if !empruntsActifs.isEmpty {
                        HStack {
                            Image(systemName: "arrow.down.forward.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(localizedString("Emprunts en cours", language: appLanguage)) (\(empruntsActifs.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Spacer()
                            NavigationLink(destination: EmpruntListePersonneView(personneId: personne.id)) {
                                Text(LocalizedStringKey("Voir tout"))
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                        
                        ForEach(empruntsActifs.sorted(by: { $0.dateFin < $1.dateFin })) { emprunt in
                            NavigationLink(destination: EmpruntDetailView(emprunt: emprunt)) {
                                EmpruntRowCompactView(emprunt: emprunt)
                            }
                        }
                    }
                    
                    // Locations Matériels ALM (pour ALM - le matériel RENTRE chez nous depuis l'ALM)
                    if personneCourante.typePersonne == .alm && !mesLocationsALMActives.isEmpty {
                        if !empruntsActifs.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.purple)
                                .font(.caption)
                            Text("\(localizedString("Locations Matériels en cours", language: appLanguage)) (\(mesLocationsALMActives.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        
                        ForEach(mesLocationsALMActives.sorted(by: { $0.dateFin < $1.dateFin })) { maLocation in
                            NavigationLink(destination: MaLocationDetailView(maLocation: maLocation)) {
                                MaLocationRowCompactView(maLocation: maLocation)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "arrow.down.left.square.fill")
                        .foregroundColor(.green)
                    Text(LocalizedStringKey("Matériels qui rentrent"))
                        .fontWeight(.semibold)
                }
            }
            
            // Section Locations impayées (terminées mais paiement non reçu)
            if !locationsImpayees.isEmpty {
                Section {
                    // Résumé du montant total impayé
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(LocalizedStringKey("Montant total impayé"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", montantImpaye))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                    
                    ForEach(locationsImpayees.sorted(by: { $0.dateFin > $1.dateFin })) { location in
                        NavigationLink(destination: LocationDetailView(location: location)) {
                            LocationImpayeeRowView(location: location)
                        }
                    }
                    
                    // Bouton pour envoyer un rappel de paiement
                    if !personneCourante.email.isEmpty {
                        Button(action: {
#if canImport(MessageUI)
                            if MFMailComposeViewController.canSendMail() {
                                // Utiliser le mail composer pour rappel impayé
                                showingMailComposer = true
                            } else if let url = mailtoURL(personneCourante.email, subject: localizedString("Rappel de paiement", language: appLanguage), body: corpsEmailImpayeDetail(personne: personneCourante)) {
                                openURL(url)
                            } else {
                                mailErrorAlert = true
                            }
#else
                            if let url = mailtoURL(personneCourante.email, subject: localizedString("Rappel de paiement", language: appLanguage), body: corpsEmailImpayeDetail(personne: personneCourante)) {
                                openURL(url)
                            }
#endif
                        }) {
                            Label(localizedString("Envoyer un rappel de paiement", language: appLanguage), systemImage: "envelope.badge.fill")
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    HStack {
                        Image(systemName: "creditcard.trianglebadge.exclamationmark")
                            .foregroundColor(.red)
                        Text("\(localizedString("Locations impayées", language: appLanguage)) (\(locationsImpayees.count))")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Section Cautions non traitées
            if !cautionsNonTraitees.isEmpty {
                Section {
                    // Résumé du montant total des cautions
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(LocalizedStringKey("Total cautions à traiter"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", montantCautionsNonTraitees))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                    
                    ForEach(cautionsNonTraitees.sorted(by: { $0.dateFin > $1.dateFin })) { location in
                        CautionNonTraiteeRowView(location: location)
                    }
                } header: {
                    HStack {
                        Image(systemName: "banknote")
                            .foregroundColor(.orange)
                        Text("\(localizedString("Cautions à traiter", language: appLanguage)) (\(cautionsNonTraitees.count))")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Section Réparations non payées (réparateur non rémunéré) - visible uniquement pour les mécaniciens
            if personneCourante.typePersonne == .mecanicien && !reparationsImpayees.isEmpty {
                Section {
                    // Résumé du montant total impayé
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.orange)
                        Text(LocalizedStringKey("Montant total à payer"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f €", montantReparationsImpayees))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                    
                    ForEach(reparationsImpayees.sorted(by: { $0.dateDebut > $1.dateDebut })) { reparation in
                        ReparationImpayeeRowView(reparation: reparation)
                    }
                    
                    // Bouton pour payer toutes les réparations
                    Button(action: {
                        for reparation in reparationsImpayees {
                            dataManager.marquerPaiementReparation(reparation.id, recu: true)
                        }
                    }) {
                        Label(localizedString("Valider tous les paiements", language: appLanguage), systemImage: "checkmark.circle.fill")
                    }
                    .foregroundColor(.green)
                } header: {
                    HStack {
                        Image(systemName: "creditcard.trianglebadge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("\(localizedString("Réparations à payer", language: appLanguage)) (\(reparationsImpayees.count))")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Détails"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { Button(LocalizedStringKey("Modifier")) { showingEditSheet = true } }
        }
        .sheet(isPresented: $showingEditSheet) { EditPersonneView(personne: personneCourante) }
    }
}

// MARK: - Vues compactes pour la fiche personne

/// Vue compacte d'un prêt pour la fiche personne
struct PretRowCompactView: View {
    let pret: Pret
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let materiel = dataManager.getMateriel(id: pret.materielId) {
                Text(materiel.nom)
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(LocalizedStringKey("Matériel inconnu"))
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            Text(LocalizedStringKey("Retour prévu: \(formatDate(pret.dateFin))"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Vue compacte d'un emprunt pour la fiche personne
struct EmpruntRowCompactView: View {
    let emprunt: Emprunt
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(emprunt.nomObjet)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(LocalizedStringKey("Retour prévu: \(formatDate(emprunt.dateFin))"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Vue compacte d'une location pour la fiche personne
struct LocationRowCompactView: View {
    let location: Location
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let materiel = dataManager.getMateriel(id: location.materielId) {
                Text(materiel.nom)
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(LocalizedStringKey("Matériel inconnu"))
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            Text(LocalizedStringKey("Retour prévu: \(formatDate(location.dateFin))"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Text(LocalizedStringKey("Prix: \(String(format: "%.2f €", location.prixTotalReel))"))
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(location.paiementRecu ? LocalizedStringKey("Payé") : LocalizedStringKey("Non payé"))
                    .font(.caption)
                    .foregroundColor(location.paiementRecu ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Vue compacte d'une location impayée pour la fiche personne
struct LocationImpayeeRowView: View {
    let location: Location
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let materiel = dataManager.getMateriel(id: location.materielId) {
                    Text(materiel.nom)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text(LocalizedStringKey("Matériel inconnu"))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                Spacer()
                // Badge impayé
                Text(LocalizedStringKey("IMPAYÉ"))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .cornerRadius(4)
            }
            
            HStack(spacing: 12) {
                // Date de retour
                if let dateRetour = location.dateRetourEffectif {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(dateRetour))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Montant dû
                Text(String(format: "%.2f €", location.prixTotalReel))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Vue compacte d'une caution non traitée pour la fiche personne
struct CautionNonTraiteeRowView: View {
    let location: Location
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var showingActionSheet = false
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let materiel = dataManager.getMateriel(id: location.materielId) {
                    Text(materiel.nom)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text(LocalizedStringKey("Matériel inconnu"))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                Spacer()
                // Badge caution
                Text(LocalizedStringKey("CAUTION"))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .cornerRadius(4)
            }
            
            HStack(spacing: 12) {
                // Date de retour
                if let dateRetour = location.dateRetourEffectif {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(dateRetour))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Montant caution
                Text(String(format: "%.2f €", location.caution))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            // Boutons d'action
            HStack(spacing: 12) {
                Button {
                    dataManager.marquerCautionRendue(location.id, rendue: true)
                } label: {
                    Label(localizedString("Rendre", language: appLanguage), systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    showingActionSheet = true
                } label: {
                    Label(localizedString("Garder", language: appLanguage), systemImage: "hand.raised.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    localizedString("Garder la caution ?", language: appLanguage),
                    isPresented: $showingActionSheet,
                    titleVisibility: .visible
                ) {
                    Button(localizedString("Oui, garder la caution", language: appLanguage), role: .destructive) {
                        dataManager.garderCaution(location.id)
                    }
                    Button(localizedString("Annuler", language: appLanguage), role: .cancel) {}
                } message: {
                    Text(LocalizedStringKey("Cette action enregistrera la caution comme un revenu. Êtes-vous sûr ?"))
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}

struct EditPersonneView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    private let original: Personne
    @State private var nom: String
    @State private var prenom: String
    @State private var email: String
    @State private var telephone: String
    @State private var organisation: String
    @State private var typePersonne: TypePersonne?
    @State private var chantierId: UUID?
    @State private var showingAddChantier = false
    
    // Photo de la personne
    @State private var photoData: Data?
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    
    init(personne: Personne) {
        self.original = personne
        _nom = State(initialValue: personne.nom)
        _prenom = State(initialValue: personne.prenom)
        _email = State(initialValue: personne.email)
        _telephone = State(initialValue: personne.telephone)
        _organisation = State(initialValue: personne.organisation)
        _typePersonne = State(initialValue: personne.typePersonne)
        _chantierId = State(initialValue: personne.chantierId)
        _photoData = State(initialValue: personne.photoData)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Section Photo
                Section(LocalizedStringKey("Photo")) {
                    VStack(spacing: 12) {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            HStack {
                                Spacer()
                                Button(role: .destructive) { photoData = nil } label: {
                                    Label(LocalizedStringKey("Retirer la photo"), systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(width: 120, height: 120)
                                VStack(spacing: 6) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 40))
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
                                    Label(LocalizedStringKey("Prendre"), systemImage: "camera.fill")
                                }
                                .buttonStyle(.bordered)
                            }
                            Button(action: { showPhotoLibraryPicker = true }) {
                                Label(LocalizedStringKey(photoData == nil ? "Choisir" : "Changer"), systemImage: "photo.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Section(LocalizedStringKey("Identité")) {
                    TextField(LocalizedStringKey("Prénom"), text: $prenom)
                    TextField(LocalizedStringKey("Nom"), text: $nom)
                }
                
                Section(LocalizedStringKey("Type de personne")) {
                    Picker(LocalizedStringKey("Type"), selection: $typePersonne) {
                        Label(LocalizedStringKey("Client"), systemImage: "person.fill")
                            .tag(TypePersonne?.some(.client))
                        Label(LocalizedStringKey("Mécanicien"), systemImage: "wrench.and.screwdriver.fill")
                            .tag(TypePersonne?.some(.mecanicien))
                        Label(LocalizedStringKey("Salarié"), systemImage: "person.badge.clock.fill")
                            .tag(TypePersonne?.some(.salarie))
                        Label(LocalizedStringKey("Agence Location Matériel"), systemImage: "building.2.fill")
                            .tag(TypePersonne?.some(.alm))
                    }
                    .pickerStyle(.menu)
                }
                
                // Section Chantier (visible uniquement pour les salariés)
                if typePersonne == .salarie {
                    Section(LocalizedStringKey("Chantier")) {
                        Picker(LocalizedStringKey("Chantier assigné"), selection: $chantierId) {
                            Text(LocalizedStringKey("Aucun chantier")).tag(UUID?.none)
                            ForEach(dataManager.chantiers.filter { $0.estActif }) { chantier in
                                Text(chantier.nom).tag(UUID?.some(chantier.id))
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Button(action: { showingAddChantier = true }) {
                            Label(LocalizedStringKey("Ajouter un chantier"), systemImage: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(LocalizedStringKey("Contact")) {
                    TextField(LocalizedStringKey("Email"), text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField(LocalizedStringKey("Téléphone"), text: $telephone)
                        .keyboardType(.phonePad)
                }
                
                Section(LocalizedStringKey("Organisation")) {
                    TextField(LocalizedStringKey("Organisation"), text: $organisation)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Modifier la personne"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Enregistrer")) { enregistrer() }
                        .disabled(nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prenom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingAddChantier) {
                AjouterChantierView { nouveauChantierId in
                    chantierId = nouveauChantierId
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                PersonneImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let image = newImage {
                            photoData = image.jpegData(compressionQuality: 0.7)
                        }
                    }
                ), sourceType: .camera)
            }
            .sheet(isPresented: $showPhotoLibraryPicker) {
                PersonneImagePicker(image: Binding(
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
    
    private func enregistrer() {
        var updated = Personne(
            id: original.id,
            nom: nom,
            prenom: prenom,
            email: email,
            telephone: telephone,
            organisation: organisation,
            typePersonne: typePersonne,
            chantierId: typePersonne == .salarie ? chantierId : nil,
            photoData: photoData
        )
        updated.dateDernierEmail = original.dateDernierEmail
        dataManager.modifierPersonne(updated)
        dismiss()
    }
}

#if canImport(MessageUI)
struct MailComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var subject: String
    var body: String
    var onResult: ((MFMailComposeResult) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        init(parent: MailComposeView) { self.parent = parent }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) { [self] in
                parent.onResult?(result)
            }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(recipients)
        if !subject.isEmpty { vc.setSubject(subject) }
        if !body.isEmpty { vc.setMessageBody(body, isHTML: false) }
        vc.mailComposeDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

struct SMSComposerView: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    var onResult: ((MessageComposeResult) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: SMSComposerView
        init(parent: SMSComposerView) { self.parent = parent }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { [self] in
                parent.onResult?(result)
            }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        if !body.isEmpty { vc.body = body }
        vc.messageComposeDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
}
#endif

// MARK: - Fusion des doublons

struct FusionDoublonsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var groupesDoublons: [[Personne]] {
        dataManager.trouverDoublonsPersonnes()
    }
    
    var body: some View {
        NavigationView {
            List {
                if groupesDoublons.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(LocalizedStringKey("Aucun doublon détecté"))
                        }
                    }
                } else {
                    ForEach(groupesDoublons.indices, id: \.self) { index in
                        Section {
                            GroupeDoublonView(personnes: groupesDoublons[index])
                        } header: {
                            if let premier = groupesDoublons[index].first {
                                Text("\(premier.nomComplet) (\(groupesDoublons[index].count) entrées)")
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Fusion des doublons"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Fermer")) { dismiss() }
                }
            }
        }
    }
}

struct GroupeDoublonView: View {
    let personnes: [Personne]
    @EnvironmentObject var dataManager: DataManager
    @State private var showingConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(personnes) { personne in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(personne.nomComplet)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if personne.id == personnes.first?.id {
                            Text("(conservé)")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    if !personne.email.isEmpty {
                        Text(personne.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !personne.organisation.isEmpty {
                        Text(personne.organisation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    let nbPrets = dataManager.getPretsPourPersonne(personne.id).count
                    let nbEmprunts = dataManager.getEmpruntsPourPersonne(personne.id).count
                    if nbPrets > 0 || nbEmprunts > 0 {
                        Text("\(nbPrets) prêt(s), \(nbEmprunts) emprunt(s)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
                
                if personne.id != personnes.last?.id {
                    Divider()
                }
            }
            
            Button(action: { showingConfirmation = true }) {
                Label(LocalizedStringKey("Fusionner ces personnes"), systemImage: "arrow.triangle.merge")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.top, 8)
            .confirmationDialog(
                LocalizedStringKey("Confirmer la fusion"),
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button(LocalizedStringKey("Fusionner"), role: .destructive) {
                    dataManager.fusionnerPersonnes(personnes)
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {}
            } message: {
                if let premier = personnes.first {
                    Text("Les \(personnes.count - 1) doublon(s) seront supprimés. Tous les prêts et emprunts seront transférés vers \(premier.nomComplet).")
                }
            }
        }
    }
}

// MARK: - Vues de liste filtrées par personne

/// Vue affichant tous les prêts d'une personne spécifique
struct PretListePersonneView: View {
    let personneId: UUID
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var filtre = "Tous"
    private let filtreOptions = ["Tous", "En cours", "Retournés"]
    
    var personne: Personne? {
        dataManager.getPersonne(id: personneId)
    }
    
    var pretsFiltres: [Pret] {
        var prets = dataManager.getPretsPourPersonne(personneId)
        switch filtre {
        case "En cours": prets = prets.filter { $0.estActif }
        case "Retournés": prets = prets.filter { $0.estRetourne }
        default: break
        }
        return prets.sorted { $0.dateDebut > $1.dateDebut }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Picker(LocalizedStringKey("Filtre"), selection: $filtre) {
                    ForEach(filtreOptions, id: \.self) { option in
                        Text(LocalizedStringKey(option))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if pretsFiltres.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(LocalizedStringKey("Aucun prêt"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(pretsFiltres) { pret in
                            PretRowView(pret: pret)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
        .navigationTitle(personne?.nomComplet ?? NSLocalizedString("Prêts", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Vue affichant tous les emprunts d'une personne spécifique
struct EmpruntListePersonneView: View {
    let personneId: UUID
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var filtre = "Tous"
    private let filtreOptions = ["Tous", "En cours", "Rendus"]
    
    var personne: Personne? {
        dataManager.getPersonne(id: personneId)
    }
    
    var empruntsFiltres: [Emprunt] {
        var emprunts = dataManager.getEmpruntsPourPersonne(personneId)
        switch filtre {
        case "En cours": emprunts = emprunts.filter { $0.estActif }
        case "Rendus": emprunts = emprunts.filter { $0.estRetourne }
        default: break
        }
        return emprunts.sorted { $0.dateDebut > $1.dateDebut }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Picker(LocalizedStringKey("Filtre"), selection: $filtre) {
                    ForEach(filtreOptions, id: \.self) { option in
                        Text(LocalizedStringKey(option))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if empruntsFiltres.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(LocalizedStringKey("Aucun emprunt"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(empruntsFiltres) { emprunt in
                            EmpruntRowView(emprunt: emprunt)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
        .navigationTitle(personne?.nomComplet ?? NSLocalizedString("Emprunts", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Vue affichant toutes les locations d'une personne spécifique
struct LocationListePersonneView: View {
    let personneId: UUID
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var filtre = "Tous"
    private let filtreOptions = ["Tous", "En cours", "Terminées"]
    
    var personne: Personne? {
        dataManager.getPersonne(id: personneId)
    }
    
    var locationsFiltrees: [Location] {
        var locations = dataManager.getLocationsPourPersonne(personneId)
        switch filtre {
        case "En cours": locations = locations.filter { $0.estActive }
        case "Terminées": locations = locations.filter { $0.estTerminee }
        default: break
        }
        return locations.sorted { $0.dateDebut > $1.dateDebut }
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
                Picker(LocalizedStringKey("Filtre"), selection: $filtre) {
                    ForEach(filtreOptions, id: \.self) { option in
                        Text(LocalizedStringKey(option))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if locationsFiltrees.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(LocalizedStringKey("Aucune location"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(locationsFiltrees) { location in
                            LocationRowView(location: location)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
        .navigationTitle(personne?.nomComplet ?? NSLocalizedString("Locations", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Vue compacte d'une réparation pour la fiche réparateur
struct ReparationRowCompactView: View {
    let reparation: Reparation
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let materiel = dataManager.getMateriel(id: reparation.materielId) {
                    Text(materiel.nom)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text(LocalizedStringKey("Matériel inconnu"))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if reparation.estEnRetard {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    Image(systemName: "wrench.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            if !reparation.description.isEmpty {
                Text(reparation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey("Début:"))
                    Text(formatDate(reparation.dateDebut))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                if let dateFin = reparation.dateFinPrevue {
                    Text("•")
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("Fin prévue:"))
                        Text(formatDate(dateFin))
                    }
                    .font(.caption)
                    .foregroundColor(reparation.estEnRetard ? .red : .secondary)
                }
            }
            
            if let cout = reparation.coutEstime, cout > 0 {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey("Coût estimé:"))
                    Text(String(format: "%.2f €", cout))
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Vue d'une réparation impayée avec bouton de validation du paiement
struct ReparationImpayeeRowView: View {
    let reparation: Reparation
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var montant: Double {
        reparation.coutFinal ?? reparation.coutEstime ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let materiel = dataManager.getMateriel(id: reparation.materielId) {
                    Text(materiel.nom)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text(LocalizedStringKey("Matériel inconnu"))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text(String(format: "%.2f €", montant))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            if !reparation.description.isEmpty {
                Text(reparation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 8) {
                if let dateRetour = reparation.dateRetour {
                    Text(LocalizedStringKey("Terminée le: \(formatDate(dateRetour))"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Bouton pour valider le paiement individuel
            Button(action: {
                dataManager.marquerPaiementReparation(reparation.id, recu: true)
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(LocalizedStringKey("Valider le paiement"))
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

/// Vue compacte d'une MaLocation pour la fiche personne ALM
struct MaLocationRowCompactView: View {
    let maLocation: MaLocation
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(maLocation.nomObjet)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if maLocation.estEnRetard {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.purple)
                        .font(.caption)
                }
            }
            
            HStack(spacing: 8) {
                Text(LocalizedStringKey("Retour prévu: \(formatDate(maLocation.dateFin))"))
                    .font(.caption)
                    .foregroundColor(maLocation.estEnRetard ? .red : .secondary)
                
                if maLocation.estEnRetard {
                    Text("(\(maLocation.joursRetard) \(localizedString("jour(s) de retard", language: appLanguage)))")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 8) {
                Text(String(format: "%.2f €", maLocation.prixTotal))
                    .font(.caption)
                    .foregroundColor(.purple)
                
                if !maLocation.paiementEffectue {
                    Text("⚠️")
                    Text(LocalizedStringKey("Non payé"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Vue affichant toutes les réparations d'un réparateur spécifique
struct ReparationListeReparateurView: View {
    let reparateurId: UUID
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var filtre = "Tous"
    private let filtreOptions = ["Tous", "En cours", "Terminées"]
    
    var reparateur: Personne? {
        dataManager.getPersonne(id: reparateurId)
    }
    
    var reparationsFiltrees: [Reparation] {
        var reparations = dataManager.getReparationsPourReparateur(reparateurId)
        switch filtre {
        case "En cours": reparations = reparations.filter { $0.estEnCours }
        case "Terminées": reparations = reparations.filter { $0.estTerminee }
        default: break
        }
        return reparations.sorted { $0.dateDebut > $1.dateDebut }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Picker(LocalizedStringKey("Filtre"), selection: $filtre) {
                    ForEach(filtreOptions, id: \.self) { option in
                        Text(LocalizedStringKey(option))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if reparationsFiltrees.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(LocalizedStringKey("Aucune réparation"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(reparationsFiltrees) { reparation in
                            ReparationRowView(reparation: reparation)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
        .navigationTitle(reparateur?.nomComplet ?? NSLocalizedString("Réparations", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Vue détaillée d'une réparation avec actions (depuis la fiche personne)
struct ReparationDetailFromPersonneView: View {
    let reparation: Reparation
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var showingRetourSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingReglementSheet = false
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: appLanguage)
        return formatter.string(from: date)
    }
    
    // Récupérer la version courante de la réparation
    var reparationCourante: Reparation {
        dataManager.reparations.first { $0.id == reparation.id } ?? reparation
    }
    
    var body: some View {
        List {
            // Section Matériel
            Section(LocalizedStringKey("Matériel")) {
                if let materiel = dataManager.getMateriel(id: reparationCourante.materielId) {
                    HStack(spacing: 12) {
                        if let data = materiel.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                                .frame(width: 60, height: 60)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(materiel.nom)
                                .font(.headline)
                            if let desc = materiel.description as String?, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                } else {
                    Text(LocalizedStringKey("Matériel inconnu"))
                        .foregroundColor(.orange)
                }
            }
            
            // Section Réparateur
            Section(LocalizedStringKey("Réparateur")) {
                if let reparateur = dataManager.getPersonne(id: reparationCourante.reparateurId) {
                    HStack {
                        Label(reparateur.nomComplet, systemImage: "person.fill")
                        Spacer()
                        if !reparateur.telephone.isEmpty {
                            Text(reparateur.telephone)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(LocalizedStringKey("Réparateur inconnu"))
                        .foregroundColor(.orange)
                }
            }
            
            // Section Dates
            Section(LocalizedStringKey("Dates")) {
                LabeledContent(LocalizedStringKey("Date de début"), value: formatDate(reparationCourante.dateDebut))
                
                if let dateFin = reparationCourante.dateFinPrevue {
                    HStack {
                        Text(LocalizedStringKey("Fin prévue"))
                        Spacer()
                        Text(formatDate(dateFin))
                            .foregroundColor(reparationCourante.estEnRetard ? .red : .primary)
                    }
                }
                
                if let dateRetour = reparationCourante.dateRetour {
                    LabeledContent(LocalizedStringKey("Date de retour"), value: formatDate(dateRetour))
                }
                
                // Statut
                HStack {
                    Text(LocalizedStringKey("Statut"))
                    Spacer()
                    if reparationCourante.estTerminee {
                        Label(LocalizedStringKey("Terminée"), systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if reparationCourante.estEnRetard {
                        Label("\(reparationCourante.joursRetard) \(NSLocalizedString("jour(s) de retard", comment: ""))", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    } else {
                        Label(LocalizedStringKey("En cours"), systemImage: "wrench.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Section Description
            if !reparationCourante.description.isEmpty {
                Section(LocalizedStringKey("Description")) {
                    Text(reparationCourante.description)
                }
            }
            
            // Section Coûts
            Section(LocalizedStringKey("Coûts")) {
                if let coutEstime = reparationCourante.coutEstime, coutEstime > 0 {
                    LabeledContent(LocalizedStringKey("Coût estimé"), value: String(format: "%.2f €", coutEstime))
                }
                
                if let coutFinal = reparationCourante.coutFinal, coutFinal > 0 {
                    LabeledContent(LocalizedStringKey("Coût final"), value: String(format: "%.2f €", coutFinal))
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text(LocalizedStringKey("Paiement"))
                    Spacer()
                    if reparationCourante.paiementRecu {
                        Label(LocalizedStringKey("Payé"), systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    } else {
                        Label(LocalizedStringKey("Non payé"), systemImage: "clock")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Section Notes
            if !reparationCourante.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section(LocalizedStringKey("Notes")) {
                    Text(reparationCourante.notes)
                        .font(.callout)
                }
            }
            
            // Section Actions
            Section {
                // Bouton Valider le retour (si en cours)
                if reparationCourante.estEnCours {
                    Button {
                        showingRetourSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(LocalizedStringKey("Valider le retour de réparation"))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Bouton Marquer payé (si pas encore payé et coût > 0)
                if !reparationCourante.paiementRecu && ((reparationCourante.coutEstime ?? 0) > 0 || (reparationCourante.coutFinal ?? 0) > 0) {
                    Button {
                        showingReglementSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "eurosign.circle.fill")
                                .foregroundColor(.green)
                            Text(LocalizedStringKey("Régler la réparation"))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Bouton Supprimer (si terminée)
                if reparationCourante.estTerminee {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text(LocalizedStringKey("Supprimer cette réparation"))
                        }
                    }
                }
            } header: {
                Text(LocalizedStringKey("Actions"))
            }
        }
        .navigationTitle(LocalizedStringKey("Détail réparation"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRetourSheet) {
            ValiderRetourReparationFromPersonneView(reparation: reparationCourante)
        }
        .sheet(isPresented: $showingReglementSheet) {
            ReglementReparationView(reparation: reparationCourante)
        }
        .alert(LocalizedStringKey("Confirmer la suppression"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                dataManager.supprimerReparation(reparationCourante)
                dismiss()
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer cette réparation ?"))
        }
    }
}

/// Vue pour valider le retour d'une réparation (depuis la fiche personne)
struct ValiderRetourReparationFromPersonneView: View {
    let reparation: Reparation
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var notes: String = ""
    
    init(reparation: Reparation) {
        self.reparation = reparation
        _notes = State(initialValue: reparation.notes)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(LocalizedStringKey("Retour de réparation"))
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
        dataManager.validerRetourReparation(
            reparation.id,
            notes: notes
        )
        dismiss()
    }
}

// MARK: - Vue pour ajouter un chantier
struct AjouterChantierView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var onChantierCreated: ((UUID) -> Void)?
    
    @State private var nom = ""
    @State private var adresse = ""
    @State private var description = ""
    @State private var dateDebut: Date? = nil
    @State private var dateFin: Date? = nil
    @State private var notes = ""
    @State private var hasDateDebut = false
    @State private var hasDateFin = false
    @State private var selectedContactId: UUID? = nil
    @State private var showingContactSelection = false
    
    private var contactSelectionne: Personne? {
        guard let id = selectedContactId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    private var contactsDisponibles: [Personne] {
        dataManager.personnes.filter { $0.typePersonne != .salarie }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Informations")) {
                    TextField(LocalizedStringKey("Nom du chantier"), text: $nom)
                    TextField(LocalizedStringKey("Adresse"), text: $adresse)
                    TextField(LocalizedStringKey("Description"), text: $description)
                }
                
                Section(LocalizedStringKey("Contact")) {
                    Button {
                        showingContactSelection = true
                    } label: {
                        if let contact = contactSelectionne {
                            HStack(spacing: 12) {
                                if let data = contact.photoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(couleurPourTypePersonne(contact.typePersonne))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: contact.typePersonne?.icon ?? "person.fill")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .medium))
                                        )
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let type = contact.typePersonne {
                                        Text(LocalizedStringKey(type.rawValue))
                                            .font(.caption)
                                            .foregroundColor(couleurPourTypePersonne(type))
                                    }
                                }
                                Spacer()
                                Button { selectedContactId = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Text(LocalizedStringKey("Contact principal"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(LocalizedStringKey("Aucun"))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section(LocalizedStringKey("Période")) {
                    Toggle(LocalizedStringKey("Date de début"), isOn: $hasDateDebut)
                    if hasDateDebut {
                        DatePicker(LocalizedStringKey("Début"), selection: Binding(
                            get: { dateDebut ?? Date() },
                            set: { dateDebut = $0 }
                        ), displayedComponents: .date)
                    }
                    
                    Toggle(LocalizedStringKey("Date de fin"), isOn: $hasDateFin)
                    if hasDateFin {
                        DatePicker(LocalizedStringKey("Fin"), selection: Binding(
                            get: { dateFin ?? Date() },
                            set: { dateFin = $0 }
                        ), displayedComponents: .date)
                    }
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(LocalizedStringKey("Nouveau chantier"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Ajouter")) {
                        ajouterChantier()
                    }
                    .disabled(nom.isEmpty)
                }
            }
            .sheet(isPresented: $showingContactSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $selectedContactId,
                    personnes: contactsDisponibles,
                    title: LocalizedStringKey("Contact principal"),
                    showAddButton: false
                )
            }
        }
    }
    
    private func ajouterChantier() {
        let chantier = Chantier(
            nom: nom,
            adresse: adresse,
            description: description,
            dateDebut: hasDateDebut ? dateDebut : nil,
            dateFin: hasDateFin ? dateFin : nil,
            notes: notes,
            contactId: selectedContactId
        )
        dataManager.ajouterChantier(chantier)
        onChantierCreated?(chantier.id)
        dismiss()
    }
}

// MARK: - Vue pour modifier un chantier
struct ModifierChantierView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    let chantier: Chantier
    
    @State private var nom: String
    @State private var adresse: String
    @State private var description: String
    @State private var dateDebut: Date?
    @State private var dateFin: Date?
    @State private var notes: String
    @State private var estActif: Bool
    @State private var hasDateDebut: Bool
    @State private var hasDateFin: Bool
    @State private var selectedContactId: UUID?
    @State private var showingContactSelection = false
    
    private var contactSelectionne: Personne? {
        guard let id = selectedContactId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    private var contactsDisponibles: [Personne] {
        dataManager.personnes.filter { $0.typePersonne != .salarie }
    }
    
    init(chantier: Chantier) {
        self.chantier = chantier
        _nom = State(initialValue: chantier.nom)
        _adresse = State(initialValue: chantier.adresse)
        _description = State(initialValue: chantier.description)
        _dateDebut = State(initialValue: chantier.dateDebut)
        _dateFin = State(initialValue: chantier.dateFin)
        _notes = State(initialValue: chantier.notes)
        _estActif = State(initialValue: chantier.estActif)
        _hasDateDebut = State(initialValue: chantier.dateDebut != nil)
        _hasDateFin = State(initialValue: chantier.dateFin != nil)
        _selectedContactId = State(initialValue: chantier.contactId)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Informations")) {
                    TextField(LocalizedStringKey("Nom du chantier"), text: $nom)
                    TextField(LocalizedStringKey("Adresse"), text: $adresse)
                    TextField(LocalizedStringKey("Description"), text: $description)
                }
                
                Section(LocalizedStringKey("Contact")) {
                    Button {
                        showingContactSelection = true
                    } label: {
                        if let contact = contactSelectionne {
                            HStack(spacing: 12) {
                                if let data = contact.photoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(couleurPourTypePersonne(contact.typePersonne))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: contact.typePersonne?.icon ?? "person.fill")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .medium))
                                        )
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.nomComplet)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let type = contact.typePersonne {
                                        Text(LocalizedStringKey(type.rawValue))
                                            .font(.caption)
                                            .foregroundColor(couleurPourTypePersonne(type))
                                    }
                                }
                                Spacer()
                                Button { selectedContactId = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Text(LocalizedStringKey("Contact principal"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(LocalizedStringKey("Aucun"))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section(LocalizedStringKey("Période")) {
                    Toggle(LocalizedStringKey("Date de début"), isOn: $hasDateDebut)
                    if hasDateDebut {
                        DatePicker(LocalizedStringKey("Début"), selection: Binding(
                            get: { dateDebut ?? Date() },
                            set: { dateDebut = $0 }
                        ), displayedComponents: .date)
                    }
                    
                    Toggle(LocalizedStringKey("Date de fin"), isOn: $hasDateFin)
                    if hasDateFin {
                        DatePicker(LocalizedStringKey("Fin"), selection: Binding(
                            get: { dateFin ?? Date() },
                            set: { dateFin = $0 }
                        ), displayedComponents: .date)
                    }
                }
                
                Section(LocalizedStringKey("Statut")) {
                    Toggle(LocalizedStringKey("Chantier actif"), isOn: $estActif)
                }
                
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(LocalizedStringKey("Modifier le chantier"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Enregistrer")) {
                        enregistrerModifications()
                    }
                    .disabled(nom.isEmpty)
                }
            }
            .sheet(isPresented: $showingContactSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $selectedContactId,
                    personnes: contactsDisponibles,
                    title: LocalizedStringKey("Contact principal"),
                    showAddButton: false
                )
            }
        }
    }
    
    private func enregistrerModifications() {
        var modifiedChantier = chantier
        modifiedChantier.nom = nom
        modifiedChantier.adresse = adresse
        modifiedChantier.description = description
        modifiedChantier.dateDebut = hasDateDebut ? dateDebut : nil
        modifiedChantier.dateFin = hasDateFin ? dateFin : nil
        modifiedChantier.notes = notes
        modifiedChantier.estActif = estActif
        modifiedChantier.contactId = selectedContactId
        dataManager.modifierChantier(modifiedChantier)
        dismiss()
    }
}

// MARK: - Vue liste des chantiers (accessible depuis les paramètres ou le menu salariés)
struct ChantierListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var chantierToDelete: Chantier?
    @State private var searchText = ""
    @State private var shareItem: IdentifiableURL?
    @State private var showingImportPicker = false
    @State private var showingImportSuccessAlert = false
    @State private var showingImportErrorAlert = false
    
    var chantiersFiltres: [Chantier] {
        if searchText.isEmpty {
            return dataManager.chantiers
        }
        return dataManager.chantiers.filter { chantier in
            chantier.nom.localizedCaseInsensitiveContains(searchText) ||
            chantier.adresse.localizedCaseInsensitiveContains(searchText) ||
            chantier.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            Section {
                Button(action: { showingAddSheet = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text(LocalizedStringKey("Ajouter un chantier"))
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
            }
            
            ForEach(chantiersFiltres) { chantier in
                NavigationLink(destination: ChantierDetailView(chantier: chantier)) {
                    ChantierRowView(chantier: chantier)
                }
            }
            .onDelete { offsets in
                if let index = offsets.first {
                    chantierToDelete = chantiersFiltres[index]
                    showingDeleteAlert = true
                }
            }
        }
        .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher un chantier"))
        .navigationTitle(LocalizedStringKey("Chantiers"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section {
                        Button(action: { exporterTousChantiersPDF() }) {
                            Label(LocalizedStringKey("Exporter en PDF"), systemImage: "doc.richtext")
                        }
                        Button(action: { exporterTousChantiersJSON() }) {
                            Label(LocalizedStringKey("Exporter en JSON"), systemImage: "doc.text")
                        }
                    }
                    Section {
                        Button(action: { showingImportPicker = true }) {
                            Label(LocalizedStringKey("Importer JSON"), systemImage: "square.and.arrow.down")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AjouterChantierView()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                // Accès sécurisé au fichier
                guard url.startAccessingSecurityScopedResource() else {
                    showingImportErrorAlert = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                if dataManager.importerChantiers(from: url) {
                    showingImportSuccessAlert = true
                } else {
                    showingImportErrorAlert = true
                }
            case .failure(let error):
                print("[ChantierListView] Erreur sélection fichier: \(error)")
                showingImportErrorAlert = true
            }
        }
        .alert(LocalizedStringKey("Import réussi"), isPresented: $showingImportSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Les chantiers ont été importés avec succès."))
        }
        .alert(LocalizedStringKey("Erreur d'import"), isPresented: $showingImportErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Impossible d'importer le fichier. Vérifiez qu'il s'agit d'un export de chantiers valide."))
        }
        .alert(LocalizedStringKey("Supprimer ce chantier ?"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                if let chantier = chantierToDelete {
                    dataManager.supprimerChantier(chantier)
                }
                chantierToDelete = nil
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) {
                chantierToDelete = nil
            }
        } message: {
            Text(LocalizedStringKey("Les salariés assignés à ce chantier ne seront plus affectés."))
        }
    }
    
    // MARK: - Export JSON tous les chantiers
    private func exporterTousChantiersJSON() {
        let chantiersExport = dataManager.chantiers.map { chantier in
            // Récupérer le contact si présent
            var contactExport: ContactExport? = nil
            if let contactId = chantier.contactId, let contact = dataManager.getPersonne(id: contactId) {
                contactExport = ContactExport(
                    nom: contact.nom,
                    prenom: contact.prenom,
                    telephone: contact.telephone,
                    email: contact.email,
                    organisation: contact.organisation
                )
            }
            
            return ChantierExportComplet(
                id: chantier.id,
                nom: chantier.nom,
                adresse: chantier.adresse,
                description: chantier.description,
                dateDebut: chantier.dateDebut,
                dateFin: chantier.dateFin,
                notes: chantier.notes,
                estActif: chantier.estActif,
                contact: contactExport,
                salaries: dataManager.salariesPourChantier(chantier.id).map {
                    SalarieExportComplet(nom: $0.nom, prenom: $0.prenom, telephone: $0.telephone, email: $0.email)
                }
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(chantiersExport) else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "Chantiers_\(dateFormatter.string(from: Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: tempURL)
            shareItem = IdentifiableURL(url: tempURL)
        } catch {
            print("Erreur export JSON: \(error)")
        }
    }
    
    // MARK: - Export PDF tous les chantiers
    private func exporterTousChantiersPDF() {
        let pdfData = genererPDFTousChantiers()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "Chantiers_\(dateFormatter.string(from: Date())).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: tempURL)
            shareItem = IdentifiableURL(url: tempURL)
        } catch {
            print("Erreur export PDF: \(error)")
        }
    }
    
    private func genererPDFTousChantiers() -> Data {
        let pageWidth: CGFloat = 595.0  // A4
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 40.0
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        let data = pdfRenderer.pdfData { context in
            var yPosition: CGFloat = margin
            
            func nouvellePage() {
                context.beginPage()
                // Fond blanc explicite
                UIColor.white.setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                yPosition = margin
            }
            
            func verifierEspace(_ hauteurRequise: CGFloat) {
                if yPosition + hauteurRequise > pageHeight - margin - 30 {
                    ajouterPiedDePage()
                    nouvellePage()
                }
            }
            
            func ajouterPiedDePage() {
                let footerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .long
                dateFormatter.timeStyle = .short
                let footer = "Exporté le \(dateFormatter.string(from: Date()))"
                footer.draw(at: CGPoint(x: margin, y: pageHeight - margin), withAttributes: footerAttributes)
            }
            
            // Première page
            nouvellePage()
            
            // Titre principal
            let mainTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.orange
            ]
            "Liste des Chantiers".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: mainTitleAttributes)
            yPosition += 40
            
            // Sous-titre avec statistiques
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray
            ]
            let nbActifs = dataManager.chantiers.filter { $0.estActif }.count
            let nbTermines = dataManager.chantiers.count - nbActifs
            let stats = "\(dataManager.chantiers.count) chantier(s) • \(nbActifs) actif(s) • \(nbTermines) terminé(s)"
            stats.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: statsAttributes)
            yPosition += 30
            
            // Ligne séparatrice
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: yPosition))
            linePath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            UIColor.orange.setStroke()
            linePath.lineWidth = 2
            linePath.stroke()
            yPosition += 30
            
            // Attributs réutilisables
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray
            ]
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]
            
            // Parcourir tous les chantiers
            for (index, chantier) in dataManager.chantiers.enumerated() {
                let salaries = dataManager.salariesPourChantier(chantier.id)
                let hasContact = chantier.contactId != nil
                let hauteurChantier: CGFloat = 120 + CGFloat(salaries.count * 18) + (hasContact ? 18 : 0)
                
                verifierEspace(hauteurChantier)
                
                // Numéro et nom du chantier
                let statusColor: UIColor
                let statusIcon: String
                switch chantier.statut {
                case "En préparation":
                    statusColor = UIColor.systemBlue
                    statusIcon = "◐"
                case "Actif":
                    statusColor = UIColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1.0)
                    statusIcon = "●"
                default:
                    statusColor = UIColor.gray
                    statusIcon = "○"
                }
                
                let chantierTitle = "\(index + 1). \(chantier.nom)"
                chantierTitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
                
                // Badge statut
                let statusText = chantier.statut
                let statusAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: statusColor
                ]
                "\(statusIcon) \(statusText)".draw(at: CGPoint(x: pageWidth - margin - 60, y: yPosition + 4), withAttributes: statusAttributes)
                yPosition += 28
                
                // Adresse
                if !chantier.adresse.isEmpty {
                    "📍 ".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: valueAttributes)
                    chantier.adresse.draw(at: CGPoint(x: margin + 30, y: yPosition), withAttributes: valueAttributes)
                    yPosition += 18
                }
                
                // Période
                if !chantier.periode.isEmpty {
                    "📅 ".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: valueAttributes)
                    chantier.periode.draw(at: CGPoint(x: margin + 30, y: yPosition), withAttributes: valueAttributes)
                    yPosition += 18
                }
                
                // Contact du chantier
                if let contactId = chantier.contactId, let contact = dataManager.getPersonne(id: contactId) {
                    "👤 Contact: ".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: labelAttributes)
                    var contactInfo = contact.nomComplet
                    if !contact.telephone.isEmpty { contactInfo += " - ☎ \(contact.telephone)" }
                    if !contact.email.isEmpty { contactInfo += " - \(contact.email)" }
                    contactInfo.draw(at: CGPoint(x: margin + 80, y: yPosition), withAttributes: valueAttributes)
                    yPosition += 18
                }
                
                // Salariés
                if !salaries.isEmpty {
                    "👷 Salariés (\(salaries.count)):".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: labelAttributes)
                    yPosition += 16
                    
                    for salarie in salaries {
                        var salarieInfo = "   • \(salarie.nomComplet)"
                        if !salarie.telephone.isEmpty {
                            salarieInfo += " - \(salarie.telephone)"
                        }
                        salarieInfo.draw(at: CGPoint(x: margin + 20, y: yPosition), withAttributes: valueAttributes)
                        yPosition += 16
                    }
                } else {
                    let emptyAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.italicSystemFont(ofSize: 10),
                        .foregroundColor: UIColor.gray
                    ]
                    "   Aucun salarié assigné".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: emptyAttributes)
                    yPosition += 16
                }
                
                // Ligne séparatrice légère
                yPosition += 10
                let separatorPath = UIBezierPath()
                separatorPath.move(to: CGPoint(x: margin, y: yPosition))
                separatorPath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
                UIColor.lightGray.setStroke()
                separatorPath.lineWidth = 0.5
                separatorPath.stroke()
                yPosition += 15
            }
            
            // Pied de page final
            ajouterPiedDePage()
        }
        
        return data
    }
}

// Structures pour l'export global des chantiers
private struct ChantierExportComplet: Codable {
    let id: UUID
    let nom: String
    let adresse: String
    let description: String
    let dateDebut: Date?
    let dateFin: Date?
    let notes: String
    let estActif: Bool
    let contact: ContactExport?
    let salaries: [SalarieExportComplet]
}

private struct ContactExport: Codable {
    let nom: String
    let prenom: String
    let telephone: String
    let email: String
    let organisation: String
}

private struct SalarieExportComplet: Codable {
    let nom: String
    let prenom: String
    let telephone: String
    let email: String
}

// MARK: - Vue ligne de chantier
struct ChantierRowView: View {
    let chantier: Chantier
    @EnvironmentObject var dataManager: DataManager
    
    var nombreSalaries: Int {
        dataManager.salariesPourChantier(chantier.id).count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(chantier.nom)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(LocalizedStringKey(chantier.statut))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(chantier.statut == "Actif" ? Color.green : (chantier.statut == "En préparation" ? Color.blue : Color.gray))
                    .cornerRadius(4)
            }
            
            if !chantier.adresse.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(chantier.adresse)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                if !chantier.periode.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(chantier.periode)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(nombreSalaries)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Vue détail d'un chantier
struct ChantierDetailView: View {
    let chantier: Chantier
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAffecterSalarie = false
    @State private var salarieToRemove: Personne?
    @State private var showingRemoveAlert = false
    @State private var showingCreerSalarieAlert = false
    @State private var showingAddPersonne = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    
    var salariesAssignes: [Personne] {
        dataManager.salariesPourChantier(chantier.id)
    }
    
    var salariesDisponibles: [Personne] {
        dataManager.salariesSansChantier()
    }
    
    var chantierActuel: Chantier {
        dataManager.chantiers.first { $0.id == chantier.id } ?? chantier
    }
    
    // Génère l'URL pour ouvrir l'adresse dans Plans/Maps
    private func mapsURL(for address: String) -> URL? {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "maps://?q=\(encodedAddress)")
    }
    
    var body: some View {
        List {
            // Informations principales
            Section(LocalizedStringKey("Informations")) {
                LabeledContent(LocalizedStringKey("Nom"), value: chantierActuel.nom)
                
                if !chantierActuel.adresse.isEmpty {
                    Button(action: {
                        if let url = mapsURL(for: chantierActuel.adresse) {
                            openURL(url)
                        }
                    }) {
                        HStack {
                            Text(LocalizedStringKey("Adresse"))
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 6) {
                                Text(chantierActuel.adresse)
                                    .foregroundColor(.blue)
                                    .multilineTextAlignment(.trailing)
                                Image(systemName: "map.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                if !chantierActuel.description.isEmpty {
                    LabeledContent(LocalizedStringKey("Description"), value: chantierActuel.description)
                }
                
                LabeledContent(LocalizedStringKey("Statut")) {
                    Text(LocalizedStringKey(chantierActuel.statut))
                        .foregroundColor(chantierActuel.statut == "Actif" ? .green : (chantierActuel.statut == "En préparation" ? .blue : .gray))
                }
            }
            
            // Période
            if chantierActuel.dateDebut != nil || chantierActuel.dateFin != nil {
                Section(LocalizedStringKey("Période")) {
                    if let debut = chantierActuel.dateDebut {
                        LabeledContent(LocalizedStringKey("Début"), value: formatDate(debut))
                    }
                    if let fin = chantierActuel.dateFin {
                        LabeledContent(LocalizedStringKey("Fin"), value: formatDate(fin))
                    }
                }
            }
            
            // Contact principal
            if let contactId = chantierActuel.contactId,
               let contact = dataManager.personnes.first(where: { $0.id == contactId }) {
                Section(LocalizedStringKey("Contact")) {
                    NavigationLink(destination: PersonneDetailView(personne: contact)) {
                        HStack(spacing: 12) {
                            // Photo ou cercle coloré
                            if let data = contact.photoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .medium))
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.nomComplet)
                                    .font(.body)
                                if !contact.telephone.isEmpty {
                                    Text(contact.telephone)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if !contact.email.isEmpty {
                                    Text(contact.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            // Salariés assignés avec bouton d'ajout
            Section {
                // Bouton pour affecter un salarié
                Button(action: {
                    if salariesDisponibles.isEmpty {
                        showingCreerSalarieAlert = true
                    } else {
                        showingAffecterSalarie = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(LocalizedStringKey("Affecter un salarié"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                if salariesAssignes.isEmpty {
                    Text(LocalizedStringKey("Aucun salarié assigné"))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(salariesAssignes) { personne in
                        HStack {
                            NavigationLink(destination: PersonneDetailView(personne: personne)) {
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
                                            .fill(Color.orange)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: "person.badge.clock.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 16, weight: .medium))
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(personne.nomComplet)
                                            .font(.body)
                                        if !personne.telephone.isEmpty {
                                            Text(personne.telephone)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                salarieToRemove = personne
                                showingRemoveAlert = true
                            } label: {
                                Label(LocalizedStringKey("Retirer"), systemImage: "person.badge.minus")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text(LocalizedStringKey("Salariés assignés"))
                    Spacer()
                    Text("\(salariesAssignes.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            
            // Notes
            if !chantierActuel.notes.isEmpty {
                Section(LocalizedStringKey("Notes")) {
                    Text(chantierActuel.notes)
                        .foregroundColor(.secondary)
                }
            }
            
            // Actions
            Section {
                Button(action: { showingEditSheet = true }) {
                    Label(LocalizedStringKey("Modifier le chantier"), systemImage: "pencil")
                }
                
                Button(role: .destructive, action: { showingDeleteAlert = true }) {
                    Label(LocalizedStringKey("Supprimer le chantier"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(chantierActuel.nom)
        .sheet(isPresented: $showingEditSheet) {
            ModifierChantierView(chantier: chantierActuel)
        }
        .sheet(isPresented: $showingAffecterSalarie) {
            AffecterSalarieAuChantierView(chantier: chantierActuel)
        }
        .sheet(isPresented: $showingAddPersonne) {
            AjouterPersonneView(defaultTypePersonne: .salarie, defaultChantierId: chantierActuel.id)
        }
        .alert(LocalizedStringKey("Aucun salarié disponible"), isPresented: $showingCreerSalarieAlert) {
            Button(LocalizedStringKey("Oui")) {
                showingAddPersonne = true
            }
            Button(LocalizedStringKey("Non"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Voulez-vous créer un nouveau salarié ?"))
        }
        .alert(LocalizedStringKey("Supprimer ce chantier ?"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                dataManager.supprimerChantier(chantierActuel)
                dismiss()
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Les salariés assignés à ce chantier ne seront plus affectés."))
        }
        .alert(LocalizedStringKey("Retirer ce salarié ?"), isPresented: $showingRemoveAlert) {
            Button(LocalizedStringKey("Retirer"), role: .destructive) {
                if let personne = salarieToRemove {
                    dataManager.retirerSalarieDuChantier(personne.id)
                }
                salarieToRemove = nil
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) {
                salarieToRemove = nil
            }
        } message: {
            if let personne = salarieToRemove {
                Text("Le salarié \(personne.nomComplet) ne sera plus affecté à ce chantier.")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
}

// MARK: - Vue pour affecter un salarié à un chantier
struct AffecterSalarieAuChantierView: View {
    let chantier: Chantier
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedSalaries: Set<UUID> = []
    @State private var showingAddPersonne = false
    @State private var showingSMSAlert = false
    @State private var salariesAvecTelephone: [Personne] = []
    @State private var showingSMSComposer = false
    @State private var smsRecipients: [String] = []
    @State private var smsBody: String = ""
    
    var salariesDisponibles: [Personne] {
        let disponibles = dataManager.salariesSansChantier()
        if searchText.isEmpty {
            return disponibles
        }
        return disponibles.filter { personne in
            personne.nom.localizedCaseInsensitiveContains(searchText) ||
            personne.prenom.localizedCaseInsensitiveContains(searchText) ||
            personne.telephone.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var tousSalaries: [Personne] {
        dataManager.personnes.filter { $0.typePersonne == .salarie }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Résumé en haut
                if !selectedSalaries.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(selectedSalaries.count) salarié(s) sélectionné(s)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: { selectedSalaries.removeAll() }) {
                            Text(LocalizedStringKey("Effacer"))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                }
                
                List {
                    // Section salariés disponibles
                    if salariesDisponibles.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "person.badge.clock")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                if tousSalaries.isEmpty {
                                    Text(LocalizedStringKey("Aucun salarié créé"))
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text(LocalizedStringKey("Créez d'abord des salariés pour pouvoir les affecter à ce chantier."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                } else {
                                    Text(LocalizedStringKey("Tous les salariés sont déjà affectés"))
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text(LocalizedStringKey("Tous vos salariés sont actuellement assignés à des chantiers."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                Button(action: { showingAddPersonne = true }) {
                                    Label(LocalizedStringKey("Créer un salarié"), systemImage: "person.badge.plus")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        }
                    } else {
                        Section {
                            ForEach(salariesDisponibles) { personne in
                                Button(action: {
                                    toggleSelection(personne.id)
                                }) {
                                    HStack(spacing: 12) {
                                        // Checkbox
                                        Image(systemName: selectedSalaries.contains(personne.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundColor(selectedSalaries.contains(personne.id) ? .orange : .secondary)
                                        
                                        // Photo ou cercle coloré
                                        if let data = personne.photoData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color.orange)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Image(systemName: "person.badge.clock.fill")
                                                        .foregroundColor(.white)
                                                        .font(.system(size: 16, weight: .medium))
                                                )
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(personne.nomComplet)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            if !personne.telephone.isEmpty {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "phone.fill")
                                                        .font(.caption2)
                                                    Text(personne.telephone)
                                                }
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Badge disponible
                                        Text(LocalizedStringKey("Disponible"))
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.green)
                                            .cornerRadius(4)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(LocalizedStringKey("Salariés disponibles"))
                        } footer: {
                            Text(LocalizedStringKey("Sélectionnez les salariés à affecter à ce chantier"))
                        }
                    }
                    
                    // Bouton créer un salarié
                    Section {
                        Button(action: { showingAddPersonne = true }) {
                            HStack {
                                Image(systemName: "person.badge.plus.fill")
                                    .foregroundColor(.orange)
                                Text(LocalizedStringKey("Créer un nouveau salarié"))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher un salarié"))
            }
            .navigationTitle(LocalizedStringKey("Affecter des salariés"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Affecter")) {
                        affecterSalariesSelectionnes()
                    }
                    .disabled(selectedSalaries.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddPersonne) {
                AjouterPersonneView(defaultTypePersonne: .salarie, defaultChantierId: chantier.id)
            }
            .alert(LocalizedStringKey("Notifier les salariés ?"), isPresented: $showingSMSAlert) {
                Button(LocalizedStringKey("Envoyer SMS")) {
                    preparerSMS()
                }
                Button(LocalizedStringKey("Non merci"), role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(LocalizedStringKey("Voulez-vous envoyer un SMS aux salariés affectés pour les informer de leur assignation au chantier ?"))
            }
            #if canImport(MessageUI)
            .sheet(isPresented: $showingSMSComposer) {
                SMSComposerView(recipients: smsRecipients, body: smsBody) { _ in
                    dismiss()
                }
            }
            #endif
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedSalaries.contains(id) {
            selectedSalaries.remove(id)
        } else {
            selectedSalaries.insert(id)
        }
    }
    
    private func affecterSalariesSelectionnes() {
        for salarieId in selectedSalaries {
            dataManager.assignerSalarieAuChantier(salarieId, chantierId: chantier.id)
        }
        
        // Vérifier si des salariés ont un numéro de téléphone pour proposer l'envoi de SMS
        salariesAvecTelephone = selectedSalaries.compactMap { salarieId in
            dataManager.personnes.first { $0.id == salarieId && !$0.telephone.isEmpty }
        }
        
        #if canImport(MessageUI)
        if !salariesAvecTelephone.isEmpty && MFMessageComposeViewController.canSendText() {
            showingSMSAlert = true
        } else {
            dismiss()
        }
        #else
        dismiss()
        #endif
    }
    
    private func preparerSMS() {
        smsRecipients = salariesAvecTelephone.map { $0.telephone }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        
        var message = NSLocalizedString("Bonjour,\n\nVous êtes affecté(e) au chantier : ", comment: "")
        message += chantier.nom
        
        if !chantier.adresse.isEmpty {
            message += "\n\(NSLocalizedString("Adresse", comment: "")) : \(chantier.adresse)"
        }
        
        if let dateDebut = chantier.dateDebut {
            message += "\n\(NSLocalizedString("Début", comment: "")) : \(dateFormatter.string(from: dateDebut))"
        }
        
        // Ajouter le contact sur site si défini
        if let contactId = chantier.contactId,
           let contact = dataManager.personnes.first(where: { $0.id == contactId }) {
            message += "\n\(NSLocalizedString("Contact sur site", comment: "")) : \(contact.nomComplet)"
            if !contact.telephone.isEmpty {
                message += " (\(contact.telephone))"
            }
        }
        
        message += "\n\n\(NSLocalizedString("Cordialement", comment: ""))"
        
        smsBody = message
        showingSMSComposer = true
    }
}

// MARK: - Image Picker pour les personnes
struct PersonneImagePicker: UIViewControllerRepresentable {
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
        let parent: PersonneImagePicker
        init(_ parent: PersonneImagePicker) { self.parent = parent }
        
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