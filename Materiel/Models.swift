//
//  Models.swift
//  Materiel
//
//  Created by Robert Oulhen on 10/11/2025.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Matériel
struct Materiel: Identifiable, Codable {
    var id = UUID()
    var nom: String
    var description: String
    var categorie: String
    var lieuStockageId: UUID?
    var localisation: String? // Localisation spécifique du matériel (ex: placard, étagère)
    var notesMateriel: String? // Notes spécifiques au matériel
    var dateAcquisition: Date
    var valeur: Double
    var imageData: Data? // Photo optionnelle du matériel
    var factureImageData: Data? // Photo de la facture d'achat
    var factureIsPDF: Bool? // true si la facture est un PDF, false ou nil si c'est une image
    var numeroFacture: String? // Numéro de facture
    var vendeur: String? // Nom du vendeur/magasin
}

// MARK: - Type de personne
enum TypePersonne: String, Codable, CaseIterable {
    case client = "Client"
    case mecanicien = "Mécanicien"
    case salarie = "Salarié"
    case alm = "ALM"
    
    var localizedName: String {
        switch self {
        case .client: return NSLocalizedString("Client", comment: "")
        case .mecanicien: return NSLocalizedString("Mécanicien", comment: "")
        case .salarie: return NSLocalizedString("Salarié", comment: "")
        case .alm: return NSLocalizedString("Agence Location Matériel", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .client: return "person.fill"
        case .mecanicien: return "wrench.and.screwdriver.fill"
        case .salarie: return "person.badge.clock.fill"
        case .alm: return "building.2.fill"
        }
    }
}

// MARK: - Personne
struct Personne: Identifiable, Codable, Hashable {
    var id = UUID()
    var nom: String
    var prenom: String
    var email: String
    var telephone: String
    var organisation: String
    var typePersonne: TypePersonne? // nil = non spécifié (ancien format), sinon Client ou Réparateur
    var dateDernierEmail: Date? // Historique du dernier email envoyé
    var chantierId: UUID? // ID du chantier assigné (pour les salariés)
    var photoData: Data? // Photo optionnelle de la personne
    
    var nomComplet: String {
        "\(prenom) \(nom)"
    }
}

// MARK: - Chantier (pour les salariés)
struct Chantier: Identifiable, Codable, Hashable {
    var id = UUID()
    var nom: String
    var adresse: String
    var description: String
    var dateDebut: Date?
    var dateFin: Date?
    var notes: String
    var estActif: Bool = true
    var contactId: UUID? // ID du contact principal pour ce chantier
    
    var periode: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if let debut = dateDebut, let fin = dateFin {
            return "\(formatter.string(from: debut)) - \(formatter.string(from: fin))"
        } else if let debut = dateDebut {
            return "Depuis le \(formatter.string(from: debut))"
        } else if let fin = dateFin {
            return "Jusqu'au \(formatter.string(from: fin))"
        }
        return ""
    }
    
    /// Retourne le statut du chantier: "En préparation", "Actif" ou "Terminé"
    var statut: String {
        // Si la date de début n'est pas encore atteinte, le chantier est en préparation
        if let debut = dateDebut, debut > Date() {
            return "En préparation"
        }
        // Sinon, on regarde si le chantier est actif ou terminé
        return estActif ? "Actif" : "Terminé"
    }
    
    /// Retourne la couleur associée au statut
    var statutColor: String {
        switch statut {
        case "En préparation":
            return "blue"
        case "Actif":
            return "green"
        default:
            return "gray"
        }
    }
}

// MARK: - Lieu de stockage
struct LieuStockage: Identifiable, Codable {
    var id = UUID()
    var nom: String
    var adresse: String
    var batiment: String
    var etage: String
    var salle: String
    var notes: String
    
    var adresseComplete: String {
        var composants: [String] = []
        if !batiment.isEmpty { composants.append(batiment) }
        if !etage.isEmpty { composants.append("Étage \(etage)") }
        if !salle.isEmpty { composants.append("Salle \(salle)") }
        return composants.joined(separator: ", ")
    }
}

// MARK: - Prêt
struct Pret: Identifiable, Codable {
    var id = UUID()
    var materielId: UUID
    var personneId: UUID
    var lieuId: UUID?
    var dateDebut: Date
    var dateFin: Date
    var dateRetourEffectif: Date?
    var notes: String
    
    var estEnRetard: Bool {
        guard dateRetourEffectif == nil else { return false }
        return Date() > dateFin
    }
    
    var estRetourne: Bool {
        return dateRetourEffectif != nil
    }
    
    var estActif: Bool {
        return dateRetourEffectif == nil
    }
    
    var joursRetard: Int {
        guard estEnRetard else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dateFin, to: Date())
        return components.day ?? 0
    }
}

// MARK: - Emprunt (objet prêté à moi)
struct Emprunt: Identifiable, Codable {
    var id = UUID()
    var nomObjet: String
    var personneId: UUID // Personne qui me prête l'objet
    var dateDebut: Date
    var dateFin: Date
    var dateRetourEffectif: Date?
    var notes: String
    var imageData: Data? // Photo optionnelle de l'objet emprunté
    var materielLieId: UUID? // ID du matériel créé à partir de cet emprunt
    var pretActifId: UUID? // ID du prêt actif si l'emprunt est re-prêté
    var locationActifId: UUID? // ID de la location active si l'emprunt est sous-loué
    var reparationActifId: UUID? // ID de la réparation active si l'emprunt est en réparation

    var estEnRetard: Bool {
        guard dateRetourEffectif == nil else { return false }
        return Date() > dateFin
    }
    var estRetourne: Bool { dateRetourEffectif != nil }
    var estActif: Bool { dateRetourEffectif == nil }
    var joursRetard: Int {
        guard estEnRetard else { return 0 }
        let components = Calendar.current.dateComponents([.day], from: dateFin, to: Date())
        return components.day ?? 0
    }
}

// MARK: - Coffre-fort (objets de valeur pour assurance)
struct CoffreItem: Identifiable, Codable {
    var id: UUID
    var nom: String
    var description: String
    var categorie: String
    var valeurEstimee: Double
    var dateAcquisition: Date
    var dateCreation: Date
    var photoData: Data?
    var factureData: Data?
    var factureIsPDF: Bool? // true si la facture est un PDF, false ou nil si c'est une image
    var numeroSerie: String?
    var marque: String?
    var modele: String?
    var notes: String?
    
    init(
        id: UUID = UUID(),
        nom: String,
        description: String,
        categorie: String,
        valeurEstimee: Double,
        dateAcquisition: Date,
        dateCreation: Date = Date(),
        photoData: Data? = nil,
        factureData: Data? = nil,
        factureIsPDF: Bool? = nil,
        numeroSerie: String? = nil,
        marque: String? = nil,
        modele: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.nom = nom
        self.description = description
        self.categorie = categorie
        self.valeurEstimee = valeurEstimee
        self.dateAcquisition = dateAcquisition
        self.dateCreation = dateCreation
        self.photoData = photoData
        self.factureData = factureData
        self.factureIsPDF = factureIsPDF
        self.numeroSerie = numeroSerie
        self.marque = marque
        self.modele = modele
        self.notes = notes
    }
    
    // Catégories prédéfinies pour le coffre-fort
    static let categoriesPredefinies = [
        "Électronique",
        "Bijoux",
        "Art & Décoration",
        "Mobilier",
        "Électroménager",
        "Instruments de musique",
        "Sport & Loisirs",
        "Véhicules",
        "Vêtements de valeur",
        "Collections",
        "Autre"
    ]
}

// MARK: - Location (location payante de matériel)
struct Location: Identifiable, Codable {
    var id = UUID()
    var materielId: UUID
    var locataireId: UUID // Personne qui loue
    var dateDebut: Date
    var dateFin: Date
    var dateRetourEffectif: Date?
    var prixTotal: Double // Prix total de la location
    var caution: Double // Caution demandée
    var cautionRendue: Bool // La caution a-t-elle été rendue ?
    var cautionGardee: Bool = false // La caution a-t-elle été gardée (problème avec matériel)
    var montantCautionGardee: Double = 0 // Montant de caution gardée (peut être partiel)
    var paiementRecu: Bool // Le paiement a-t-il été reçu ?
    var typeTarif: TypeTarif // Type de tarification
    var prixUnitaire: Double = 0 // Prix par jour/semaine/mois
    var notes: String
    var sousLocationActifId: UUID? = nil // ID de la sous-location active (si l'objet est sous-loué)
    
    enum TypeTarif: String, Codable, CaseIterable {
        case jour = "Jour"
        case semaine = "Semaine"
        case mois = "Mois"
        case forfait = "Forfait"
        
        var localizedName: String {
            switch self {
            case .jour: return NSLocalizedString("Jour", comment: "")
            case .semaine: return NSLocalizedString("Semaine", comment: "")
            case .mois: return NSLocalizedString("Mois", comment: "")
            case .forfait: return NSLocalizedString("Forfait", comment: "")
            }
        }
    }
    
    var estEnRetard: Bool {
        guard dateRetourEffectif == nil else { return false }
        return Date() > dateFin
    }
    
    var estTerminee: Bool {
        return dateRetourEffectif != nil
    }
    
    var estActive: Bool {
        return dateRetourEffectif == nil
    }
    
    var joursRetard: Int {
        guard estEnRetard else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dateFin, to: Date())
        return components.day ?? 0
    }
    
    var dureeEnJours: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dateDebut, to: dateFin)
        return (components.day ?? 0) + 1
    }
    
    // Durée effective (entre début et retour réel)
    var dureeEffectiveEnJours: Int {
        let calendar = Calendar.current
        let finEffective = dateRetourEffectif ?? dateFin
        let components = calendar.dateComponents([.day], from: dateDebut, to: finEffective)
        return max(1, (components.day ?? 0) + 1)
    }
    
    // Nombre d'unités effectives selon le type de tarif
    var nombreUnitesEffectives: Int {
        let jours = dureeEffectiveEnJours
        switch typeTarif {
        case .jour:
            return jours
        case .semaine:
            return max(1, Int(ceil(Double(jours) / 7.0)))
        case .mois:
            return max(1, Int(ceil(Double(jours) / 30.0)))
        case .forfait:
            return 1
        }
    }
    
    // Prix calculé selon la durée effective
    var prixTotalEffectif: Double {
        if typeTarif == .forfait {
            return prixTotal // Le forfait ne change pas
        }
        return prixUnitaire * Double(nombreUnitesEffectives)
    }
    
    // MARK: - Calculs pour paiement avant retour
    
    /// Durée réelle jusqu'à aujourd'hui ou jusqu'au retour effectif
    /// Utilisé pour calculer le prix réel quand le paiement est fait avant le retour
    var dureeReelleEnJours: Int {
        let calendar = Calendar.current
        let finReelle: Date
        if let retour = dateRetourEffectif {
            // Location terminée : utiliser la date de retour
            finReelle = retour
        } else {
            // Location en cours : utiliser aujourd'hui mais pas avant la date de début
            finReelle = max(dateDebut, Date())
        }
        let components = calendar.dateComponents([.day], from: dateDebut, to: finReelle)
        return max(1, (components.day ?? 0) + 1)
    }
    
    /// Nombre d'unités réelles selon le type de tarif (basé sur la durée réelle)
    var nombreUnitesReelles: Int {
        let jours = dureeReelleEnJours
        switch typeTarif {
        case .jour:
            return jours
        case .semaine:
            return max(1, Int(ceil(Double(jours) / 7.0)))
        case .mois:
            return max(1, Int(ceil(Double(jours) / 30.0)))
        case .forfait:
            return 1
        }
    }
    
    /// Prix réel basé sur la durée réelle (jusqu'à aujourd'hui ou jusqu'au retour)
    /// C'est ce prix qui doit être utilisé pour le règlement
    var prixTotalReel: Double {
        if typeTarif == .forfait {
            return prixTotal // Le forfait ne change pas
        }
        return prixUnitaire * Double(nombreUnitesReelles)
    }
}

// MARK: - MaLocation (je loue du matériel à quelqu'un d'autre)
/// Représente une location où l'utilisateur est le locataire (il paie pour louer)
struct MaLocation: Identifiable, Codable {
    var id = UUID()
    var nomObjet: String // Nom de l'objet loué
    var loueurId: UUID // Personne à qui je loue (le propriétaire)
    var dateDebut: Date
    var dateFin: Date
    var dateRetourEffectif: Date?
    var prixTotal: Double // Prix total de la location
    var caution: Double // Caution versée
    var montantCautionRecuperee: Double = 0 // Montant de la caution récupérée
    var montantCautionPerdue: Double = 0 // Montant gardé par le loueur (dégâts, frais, etc.)
    var paiementEffectue: Bool // Le paiement a-t-il été effectué ?
    var typeTarif: Location.TypeTarif // Réutilise le même enum que Location
    var prixUnitaire: Double = 0 // Prix par jour/semaine/mois
    var notes: String
    var imageData: Data? // Photo optionnelle de l'objet loué
    var materielLieId: UUID? // ID du matériel créé à partir de cette location (pour re-prêter)
    var pretActifId: UUID? // ID du prêt actif si l'objet loué est re-prêté
    var locationActifId: UUID? // ID de la sous-location active si l'objet est sous-loué
    
    // La caution est entièrement traitée (récupérée + perdue = caution)
    var cautionTraitee: Bool {
        return (montantCautionRecuperee + montantCautionPerdue) >= caution
    }
    
    // Compatibilité : caution entièrement récupérée (sans perte)
    var cautionRecuperee: Bool {
        return montantCautionRecuperee >= caution && montantCautionPerdue == 0
    }
    
    // Montant de caution restant à traiter
    var cautionRestante: Double {
        return max(0, caution - montantCautionRecuperee - montantCautionPerdue)
    }
    
    // Y a-t-il eu une récupération partielle (pas tout récupéré) ?
    // Inclut les cas où une partie a été perdue, même si la caution est entièrement traitée
    var cautionPartiellementRecuperee: Bool {
        // Si pas de caution, pas de récupération partielle
        guard caution > 0 else { return false }
        // Récupération partielle = on a récupéré quelque chose mais pas tout (il y a eu une perte ou il reste à traiter)
        return montantCautionRecuperee > 0 && montantCautionRecuperee < caution
    }
    
    // Y a-t-il eu une perte de caution ?
    var aCautionPerdue: Bool {
        return montantCautionPerdue > 0
    }
    
    var estEnRetard: Bool {
        guard dateRetourEffectif == nil else { return false }
        return Date() > dateFin
    }
    
    var estTerminee: Bool {
        return dateRetourEffectif != nil
    }
    
    var estActive: Bool {
        return dateRetourEffectif == nil
    }
    
    var joursRetard: Int {
        guard estEnRetard else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dateFin, to: Date())
        return components.day ?? 0
    }
    
    var dureeEnJours: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dateDebut, to: dateFin)
        return (components.day ?? 0) + 1
    }
    
    // Durée effective (entre début et retour réel)
    var dureeEffectiveEnJours: Int {
        let calendar = Calendar.current
        let finEffective = dateRetourEffectif ?? dateFin
        let components = calendar.dateComponents([.day], from: dateDebut, to: finEffective)
        return max(1, (components.day ?? 0) + 1)
    }
    
    // Nombre d'unités effectives selon le type de tarif
    var nombreUnitesEffectives: Int {
        let jours = dureeEffectiveEnJours
        switch typeTarif {
        case .jour:
            return jours
        case .semaine:
            return max(1, Int(ceil(Double(jours) / 7.0)))
        case .mois:
            return max(1, Int(ceil(Double(jours) / 30.0)))
        case .forfait:
            return 1
        }
    }
    
    // Prix calculé selon la durée effective
    var prixTotalEffectif: Double {
        if typeTarif == .forfait {
            return prixTotal
        }
        return prixUnitaire * Double(nombreUnitesEffectives)
    }
    
    /// Durée réelle jusqu'à aujourd'hui ou jusqu'au retour effectif
    var dureeReelleEnJours: Int {
        let calendar = Calendar.current
        let finReelle: Date
        if let retour = dateRetourEffectif {
            finReelle = retour
        } else {
            finReelle = max(dateDebut, Date())
        }
        let components = calendar.dateComponents([.day], from: dateDebut, to: finReelle)
        return max(1, (components.day ?? 0) + 1)
    }
    
    /// Nombre d'unités réelles selon le type de tarif (basé sur la durée réelle)
    var nombreUnitesReelles: Int {
        let jours = dureeReelleEnJours
        switch typeTarif {
        case .jour:
            return jours
        case .semaine:
            return max(1, Int(ceil(Double(jours) / 7.0)))
        case .mois:
            return max(1, Int(ceil(Double(jours) / 30.0)))
        case .forfait:
            return 1
        }
    }
    
    /// Prix réel basé sur la durée réelle
    var prixTotalReel: Double {
        if typeTarif == .forfait {
            return prixTotal
        }
        return prixUnitaire * Double(nombreUnitesReelles)
    }
}

// MARK: - Réparation (matériel en réparation chez un réparateur)
struct Reparation: Identifiable, Codable {
    var id = UUID()
    var materielId: UUID // Matériel concerné
    var reparateurId: UUID // Personne (réparateur) en charge
    var pretOrigineId: UUID? // ID du prêt d'origine si vient d'un retour
    var locationOrigineId: UUID? // ID de la location d'origine si vient d'un retour location
    var dateDebut: Date // Date de mise en réparation
    var dateFinPrevue: Date? // Date de fin prévue (optionnel)
    var dateRetour: Date? // Date de retour effectif
    var description: String // Description du problème/réparation
    var coutEstime: Double? // Coût estimé
    var coutFinal: Double? // Coût final
    var paiementRecu: Bool = false // Le paiement a-t-il été effectué ?
    var notes: String
    
    var estEnCours: Bool {
        return dateRetour == nil
    }
    
    var estTerminee: Bool {
        return dateRetour != nil
    }
    
    var joursEnReparation: Int {
        let finDate = dateRetour ?? Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dateDebut, to: finDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    var estEnRetard: Bool {
        guard let dateFin = dateFinPrevue, dateRetour == nil else { return false }
        return Date() > dateFin
    }
    
    var joursRetard: Int {
        guard let dateFin = dateFinPrevue, estEnRetard else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dateFin, to: Date())
        return components.day ?? 0
    }
}

// MARK: - Opération comptable (historique permanent des transactions)
enum TypeOperation: String, Codable, CaseIterable {
    case locationRevenu = "Location (Revenu)"
    case locationCaution = "Caution gardée"
    case reparationDepense = "Réparation (Dépense)"
    case maLocationDepense = "Je loue (Dépense)"
    case maLocationCautionPerdue = "Caution perdue"
    
    var localizedName: String {
        switch self {
        case .locationRevenu: return NSLocalizedString("Location (Revenu)", comment: "")
        case .locationCaution: return NSLocalizedString("Caution gardée", comment: "")
        case .reparationDepense: return NSLocalizedString("Réparation (Dépense)", comment: "")
        case .maLocationDepense: return NSLocalizedString("Je loue (Dépense)", comment: "")
        case .maLocationCautionPerdue: return NSLocalizedString("Caution perdue", comment: "")
        }
    }
    
    var isRevenu: Bool {
        switch self {
        case .locationRevenu, .locationCaution: return true
        case .reparationDepense, .maLocationDepense, .maLocationCautionPerdue: return false
        }
    }
}

struct OperationComptable: Identifiable, Codable {
    var id = UUID()
    var date: Date // Date de l'opération
    var typeOperation: TypeOperation
    var montant: Double
    var description: String // Description de l'opération
    var materielNom: String? // Nom du matériel concerné
    var personneNom: String? // Nom de la personne concernée
    var referenceId: UUID? // ID de la location ou réparation d'origine
    
    // Composants de date pour faciliter le filtrage
    var mois: Int {
        Calendar.current.component(.month, from: date)
    }
    
    var annee: Int {
        Calendar.current.component(.year, from: date)
    }
    
    var moisAnnee: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Module Achat/Vente (Commerce indépendant)

/// Taux de TVA disponibles
enum TauxTVA: String, Codable, CaseIterable {
    case tva0 = "0%"
    case tva5_5 = "5.5%"
    case tva10 = "10%"
    case tva20 = "20%"
    
    var valeur: Double {
        switch self {
        case .tva0: return 0.0
        case .tva5_5: return 0.055
        case .tva10: return 0.10
        case .tva20: return 0.20
        }
    }
    
    var pourcentage: String {
        return self.rawValue
    }
}

/// Type de remise applicable
enum TypeRemise: String, Codable, CaseIterable {
    case aucune = "Aucune"
    case pourcentage = "Pourcentage"
    case montantFixe = "Montant fixe"
    
    var localizedName: String {
        switch self {
        case .aucune: return NSLocalizedString("Aucune remise", comment: "")
        case .pourcentage: return NSLocalizedString("Remise en %", comment: "")
        case .montantFixe: return NSLocalizedString("Remise fixe (€)", comment: "")
        }
    }
}

/// Type de transaction commerciale
enum TypeTransactionCommerce: String, Codable, CaseIterable {
    case achat = "Achat"
    case vente = "Vente"
    
    var localizedName: String {
        switch self {
        case .achat: return NSLocalizedString("Achat", comment: "")
        case .vente: return NSLocalizedString("Vente", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .achat: return "arrow.down.circle.fill"
        case .vente: return "arrow.up.circle.fill"
        }
    }
}

/// Mode de paiement
enum ModePaiement: String, Codable, CaseIterable {
    case especes = "Espèces"
    case carte = "Carte bancaire"
    case cheque = "Chèque"
    case virement = "Virement"
    case autre = "Autre"
    
    var localizedName: String {
        switch self {
        case .especes: return NSLocalizedString("Espèces", comment: "")
        case .carte: return NSLocalizedString("Carte bancaire", comment: "")
        case .cheque: return NSLocalizedString("Chèque", comment: "")
        case .virement: return NSLocalizedString("Virement", comment: "")
        case .autre: return NSLocalizedString("Autre", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .especes: return "banknote.fill"
        case .carte: return "creditcard.fill"
        case .cheque: return "doc.text.fill"
        case .virement: return "arrow.left.arrow.right.circle.fill"
        case .autre: return "ellipsis.circle.fill"
        }
    }
}

/// Article de commerce (produit à acheter/vendre)
struct ArticleCommerce: Identifiable, Codable {
    var id = UUID()
    var nom: String
    var description: String
    var categorie: String
    var reference: String // Référence/SKU du produit
    var prixAchatHT: Double // Prix d'achat HT (par unité ou par kg si vente au poids)
    var tauxTVAAchat: TauxTVA // Taux de TVA à l'achat
    var prixVenteHT: Double // Prix de vente conseillé HT (par unité ou par kg si vente au poids)
    var tauxTVAVente: TauxTVA // Taux de TVA à la vente
    var quantiteEnStock: Int
    var seuilAlerteStock: Int // Alerte si stock en dessous
    var fournisseur: String // Nom du fournisseur
    var dateCreation: Date
    var photoData: Data?
    var notes: String
    
    // MARK: - Vente au poids
    var venteAuPoids: Bool = false // Si true, les prix sont au kg et les quantités en poids
    var stockEnKg: Double = 0 // Stock en kg (utilisé si venteAuPoids = true)
    var seuilAlerteStockKg: Double = 0 // Seuil d'alerte en kg
    
    // Calculs avec arrondi à 2 décimales
    var prixAchatTTC: Double {
        return ((prixAchatHT * (1 + tauxTVAAchat.valeur)) * 100).rounded() / 100
    }
    
    var prixVenteTTC: Double {
        return ((prixVenteHT * (1 + tauxTVAVente.valeur)) * 100).rounded() / 100
    }
    
    var margeHT: Double {
        return ((prixVenteHT - prixAchatHT) * 100).rounded() / 100
    }
    
    var margePourcentage: Double {
        guard prixAchatHT > 0 else { return 0 }
        return (margeHT / prixAchatHT) * 100
    }
    
    var stockBas: Bool {
        return quantiteEnStock <= seuilAlerteStock
    }
    
    var stockBasPoids: Bool {
        return stockEnKg <= seuilAlerteStockKg
    }
    
    /// Vérifie si le stock est bas (unités ou poids selon le type d'article)
    var stockEstBas: Bool {
        return venteAuPoids ? stockBasPoids : stockBas
    }
    
    // Catégories prédéfinies pour les articles
    static let categoriesPredefinies = [
        "Électronique",
        "Vêtements",
        "Accessoires",
        "Alimentation",
        "Maison & Déco",
        "Jouets",
        "Sport & Loisirs",
        "Livres & Papeterie",
        "Bijoux",
        "Autre"
    ]
}

/// Transaction commerciale (achat ou vente)
struct TransactionCommerce: Identifiable, Codable {
    var id = UUID()
    var typeTransaction: TypeTransactionCommerce
    var articleId: UUID?
    var nomArticle: String // Copie du nom pour historique
    var quantite: Int // Quantité (pour articles à l'unité)
    var poids: Double = 0 // Poids en kg (pour articles au poids)
    var venteAuPoids: Bool = false // Si true, utilise le poids au lieu de la quantité
    var prixUnitaireHT: Double // Prix unitaire HT (par unité ou par kg)
    var tauxTVA: TauxTVA // Taux de TVA appliqué
    var typeRemise: TypeRemise
    var valeurRemise: Double // Valeur de la remise (% ou €)
    var modePaiement: ModePaiement
    var clientFournisseur: String // Nom du client (vente) ou fournisseur (achat)
    var dateTransaction: Date
    var notes: String
    var estPaye: Bool
    var dateReglement: Date? // Date de règlement prévue si non payé
    
    // Vérifie si le paiement est en retard
    var paiementEnRetard: Bool {
        guard !estPaye, let dateReglement = dateReglement else { return false }
        return Date() > dateReglement
    }
    
    // Vérifie si le paiement est bientôt dû (dans les 3 jours)
    var paiementBientotDu: Bool {
        guard !estPaye, let dateReglement = dateReglement else { return false }
        let calendar = Calendar.current
        let dans3Jours = calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return dateReglement <= dans3Jours && dateReglement >= Date()
    }
    
    // Jours restants avant le paiement
    var joursAvantReglement: Int? {
        guard !estPaye, let dateReglement = dateReglement else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: dateReglement)
        return components.day
    }
    
    // Quantité ou poids effectif pour l'affichage
    var quantiteOuPoids: String {
        if venteAuPoids {
            return String(format: "%.3f kg", poids)
        } else {
            return "\(quantite)"
        }
    }
    
    // Calculs - Remise appliquée sur le TTC
    var montantBrutHT: Double {
        if venteAuPoids {
            return ((prixUnitaireHT * poids) * 100).rounded() / 100
        } else {
            return ((prixUnitaireHT * Double(quantite)) * 100).rounded() / 100
        }
    }
    
    var montantBrutTVA: Double {
        return ((montantBrutHT * tauxTVA.valeur) * 100).rounded() / 100
    }
    
    var montantBrutTTC: Double {
        return ((montantBrutHT + montantBrutTVA) * 100).rounded() / 100
    }
    
    // Remise appliquée sur le TTC
    var montantRemise: Double {
        switch typeRemise {
        case .aucune:
            return 0
        case .pourcentage:
            return ((montantBrutTTC * (valeurRemise / 100)) * 100).rounded() / 100
        case .montantFixe:
            return min(valeurRemise, montantBrutTTC)
        }
    }
    
    var montantTTC: Double {
        return ((montantBrutTTC - montantRemise) * 100).rounded() / 100
    }
    
    // Calcul inversé du HT net après remise TTC
    var montantNetHT: Double {
        return ((montantTTC / (1 + tauxTVA.valeur)) * 100).rounded() / 100
    }
    
    var montantTVA: Double {
        return ((montantTTC - montantNetHT) * 100).rounded() / 100
    }
    
    // Composants de date pour faciliter le filtrage
    var mois: Int {
        Calendar.current.component(.month, from: dateTransaction)
    }
    
    var annee: Int {
        Calendar.current.component(.year, from: dateTransaction)
    }
    
    var moisAnnee: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: dateTransaction).capitalized
    }
}
