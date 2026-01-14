//
//  AutreView.swift
//  Materiel
//
//  Vue personnalisée pour regrouper Personnes et Lieux
//

import SwiftUI

struct AutreView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingSettings = false
    @State private var showingUserGuide = false
    @State private var showingCoffreFort = false
    @State private var showingReparations = false
    @State private var showingComptabilite = false
    @State private var showingCommerce = false
    @State private var showingMesLocations = false
    @State private var showingAlertLocationImpayee = false
    @State private var animateCards = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fond dégradé animé
                LinearGradient(
                    colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.08), Color.pink.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Section Cautions à rendre
                        let cautionsNonRendues = dataManager.locations.filter { $0.estTerminee && $0.caution > 0 && !$0.cautionRendue && !$0.cautionGardee }
                        if !cautionsNonRendues.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: LocalizedStringKey("Cautions à rendre"), icon: "eurosign.arrow.circlepath", color: .orange)
                                
                                ForEach(cautionsNonRendues) { location in
                                    CautionRowView(location: location)
                                }
                            }
                            .offset(y: animateCards ? 0 : 20)
                            .opacity(animateCards ? 1 : 0)
                        }
                        
                        // Section Gestion
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: LocalizedStringKey("Gestion"), icon: "folder.fill", color: .blue)
                            
                            VStack(spacing: 10) {
                                // Carte Personnes
                                NavigationLink(destination: PersonneListViewEmbedded()) {
                                    ModernCard(
                                        icon: "person.2.fill",
                                        title: LocalizedStringKey("Personnes"),
                                        subtitle: Text("\(dataManager.personnes.count) ") + Text(LocalizedStringKey("contact(s)")),
                                        colors: [.blue, .purple],
                                        badge: dataManager.personnes.count > 0 ? "\(dataManager.personnes.count)" : nil,
                                        badgeColor: .blue
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                // Carte Lieux
                                NavigationLink(destination: LieuListViewEmbedded()) {
                                    ModernCard(
                                        icon: "location.fill",
                                        title: LocalizedStringKey("Lieux de stockage"),
                                        subtitle: Text("\(dataManager.lieuxStockage.count) ") + Text(LocalizedStringKey("lieu(x)")),
                                        colors: [.green, .teal],
                                        badge: dataManager.lieuxStockage.count > 0 ? "\(dataManager.lieuxStockage.count)" : nil,
                                        badgeColor: .green
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                // Carte Chantiers
                                NavigationLink(destination: ChantierListView()) {
                                    let chantiersActifs = dataManager.chantiers.filter { $0.estActif }.count
                                    let nbSalariesAffectes = dataManager.personnes.filter { $0.typePersonne == .salarie && $0.chantierId != nil }.count
                                    ModernCard(
                                        icon: "hammer.fill",
                                        title: LocalizedStringKey("Chantiers"),
                                        subtitle: Text("\(chantiersActifs) ") + Text(LocalizedStringKey("actif(s)")),
                                        colors: [.orange, .red],
                                        badge: nbSalariesAffectes > 0 ? "\(nbSalariesAffectes)" : nil,
                                        badgeColor: .orange
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .offset(y: animateCards ? 0 : 20)
                        .opacity(animateCards ? 1 : 0)
                        
                        // Section Application (Locations, Je loue, Réparations)
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: LocalizedStringKey("Application"), icon: "app.badge.fill", color: .purple)
                            
                            VStack(spacing: 10) {
                                // Carte Locations
                                NavigationLink(destination: LocationListView()) {
                                    let locationsActives = dataManager.locations.filter { !$0.estTerminee }.count
                                    let locationsEnRetard = dataManager.locations.filter { $0.estEnRetard }.count
                                    let locationsImpayees = dataManager.locations.filter { $0.estTerminee && !$0.paiementRecu }.count
                                    ModernCard(
                                        icon: "eurosign.circle.fill",
                                        title: LocalizedStringKey("Locations"),
                                        subtitle: Text("\(locationsActives) ") + Text(LocalizedStringKey("en cours")),
                                        colors: [.orange, .yellow],
                                        badge: locationsActives > 0 ? "\(locationsActives)" : nil,
                                        badgeColor: locationsEnRetard > 0 ? .red : .orange,
                                        warningBadge: locationsImpayees > 0 ? "\(locationsImpayees)" : nil
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                // Carte Je loue (MaLocation)
                                Button(action: {
                                    // Vérifier s'il y a des locations terminées avec caution récupérée mais non réglées
                                    let locationsImpayeesAvecCaution = dataManager.mesLocations.filter { 
                                        $0.estTerminee && !$0.paiementEffectue && $0.montantCautionRecuperee > 0 
                                    }
                                    if !locationsImpayeesAvecCaution.isEmpty {
                                        showingAlertLocationImpayee = true
                                    } else {
                                        showingMesLocations = true
                                    }
                                }) {
                                    let mesLocationsActives = dataManager.mesLocations.filter { !$0.estTerminee }.count
                                    let mesLocationsEnRetard = dataManager.mesLocations.filter { $0.estEnRetard }.count
                                    let cautionsEnCours = dataManager.mesLocations.filter { $0.cautionRestante > 0 }.count
                                    let locationsImpayeesAvecCaution = dataManager.mesLocations.filter { 
                                        $0.estTerminee && !$0.paiementEffectue && $0.montantCautionRecuperee > 0 
                                    }.count
                                    ModernCard(
                                        icon: "cart.fill",
                                        title: LocalizedStringKey("Je loue"),
                                        subtitle: Text("\(mesLocationsActives) ") + Text(LocalizedStringKey("en cours")),
                                        colors: [.purple, .pink],
                                        badge: mesLocationsActives > 0 ? "\(mesLocationsActives)" : nil,
                                        badgeColor: mesLocationsEnRetard > 0 ? .red : .purple,
                                        warningBadge: locationsImpayeesAvecCaution > 0 ? "\(locationsImpayeesAvecCaution)" : (cautionsEnCours > 0 ? "\(cautionsEnCours)" : nil)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                // Carte Réparations
                                Button(action: { showingReparations = true }) {
                                    let reparationsEnCours = dataManager.reparations.filter { $0.estEnCours }.count
                                    let reparationsEnRetard = dataManager.reparations.filter { $0.estEnRetard }.count
                                    let reparationsImpayees = dataManager.reparations.filter { $0.estTerminee && !$0.paiementRecu }.count
                                    ModernCard(
                                        icon: "wrench.and.screwdriver.fill",
                                        title: LocalizedStringKey("Réparations"),
                                        subtitle: Text("\(reparationsEnCours) ") + Text(LocalizedStringKey("en cours")),
                                        colors: [.red, .orange],
                                        badge: reparationsEnCours > 0 ? "\(reparationsEnCours)" : nil,
                                        badgeColor: reparationsEnRetard > 0 ? .red : .orange,
                                        warningBadge: reparationsImpayees > 0 ? "\(reparationsImpayees)" : nil
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .offset(y: animateCards ? 0 : 20)
                        .opacity(animateCards ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.05), value: animateCards)
                        
                        // Section Commerce (Achat/Vente)
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: LocalizedStringKey("Commerce"), icon: "cart.fill", color: .teal)
                            
                            // Carte Commerce
                            Button(action: { showingCommerce = true }) {
                                let nbArticles = dataManager.articlesCommerce.count
                                let ventesAujourdhui = dataManager.transactionsCommerce
                                    .filter { $0.typeTransaction == .vente && Calendar.current.isDateInToday($0.dateTransaction) }
                                    .reduce(0) { $0 + $1.montantTTC }
                                ModernCard(
                                    icon: "cart.fill",
                                    title: LocalizedStringKey("Achat / Vente"),
                                    subtitle: Text("\(nbArticles) ") + Text(LocalizedStringKey("article(s)")),
                                    colors: [.teal, .green],
                                    badge: ventesAujourdhui > 0 ? String(format: "%.0f€", ventesAujourdhui) : nil,
                                    badgeColor: .green
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .offset(y: animateCards ? 0 : 20)
                        .opacity(animateCards ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: animateCards)
                        
                        // Section Sécurité
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: LocalizedStringKey("Sécurité"), icon: "shield.fill", color: .orange)
                            
                            // Carte Coffre-fort
                            Button(action: { showingCoffreFort = true }) {
                                ModernCard(
                                    icon: "lock.shield.fill",
                                    title: LocalizedStringKey("Coffre-fort"),
                                    subtitle: Text(LocalizedStringKey("Objets de valeur")),
                                    colors: [.red, .orange],
                                    badge: dataManager.coffreItems.count > 0 ? "\(dataManager.coffreItems.count)" : nil,
                                    badgeColor: .red
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .offset(y: animateCards ? 0 : 20)
                        .opacity(animateCards ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: animateCards)
                        
                        // Section Utilitaire (Réglages, Mode d'emploi, Comptabilité)
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: LocalizedStringKey("Utilitaire"), icon: "wrench.fill", color: .gray)
                            
                            VStack(spacing: 10) {
                                // Carte Réglages
                                Button(action: { showingSettings = true }) {
                                    ModernCard(
                                        icon: "gearshape.fill",
                                        title: LocalizedStringKey("Réglages"),
                                        subtitle: Text(LocalizedStringKey("Langue, sauvegarde...")),
                                        colors: [.gray, .gray.opacity(0.6)],
                                        badge: nil
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                // Carte Mode d'emploi
                                Button(action: { showingUserGuide = true }) {
                                    ModernCard(
                                        icon: "book.fill",
                                        title: LocalizedStringKey("Mode d'emploi"),
                                        subtitle: Text(LocalizedStringKey("Guide d'utilisation")),
                                        colors: [.orange, .yellow],
                                        badge: nil
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                // Carte Comptabilité
                                Button(action: { showingComptabilite = true }) {
                                    let benefice = dataManager.beneficeNetComptabilite()
                                    let nbOperations = dataManager.operationsComptables.count
                                    ModernCard(
                                        icon: "chart.bar.doc.horizontal.fill",
                                        title: LocalizedStringKey("Comptabilité"),
                                        subtitle: Text("\(nbOperations) ") + Text(LocalizedStringKey("opération(s)")),
                                        colors: [.indigo, .purple],
                                        badge: benefice != 0 ? String(format: "%.0f€", benefice) : nil,
                                        badgeColor: benefice >= 0 ? .green : .red
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .offset(y: animateCards ? 0 : 20)
                        .opacity(animateCards ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: animateCards)
                        
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle(LocalizedStringKey("Autre"))
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateCards = true
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingUserGuide) {
                UserGuideView()
            }
            .fullScreenCover(isPresented: $showingCoffreFort) {
                CoffreFortView()
            }
            .fullScreenCover(isPresented: $showingReparations) {
                ReparationListView()
            }
            .fullScreenCover(isPresented: $showingComptabilite) {
                ComptabiliteView()
            }
            .fullScreenCover(isPresented: $showingCommerce) {
                AchatVenteView()
            }
            .fullScreenCover(isPresented: $showingMesLocations) {
                MaLocationListView()
            }
            .alert(LocalizedStringKey("Attention : Location(s) impayée(s)"), isPresented: $showingAlertLocationImpayee) {
                Button(LocalizedStringKey("Voir les locations"), role: .none) {
                    showingMesLocations = true
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) { }
            } message: {
                let locationsImpayees = dataManager.mesLocations.filter { 
                    $0.estTerminee && !$0.paiementEffectue && $0.montantCautionRecuperee > 0 
                }
                let montantTotal = locationsImpayees.reduce(0) { $0 + $1.prixTotal }
                Text("Vous avez \(locationsImpayees.count) location(s) terminée(s) avec caution récupérée mais dont le paiement n'a pas été effectué.\n\nMontant total dû : \(String(format: "%.2f", montantTotal)) €")
            }
        }
    }
}

// MARK: - Composants réutilisables pour AutreView

struct StatBubble: View {
    let icon: String
    let value: String
    let label: LocalizedStringKey
    let colors: [Color]
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: colors[0].opacity(0.4), radius: 6, x: 0, y: 3)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.leading, 4)
    }
}

struct ModernCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: Text
    let colors: [Color]
    let badge: String?
    var badgeColor: Color = .red
    var warningBadge: String? = nil // Badge d'avertissement pour impayés
    
    var body: some View {
        HStack(spacing: 14) {
            // Icône avec dégradé
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: colors[0].opacity(0.35), radius: 6, x: 0, y: 3)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                subtitle
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Badge d'avertissement impayés (triangle rouge)
            if let warningBadge = warningBadge {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(warningBadge)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.red)
                )
            }
            
            // Badge optionnel avec couleur personnalisable
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(badgeColor)
                    )
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [colors[0].opacity(0.3), colors[1].opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Version sans NavigationView pour l'intégration
struct PersonneListViewEmbedded: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSheet = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    @State private var searchText = ""
    @State private var showingFusionSheet = false
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    @State private var filtreType = "Tous"
    
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
    
    // Nombre de groupes de doublons
    var nombreDoublons: Int {
        dataManager.trouverDoublonsPersonnes().count
    }
    
    // Nombre de prêts orphelins (sans personne valide)
    var nombrePretsOrphelins: Int {
        dataManager.getPretsOrphelins().count
    }
    
    // Nombre d'emprunts orphelins (sans personne valide)
    var nombreEmpruntsOrphelins: Int {
        dataManager.getEmpruntsOrphelins().count
    }
    
    @State private var showingOrphelinsSheet = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Bouton Ajouter (en dehors de la List)
                Button(action: { 
                    if dataManager.peutAjouterPersonne() {
                        showingAddSheet = true
                    } else {
                        showingLimitAlert = true
                    }
                }) {
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
                .padding(.bottom, 12)
                
                // Picker filtre type de personne (en dehors de la List)
                Picker(LocalizedStringKey("Type de personne"), selection: $filtreType) {
                    Text(LocalizedStringKey("Tous")).tag("Tous")
                    Text(LocalizedStringKey("Clients")).tag("Clients")
                    Text(LocalizedStringKey("Mécaniciens")).tag("Mécaniciens")
                    Text(LocalizedStringKey("Salariés")).tag("Salariés")
                    Text(LocalizedStringKey("ALM")).tag("ALM")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                List {
                // Section alertes: doublons et orphelins
                if nombreDoublons > 0 || nombrePretsOrphelins > 0 || nombreEmpruntsOrphelins > 0 {
                    Section {
                        // Doublons
                        if nombreDoublons > 0 {
                            Button(action: { showingFusionSheet = true }) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey("Doublons détectés"))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("\(nombreDoublons) groupe(s) de personnes en doublon")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.blue.opacity(0.1))
                        }
                        
                        // Prêts orphelins
                        if nombrePretsOrphelins > 0 {
                            Button(action: { showingOrphelinsSheet = true }) {
                                HStack {
                                    Image(systemName: "arrow.up.forward.circle.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey("Prêts sans personne"))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("\(nombrePretsOrphelins) prêt(s) à réaffecter")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.orange.opacity(0.1))
                        }
                        
                        // Emprunts orphelins
                        if nombreEmpruntsOrphelins > 0 {
                            Button(action: { showingOrphelinsSheet = true }) {
                                HStack {
                                    Image(systemName: "arrow.down.forward.circle.fill")
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey("Emprunts sans personne"))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("\(nombreEmpruntsOrphelins) emprunt(s) à réaffecter")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.purple.opacity(0.1))
                        }
                    } header: {
                        Text(LocalizedStringKey("Alertes"))
                    }
                }
                
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingFusionSheet = true }) {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AjouterPersonneView()
        }
        .sheet(isPresented: $showingFusionSheet) {
            FusionDoublonsView()
        }
        .sheet(isPresented: $showingOrphelinsSheet) {
            OrphelinsView()
        }
        .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
            Button(LocalizedStringKey("Passer à Premium")) {
                showPremiumSheet = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Limite personnes atteinte"))
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumView()
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

// Version sans NavigationView pour l'intégration
struct LieuListViewEmbedded: View {
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
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            List {
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle(LocalizedStringKey("Lieux de stockage"))
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
    }
}

// MARK: - CautionRowView
struct CautionRowView: View {
    let location: Location
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "eurosign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            // Infos
            VStack(alignment: .leading, spacing: 4) {
                if let materiel = dataManager.materiels.first(where: { $0.id == location.materielId }) {
                    Text(materiel.nom)
                        .font(.headline)
                } else {
                    Text(LocalizedStringKey("Matériel inconnu"))
                        .font(.headline)
                }
                
                if let locataire = dataManager.personnes.first(where: { $0.id == location.locataireId }) {
                    Text(locataire.nom)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let dateRetour = location.dateRetourEffectif {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("Terminée le"))
                        Text(dateRetour.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Montant caution
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(location.caution, specifier: "%.2f") €")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Button {
                    dataManager.marquerCautionRendue(location.id, rendue: true)
                } label: {
                    Text(LocalizedStringKey("Rendre"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Vue des orphelins (Prêts et Emprunts sans personne)
struct OrphelinsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    var pretsOrphelins: [Pret] {
        dataManager.getPretsOrphelins()
    }
    
    var empruntsOrphelins: [Emprunt] {
        dataManager.getEmpruntsOrphelins()
    }
    
    var body: some View {
        NavigationView {
            List {
                if pretsOrphelins.isEmpty && empruntsOrphelins.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(LocalizedStringKey("Aucun orphelin détecté"))
                        }
                    }
                } else {
                    // Prêts orphelins
                    if !pretsOrphelins.isEmpty {
                        Section {
                            ForEach(pretsOrphelins) { pret in
                                OrphelinPretRowView(pret: pret)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "arrow.up.forward.circle.fill")
                                    .foregroundColor(.orange)
                                Text(LocalizedStringKey("Prêts sans personne"))
                            }
                        }
                    }
                    
                    // Emprunts orphelins
                    if !empruntsOrphelins.isEmpty {
                        Section {
                            ForEach(empruntsOrphelins) { emprunt in
                                OrphelinEmpruntRowView(emprunt: emprunt)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "arrow.down.forward.circle.fill")
                                    .foregroundColor(.purple)
                                Text(LocalizedStringKey("Emprunts sans personne"))
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Orphelins"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Fermer")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OrphelinPretRowView: View {
    let pret: Pret
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAffectation = false
    @State private var showingDeleteAlert = false
    
    var materielNom: String {
        dataManager.materiels.first { $0.id == pret.materielId }?.nom ?? "Matériel inconnu"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(materielNom)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(LocalizedStringKey("Personne supprimée"))
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Depuis le \(pret.dateDebut.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            // Bouton Supprimer
            Button(action: { showingDeleteAlert = true }) {
                Text(LocalizedStringKey("Supprimer"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // Bouton Affecter
            Button(action: { showingAffectation = true }) {
                Text(LocalizedStringKey("Affecter"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingAffectation) {
            ReaffecterPretView(pret: pret)
        }
        .alert(LocalizedStringKey("Supprimer ce prêt ?"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                dataManager.supprimerPret(pret)
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Le prêt sera définitivement supprimé. Le matériel redeviendra disponible."))
        }
    }
}

struct OrphelinEmpruntRowView: View {
    let emprunt: Emprunt
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAffectation = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(emprunt.nomObjet)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(LocalizedStringKey("Personne supprimée"))
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Depuis le \(emprunt.dateDebut.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            // Bouton Supprimer
            Button(action: { showingDeleteAlert = true }) {
                Text(LocalizedStringKey("Supprimer"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // Bouton Affecter
            Button(action: { showingAffectation = true }) {
                Text(LocalizedStringKey("Affecter"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingAffectation) {
            AffecterEmpruntView(emprunt: emprunt)
        }
        .alert(LocalizedStringKey("Supprimer cet emprunt ?"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                dataManager.supprimerEmprunt(emprunt)
            }
            Button(LocalizedStringKey("Annuler"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("L'emprunt sera définitivement supprimé."))
        }
    }
}

#Preview {
    AutreView()
        .environmentObject(DataManager())
}
