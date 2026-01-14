//
//  DataManager.swift
//  Materiel
//
//  Created by Robert Oulhen on 10/11/2025.
//

import Foundation
import SwiftUI
import Combine
import PDFKit
import UserNotifications

// MARK: - Compression d'images pour export
extension UIImage {
    /// Compresse et redimensionne l'image selon les paramètres de qualité
    func compressedForExport() -> UIImage {
        let qualityRaw = UserDefaults.standard.string(forKey: "App.ImageExportQuality") ?? "medium"
        let quality = ImageExportQuality(rawValue: qualityRaw) ?? .medium
        
        // Si qualité originale, retourner l'image telle quelle
        if quality == .original {
            return self
        }
        
        // Redimensionner si nécessaire
        let maxDim = quality.maxDimension
        var newImage = self
        
        if maxDim > 0 && (size.width > maxDim || size.height > maxDim) {
            let ratio = min(maxDim / size.width, maxDim / size.height)
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                newImage = resized
            }
            UIGraphicsEndImageContext()
        }
        
        // Compresser en JPEG et recréer UIImage
        if let jpegData = newImage.jpegData(compressionQuality: quality.compressionQuality),
           let compressed = UIImage(data: jpegData) {
            return compressed
        }
        
        return newImage
    }
    
    /// Compresse l'image et retourne les données JPEG compressées
    func compressedDataForExport() -> Data? {
        let qualityRaw = UserDefaults.standard.string(forKey: "App.ImageExportQuality") ?? "medium"
        let quality = ImageExportQuality(rawValue: qualityRaw) ?? .medium
        
        // Si qualité originale, retourner les données originales
        if quality == .original {
            return self.jpegData(compressionQuality: 1.0)
        }
        
        // Redimensionner si nécessaire
        let maxDim = quality.maxDimension
        var newImage = self
        
        if maxDim > 0 && (size.width > maxDim || size.height > maxDim) {
            let ratio = min(maxDim / size.width, maxDim / size.height)
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                newImage = resized
            }
            UIGraphicsEndImageContext()
        }
        
        // Retourner les données JPEG compressées
        return newImage.jpegData(compressionQuality: quality.compressionQuality)
    }
    
    /// Prépare une facture pour l'export PDF avec haute qualité
    /// Les factures ont besoin d'une meilleure lisibilité que les photos
    func preparedForInvoiceExport() -> UIImage {
        // Utiliser une qualité plus élevée pour les factures (lisibilité du texte)
        let maxDim: CGFloat = 2400 // Plus grande dimension pour les factures
        let compressionQuality: CGFloat = 0.92 // Haute qualité pour la lisibilité
        
        var newImage = self
        
        // Redimensionner si l'image est trop grande
        if size.width > maxDim || size.height > maxDim {
            let ratio = min(maxDim / size.width, maxDim / size.height)
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            
            // Utiliser un rendu haute qualité
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.preferredRange = .standard
            
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            newImage = renderer.image { context in
                // Activer l'interpolation haute qualité
                context.cgContext.interpolationQuality = .high
                draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        
        // Compresser avec haute qualité et recréer UIImage
        if let jpegData = newImage.jpegData(compressionQuality: compressionQuality),
           let compressed = UIImage(data: jpegData) {
            return compressed
        }
        
        return newImage
    }
}

/// Compresse les données d'image selon les paramètres de qualité d'export
func compressImageData(_ data: Data?) -> Data? {
    guard let data = data, let image = UIImage(data: data) else { return data }
    return image.compressedDataForExport()
}

@MainActor
class DataManager: ObservableObject {
    // MARK: - Singleton pour accès depuis App Intents (Siri)
    static let shared = DataManager()
    
    @Published var materiels: [Materiel] = []
    @Published var personnes: [Personne] = []
    @Published var lieuxStockage: [LieuStockage] = []
    @Published var chantiers: [Chantier] = [] // Liste des chantiers pour les salariés
    @Published var prets: [Pret] = []
    @Published var emprunts: [Emprunt] = []
    @Published var coffreItems: [CoffreItem] = []
    @Published var locations: [Location] = []
    @Published var reparations: [Reparation] = []
    @Published var mesLocations: [MaLocation] = [] // Je loue du matériel à quelqu'un
    @Published var operationsComptables: [OperationComptable] = []
    
    // MARK: - Module Commerce (Achat/Vente indépendant)
    @Published var articlesCommerce: [ArticleCommerce] = []
    @Published var transactionsCommerce: [TransactionCommerce] = []
    @Published var categoriesCommercePersonnalisees: [String] = []
    @Published var fournisseursCommercePersonnalises: [String] = []
    @Published var fournisseursCommerceExclus: [String] = [] // Fournisseurs exclus de la liste de sélection
    
    // MARK: - Compteurs persistants (total créé depuis l'installation)
    @Published var totalMaterielsCreated: Int {
        didSet { UserDefaults.standard.set(totalMaterielsCreated, forKey: "totalMaterielsCreated") }
    }
    @Published var totalPretsCreated: Int {
        didSet { UserDefaults.standard.set(totalPretsCreated, forKey: "totalPretsCreated") }
    }
    @Published var totalEmpruntsCreated: Int {
        didSet { UserDefaults.standard.set(totalEmpruntsCreated, forKey: "totalEmpruntsCreated") }
    }
    @Published var totalPersonnesCreated: Int {
        didSet { UserDefaults.standard.set(totalPersonnesCreated, forKey: "totalPersonnesCreated") }
    }
    @Published var totalCoffreItemsCreated: Int {
        didSet { UserDefaults.standard.set(totalCoffreItemsCreated, forKey: "totalCoffreItemsCreated") }
    }
    @Published var totalLieuxCreated: Int {
        didSet { UserDefaults.standard.set(totalLieuxCreated, forKey: "totalLieuxCreated") }
    }
    @Published var totalLocationsCreated: Int {
        didSet { UserDefaults.standard.set(totalLocationsCreated, forKey: "totalLocationsCreated") }
    }
    @Published var totalReparationsCreated: Int {
        didSet { UserDefaults.standard.set(totalReparationsCreated, forKey: "totalReparationsCreated") }
    }
    @Published var totalMesLocationsCreated: Int {
        didSet { UserDefaults.standard.set(totalMesLocationsCreated, forKey: "totalMesLocationsCreated") }
    }
    
    // MARK: - Limites de la version
    // Utilise StoreManager pour vérifier si l'utilisateur est Premium
    private var storeManager: StoreManager { StoreManager.shared }
    
    var limiteMateriels: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freeMaterielLimit 
    }
    var limitePersonnes: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freePersonneLimit 
    }
    var limiteLieux: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freeLieuLimit 
    }
    var limitePrets: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freePretLimit 
    }
    var limiteEmprunts: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freeEmpruntLimit 
    }
    var limiteCoffre: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freeCoffreLimit 
    }
    var limiteLocations: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freeLocationLimit 
    }
    var limiteReparations: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freeReparationLimit 
    }
    var limiteMesLocations: Int { 
        storeManager.hasUnlockedPremium ? Int.max : StoreManager.freeMaLocationLimit 
    }
    
    // Nombre de créations restantes
    var materielsRestants: Int {
        max(0, limiteMateriels - totalMaterielsCreated)
    }
    var pretsRestants: Int {
        max(0, limitePrets - totalPretsCreated)
    }
    var empruntsRestants: Int {
        max(0, limiteEmprunts - totalEmpruntsCreated)
    }
    var personnesRestantes: Int {
        max(0, limitePersonnes - totalPersonnesCreated)
    }
    var coffreItemsRestants: Int {
        max(0, limiteCoffre - totalCoffreItemsCreated)
    }
    var lieuxRestants: Int {
        max(0, limiteLieux - totalLieuxCreated)
    }
    var locationsRestantes: Int {
        max(0, limiteLocations - totalLocationsCreated)
    }
    var reparationsRestantes: Int {
        max(0, limiteReparations - totalReparationsCreated)
    }
    var mesLocationsRestantes: Int {
        max(0, limiteMesLocations - totalMesLocationsCreated)
    }
    
    // Synchroniser les compteurs avec le nombre réel d'éléments actuels
    func synchroniserCompteurs() {
        objectWillChange.send()
        totalMaterielsCreated = materiels.count
        totalPretsCreated = prets.count  // Tous les prêts (actifs et retournés)
        totalEmpruntsCreated = emprunts.count  // Tous les emprunts (actifs et retournés)
        totalPersonnesCreated = personnes.count
        totalCoffreItemsCreated = coffreItems.count
        totalLieuxCreated = lieuxStockage.count
        totalReparationsCreated = reparations.count
        totalMesLocationsCreated = mesLocations.count
        print("[DataManager] Compteurs synchronisés: Mat=\(totalMaterielsCreated), Prets=\(totalPretsCreated), Emp=\(totalEmpruntsCreated), Pers=\(totalPersonnesCreated), Lieux=\(totalLieuxCreated), Coffre=\(totalCoffreItemsCreated), Rep=\(totalReparationsCreated), MesLoc=\(totalMesLocationsCreated)")
    }
    
    private let materielsKey = "materiels"
    private let personnesKey = "personnes"
    private let lieuxKey = "lieuxStockage"
    private let chantiersKey = "chantiers"
    private let pretsKey = "prets"
    private let empruntsKey = "emprunts"
    private let coffreKey = "coffreItems"
    private let locationsKey = "locations"
    private let reparationsKey = "reparations"
    private let mesLocationsKey = "mesLocations"
    private let operationsComptablesKey = "operationsComptables"
    private let articlesCommerceKey = "articlesCommerce"
    private let transactionsCommerceKey = "transactionsCommerce"
    private let categoriesCommerceKey = "categoriesCommercePersonnalisees"
    private let fournisseursCommerceKey = "fournisseursCommercePersonnalises"
    private let fournisseursExclusKey = "fournisseursCommerceExclus"
    private lazy var baseDirectory: URL = {
        do {
            return try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)
                .appendingPathComponent("Persist", isDirectory: true)
        } catch {
            print("[DataManager] Erreur accès ApplicationSupport: \(error). Fallback Documents.")
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Persist", isDirectory: true)
        }
    }()
    private var saveCancellable: AnyCancellable?
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
    
    init() {
        // Charger les compteurs persistants
        self.totalMaterielsCreated = UserDefaults.standard.integer(forKey: "totalMaterielsCreated")
        self.totalPretsCreated = UserDefaults.standard.integer(forKey: "totalPretsCreated")
        self.totalEmpruntsCreated = UserDefaults.standard.integer(forKey: "totalEmpruntsCreated")
        self.totalPersonnesCreated = UserDefaults.standard.integer(forKey: "totalPersonnesCreated")
        self.totalCoffreItemsCreated = UserDefaults.standard.integer(forKey: "totalCoffreItemsCreated")
        self.totalLieuxCreated = UserDefaults.standard.integer(forKey: "totalLieuxCreated")
        self.totalLocationsCreated = UserDefaults.standard.integer(forKey: "totalLocationsCreated")
        self.totalReparationsCreated = UserDefaults.standard.integer(forKey: "totalReparationsCreated")
        self.totalMesLocationsCreated = UserDefaults.standard.integer(forKey: "totalMesLocationsCreated")
        
        preparerDossier()
        chargerDonnees()
        configurerAutosave()
        
        // Migration: si les compteurs sont à 0 mais qu'il y a des données existantes,
        // initialiser les compteurs avec le nombre actuel (actifs seulement pour prêts/emprunts)
        if totalMaterielsCreated == 0 && !materiels.isEmpty {
            totalMaterielsCreated = materiels.count
        }
        if totalPretsCreated == 0 && !prets.isEmpty {
            totalPretsCreated = prets.filter { $0.estActif }.count
        }
        if totalEmpruntsCreated == 0 && !emprunts.isEmpty {
            totalEmpruntsCreated = emprunts.filter { $0.estActif }.count
        }
        if totalPersonnesCreated == 0 && !personnes.isEmpty {
            totalPersonnesCreated = personnes.count
        }
        if totalCoffreItemsCreated == 0 && !coffreItems.isEmpty {
            totalCoffreItemsCreated = coffreItems.count
        }
        if totalLieuxCreated == 0 && !lieuxStockage.isEmpty {
            totalLieuxCreated = lieuxStockage.count
        }
        if totalLocationsCreated == 0 && !locations.isEmpty {
            totalLocationsCreated = locations.filter { $0.estActive }.count
        }
        if totalMesLocationsCreated == 0 && !mesLocations.isEmpty {
            totalMesLocationsCreated = mesLocations.filter { $0.estActive }.count
        }
        
        // Configurer les notifications de rappel de paiement
        demanderAutorisationNotifications()
        replanifierToutesLesNotificationsPaiement()
    }
    
    // MARK: - Persistance
    func chargerDonnees() {
        // Migration: essayer fichier, sinon UserDefaults puis écrire fichier
        materiels = chargerListe([Materiel].self, cle: materielsKey)
        personnes = chargerListe([Personne].self, cle: personnesKey)
        lieuxStockage = chargerListe([LieuStockage].self, cle: lieuxKey)
        chantiers = chargerListe([Chantier].self, cle: chantiersKey)
        prets = chargerListe([Pret].self, cle: pretsKey)
        emprunts = chargerListe([Emprunt].self, cle: empruntsKey)
        coffreItems = chargerListe([CoffreItem].self, cle: coffreKey)
        locations = chargerListe([Location].self, cle: locationsKey)
        reparations = chargerListe([Reparation].self, cle: reparationsKey)
        mesLocations = chargerListe([MaLocation].self, cle: mesLocationsKey)
        operationsComptables = chargerListe([OperationComptable].self, cle: operationsComptablesKey)
        articlesCommerce = chargerListe([ArticleCommerce].self, cle: articlesCommerceKey)
        transactionsCommerce = chargerListe([TransactionCommerce].self, cle: transactionsCommerceKey)
        categoriesCommercePersonnalisees = chargerListe([String].self, cle: categoriesCommerceKey)
        fournisseursCommercePersonnalises = chargerListe([String].self, cle: fournisseursCommerceKey)
        fournisseursCommerceExclus = chargerListe([String].self, cle: fournisseursExclusKey)
    }
    
    private func chargerListe<T: Decodable>(_ type: T.Type, cle: String) -> T where T: ExpressibleByArrayLiteral {
        let url = urlPourCle(cle)
        if let data = try? Data(contentsOf: url), let decoded = try? decoder.decode(T.self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: cle), let decoded = try? decoder.decode(T.self, from: data) {
            // Écrire vers fichier pour migration
            do { try data.write(to: url, options: .atomic) } catch { print("[DataManager] Erreur migration \(cle): \(error)") }
            UserDefaults.standard.removeObject(forKey: cle)
            return decoded
        }
        return []
    }
    
    func sauvegarderDonnees() {
        sauvegarderListe(materiels, cle: materielsKey)
        sauvegarderListe(personnes, cle: personnesKey)
        sauvegarderListe(lieuxStockage, cle: lieuxKey)
        sauvegarderListe(chantiers, cle: chantiersKey)
        sauvegarderListe(prets, cle: pretsKey)
        sauvegarderListe(emprunts, cle: empruntsKey)
        sauvegarderListe(coffreItems, cle: coffreKey)
        sauvegarderListe(locations, cle: locationsKey)
        sauvegarderListe(reparations, cle: reparationsKey)
        sauvegarderListe(mesLocations, cle: mesLocationsKey)
        sauvegarderListe(operationsComptables, cle: operationsComptablesKey)
        sauvegarderListe(articlesCommerce, cle: articlesCommerceKey)
        sauvegarderListe(transactionsCommerce, cle: transactionsCommerceKey)
        sauvegarderListe(categoriesCommercePersonnalisees, cle: categoriesCommerceKey)
        sauvegarderListe(fournisseursCommercePersonnalises, cle: fournisseursCommerceKey)
        sauvegarderListe(fournisseursCommerceExclus, cle: fournisseursExclusKey)
    }
    
    private func sauvegarderListe<T: Encodable>(_ liste: T, cle: String) {
        let url = urlPourCle(cle)
        do {
            let data = try encoder.encode(liste)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[DataManager] Erreur sauvegarde \(cle): \(error)")
        }
    }
    
    private func preparerDossier() {
        do {
            try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            print("[DataManager] Erreur création dossier persistance: \(error)")
        }
    }
    
    private func urlPourCle(_ cle: String) -> URL {
        baseDirectory.appendingPathComponent("\(cle).json")
    }
    
    private func configurerAutosave() {
        // Déclenche une sauvegarde coalescée quand n'importe quelle liste change
        // Erreur précédente: MergeMany avec des Publishers.Map de types parents différents
        // Solution: type erasure vers AnyPublisher<Void, Never>
        let publishers: [AnyPublisher<Void, Never>] = [
            $materiels.map { _ in () }.eraseToAnyPublisher(),
            $personnes.map { _ in () }.eraseToAnyPublisher(),
            $lieuxStockage.map { _ in () }.eraseToAnyPublisher(),
            $prets.map { _ in () }.eraseToAnyPublisher(),
            $emprunts.map { _ in () }.eraseToAnyPublisher(),
            $coffreItems.map { _ in () }.eraseToAnyPublisher(),
            $locations.map { _ in () }.eraseToAnyPublisher()
        ]
        saveCancellable = Publishers.MergeMany(publishers)
            .debounce(for: .seconds(0.6), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.sauvegarderDonnees() }
    }
    
    // MARK: - Matériel
    func ajouterMateriel(_ materiel: Materiel) {
        guard peutAjouterMateriel() else { return }
        materiels.append(materiel)
        totalMaterielsCreated += 1 // Incrémenter le compteur persistant
        sauvegarderDonnees()
    }
    
    func peutAjouterMateriel() -> Bool {
        // Vérifie contre le total créé, pas le nombre actuel
        return storeManager.hasUnlockedPremium || totalMaterielsCreated < limiteMateriels
    }
    
    func modifierMateriel(_ materiel: Materiel) {
        if let index = materiels.firstIndex(where: { $0.id == materiel.id }) {
            materiels[index] = materiel
            sauvegarderDonnees()
        }
    }
    
    func supprimerMateriel(_ materiel: Materiel) {
        materiels.removeAll { $0.id == materiel.id }
        prets.removeAll { $0.materielId == materiel.id }
        reparations.removeAll { $0.materielId == materiel.id }
        sauvegarderDonnees()
    }
    
    /// Supprime une catégorie en vidant le champ catégorie de tous les matériels concernés
    func supprimerCategorie(_ categorie: String) {
        for index in materiels.indices {
            if materiels[index].categorie.caseInsensitiveCompare(categorie) == .orderedSame {
                materiels[index].categorie = ""
            }
        }
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Renomme une catégorie (change le nom de catégorie pour tous les matériels concernés)
    func renommerCategorie(ancienNom: String, nouveauNom: String) {
        let trimmed = nouveauNom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for index in materiels.indices {
            if materiels[index].categorie.caseInsensitiveCompare(ancienNom) == .orderedSame {
                materiels[index].categorie = trimmed
            }
        }
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Retourne la liste des catégories utilisées dans les matériels
    var categoriesMateriels: [String] {
        let raw = materiels.map { $0.categorie.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
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
    
    func materielEstDisponible(_ materielId: UUID) -> Bool {
        let estPrete = prets.contains { $0.materielId == materielId && $0.dateRetourEffectif == nil }
        let estLoue = locations.contains { $0.materielId == materielId && $0.estActive }
        let estEnReparation = reparations.contains { $0.materielId == materielId && $0.estEnCours }
        return !estPrete && !estLoue && !estEnReparation
    }
    
    /// Retourne le statut du matériel: "disponible", "prete", "loue", "reparation"
    func statutMateriel(_ materielId: UUID) -> String {
        if prets.contains(where: { $0.materielId == materielId && $0.dateRetourEffectif == nil }) {
            return "prete"
        }
        if locations.contains(where: { $0.materielId == materielId && $0.estActive }) {
            return "loue"
        }
        if reparations.contains(where: { $0.materielId == materielId && $0.estEnCours }) {
            return "reparation"
        }
        return "disponible"
    }
    
    // MARK: - Réparations
    func ajouterReparation(_ reparation: Reparation) {
        guard peutAjouterReparation() else { return }
        reparations.append(reparation)
        totalReparationsCreated += 1
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    func peutAjouterReparation() -> Bool {
        return storeManager.hasUnlockedPremium || totalReparationsCreated < limiteReparations
    }
    
    func modifierReparation(_ reparation: Reparation) {
        if let index = reparations.firstIndex(where: { $0.id == reparation.id }) {
            reparations[index] = reparation
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func supprimerReparation(_ reparation: Reparation) {
        reparations.removeAll { $0.id == reparation.id }
        sauvegarderDonnees()
    }
    
    func validerRetourReparation(_ reparationId: UUID, coutFinal: Double? = nil, notes: String = "") {
        if let index = reparations.firstIndex(where: { $0.id == reparationId }) {
            reparations[index].dateRetour = Date()
            if let cout = coutFinal {
                reparations[index].coutFinal = cout
            }
            if !notes.isEmpty {
                reparations[index].notes = notes
            }
            // Ne pas modifier paiementRecu - géré séparément par marquerPaiementReparation
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func getReparationsPourMateriel(_ materielId: UUID) -> [Reparation] {
        return reparations.filter { $0.materielId == materielId }
    }
    
    func getReparationsPourReparateur(_ reparateurId: UUID) -> [Reparation] {
        return reparations.filter { $0.reparateurId == reparateurId }
    }
    
    func getReparationsEnCours() -> [Reparation] {
        return reparations.filter { $0.estEnCours }
    }
    
    /// Envoie un matériel en réparation depuis un prêt retourné
    func envoyerEnReparation(pretId: UUID, reparateurId: UUID, description: String, dateFinPrevue: Date?, coutEstime: Double?, notes: String, estGratuite: Bool = false) {
        guard let pret = prets.first(where: { $0.id == pretId }) else { return }
        
        // Valider le retour du prêt
        if let index = prets.firstIndex(where: { $0.id == pretId }) {
            prets[index].dateRetourEffectif = Date()
        }
        
        // Si gratuite, coût = nil et paiement déjà considéré comme "réglé"
        let coutEffectif: Double? = estGratuite ? nil : coutEstime
        let notesFinales = estGratuite ? (notes.isEmpty ? NSLocalizedString("Réparation gratuite", comment: "") : notes + "\n" + NSLocalizedString("Réparation gratuite", comment: "")) : notes
        
        // Créer la réparation
        let reparation = Reparation(
            materielId: pret.materielId,
            reparateurId: reparateurId,
            pretOrigineId: pretId,
            locationOrigineId: nil,
            dateDebut: Date(),
            dateFinPrevue: dateFinPrevue,
            dateRetour: nil,
            description: description,
            coutEstime: coutEffectif,
            coutFinal: estGratuite ? 0 : nil,
            paiementRecu: estGratuite, // Si gratuite, considérée comme réglée
            notes: notesFinales
        )
        reparations.append(reparation)
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Retourne les personnes de type mécanicien
    func getMecaniciens() -> [Personne] {
        return personnes.filter { $0.typePersonne == .mecanicien }
    }
    
    /// Retourne les personnes de type client
    func getClients() -> [Personne] {
        return personnes.filter { $0.typePersonne == .client || $0.typePersonne == nil }
    }
    
    /// Retourne les agences de location de matériel (ALM)
    func getALM() -> [Personne] {
        return personnes.filter { $0.typePersonne == .alm }
    }
    
    /// Retourne les personnes de type salarié
    func getSalaries() -> [Personne] {
        return personnes.filter { $0.typePersonne == .salarie }
    }
    
    // MARK: - Personne
    func ajouterPersonne(_ personne: Personne) {
        guard peutAjouterPersonne() else { return }
        personnes.append(personne)
        totalPersonnesCreated += 1 // Incrémenter le compteur persistant
        sauvegarderDonnees()
    }
    
    func peutAjouterPersonne() -> Bool {
        // Vérifie contre le total créé, pas le nombre actuel
        return storeManager.hasUnlockedPremium || totalPersonnesCreated < limitePersonnes
    }
    
    func modifierPersonne(_ personne: Personne) {
        if let index = personnes.firstIndex(where: { $0.id == personne.id }) {
            personnes[index] = personne
            sauvegarderDonnees()
        }
    }
    
    func supprimerPersonne(_ personne: Personne) {
        personnes.removeAll { $0.id == personne.id }
        // Les prêts et emprunts associés deviennent orphelins (ne sont plus supprimés)
        // L'utilisateur pourra les réaffecter à une autre personne via le bouton "Affecter"
        sauvegarderDonnees()
    }
    
    // MARK: - Gestion des orphelins et doublons
    
    /// Retourne les prêts sans personne valide assignée
    func getPretsOrphelins() -> [Pret] {
        return prets.filter { pret in
            !personnes.contains { $0.id == pret.personneId }
        }
    }
    
    /// Retourne les emprunts sans personne valide assignée
    func getEmpruntsOrphelins() -> [Emprunt] {
        return emprunts.filter { emprunt in
            !personnes.contains { $0.id == emprunt.personneId }
        }
    }
    
    /// Réaffecte un prêt à une nouvelle personne
    func reaffecterPret(_ pret: Pret, nouvellePersonneId: UUID) {
        if let index = prets.firstIndex(where: { $0.id == pret.id }) {
            prets[index].personneId = nouvellePersonneId
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Réaffecte un emprunt à une nouvelle personne
    func reaffecterEmprunt(_ emprunt: Emprunt, nouvellePersonneId: UUID) {
        if let index = emprunts.firstIndex(where: { $0.id == emprunt.id }) {
            emprunts[index].personneId = nouvellePersonneId
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Trouve les groupes de personnes en doublon (même nom et prénom)
    func trouverDoublonsPersonnes() -> [[Personne]] {
        var groupes: [String: [Personne]] = [:]
        
        for personne in personnes {
            let cle = "\(personne.nom.lowercased().trimmingCharacters(in: .whitespaces))_\(personne.prenom.lowercased().trimmingCharacters(in: .whitespaces))"
            if groupes[cle] == nil {
                groupes[cle] = []
            }
            groupes[cle]?.append(personne)
        }
        
        return groupes.values.filter { $0.count > 1 }.sorted { $0.first?.nom ?? "" < $1.first?.nom ?? "" }
    }
    
    /// Fusionne plusieurs personnes en une seule
    func fusionnerPersonnes(_ personnesAFusionner: [Personne]) {
        guard personnesAFusionner.count > 1 else { return }
        
        func scoreInfos(_ p: Personne) -> Int {
            var score = 0
            if !p.email.isEmpty { score += 2 }
            if !p.telephone.isEmpty { score += 2 }
            if !p.organisation.isEmpty { score += 1 }
            return score
        }
        
        let personnesTriees = personnesAFusionner.sorted { scoreInfos($0) > scoreInfos($1) }
        var personneGardee = personnesTriees.first!
        
        for autrePersonne in personnesTriees.dropFirst() {
            if personneGardee.email.isEmpty && !autrePersonne.email.isEmpty {
                personneGardee.email = autrePersonne.email
            }
            if personneGardee.telephone.isEmpty && !autrePersonne.telephone.isEmpty {
                personneGardee.telephone = autrePersonne.telephone
            }
            if personneGardee.organisation.isEmpty && !autrePersonne.organisation.isEmpty {
                personneGardee.organisation = autrePersonne.organisation
            }
        }
        
        if let index = personnes.firstIndex(where: { $0.id == personneGardee.id }) {
            personnes[index] = personneGardee
        }
        
        let idPersonneGardee = personneGardee.id
        let idsASupprimer = personnesAFusionner.filter { $0.id != idPersonneGardee }.map { $0.id }
        
        for id in idsASupprimer {
            for i in prets.indices {
                if prets[i].personneId == id {
                    prets[i].personneId = idPersonneGardee
                }
            }
            for i in emprunts.indices {
                if emprunts[i].personneId == id {
                    emprunts[i].personneId = idPersonneGardee
                }
            }
        }
        
        personnes.removeAll { idsASupprimer.contains($0.id) }
        objectWillChange.send()
        sauvegarderDonnees()
    }

    
    // MARK: - Lieu de stockage
    func ajouterLieu(_ lieu: LieuStockage) {
        guard peutAjouterLieu() else { return }
        lieuxStockage.append(lieu)
        totalLieuxCreated += 1
        sauvegarderDonnees()
    }
    
    func peutAjouterLieu() -> Bool {
        return storeManager.hasUnlockedPremium || totalLieuxCreated < limiteLieux
    }
    
    func modifierLieu(_ lieu: LieuStockage) {
        if let index = lieuxStockage.firstIndex(where: { $0.id == lieu.id }) {
            lieuxStockage[index] = lieu
            sauvegarderDonnees()
        }
    }
    
    func supprimerLieu(_ lieu: LieuStockage) {
        lieuxStockage.removeAll { $0.id == lieu.id }
        // Retirer l'association des matériels
        for i in materiels.indices {
            if materiels[i].lieuStockageId == lieu.id {
                materiels[i].lieuStockageId = nil
            }
        }
        sauvegarderDonnees()
    }
    
    // MARK: - Chantier (pour les salariés)
    func ajouterChantier(_ chantier: Chantier) {
        chantiers.append(chantier)
        sauvegarderDonnees()
    }
    
    func modifierChantier(_ chantier: Chantier) {
        if let index = chantiers.firstIndex(where: { $0.id == chantier.id }) {
            chantiers[index] = chantier
            sauvegarderDonnees()
        }
    }
    
    func supprimerChantier(_ chantier: Chantier) {
        chantiers.removeAll { $0.id == chantier.id }
        // Retirer l'association des personnes (salariés)
        for i in personnes.indices {
            if personnes[i].chantierId == chantier.id {
                personnes[i].chantierId = nil
            }
        }
        sauvegarderDonnees()
    }
    
    func getChantier(id: UUID?) -> Chantier? {
        guard let id = id else { return nil }
        return chantiers.first { $0.id == id }
    }
    
    func salariesPourChantier(_ chantierId: UUID) -> [Personne] {
        return personnes.filter { $0.typePersonne == .salarie && $0.chantierId == chantierId }
    }
    
    /// Retourne les salariés disponibles (sans chantier assigné ou avec un autre chantier)
    func salariesDisponibles(pourChantier chantierId: UUID? = nil) -> [Personne] {
        return personnes.filter { personne in
            personne.typePersonne == .salarie && (personne.chantierId == nil || personne.chantierId != chantierId)
        }
    }
    
    /// Retourne tous les salariés non affectés à un chantier
    func salariesSansChantier() -> [Personne] {
        return personnes.filter { $0.typePersonne == .salarie && $0.chantierId == nil }
    }
    
    // MARK: - Import/Export Chantiers JSON
    
    /// Structure pour l'import des chantiers (compatible avec l'export)
    private struct ChantierImport: Codable {
        let id: UUID?
        let nom: String
        let adresse: String
        let description: String
        let dateDebut: Date?
        let dateFin: Date?
        let notes: String
        let estActif: Bool
        let salaries: [SalarieImport]?
        
        struct SalarieImport: Codable {
            let nom: String
            let prenom: String
            let telephone: String
            let email: String
        }
    }
    
    /// Importe des chantiers depuis un fichier JSON
    func importerChantiers(from url: URL) -> Bool {
        print("[DataManager] Tentative d'import chantiers depuis: \(url.path)")
        
        // Copier le fichier localement pour éviter les problèmes d'accès
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("import_chantiers_temp.json")
        
        do {
            // Supprimer le fichier temporaire s'il existe
            try? FileManager.default.removeItem(at: tempURL)
            
            // Copier le fichier
            try FileManager.default.copyItem(at: url, to: tempURL)
            print("[DataManager] Fichier copié vers: \(tempURL.path)")
            
            let data = try Data(contentsOf: tempURL)
            print("[DataManager] Données lues: \(data.count) bytes")
            
            // Essayer d'abord avec iso8601 (format utilisé à l'export)
            var chantiersImport: [ChantierImport]?
            
            let decoder1 = JSONDecoder()
            decoder1.dateDecodingStrategy = .iso8601
            do {
                chantiersImport = try decoder1.decode([ChantierImport].self, from: data)
                print("[DataManager] Décodage chantiers réussi avec iso8601")
            } catch {
                print("[DataManager] Échec iso8601: \(error)")
            }
            
            // Si échec, essayer avec secondsSince1970
            if chantiersImport == nil {
                let decoder2 = JSONDecoder()
                decoder2.dateDecodingStrategy = .secondsSince1970
                do {
                    chantiersImport = try decoder2.decode([ChantierImport].self, from: data)
                    print("[DataManager] Décodage chantiers réussi avec secondsSince1970")
                } catch {
                    print("[DataManager] Échec secondsSince1970: \(error)")
                }
            }
            
            // Si toujours échec, essayer sans stratégie spécifique
            if chantiersImport == nil {
                let decoder3 = JSONDecoder()
                do {
                    chantiersImport = try decoder3.decode([ChantierImport].self, from: data)
                    print("[DataManager] Décodage chantiers réussi avec format par défaut")
                } catch {
                    print("[DataManager] Échec format par défaut: \(error)")
                }
            }
            
            // Nettoyer le fichier temporaire
            try? FileManager.default.removeItem(at: tempURL)
            
            guard let validChantiers = chantiersImport else {
                print("[DataManager] Impossible de décoder le fichier JSON chantiers")
                return false
            }
            
            // Importer les chantiers
            var importCount = 0
            for chantierImport in validChantiers {
                // Utiliser l'ID existant ou en créer un nouveau
                let chantierId = chantierImport.id ?? UUID()
                
                // Vérifier si ce chantier existe déjà
                if !chantiers.contains(where: { $0.id == chantierId }) {
                    let nouveauChantier = Chantier(
                        id: chantierId,
                        nom: chantierImport.nom,
                        adresse: chantierImport.adresse,
                        description: chantierImport.description,
                        dateDebut: chantierImport.dateDebut,
                        dateFin: chantierImport.dateFin,
                        notes: chantierImport.notes,
                        estActif: chantierImport.estActif
                    )
                    chantiers.append(nouveauChantier)
                    importCount += 1
                    
                    // Importer les salariés associés si présents
                    if let salaries = chantierImport.salaries {
                        for salarie in salaries {
                            // Vérifier si ce salarié existe déjà par nom/prénom
                            if let existingSalarie = personnes.first(where: {
                                $0.nom == salarie.nom && $0.prenom == salarie.prenom && $0.typePersonne == .salarie
                            }) {
                                // Assigner au chantier s'il n'est pas déjà assigné
                                if existingSalarie.chantierId == nil {
                                    assignerSalarieAuChantier(existingSalarie.id, chantierId: chantierId)
                                }
                            } else {
                                // Créer le salarié et l'assigner au chantier
                                let nouvellePersonne = Personne(
                                    nom: salarie.nom,
                                    prenom: salarie.prenom,
                                    email: salarie.email,
                                    telephone: salarie.telephone,
                                    organisation: "",
                                    typePersonne: .salarie,
                                    chantierId: chantierId
                                )
                                personnes.append(nouvellePersonne)
                                totalPersonnesCreated += 1
                            }
                        }
                    }
                }
            }
            
            print("[DataManager] Import chantiers réussi: \(importCount) chantiers importés")
            sauvegarderDonnees()
            return importCount > 0
        } catch {
            print("[DataManager] Erreur import chantiers: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }
    
    /// Assigne un salarié à un chantier
    func assignerSalarieAuChantier(_ personneId: UUID, chantierId: UUID) {
        if let index = personnes.firstIndex(where: { $0.id == personneId }) {
            personnes[index].chantierId = chantierId
            sauvegarderDonnees()
        }
    }
    
    /// Retire un salarié d'un chantier
    func retirerSalarieDuChantier(_ personneId: UUID) {
        if let index = personnes.firstIndex(where: { $0.id == personneId }) {
            personnes[index].chantierId = nil
            sauvegarderDonnees()
        }
    }
    
    // MARK: - Prêt
    func ajouterPret(_ pret: Pret) {
        guard peutAjouterPret() else { return }
        prets.append(pret)
        totalPretsCreated += 1 // Incrémenter le compteur persistant
        sauvegarderDonnees()
    }
    
    func peutAjouterPret() -> Bool {
        // Vérifie contre le total créé, pas le nombre actuel
        return storeManager.hasUnlockedPremium || totalPretsCreated < limitePrets
    }
    
    func modifierPret(_ pret: Pret) {
        if let index = prets.firstIndex(where: { $0.id == pret.id }) {
            prets[index] = pret
            // Forcer la publication du changement pour mettre à jour l'UI
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func supprimerPret(_ pret: Pret) {
        prets.removeAll { $0.id == pret.id }
        sauvegarderDonnees()
    }
    
    func validerRetour(_ pretId: UUID) {
        if let index = prets.firstIndex(where: { $0.id == pretId }) {
            prets[index].dateRetourEffectif = Date()
            
            // Vérifier si ce prêt provient d'un emprunt (via pretActifId)
            if let empruntIndex = emprunts.firstIndex(where: { $0.pretActifId == pretId }) {
                // Dissocier le prêt de l'emprunt
                emprunts[empruntIndex].pretActifId = nil
                // Note: Le matériel reste jusqu'à la restitution de l'emprunt
            }
            
            // Ne pas décrémenter le compteur - la limite est définitive
            // (chaque prêt créé compte dans la limite)
            // Publication explicite
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func supprimerPretsRetournes() {
        prets.removeAll { $0.estRetourne }
        sauvegarderDonnees()
    }
    
    // MARK: - Emprunt (autonome)
    func ajouterEmprunt(_ emprunt: Emprunt) {
        guard peutAjouterEmprunt() else { return }
        emprunts.append(emprunt)
        totalEmpruntsCreated += 1 // Incrémenter le compteur persistant
        sauvegarderDonnees()
    }
    
    func peutAjouterEmprunt() -> Bool {
        // Vérifie contre le total créé, pas le nombre actuel
        return storeManager.hasUnlockedPremium || totalEmpruntsCreated < limiteEmprunts
    }
    
    func modifierEmprunt(_ emprunt: Emprunt) {
        if let index = emprunts.firstIndex(where: { $0.id == emprunt.id }) {
            emprunts[index] = emprunt
            sauvegarderDonnees()
        }
    }
    
    func supprimerEmprunt(_ emprunt: Emprunt) {
        // Supprimer le matériel lié s'il existe
        if let materielLieId = emprunt.materielLieId {
            materiels.removeAll { $0.id == materielLieId }
        }
        emprunts.removeAll { $0.id == emprunt.id }
        sauvegarderDonnees()
    }
    
    /// Vérifie si un emprunt est actuellement prêté à quelqu'un
    /// Vérifie à la fois le pretActifId direct ET si le matériel lié est en prêt
    func empruntEstPrete(_ empruntId: UUID) -> Pret? {
        guard let emprunt = emprunts.first(where: { $0.id == empruntId }) else {
            return nil
        }
        
        // 1. Vérifier le pretActifId direct (créé via "Prêter l'emprunt")
        if let pretActifId = emprunt.pretActifId,
           let pret = prets.first(where: { $0.id == pretActifId }), pret.estActif {
            return pret
        }
        
        // 2. Vérifier si le matériel lié est en prêt actif (créé via la liste des prêts)
        if let materielLieId = emprunt.materielLieId {
            if let pretMateriel = prets.first(where: { $0.materielId == materielLieId && $0.estActif }) {
                return pretMateriel
            }
        }
        
        return nil
    }
    
    /// Crée un matériel à partir d'un emprunt et lie les deux
    func creerMaterielDepuisEmprunt(_ empruntId: UUID, categorie: String, lieuId: UUID?) {
        guard let index = emprunts.firstIndex(where: { $0.id == empruntId }) else { return }
        let emprunt = emprunts[index]
        
        let materiel = Materiel(
            nom: emprunt.nomObjet,
            description: "Créé depuis un emprunt",
            categorie: categorie,
            lieuStockageId: lieuId,
            dateAcquisition: emprunt.dateDebut,
            valeur: 0,
            imageData: emprunt.imageData
        )
        
        materiels.append(materiel)
        emprunts[index].materielLieId = materiel.id
        sauvegarderDonnees()
    }
    
    /// Crée un prêt à partir d'un emprunt (re-prêter un objet emprunté)
    func creerPretDepuisEmprunt(_ empruntId: UUID, personneId: UUID, dateFin: Date, notes: String) {
        // Vérifier la limite de prêts
        guard peutAjouterPret() else { return }
        
        guard let empruntIndex = emprunts.firstIndex(where: { $0.id == empruntId }) else { return }
        let emprunt = emprunts[empruntIndex]
        
        // Si un matériel lié existe ET qu'il existe toujours, l'utiliser; sinon en créer un temporaire
        let materielId: UUID
        if let existingMaterielId = emprunt.materielLieId,
           materiels.contains(where: { $0.id == existingMaterielId }) {
            materielId = existingMaterielId
        } else {
            // Créer un matériel temporaire pour le prêt (uniquement si pas de matériel existant)
            let materiel = Materiel(
                nom: emprunt.nomObjet,
                description: "Objet emprunté - prêté temporairement",
                categorie: "Emprunt",
                lieuStockageId: nil,
                dateAcquisition: emprunt.dateDebut,
                valeur: 0,
                imageData: emprunt.imageData
            )
            materiels.append(materiel)
            emprunts[empruntIndex].materielLieId = materiel.id
            materielId = materiel.id
        }
        
        let pret = Pret(
            materielId: materielId,
            personneId: personneId,
            lieuId: nil,
            dateDebut: Date(),
            dateFin: dateFin,
            dateRetourEffectif: nil,
            notes: notes.isEmpty ? "Re-prêt de l'emprunt: \(emprunt.nomObjet)" : notes
        )
        
        prets.append(pret)
        totalPretsCreated += 1 // Incrémenter le compteur persistant
        emprunts[empruntIndex].pretActifId = pret.id
        sauvegarderDonnees()
    }
    
    /// Valide le retour du prêt lié à un emprunt
    func validerRetourPretEmprunt(_ empruntId: UUID) {
        guard let empruntIndex = emprunts.firstIndex(where: { $0.id == empruntId }) else {
            return
        }
        
        let emprunt = emprunts[empruntIndex]
        var pretIndex: Int?
        
        // 1. Chercher via pretActifId direct (créé via "Prêter l'emprunt")
        if let pretActifId = emprunt.pretActifId {
            pretIndex = prets.firstIndex(where: { $0.id == pretActifId })
        }
        
        // 2. Sinon chercher via materielLieId (créé via la liste des prêts)
        if pretIndex == nil, let materielLieId = emprunt.materielLieId {
            pretIndex = prets.firstIndex(where: { $0.materielId == materielLieId && $0.estActif })
        }
        
        guard let foundPretIndex = pretIndex else {
            return
        }
        
        prets[foundPretIndex].dateRetourEffectif = Date()
        emprunts[empruntIndex].pretActifId = nil
        // Note: Le matériel reste jusqu'à la restitution de l'emprunt (validerRetourEmprunt)
        
        sauvegarderDonnees()
    }
    
    /// Crée une location à partir d'un emprunt (sous-louer un objet emprunté)
    func creerLocationDepuisEmprunt(_ empruntId: UUID, personneId: UUID, dateDebut: Date, dateFin: Date, prixTotal: Double, prixUnitaire: Double, typeTarif: Location.TypeTarif, caution: Double, notes: String) {
        // Vérifier la limite de locations
        guard peutAjouterLocation() else { return }
        
        guard let empruntIndex = emprunts.firstIndex(where: { $0.id == empruntId }) else { return }
        let emprunt = emprunts[empruntIndex]
        
        // Si un matériel lié existe ET qu'il existe toujours, l'utiliser; sinon en créer un temporaire
        let materielId: UUID
        if let existingMaterielId = emprunt.materielLieId,
           materiels.contains(where: { $0.id == existingMaterielId }) {
            materielId = existingMaterielId
        } else {
            // Créer un matériel temporaire pour la location (uniquement si pas de matériel existant)
            let materiel = Materiel(
                nom: emprunt.nomObjet,
                description: "Objet emprunté - loué temporairement",
                categorie: "Emprunt",
                lieuStockageId: nil,
                dateAcquisition: emprunt.dateDebut,
                valeur: 0,
                imageData: emprunt.imageData
            )
            materiels.append(materiel)
            emprunts[empruntIndex].materielLieId = materiel.id
            materielId = materiel.id
        }
        
        let location = Location(
            materielId: materielId,
            locataireId: personneId,
            dateDebut: dateDebut,
            dateFin: dateFin,
            dateRetourEffectif: nil,
            prixTotal: prixTotal,
            caution: caution,
            cautionRendue: false,
            paiementRecu: false,
            typeTarif: typeTarif,
            prixUnitaire: prixUnitaire,
            notes: notes.isEmpty ? "Location de l'emprunt: \(emprunt.nomObjet)" : notes
        )
        
        locations.append(location)
        totalLocationsCreated += 1 // Incrémenter le compteur persistant
        emprunts[empruntIndex].locationActifId = location.id
        sauvegarderDonnees()
    }
    
    /// Valide le retour de la location liée à un emprunt
    func validerRetourLocationEmprunt(_ empruntId: UUID) {
        guard let empruntIndex = emprunts.firstIndex(where: { $0.id == empruntId }),
              let locationActifId = emprunts[empruntIndex].locationActifId,
              let locationIndex = locations.firstIndex(where: { $0.id == locationActifId }) else {
            return
        }
        
        locations[locationIndex].dateRetourEffectif = Date()
        emprunts[empruntIndex].locationActifId = nil
        // Note: Le matériel reste jusqu'à la restitution de l'emprunt (validerRetourEmprunt)
        
        sauvegarderDonnees()
    }
    
    /// Vérifie si un emprunt est actuellement en réparation
    func empruntEnReparation(_ empruntId: UUID) -> Reparation? {
        guard let emprunt = emprunts.first(where: { $0.id == empruntId }) else {
            return nil
        }
        
        // Vérifier le reparationActifId direct
        if let reparationActifId = emprunt.reparationActifId,
           let reparation = reparations.first(where: { $0.id == reparationActifId }), reparation.estEnCours {
            return reparation
        }
        
        // Vérifier aussi si le matériel lié est en réparation
        if let materielLieId = emprunt.materielLieId {
            if let reparationMateriel = reparations.first(where: { $0.materielId == materielLieId && $0.estEnCours }) {
                return reparationMateriel
            }
        }
        
        return nil
    }
    
    /// Envoie un emprunt en réparation
    func envoyerEmpruntEnReparation(_ empruntId: UUID, reparateurId: UUID, description: String, dateFinPrevue: Date?, coutEstime: Double?, notes: String, estGratuite: Bool = false) {
        // Vérifier la limite de réparations
        guard peutAjouterReparation() else { return }
        
        guard let empruntIndex = emprunts.firstIndex(where: { $0.id == empruntId }) else { return }
        let emprunt = emprunts[empruntIndex]
        
        // Si un matériel lié existe ET qu'il existe toujours, l'utiliser; sinon en créer un temporaire
        let materielId: UUID
        if let existingMaterielId = emprunt.materielLieId,
           materiels.contains(where: { $0.id == existingMaterielId }) {
            materielId = existingMaterielId
        } else {
            // Créer un matériel temporaire pour la réparation
            let materiel = Materiel(
                nom: emprunt.nomObjet,
                description: "Objet emprunté - en réparation",
                categorie: "Emprunt",
                lieuStockageId: nil,
                dateAcquisition: emprunt.dateDebut,
                valeur: 0,
                imageData: emprunt.imageData
            )
            materiels.append(materiel)
            emprunts[empruntIndex].materielLieId = materiel.id
            materielId = materiel.id
        }
        
        // Si gratuite, coût = nil et paiement déjà considéré comme "réglé"
        let coutEffectif: Double? = estGratuite ? nil : coutEstime
        let notesFinales: String
        if estGratuite {
            let noteBase = notes.isEmpty ? "Réparation de l'emprunt: \(emprunt.nomObjet)" : notes
            notesFinales = noteBase + "\n" + NSLocalizedString("Réparation gratuite", comment: "")
        } else {
            notesFinales = notes.isEmpty ? "Réparation de l'emprunt: \(emprunt.nomObjet)" : notes
        }
        
        let reparation = Reparation(
            materielId: materielId,
            reparateurId: reparateurId,
            pretOrigineId: nil,
            locationOrigineId: nil,
            dateDebut: Date(),
            dateFinPrevue: dateFinPrevue,
            dateRetour: nil,
            description: description,
            coutEstime: coutEffectif,
            coutFinal: estGratuite ? 0 : nil,
            paiementRecu: estGratuite, // Si gratuite, considérée comme réglée
            notes: notesFinales
        )
        
        reparations.append(reparation)
        totalReparationsCreated += 1
        emprunts[empruntIndex].reparationActifId = reparation.id
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Valide le retour de la réparation liée à un emprunt
    func validerRetourReparationEmprunt(_ empruntId: UUID, coutFinal: Double? = nil) {
        guard let empruntIndex = emprunts.firstIndex(where: { $0.id == empruntId }),
              let reparationActifId = emprunts[empruntIndex].reparationActifId,
              let reparationIndex = reparations.firstIndex(where: { $0.id == reparationActifId }) else {
            return
        }
        
        reparations[reparationIndex].dateRetour = Date()
        if let cout = coutFinal {
            reparations[reparationIndex].coutFinal = cout
        }
        // Ne pas modifier paiementRecu - géré séparément par marquerPaiementReparation
        emprunts[empruntIndex].reparationActifId = nil
        
        objectWillChange.send()
        sauvegarderDonnees()
    }

    /// Valide le retour d'un emprunt et supprime le matériel lié (car il ne m'appartient pas)
    func validerRetourEmprunt(_ empruntId: UUID) {
        if let index = emprunts.firstIndex(where: { $0.id == empruntId }) {
            // Récupérer l'ID du matériel lié avant de modifier l'emprunt
            let materielLieId = emprunts[index].materielLieId
            
            // Marquer l'emprunt comme retourné
            emprunts[index].dateRetourEffectif = Date()
            emprunts[index].materielLieId = nil // Dissocier le matériel
            
            // Ne pas décrémenter le compteur - la limite est définitive
            // (chaque emprunt créé compte dans la limite)
            
            // Supprimer le matériel lié (il ne m'appartient pas, c'était un emprunt)
            if let materielId = materielLieId {
                materiels.removeAll { $0.id == materielId }
            }
            
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    // MARK: - Helpers
    func getMateriel(id: UUID) -> Materiel? {
        return materiels.first { $0.id == id }
    }
    
    func getPersonne(id: UUID) -> Personne? {
        return personnes.first { $0.id == id }
    }
    
    func getLieu(id: UUID) -> LieuStockage? {
        return lieuxStockage.first { $0.id == id }
    }
    
    // Nouveau: mise à jour de la date du dernier email pour une personne
    func mettreAJourDernierEmail(personneId: UUID) {
        if let index = personnes.firstIndex(where: { $0.id == personneId }) {
            personnes[index].dateDernierEmail = Date()
            sauvegarderDonnees()
        }
    }
    
    func getPretsPourMateriel(_ materielId: UUID) -> [Pret] {
        return prets.filter { $0.materielId == materielId }
    }
    
    func getPretsPourPersonne(_ personneId: UUID) -> [Pret] {
        return prets.filter { $0.personneId == personneId }
    }
    
    func getPretsActifsPourPersonne(_ personneId: UUID) -> [Pret] {
        return prets.filter { $0.personneId == personneId && $0.dateRetourEffectif == nil }
    }
    
    func getMaterielsDansLieu(_ lieuId: UUID) -> [Materiel] {
        return materiels.filter { $0.lieuStockageId == lieuId }
    }
    
    func getEmpruntsPourPersonne(_ personneId: UUID) -> [Emprunt] {
        emprunts.filter { $0.personneId == personneId }
    }
    
    // Retirer la fonction de prolongation (plus utilisée)
    // func prolongerPret(_ pretId: UUID, deJours jours: Int) { }
    
    // Export PDF des prêts actifs
    func exportPretsActifsPDF() -> URL? {
        let actifs = prets.filter { $0.dateRetourEffectif == nil }
        // Chemin fichier temporaire
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PretsActifs.pdf")
        // Construire contenu texte simple (sans PDFKit pour rester léger)
        var lignes: [String] = []
        lignes.append("Prêts actifs - \(Date().formatted(date: .abbreviated, time: .shortened))")
        lignes.append("")
        if actifs.isEmpty { lignes.append("Aucun prêt actif") }
        for pret in actifs.sorted(by: { $0.dateFin < $1.dateFin }) {
            let materielNom = getMateriel(id: pret.materielId)?.nom ?? "(Matériel)"
            let personneNom = getPersonne(id: pret.personneId)?.nomComplet ?? "(Personne)"
            let debut = pret.dateDebut.formatted(date: .abbreviated, time: .omitted)
            let fin = pret.dateFin.formatted(date: .abbreviated, time: .omitted)
            let retard = pret.estEnRetard ? " (RETARD)" : ""
            lignes.append("• \(materielNom) → \(personneNom) | \(debut) → \(fin)\(retard)")
            let notesTrim = pret.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notesTrim.isEmpty { lignes.append("   Notes: \(notesTrim.prefix(140))") }
        }
        let fullText = lignes.joined(separator: "\n")
        // Générer PDF rudimentaire via CoreText
        let fmt = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792), format: fmt)
        do {
            let data = renderer.pdfData { ctx in
                ctx.beginPage()
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 4
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .paragraphStyle: paragraph
                ]
                let attrStr = NSAttributedString(string: fullText, attributes: attrs)
                attrStr.draw(in: CGRect(x: 36, y: 36, width: 540, height: 720))
            }
            try data.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            print("[DataManager] Erreur génération PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Locations
    func ajouterLocation(_ location: Location) {
        guard peutAjouterLocation() else { return }
        locations.append(location)
        totalLocationsCreated += 1
        sauvegarderDonnees()
    }
    
    func peutAjouterLocation() -> Bool {
        return storeManager.hasUnlockedPremium || totalLocationsCreated < limiteLocations
    }
    
    func modifierLocation(_ location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func supprimerLocation(_ location: Location) {
        locations.removeAll { $0.id == location.id }
        sauvegarderDonnees()
    }
    
    func validerRetourLocation(_ locationId: UUID) {
        if let index = locations.firstIndex(where: { $0.id == locationId }) {
            locations[index].dateRetourEffectif = Date()
            
            // Recalculer le prix en fonction de la durée effective
            if locations[index].typeTarif != .forfait && locations[index].prixUnitaire > 0 {
                locations[index].prixTotal = locations[index].prixTotalEffectif
            }
            
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func marquerPaiementRecu(_ locationId: UUID, recu: Bool) {
        if let index = locations.firstIndex(where: { $0.id == locationId }) {
            let wasNotPaid = !locations[index].paiementRecu
            locations[index].paiementRecu = recu
            
            // Enregistrer l'opération comptable uniquement si le paiement est marqué comme reçu pour la première fois
            // Utiliser prixTotalReel pour calculer le montant réel basé sur la durée effective
            if recu && wasNotPaid {
                enregistrerRevenuLocation(locations[index], montant: locations[index].prixTotalReel)
            }
            
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func marquerCautionRendue(_ locationId: UUID, rendue: Bool) {
        if let index = locations.firstIndex(where: { $0.id == locationId }) {
            locations[index].cautionRendue = rendue
            locations[index].cautionGardee = false
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func garderCaution(_ locationId: UUID, montant: Double? = nil) {
        if let index = locations.firstIndex(where: { $0.id == locationId }) {
            let wasNotKept = !locations[index].cautionGardee
            let montantAGarder = montant ?? locations[index].caution
            
            locations[index].cautionGardee = true
            locations[index].cautionRendue = false
            locations[index].montantCautionGardee = montantAGarder
            
            // Enregistrer l'opération comptable uniquement si la caution est gardée pour la première fois
            if wasNotKept && montantAGarder > 0 {
                enregistrerCautionGardee(locations[index])
            }
            
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func getLocationsPourMateriel(_ materielId: UUID) -> [Location] {
        return locations.filter { $0.materielId == materielId }
    }
    
    func getLocationsPourPersonne(_ personneId: UUID) -> [Location] {
        return locations.filter { $0.locataireId == personneId }
    }
    
    func getLocationsActives() -> [Location] {
        return locations.filter { $0.estActive }
    }
    
    func materielEstEnLocation(_ materielId: UUID) -> Bool {
        return locations.contains { $0.materielId == materielId && $0.estActive }
    }
    
    // MARK: - Sous-location (louer un objet qu'on a soi-même loué)
    
    /// Vérifie si une location est actuellement sous-louée à quelqu'un
    func locationEstSousLouee(_ locationId: UUID) -> Location? {
        guard let location = locations.first(where: { $0.id == locationId }) else {
            return nil
        }
        
        // Vérifier si la sous-location est active
        if let sousLocationId = location.sousLocationActifId,
           let sousLocation = locations.first(where: { $0.id == sousLocationId }), sousLocation.estActive {
            return sousLocation
        }
        
        return nil
    }
    
    /// Crée une sous-location à partir d'une location existante
    func creerSousLocationDepuisLocation(_ locationId: UUID, locataireId: UUID, dateDebut: Date, dateFin: Date, prixUnitaire: Double, typeTarif: Location.TypeTarif, caution: Double, notes: String) {
        // Vérifier la limite de locations
        guard peutAjouterLocation() else { return }
        
        guard let locationIndex = locations.firstIndex(where: { $0.id == locationId }) else { return }
        let locationOriginale = locations[locationIndex]
        
        // Calculer le nombre d'unités selon le type de tarif
        let nombreUnites: Int = {
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
        }()
        
        let prixTotal = prixUnitaire * Double(nombreUnites)
        
        let sousLocation = Location(
            materielId: locationOriginale.materielId,
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
            notes: notes.isEmpty ? "Sous-location" : notes
        )
        
        locations.append(sousLocation)
        totalLocationsCreated += 1
        locations[locationIndex].sousLocationActifId = sousLocation.id
        sauvegarderDonnees()
    }
    
    /// Valide le retour de la sous-location liée à une location
    func validerRetourSousLocation(_ locationId: UUID) {
        guard let locationIndex = locations.firstIndex(where: { $0.id == locationId }),
              let sousLocationId = locations[locationIndex].sousLocationActifId,
              let sousLocationIndex = locations.firstIndex(where: { $0.id == sousLocationId }) else {
            return
        }
        
        locations[sousLocationIndex].dateRetourEffectif = Date()
        
        // Recalculer le prix en fonction de la durée effective
        if locations[sousLocationIndex].typeTarif != .forfait && locations[sousLocationIndex].prixUnitaire > 0 {
            locations[sousLocationIndex].prixTotal = locations[sousLocationIndex].prixTotalEffectif
        }
        
        locations[locationIndex].sousLocationActifId = nil
        
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    // MARK: - Mes Locations (Je loue du matériel à quelqu'un)
    
    func ajouterMaLocation(_ maLocation: MaLocation) {
        guard peutAjouterMaLocation() else { return }
        mesLocations.append(maLocation)
        totalMesLocationsCreated += 1
        sauvegarderDonnees()
    }
    
    func peutAjouterMaLocation() -> Bool {
        return storeManager.hasUnlockedPremium || totalMesLocationsCreated < limiteMesLocations
    }
    
    func modifierMaLocation(_ maLocation: MaLocation) {
        if let index = mesLocations.firstIndex(where: { $0.id == maLocation.id }) {
            mesLocations[index] = maLocation
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func supprimerMaLocation(_ maLocation: MaLocation) {
        // Supprimer le matériel lié s'il existe
        if let materielLieId = maLocation.materielLieId {
            materiels.removeAll { $0.id == materielLieId }
        }
        mesLocations.removeAll { $0.id == maLocation.id }
        sauvegarderDonnees()
    }
    
    func validerRetourMaLocation(_ maLocationId: UUID) {
        if let index = mesLocations.firstIndex(where: { $0.id == maLocationId }) {
            // Récupérer l'ID du matériel lié avant de modifier la location
            let materielLieId = mesLocations[index].materielLieId
            
            // Marquer la location comme terminée
            mesLocations[index].dateRetourEffectif = Date()
            mesLocations[index].materielLieId = nil // Dissocier le matériel
            
            // Recalculer le prix en fonction de la durée effective
            if mesLocations[index].typeTarif != .forfait && mesLocations[index].prixUnitaire > 0 {
                mesLocations[index].prixTotal = mesLocations[index].prixTotalEffectif
            }
            
            // Supprimer le matériel lié (il ne m'appartient pas, c'était une location)
            if let materielId = materielLieId {
                materiels.removeAll { $0.id == materielId }
            }
            
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func marquerPaiementMaLocation(_ maLocationId: UUID, effectue: Bool) {
        if let index = mesLocations.firstIndex(where: { $0.id == maLocationId }) {
            let maLocation = mesLocations[index]
            let wasEffectue = maLocation.paiementEffectue
            mesLocations[index].paiementEffectue = effectue
            objectWillChange.send()
            sauvegarderDonnees()
            
            // Enregistrer en comptabilité si le paiement vient d'être effectué
            if effectue && !wasEffectue {
                let loueurNom = getPersonne(id: maLocation.loueurId)?.nomComplet ?? "Inconnu"
                enregistrerMaLocationEnComptabilite(maLocation, loueurNom: loueurNom)
            }
        }
    }
    
    func marquerCautionRecuperee(_ maLocationId: UUID, montant: Double) {
        if let index = mesLocations.firstIndex(where: { $0.id == maLocationId }) {
            mesLocations[index].montantCautionRecuperee += montant
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    func marquerCautionPerdue(_ maLocationId: UUID, montant: Double) {
        if let index = mesLocations.firstIndex(where: { $0.id == maLocationId }) {
            let maLocation = mesLocations[index]
            mesLocations[index].montantCautionPerdue += montant
            objectWillChange.send()
            sauvegarderDonnees()
            
            // Enregistrer la perte de caution en comptabilité
            if montant > 0 {
                let loueurNom = getPersonne(id: maLocation.loueurId)?.nomComplet ?? "Inconnu"
                enregistrerCautionPerdueEnComptabilite(maLocation, montant: montant, loueurNom: loueurNom)
            }
        }
    }
    
    func getMesLocationsPourPersonne(_ personneId: UUID) -> [MaLocation] {
        return mesLocations.filter { $0.loueurId == personneId }
    }
    
    func getMesLocationsActives() -> [MaLocation] {
        return mesLocations.filter { $0.estActive }
    }
    
    /// Calcule le total dépensé en locations (terminées et payées)
    func depensesTotalesMesLocations() -> Double {
        return mesLocations.filter { $0.estTerminee && $0.paiementEffectue }.reduce(0) { $0 + $1.prixTotalReel }
    }
    
    /// Calcule les dépenses en attente (mes locations actives ou non payées)
    func depensesEnAttenteMesLocations() -> Double {
        return mesLocations.filter { !$0.paiementEffectue }.reduce(0) { $0 + $1.prixTotalReel }
    }
    
    /// Calcule le total des cautions versées et non récupérées
    func cautionsEnCoursMesLocations() -> Double {
        return mesLocations.filter { $0.cautionRestante > 0 }.reduce(0) { $0 + $1.cautionRestante }
    }
    
    /// Vérifie si une MaLocation est actuellement prêtée à quelqu'un
    func maLocationEstPretee(_ maLocationId: UUID) -> Pret? {
        guard let maLocation = mesLocations.first(where: { $0.id == maLocationId }) else {
            return nil
        }
        
        if let pretActifId = maLocation.pretActifId,
           let pret = prets.first(where: { $0.id == pretActifId }), pret.estActif {
            return pret
        }
        
        if let materielLieId = maLocation.materielLieId {
            if let pretMateriel = prets.first(where: { $0.materielId == materielLieId && $0.estActif }) {
                return pretMateriel
            }
        }
        
        return nil
    }
    
    /// Vérifie si une MaLocation est actuellement sous-louée à quelqu'un
    func maLocationEstSousLouee(_ maLocationId: UUID) -> Location? {
        guard let maLocation = mesLocations.first(where: { $0.id == maLocationId }) else {
            return nil
        }
        
        // 1. Vérifier via locationActifId direct (créé via "Sous-louer" depuis MaLocation)
        if let locationActifId = maLocation.locationActifId,
           let location = locations.first(where: { $0.id == locationActifId }), location.estActive {
            return location
        }
        
        // 2. Vérifier si le matériel lié est en location (créé depuis la liste des matériels)
        if let materielLieId = maLocation.materielLieId {
            if let locationMateriel = locations.first(where: { $0.materielId == materielLieId && $0.estActive }) {
                return locationMateriel
            }
        }
        
        return nil
    }
    
    /// Crée un matériel à partir d'une MaLocation pour pouvoir la re-prêter
    func creerMaterielDepuisMaLocation(_ maLocationId: UUID, categorie: String, lieuId: UUID?) {
        guard let index = mesLocations.firstIndex(where: { $0.id == maLocationId }) else { return }
        let maLocation = mesLocations[index]
        
        let materiel = Materiel(
            nom: maLocation.nomObjet,
            description: "Créé depuis une location",
            categorie: categorie,
            lieuStockageId: lieuId,
            dateAcquisition: maLocation.dateDebut,
            valeur: 0,
            imageData: maLocation.imageData
        )
        
        materiels.append(materiel)
        mesLocations[index].materielLieId = materiel.id
        sauvegarderDonnees()
    }
    
    /// Crée un prêt à partir d'une MaLocation (re-prêter un objet loué)
    func creerPretDepuisMaLocation(_ maLocationId: UUID, personneId: UUID, dateFin: Date, notes: String) {
        guard peutAjouterPret() else { return }
        
        guard let maLocationIndex = mesLocations.firstIndex(where: { $0.id == maLocationId }) else { return }
        let maLocation = mesLocations[maLocationIndex]
        
        // Vérifier que la MaLocation n'est pas déjà sous-louée ou prêtée
        if maLocationEstSousLouee(maLocationId) != nil || maLocationEstPretee(maLocationId) != nil {
            return // Déjà en prêt ou sous-location
        }
        
        let materielId: UUID
        if let existingMaterielId = maLocation.materielLieId,
           materiels.contains(where: { $0.id == existingMaterielId }) {
            materielId = existingMaterielId
        } else {
            let materiel = Materiel(
                nom: maLocation.nomObjet,
                description: "Objet loué - prêté temporairement",
                categorie: "Location",
                lieuStockageId: nil,
                dateAcquisition: maLocation.dateDebut,
                valeur: 0,
                imageData: maLocation.imageData
            )
            materiels.append(materiel)
            mesLocations[maLocationIndex].materielLieId = materiel.id
            materielId = materiel.id
        }
        
        let pret = Pret(
            materielId: materielId,
            personneId: personneId,
            lieuId: nil,
            dateDebut: Date(),
            dateFin: dateFin,
            dateRetourEffectif: nil,
            notes: notes.isEmpty ? "Re-prêt de la location: \(maLocation.nomObjet)" : notes
        )
        
        prets.append(pret)
        totalPretsCreated += 1
        mesLocations[maLocationIndex].pretActifId = pret.id
        sauvegarderDonnees()
    }
    
    /// Valide le retour du prêt lié à une MaLocation
    func validerRetourPretMaLocation(_ maLocationId: UUID) {
        guard let maLocationIndex = mesLocations.firstIndex(where: { $0.id == maLocationId }) else {
            return
        }
        
        let maLocation = mesLocations[maLocationIndex]
        var pretIndex: Int?
        
        if let pretActifId = maLocation.pretActifId {
            pretIndex = prets.firstIndex(where: { $0.id == pretActifId })
        }
        
        if pretIndex == nil, let materielLieId = maLocation.materielLieId {
            pretIndex = prets.firstIndex(where: { $0.materielId == materielLieId && $0.estActif })
        }
        
        guard let foundPretIndex = pretIndex else {
            return
        }
        
        prets[foundPretIndex].dateRetourEffectif = Date()
        mesLocations[maLocationIndex].pretActifId = nil
        
        sauvegarderDonnees()
    }
    
    /// Crée une sous-location à partir d'une MaLocation
    func creerSousLocationDepuisMaLocation(_ maLocationId: UUID, locataireId: UUID, dateDebut: Date, dateFin: Date, prixUnitaire: Double, typeTarif: Location.TypeTarif, caution: Double, notes: String) {
        guard peutAjouterLocation() else { return }
        
        guard let maLocationIndex = mesLocations.firstIndex(where: { $0.id == maLocationId }) else { return }
        let maLocation = mesLocations[maLocationIndex]
        
        // Vérifier que la MaLocation n'est pas déjà sous-louée ou prêtée
        if maLocationEstSousLouee(maLocationId) != nil || maLocationEstPretee(maLocationId) != nil {
            return // Déjà en prêt ou sous-location
        }
        
        let materielId: UUID
        if let existingMaterielId = maLocation.materielLieId,
           materiels.contains(where: { $0.id == existingMaterielId }) {
            materielId = existingMaterielId
        } else {
            let materiel = Materiel(
                nom: maLocation.nomObjet,
                description: "Objet loué - sous-loué temporairement",
                categorie: "Location",
                lieuStockageId: nil,
                dateAcquisition: maLocation.dateDebut,
                valeur: 0,
                imageData: maLocation.imageData
            )
            materiels.append(materiel)
            mesLocations[maLocationIndex].materielLieId = materiel.id
            materielId = materiel.id
        }
        
        let nombreUnites: Int = {
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
        }()
        
        let prixTotal = prixUnitaire * Double(nombreUnites)
        
        let sousLocation = Location(
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
            notes: notes.isEmpty ? "Sous-location depuis ma location" : notes
        )
        
        locations.append(sousLocation)
        totalLocationsCreated += 1
        mesLocations[maLocationIndex].locationActifId = sousLocation.id
        sauvegarderDonnees()
    }
    
    /// Valide le retour de la sous-location liée à une MaLocation
    func validerRetourSousLocationMaLocation(_ maLocationId: UUID) {
        guard let maLocationIndex = mesLocations.firstIndex(where: { $0.id == maLocationId }),
              let locationActifId = mesLocations[maLocationIndex].locationActifId,
              let locationIndex = locations.firstIndex(where: { $0.id == locationActifId }) else {
            return
        }
        
        locations[locationIndex].dateRetourEffectif = Date()
        
        if locations[locationIndex].typeTarif != .forfait && locations[locationIndex].prixUnitaire > 0 {
            locations[locationIndex].prixTotal = locations[locationIndex].prixTotalEffectif
        }
        
        mesLocations[maLocationIndex].locationActifId = nil
        
        objectWillChange.send()
        sauvegarderDonnees()
    }

    /// Calcule le revenu total des locations terminées et payées
    func revenuTotalLocations() -> Double {
        return locations.filter { $0.estTerminee && $0.paiementRecu }.reduce(0) { $0 + $1.prixTotalReel }
    }
    
    /// Calcule le revenu en attente (locations actives ou non payées)
    /// Utilise prixTotalReel pour refléter le montant réel basé sur la durée effective
    func revenuEnAttenteLocations() -> Double {
        return locations.filter { !$0.paiementRecu }.reduce(0) { $0 + $1.prixTotalReel }
    }
    
    // MARK: - Réparations - Statistiques financières
    
    /// Marque le paiement d'une réparation comme reçu
    func marquerPaiementReparation(_ reparationId: UUID, recu: Bool) {
        if let index = reparations.firstIndex(where: { $0.id == reparationId }) {
            let wasNotPaid = !reparations[index].paiementRecu
            reparations[index].paiementRecu = recu
            
            // Enregistrer l'opération comptable uniquement si le paiement est marqué comme effectué pour la première fois
            if recu && wasNotPaid {
                enregistrerDepenseReparation(reparations[index])
            }
            
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Calcule le total des dépenses de réparations terminées et payées
    func depensesTotalesReparations() -> Double {
        return reparations.filter { $0.estTerminee && $0.paiementRecu }
            .reduce(0) { $0 + ($1.coutFinal ?? $1.coutEstime ?? 0) }
    }
    
    /// Calcule les dépenses en attente (réparations non payées)
    func depensesEnAttenteReparations() -> Double {
        return reparations.filter { !$0.paiementRecu }
            .reduce(0) { $0 + ($1.coutFinal ?? $1.coutEstime ?? 0) }
    }
    
    // MARK: - Opérations comptables (historique permanent)
    
    /// Ajoute une opération comptable à l'historique
    func ajouterOperationComptable(_ operation: OperationComptable) {
        operationsComptables.append(operation)
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Enregistre une opération de location (revenu)
    func enregistrerRevenuLocation(_ location: Location, montant: Double) {
        let materielNom = getMateriel(id: location.materielId)?.nom
        let personneNom = getPersonne(id: location.locataireId)?.nomComplet
        
        let operation = OperationComptable(
            date: Date(),
            typeOperation: .locationRevenu,
            montant: montant,
            description: "Location de \(materielNom ?? "matériel inconnu")",
            materielNom: materielNom,
            personneNom: personneNom,
            referenceId: location.id
        )
        ajouterOperationComptable(operation)
    }
    
    /// Enregistre une caution gardée (revenu) - utilise le montant partiel si défini
    func enregistrerCautionGardee(_ location: Location) {
        let materielNom = getMateriel(id: location.materielId)?.nom
        let personneNom = getPersonne(id: location.locataireId)?.nomComplet
        let montantGarde = location.montantCautionGardee > 0 ? location.montantCautionGardee : location.caution
        
        let descriptionCaution: String
        if montantGarde < location.caution {
            descriptionCaution = "Caution partielle gardée (\(String(format: "%.2f", montantGarde))€ sur \(String(format: "%.2f", location.caution))€) - \(materielNom ?? "matériel inconnu")"
        } else {
            descriptionCaution = "Caution gardée - \(materielNom ?? "matériel inconnu")"
        }
        
        let operation = OperationComptable(
            date: Date(),
            typeOperation: .locationCaution,
            montant: montantGarde,
            description: descriptionCaution,
            materielNom: materielNom,
            personneNom: personneNom,
            referenceId: location.id
        )
        ajouterOperationComptable(operation)
    }
    
    /// Enregistre une dépense de réparation (uniquement le coût final réel)
    func enregistrerDepenseReparation(_ reparation: Reparation) {
        // N'enregistrer que si un coût final a été défini (prix réel payé)
        guard let coutFinal = reparation.coutFinal, coutFinal > 0 else { return }
        
        let materielNom = getMateriel(id: reparation.materielId)?.nom
        let personneNom = getPersonne(id: reparation.reparateurId)?.nomComplet
        
        let operation = OperationComptable(
            date: Date(),
            typeOperation: .reparationDepense,
            montant: coutFinal,
            description: "Réparation de \(materielNom ?? "matériel inconnu")",
            materielNom: materielNom,
            personneNom: personneNom,
            referenceId: reparation.id
        )
        ajouterOperationComptable(operation)
    }
    
    /// Enregistre une dépense de location (Je loue) en comptabilité
    func enregistrerMaLocationEnComptabilite(_ maLocation: MaLocation, loueurNom: String) {
        let montant = maLocation.prixTotalReel
        guard montant > 0 else { return }
        
        let operation = OperationComptable(
            date: Date(),
            typeOperation: .maLocationDepense,
            montant: montant,
            description: "Location de \(maLocation.nomObjet) auprès de \(loueurNom)",
            materielNom: maLocation.nomObjet,
            personneNom: loueurNom,
            referenceId: maLocation.id
        )
        ajouterOperationComptable(operation)
    }
    
    /// Enregistre une perte de caution (Je loue) en comptabilité
    func enregistrerCautionPerdueEnComptabilite(_ maLocation: MaLocation, montant: Double, loueurNom: String) {
        guard montant > 0 else { return }
        
        var description: String
        if montant < maLocation.caution {
            description = "Caution partielle perdue (\(String(format: "%.2f", montant))€ sur \(String(format: "%.2f", maLocation.caution))€) - \(maLocation.nomObjet)"
        } else {
            description = "Caution perdue - \(maLocation.nomObjet)"
        }
        
        let operation = OperationComptable(
            date: Date(),
            typeOperation: .maLocationCautionPerdue,
            montant: montant,
            description: description,
            materielNom: maLocation.nomObjet,
            personneNom: loueurNom,
            referenceId: maLocation.id
        )
        ajouterOperationComptable(operation)
    }
    
    /// Retourne les opérations comptables filtrées par mois et année
    func getOperationsParMoisAnnee(mois: Int, annee: Int) -> [OperationComptable] {
        return operationsComptables.filter { $0.mois == mois && $0.annee == annee }
            .sorted { $0.date > $1.date }
    }
    
    /// Retourne les opérations comptables filtrées par année
    func getOperationsParAnnee(annee: Int) -> [OperationComptable] {
        return operationsComptables.filter { $0.annee == annee }
            .sorted { $0.date > $1.date }
    }
    
    /// Retourne toutes les opérations comptables triées
    func getToutesOperations() -> [OperationComptable] {
        return operationsComptables.sorted { $0.date > $1.date }
    }
    
    /// Calcule le total des revenus (locations + cautions gardées)
    func totalRevenusComptabilite(operations: [OperationComptable]? = nil) -> Double {
        let ops = operations ?? operationsComptables
        return ops.filter { $0.typeOperation.isRevenu }.reduce(0) { $0 + $1.montant }
    }
    
    /// Calcule le total des dépenses (réparations)
    func totalDepensesComptabilite(operations: [OperationComptable]? = nil) -> Double {
        let ops = operations ?? operationsComptables
        return ops.filter { !$0.typeOperation.isRevenu }.reduce(0) { $0 + $1.montant }
    }
    
    /// Calcule le bénéfice net (revenus - dépenses)
    func beneficeNetComptabilite(operations: [OperationComptable]? = nil) -> Double {
        return totalRevenusComptabilite(operations: operations) - totalDepensesComptabilite(operations: operations)
    }
    
    /// Retourne les années disponibles dans l'historique comptable
    func getAnneesDisponibles() -> [Int] {
        let annees = Set(operationsComptables.map { $0.annee })
        return Array(annees).sorted(by: >)
    }
    
    /// Retourne les mois disponibles pour une année donnée
    func getMoisDisponibles(annee: Int) -> [Int] {
        let mois = Set(operationsComptables.filter { $0.annee == annee }.map { $0.mois })
        return Array(mois).sorted(by: >)
    }
    
    /// Supprime une opération comptable
    func supprimerOperationComptable(_ operation: OperationComptable) {
        operationsComptables.removeAll { $0.id == operation.id }
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Supprime plusieurs opérations comptables
    func supprimerOperationsComptables(_ operations: [OperationComptable]) {
        let idsToRemove = Set(operations.map { $0.id })
        operationsComptables.removeAll { idsToRemove.contains($0.id) }
        objectWillChange.send()
        sauvegarderDonnees()
    }

    /// Envoie un matériel en réparation depuis une location terminée
    func envoyerEnReparationDepuisLocation(locationId: UUID, reparateurId: UUID, description: String, dateFinPrevue: Date?, coutEstime: Double?, notes: String, estGratuite: Bool = false) {
        guard let location = locations.first(where: { $0.id == locationId }) else { return }
        
        // Valider le retour de la location si pas encore fait
        if let index = locations.firstIndex(where: { $0.id == locationId }), locations[index].dateRetourEffectif == nil {
            locations[index].dateRetourEffectif = Date()
        }
        
        // Si gratuite, coût = nil et paiement déjà considéré comme "réglé"
        let coutEffectif: Double? = estGratuite ? nil : coutEstime
        let notesFinales = estGratuite ? (notes.isEmpty ? NSLocalizedString("Réparation gratuite", comment: "") : notes + "\n" + NSLocalizedString("Réparation gratuite", comment: "")) : notes
        
        // Créer la réparation
        let reparation = Reparation(
            materielId: location.materielId,
            reparateurId: reparateurId,
            pretOrigineId: nil,
            locationOrigineId: locationId,
            dateDebut: Date(),
            dateFinPrevue: dateFinPrevue,
            dateRetour: nil,
            description: description,
            coutEstime: coutEffectif,
            coutFinal: estGratuite ? 0 : nil,
            paiementRecu: estGratuite, // Si gratuite, considérée comme réglée
            notes: notesFinales
        )
        reparations.append(reparation)
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    // MARK: - Module Commerce (Achat/Vente indépendant)
    
    /// Ajoute un article de commerce
    func ajouterArticleCommerce(_ article: ArticleCommerce) {
        articlesCommerce.append(article)
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Modifie un article de commerce
    func modifierArticleCommerce(_ article: ArticleCommerce) {
        if let index = articlesCommerce.firstIndex(where: { $0.id == article.id }) {
            articlesCommerce[index] = article
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Supprime un article de commerce
    func supprimerArticleCommerce(_ article: ArticleCommerce) {
        articlesCommerce.removeAll { $0.id == article.id }
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Récupère un article par son ID
    func getArticleCommerce(id: UUID) -> ArticleCommerce? {
        return articlesCommerce.first { $0.id == id }
    }
    
    /// Met à jour le stock d'un article après une transaction
    func mettreAJourStockArticle(articleId: UUID, quantite: Int, estVente: Bool) {
        if let index = articlesCommerce.firstIndex(where: { $0.id == articleId }) {
            if estVente {
                articlesCommerce[index].quantiteEnStock = max(0, articlesCommerce[index].quantiteEnStock - quantite)
            } else {
                articlesCommerce[index].quantiteEnStock += quantite
            }
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Met à jour le stock en kg d'un article après une transaction au poids
    func mettreAJourStockArticlePoids(articleId: UUID, poids: Double, estVente: Bool) {
        if let index = articlesCommerce.firstIndex(where: { $0.id == articleId }) {
            if estVente {
                articlesCommerce[index].stockEnKg = max(0, articlesCommerce[index].stockEnKg - poids)
            } else {
                articlesCommerce[index].stockEnKg += poids
            }
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Ajoute une catégorie personnalisée commerce
    func ajouterCategorieCommerce(_ categorie: String) {
        let trimmed = categorie.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !categoriesCommercePersonnalisees.contains(trimmed) && !ArticleCommerce.categoriesPredefinies.contains(trimmed) {
            categoriesCommercePersonnalisees.append(trimmed)
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Retourne toutes les catégories (prédéfinies + personnalisées)
    var toutesLesCategoriesCommerce: [String] {
        return ArticleCommerce.categoriesPredefinies + categoriesCommercePersonnalisees.sorted()
    }
    
    /// Ajoute un fournisseur personnalisé commerce
    func ajouterFournisseurCommerce(_ fournisseur: String) {
        let trimmed = fournisseur.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !fournisseursCommercePersonnalises.contains(trimmed) {
            fournisseursCommercePersonnalises.append(trimmed)
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Supprime un fournisseur personnalisé commerce
    func supprimerFournisseurCommerce(_ fournisseur: String) {
        fournisseursCommercePersonnalises.removeAll { $0 == fournisseur }
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Exclut un fournisseur de la liste de sélection (pour les fournisseurs utilisés dans des transactions)
    func exclureFournisseurCommerce(_ fournisseur: String) {
        let trimmed = fournisseur.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !fournisseursCommerceExclus.contains(trimmed) {
            fournisseursCommerceExclus.append(trimmed)
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Retourne tous les fournisseurs (personnalisés + utilisés dans les articles) en excluant ceux de la liste d'exclusion
    var tousLesFournisseursCommerce: [String] {
        let fournisseursArticles = Set(articlesCommerce.compactMap { $0.fournisseur.isEmpty ? nil : $0.fournisseur })
        let tousLesFournisseurs = fournisseursArticles.union(Set(fournisseursCommercePersonnalises))
        return Array(tousLesFournisseurs)
            .filter { !fournisseursCommerceExclus.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    /// Ajoute une transaction commerciale
    func ajouterTransactionCommerce(_ transaction: TransactionCommerce) {
        transactionsCommerce.append(transaction)
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    /// Modifie une transaction commerciale
    func modifierTransactionCommerce(_ transaction: TransactionCommerce) {
        if let index = transactionsCommerce.firstIndex(where: { $0.id == transaction.id }) {
            transactionsCommerce[index] = transaction
            // Mettre à jour les notifications et le badge
            mettreAJourRappelPaiement(transaction: transaction)
            objectWillChange.send()
            sauvegarderDonnees()
        }
    }
    
    /// Supprime une transaction commerciale
    func supprimerTransactionCommerce(_ transaction: TransactionCommerce) {
        transactionsCommerce.removeAll { $0.id == transaction.id }
        // Supprimer la notification associée
        annulerRappelPaiement(transactionId: transaction.id)
        objectWillChange.send()
        sauvegarderDonnees()
    }
    
    // MARK: - Notifications de rappel de paiement
    
    /// Demande l'autorisation pour les notifications
    func demanderAutorisationNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("[DataManager] Erreur autorisation notifications: \(error.localizedDescription)")
            } else {
                print("[DataManager] Notifications autorisées: \(granted)")
            }
        }
    }
    
    /// Planifie une notification de rappel le jour du règlement
    func planifierRappelPaiement(transaction: TransactionCommerce) {
        guard !transaction.estPaye, let dateReglement = transaction.dateReglement else { return }
        
        // Ne pas planifier si la date de règlement est déjà passée
        let calendar = Calendar.current
        let aujourdhui = calendar.startOfDay(for: Date())
        let dateReglementJour = calendar.startOfDay(for: dateReglement)
        guard dateReglementJour >= aujourdhui else { return }
        
        // Créer le contenu de la notification
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Rappel paiement", comment: "")
        
        let typeText = transaction.typeTransaction == .vente ? 
            NSLocalizedString("Vente", comment: "") : 
            NSLocalizedString("Achat", comment: "")
        let montantText = String(format: "%.2f €", transaction.montantTTC)
        
        content.body = "\(typeText) - \(transaction.nomArticle) (\(montantText)) - \(NSLocalizedString("Paiement à régler aujourd'hui", comment: ""))"
        content.sound = .default
        content.badge = 1
        
        // Créer le déclencheur pour la date de règlement à 9h du matin
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: dateReglement)
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Créer la requête avec un identifiant unique basé sur l'ID de la transaction
        let identifier = "paiement_\(transaction.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Ajouter la notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[DataManager] Erreur planification notification: \(error.localizedDescription)")
            } else {
                print("[DataManager] Notification planifiée pour le \(dateReglement)")
            }
        }
    }
    
    /// Met à jour la notification de rappel pour une transaction modifiée
    func mettreAJourRappelPaiement(transaction: TransactionCommerce) {
        // Supprimer l'ancienne notification
        annulerRappelPaiement(transactionId: transaction.id)
        
        // Si la transaction est maintenant payée, ne pas replanifier
        if transaction.estPaye {
            return
        }
        
        // Replanifier si non payée avec une nouvelle date
        planifierRappelPaiement(transaction: transaction)
    }
    
    /// Annule la notification de rappel pour une transaction
    func annulerRappelPaiement(transactionId: UUID) {
        let identifier = "paiement_\(transactionId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        // Réinitialiser le badge de l'app
        mettreAJourBadgeApp()
        print("[DataManager] Notification annulée: \(identifier)")
    }
    
    /// Met à jour le badge de l'application en fonction des paiements en attente
    func mettreAJourBadgeApp() {
        let paiementsEnAttente = transactionsCommerce.filter { !$0.estPaye && $0.dateReglement != nil && $0.paiementEnRetard }
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(paiementsEnAttente.count)
        }
    }
    
    /// Replanifie toutes les notifications de paiement au lancement de l'app
    func replanifierToutesLesNotificationsPaiement() {
        // Supprimer toutes les anciennes notifications de paiement
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let paiementIds = requests.filter { $0.identifier.hasPrefix("paiement_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: paiementIds)
            
            // Replanifier pour les transactions non payées
            Task { @MainActor in
                for transaction in self.transactionsCommerce where !transaction.estPaye && transaction.dateReglement != nil {
                    self.planifierRappelPaiement(transaction: transaction)
                }
                // Mettre à jour le badge de l'app
                self.mettreAJourBadgeApp()
            }
        }
    }

    /// Récupère les transactions filtrées par période
    func getTransactionsCommercePeriode(mois: Int? = nil, annee: Int) -> [TransactionCommerce] {
        if let mois = mois {
            return transactionsCommerce.filter { $0.mois == mois && $0.annee == annee }
                .sorted { $0.dateTransaction > $1.dateTransaction }
        } else {
            return transactionsCommerce.filter { $0.annee == annee }
                .sorted { $0.dateTransaction > $1.dateTransaction }
        }
    }
    
    /// Calcule le total des ventes TTC pour une période
    func totalVentesCommerce(mois: Int? = nil, annee: Int? = nil) -> Double {
        var transactions = transactionsCommerce.filter { $0.typeTransaction == .vente }
        if let annee = annee {
            transactions = transactions.filter { $0.annee == annee }
            if let mois = mois {
                transactions = transactions.filter { $0.mois == mois }
            }
        }
        return transactions.reduce(0) { $0 + $1.montantTTC }
    }
    
    /// Calcule le total des achats TTC pour une période
    func totalAchatsCommerce(mois: Int? = nil, annee: Int? = nil) -> Double {
        var transactions = transactionsCommerce.filter { $0.typeTransaction == .achat }
        if let annee = annee {
            transactions = transactions.filter { $0.annee == annee }
            if let mois = mois {
                transactions = transactions.filter { $0.mois == mois }
            }
        }
        return transactions.reduce(0) { $0 + $1.montantTTC }
    }
    
    /// Calcule la TVA collectée (sur les ventes)
    func tvaCollecteeCommerce(mois: Int? = nil, annee: Int? = nil) -> Double {
        var transactions = transactionsCommerce.filter { $0.typeTransaction == .vente }
        if let annee = annee {
            transactions = transactions.filter { $0.annee == annee }
            if let mois = mois {
                transactions = transactions.filter { $0.mois == mois }
            }
        }
        return transactions.reduce(0) { $0 + $1.montantTVA }
    }
    
    /// Calcule la TVA déductible (sur les achats)
    func tvaDeductibleCommerce(mois: Int? = nil, annee: Int? = nil) -> Double {
        var transactions = transactionsCommerce.filter { $0.typeTransaction == .achat }
        if let annee = annee {
            transactions = transactions.filter { $0.annee == annee }
            if let mois = mois {
                transactions = transactions.filter { $0.mois == mois }
            }
        }
        return transactions.reduce(0) { $0 + $1.montantTVA }
    }
    
    /// Calcule la marge commerciale
    func margeCommerce(mois: Int? = nil, annee: Int? = nil) -> Double {
        return totalVentesCommerce(mois: mois, annee: annee) - totalAchatsCommerce(mois: mois, annee: annee)
    }

    // MARK: - Coffre-fort
    func ajouterCoffreItem(_ item: CoffreItem) {
        guard peutAjouterCoffreItem() else { return }
        coffreItems.append(item)
        totalCoffreItemsCreated += 1 // Incrémenter le compteur persistant
        sauvegarderDonnees()
    }
    
    func peutAjouterCoffreItem() -> Bool {
        // Vérifie contre le total créé, pas le nombre actuel
        return storeManager.hasUnlockedPremium || totalCoffreItemsCreated < limiteCoffre
    }
    
    func modifierCoffreItem(_ item: CoffreItem) {
        if let index = coffreItems.firstIndex(where: { $0.id == item.id }) {
            coffreItems[index] = item
            sauvegarderDonnees()
        }
    }
    
    func supprimerCoffreItem(_ item: CoffreItem) {
        coffreItems.removeAll { $0.id == item.id }
        sauvegarderDonnees()
    }
    
    /// Supprime TOUS les éléments du coffre-fort (réinitialisation complète)
    func supprimerTousCoffreItems() {
        coffreItems.removeAll()
        sauvegarderDonnees()
    }
    
    func getCoffreItem(id: UUID) -> CoffreItem? {
        return coffreItems.first { $0.id == id }
    }
    
    // Valeur totale du coffre-fort
    var valeurTotaleCoffre: Double {
        coffreItems.reduce(0) { $0 + $1.valeurEstimee }
    }
    
    // MARK: - Export Matériel en fiche PDF (avec photos et factures)
    func exporterMaterielEnFiche(_ materiel: Materiel) -> URL? {
        let pdfData = genererFichePDFMateriel(materiel)
        let fileName = "Fiche_\(materiel.nom.replacingOccurrences(of: " ", with: "_"))_\(materiel.id.uuidString.prefix(8)).pdf"
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            print("[DataManager] Erreur export fiche matériel PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Export JSON flexible
    
    // Structure pour l'export JSON complet
    struct ExportData: Codable {
        var materiels: [Materiel]?
        var personnes: [Personne]?
        var lieuxStockage: [LieuStockage]?
        var chantiers: [Chantier]?
        var prets: [Pret]?
        var emprunts: [Emprunt]?
        var locations: [Location]?
        var reparations: [Reparation]?
        var exportDate: Date
        var appVersion: String
    }
    
    // Export des données sélectionnées en JSON
    func exporterDonneesJSON(
        materiels inclureMateriels: Bool,
        personnes inclurePersonnes: Bool,
        lieux inclureLieux: Bool,
        prets inclurePrets: Bool,
        emprunts inclureEmprunts: Bool,
        locations inclureLocations: Bool = false,
        reparations inclureReparations: Bool = false,
        chantiers inclureChantiers: Bool = false,
        exclureRetournes: Bool = false
    ) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        
        // Filtrer les prêts/emprunts si nécessaire
        var pretsExport: [Pret]? = nil
        var empruntsExport: [Emprunt]? = nil
        
        if inclurePrets {
            if exclureRetournes {
                pretsExport = prets.filter { $0.estActif }
            } else {
                pretsExport = prets
            }
        }
        
        if inclureEmprunts {
            if exclureRetournes {
                empruntsExport = emprunts.filter { $0.estActif }.map { emprunt in
                    var compressed = emprunt
                    compressed.imageData = compressImageData(emprunt.imageData)
                    return compressed
                }
            } else {
                empruntsExport = emprunts.map { emprunt in
                    var compressed = emprunt
                    compressed.imageData = compressImageData(emprunt.imageData)
                    return compressed
                }
            }
        }
        
        // Filtrer les locations si nécessaire
        var locationsExport: [Location]? = nil
        if inclureLocations {
            if exclureRetournes {
                locationsExport = locations.filter { $0.estActive }
            } else {
                locationsExport = locations
            }
        }
        
        // Filtrer les réparations si nécessaire
        var reparationsExport: [Reparation]? = nil
        if inclureReparations {
            if exclureRetournes {
                reparationsExport = reparations.filter { $0.estEnCours }
            } else {
                reparationsExport = reparations
            }
        }
        
        // Compresser les images des matériels
        var materielsExport: [Materiel]? = nil
        if inclureMateriels {
            materielsExport = self.materiels.map { materiel in
                var compressed = materiel
                compressed.imageData = compressImageData(materiel.imageData)
                compressed.factureImageData = compressImageData(materiel.factureImageData)
                return compressed
            }
        }
        
        // Exporter les chantiers et inclure automatiquement les salariés associés
        var chantiersExport: [Chantier]? = nil
        var personnesExport: [Personne]? = inclurePersonnes ? self.personnes : nil
        if inclureChantiers {
            chantiersExport = self.chantiers
            // Si on exporte les chantiers mais pas toutes les personnes, 
            // inclure au moins les salariés assignés aux chantiers
            if !inclurePersonnes {
                let salariesAssignes = self.personnes.filter { personne in
                    personne.typePersonne == .salarie && personne.chantierId != nil
                }
                if !salariesAssignes.isEmpty {
                    personnesExport = salariesAssignes
                }
            }
        }
        
        let exportData = ExportData(
            materiels: materielsExport,
            personnes: personnesExport,
            lieuxStockage: inclureLieux ? self.lieuxStockage : nil,
            chantiers: chantiersExport,
            prets: pretsExport,
            emprunts: empruntsExport,
            locations: locationsExport,
            reparations: reparationsExport,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        
        do {
            let data = try encoder.encode(exportData)
            
            // Nom du fichier selon le contenu
            var types: [String] = []
            if inclureMateriels { types.append("Mat") }
            if inclurePersonnes { types.append("Pers") }
            if inclureLieux { types.append("Lieux") }
            if inclureChantiers { types.append("Chant") }
            if inclurePrets { types.append("Prets") }
            if inclureEmprunts { types.append("Emp") }
            if inclureLocations { types.append("Loc") }
            if inclureReparations { types.append("Rep") }
            
            let typesStr = types.isEmpty ? "Vide" : types.joined(separator: "-")
            let dateStr = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
            let fileName = "Export_\(typesStr)_\(dateStr).json"
            
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            try data.write(to: tmp, options: .atomic)
            print("[DataManager] Export JSON créé: \(fileName)")
            return tmp
        } catch {
            print("[DataManager] Erreur export JSON: \(error)")
            return nil
        }
    }
    
    // Export tous les matériels en archive JSON (ancienne méthode pour compatibilité)
    func exporterTousMaterielsArchive() -> URL? {
        return exporterDonneesJSON(
            materiels: true,
            personnes: false,
            lieux: false,
            prets: false,
            emprunts: false
        )
    }
    
    // Export coffre-fort complet
    func exporterCoffreFort() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970  // Même format que le décodeur
        
        // Compresser les images avant export
        let coffreItemsCompresses = coffreItems.map { item in
            var compressed = item
            compressed.photoData = compressImageData(item.photoData)
            compressed.factureData = compressImageData(item.factureData)
            return compressed
        }
        
        do {
            let data = try encoder.encode(coffreItemsCompresses)
            let dateStr = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
            let fileName = "CoffreFort_Export_\(dateStr).json"
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            try data.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            print("[DataManager] Erreur export coffre-fort: \(error)")
            return nil
        }
    }
    
    // Import coffre-fort depuis fichier JSON
    func importerCoffreFort(from url: URL) -> Bool {
        print("[DataManager] Tentative d'import coffre-fort depuis: \(url.path)")
        
        // Copier le fichier localement pour éviter les problèmes d'accès
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("import_coffre_temp.json")
        
        do {
            // Supprimer le fichier temporaire s'il existe
            try? FileManager.default.removeItem(at: tempURL)
            
            // Copier le fichier
            try FileManager.default.copyItem(at: url, to: tempURL)
            print("[DataManager] Fichier copié vers: \(tempURL.path)")
            
            let data = try Data(contentsOf: tempURL)
            print("[DataManager] Données lues: \(data.count) bytes")
            
            // Essayer d'abord avec secondsSince1970 (format standard)
            var items: [CoffreItem]?
            let decoder1 = JSONDecoder()
            decoder1.dateDecodingStrategy = .secondsSince1970
            do {
                items = try decoder1.decode([CoffreItem].self, from: data)
                print("[DataManager] Décodage coffre réussi avec secondsSince1970")
            } catch {
                print("[DataManager] Échec secondsSince1970: \(error)")
            }
            
            // Si échec, essayer avec iso8601
            if items == nil {
                let decoder2 = JSONDecoder()
                decoder2.dateDecodingStrategy = .iso8601
                do {
                    items = try decoder2.decode([CoffreItem].self, from: data)
                    print("[DataManager] Décodage coffre réussi avec iso8601")
                } catch {
                    print("[DataManager] Échec iso8601: \(error)")
                }
            }
            
            // Si toujours échec, essayer sans stratégie spécifique
            if items == nil {
                let decoder3 = JSONDecoder()
                do {
                    items = try decoder3.decode([CoffreItem].self, from: data)
                    print("[DataManager] Décodage coffre réussi avec format par défaut")
                } catch {
                    print("[DataManager] Échec format par défaut: \(error)")
                }
            }
            
            // Nettoyer le fichier temporaire
            try? FileManager.default.removeItem(at: tempURL)
            
            guard let validItems = items else {
                print("[DataManager] Impossible de décoder le fichier JSON coffre-fort")
                return false
            }
            
            // Fusionner avec les items existants (éviter les doublons par ID)
            var importCount = 0
            for item in validItems {
                if !coffreItems.contains(where: { $0.id == item.id }) {
                    coffreItems.append(item)
                    totalCoffreItemsCreated += 1
                    importCount += 1
                }
            }
            print("[DataManager] Import coffre-fort réussi: \(importCount) items importés")
            sauvegarderDonnees()
            return true
        } catch {
            print("[DataManager] Erreur import coffre-fort: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }
    
    // Import données depuis fichier JSON (supporte ancien et nouveau format)
    func importerMateriels(from url: URL) -> Bool {
        print("[DataManager] Tentative d'import depuis: \(url.path)")
        
        // Copier le fichier localement pour éviter les problèmes d'accès
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("import_temp.json")
        
        do {
            // Supprimer le fichier temporaire s'il existe
            try? FileManager.default.removeItem(at: tempURL)
            
            // Copier le fichier
            try FileManager.default.copyItem(at: url, to: tempURL)
            print("[DataManager] Fichier copié vers: \(tempURL.path)")
            
            let data = try Data(contentsOf: tempURL)
            print("[DataManager] Données lues: \(data.count) bytes")
            
            // Afficher un aperçu du contenu pour debug
            if let jsonString = String(data: data.prefix(500), encoding: .utf8) {
                print("[DataManager] Aperçu JSON: \(jsonString)")
            }
            
            var totalImported = 0
            
            // Essayer d'abord le nouveau format ExportData
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            if let exportData = try? decoder.decode(ExportData.self, from: data) {
                print("[DataManager] Format ExportData détecté")
                
                // Importer les matériels
                if let items = exportData.materiels {
                    for item in items {
                        if !materiels.contains(where: { $0.id == item.id }) {
                            materiels.append(item)
                            totalMaterielsCreated += 1
                            totalImported += 1
                        }
                    }
                    print("[DataManager] \(items.count) matériels trouvés")
                }
                
                // Importer les lieux (avant les prêts/locations qui y font référence)
                if let items = exportData.lieuxStockage {
                    for item in items {
                        if !lieuxStockage.contains(where: { $0.id == item.id }) {
                            lieuxStockage.append(item)
                            totalImported += 1
                        }
                    }
                    print("[DataManager] \(items.count) lieux trouvés")
                }
                
                // Importer les chantiers (avant les personnes qui y font référence via chantierId)
                if let items = exportData.chantiers {
                    for item in items {
                        if !chantiers.contains(where: { $0.id == item.id }) {
                            chantiers.append(item)
                            totalImported += 1
                        }
                    }
                    print("[DataManager] \(items.count) chantiers trouvés")
                }
                
                // Importer les personnes (après les chantiers pour les références chantierId)
                if let items = exportData.personnes {
                    for item in items {
                        if let existingIndex = personnes.firstIndex(where: { $0.id == item.id }) {
                            // Si la personne existe déjà, mettre à jour son chantierId si nécessaire
                            if item.chantierId != nil && personnes[existingIndex].chantierId == nil {
                                personnes[existingIndex].chantierId = item.chantierId
                                print("[DataManager] Mise à jour chantierId pour \(item.prenom) \(item.nom)")
                            }
                        } else {
                            // Nouvelle personne, l'ajouter
                            personnes.append(item)
                            totalPersonnesCreated += 1
                            totalImported += 1
                        }
                    }
                    print("[DataManager] \(items.count) personnes trouvées")
                }
                
                // Importer les prêts
                if let items = exportData.prets {
                    for item in items {
                        if !prets.contains(where: { $0.id == item.id }) {
                            prets.append(item)
                            totalPretsCreated += 1
                            totalImported += 1
                        }
                    }
                    print("[DataManager] \(items.count) prêts trouvés")
                }
                
                // Importer les emprunts
                if let items = exportData.emprunts {
                    for item in items {
                        if !emprunts.contains(where: { $0.id == item.id }) {
                            emprunts.append(item)
                            totalEmpruntsCreated += 1
                            totalImported += 1
                        }
                    }
                    print("[DataManager] \(items.count) emprunts trouvés")
                }
                
                // Importer les locations
                if let items = exportData.locations {
                    for item in items {
                        if !locations.contains(where: { $0.id == item.id }) {
                            locations.append(item)
                            totalImported += 1
                        }
                    }
                    print("[DataManager] \(items.count) locations trouvées")
                }
                
                // Importer les réparations
                if let items = exportData.reparations {
                    for item in items {
                        if !reparations.contains(where: { $0.id == item.id }) {
                            reparations.append(item)
                            totalImported += 1
                        }
                    }
                    print("[DataManager] \(items.count) réparations trouvées")
                }
                
                try? FileManager.default.removeItem(at: tempURL)
                print("[DataManager] Import réussi: \(totalImported) éléments importés au total")
                sauvegarderDonnees()
                // Retourner true si le fichier était valide, même si aucun nouvel élément importé (déjà existants)
                return true
            }
            
            // Sinon essayer l'ancien format (tableau de Materiel)
            print("[DataManager] Essai ancien format [Materiel]...")
            
            var items: [Materiel]?
            
            // Essayer avec secondsSince1970
            do {
                items = try decoder.decode([Materiel].self, from: data)
                print("[DataManager] Décodage réussi avec secondsSince1970")
            } catch {
                print("[DataManager] Échec secondsSince1970: \(error)")
            }
            
            // Si échec, essayer avec iso8601
            if items == nil {
                let decoder2 = JSONDecoder()
                decoder2.dateDecodingStrategy = .iso8601
                do {
                    items = try decoder2.decode([Materiel].self, from: data)
                    print("[DataManager] Décodage réussi avec iso8601")
                } catch {
                    print("[DataManager] Échec iso8601: \(error)")
                }
            }
            
            // Nettoyer le fichier temporaire
            try? FileManager.default.removeItem(at: tempURL)
            
            guard let validItems = items else {
                print("[DataManager] Impossible de décoder le fichier JSON - aucun format ne fonctionne")
                return false
            }
            
            var importCount = 0
            for item in validItems {
                if !materiels.contains(where: { $0.id == item.id }) {
                    materiels.append(item)
                    totalMaterielsCreated += 1
                    importCount += 1
                }
            }
            print("[DataManager] Import réussi: \(importCount) matériels importés sur \(validItems.count) dans le fichier")
            sauvegarderDonnees()
            // Retourner true si le fichier était valide, même si les matériels existaient déjà
            return true
        } catch {
            print("[DataManager] Erreur import: \(error)")
            // Nettoyer le fichier temporaire en cas d'erreur
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }
    
    // MARK: - Export PDF Fiches
    
    // Export un matériel en fiche PDF
    func exporterMaterielPDF(_ materiel: Materiel) -> URL? {
        let pdfData = genererFichePDFMateriel(materiel)
        let fileName = "Fiche_\(materiel.nom.replacingOccurrences(of: " ", with: "_")).pdf"
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            print("[DataManager] Erreur export PDF matériel: \(error)")
            return nil
        }
    }
    
    // Export tous les matériels en un seul PDF
    func exporterTousMaterielsPDF() -> URL? {
        let pdfData = genererCataloguePDFMateriels()
        let dateStr = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
        let fileName = "Catalogue_Materiels_\(dateStr).pdf"
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            print("[DataManager] Erreur export catalogue PDF: \(error)")
            return nil
        }
    }
    
    // Export un item coffre-fort en fiche PDF
    func exporterCoffreItemPDF(_ item: CoffreItem) -> URL? {
        let pdfData = genererFichePDFCoffre(item)
        let fileName = "Fiche_Coffre_\(item.nom.replacingOccurrences(of: " ", with: "_")).pdf"
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            print("[DataManager] Erreur export PDF coffre: \(error)")
            return nil
        }
    }
    
    // Export tout le coffre-fort en PDF (inventaire assurance)
    func exporterCoffreFortPDF() -> URL? {
        let pdfData = genererInventairePDFCoffre()
        let dateStr = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
        let fileName = "Inventaire_Assurance_\(dateStr).pdf"
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            print("[DataManager] Erreur export inventaire PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Génération PDF
    
    private func genererFichePDFMateriel(_ materiel: Materiel) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            context.beginPage()
            
            var yPos: CGFloat = 40
            let margin: CGFloat = 40
            let contentWidth = pageRect.width - (margin * 2)
            
            // Titre
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.systemOrange
            ]
            let title = "FICHE MATÉRIEL"
            title.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttr)
            yPos += 40
            
            // Ligne de séparation
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: yPos))
            path.addLine(to: CGPoint(x: pageRect.width - margin, y: yPos))
            UIColor.systemOrange.setStroke()
            path.lineWidth = 2
            path.stroke()
            yPos += 20
            
            // Photo du matériel
            if let imageData = materiel.imageData, let originalImage = UIImage(data: imageData) {
                let image = originalImage.compressedForExport()
                let maxPhotoHeight: CGFloat = 200
                let photoWidth = min(contentWidth / 2, 250)
                let aspectRatio = image.size.height / image.size.width
                let photoHeight = min(photoWidth * aspectRatio, maxPhotoHeight)
                let photoRect = CGRect(x: margin, y: yPos, width: photoWidth, height: photoHeight)
                image.draw(in: photoRect)
                yPos += photoHeight + 20
            }
            
            // Informations
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray
            ]
            let valueAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            
            func drawField(label: String, value: String) {
                label.draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                yPos += 18
                value.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: valueAttr)
                yPos += 25
            }
            
            drawField(label: "Nom:", value: materiel.nom)
            drawField(label: "Catégorie:", value: materiel.categorie)
            drawField(label: "Description:", value: materiel.description)
            
            let lieu = lieuxStockage.first(where: { $0.id == materiel.lieuStockageId })
            drawField(label: "Lieu de stockage:", value: lieu?.nom ?? "Non défini")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            drawField(label: "Date d'acquisition:", value: dateFormatter.string(from: materiel.dateAcquisition))
            
            let valeurStr = String(format: "%.2f €", materiel.valeur)
            drawField(label: "Valeur:", value: valeurStr)
            
            if let vendeur = materiel.vendeur, !vendeur.isEmpty {
                drawField(label: "Vendeur:", value: vendeur)
            }
            if let numFacture = materiel.numeroFacture, !numFacture.isEmpty {
                drawField(label: "N° Facture:", value: numFacture)
            }
            
            // Photo de la facture ou PDF
            if let factureData = materiel.factureImageData {
                yPos += 20
                "Facture / Justificatif d'achat:".draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                yPos += 25
                
                // Vérifier si on est proche du bas de page, commencer une nouvelle page si nécessaire
                if yPos > pageRect.height - 400 {
                    context.beginPage()
                    yPos = 40
                    "Facture / Justificatif (suite):".draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                    yPos += 25
                }
                
                var factureImage: UIImage? = nil
                
                // Vérifier si c'est un PDF
                if materiel.factureIsPDF == true, let pdfDoc = PDFDocument(data: factureData), let pdfPage = pdfDoc.page(at: 0) {
                    // Générer une image haute qualité du PDF
                    let pdfRect = pdfPage.bounds(for: .mediaBox)
                    let scale: CGFloat = 3.0 // Très haute résolution pour lisibilité
                    let thumbSize = CGSize(width: pdfRect.width * scale, height: pdfRect.height * scale)
                    factureImage = pdfPage.thumbnail(of: thumbSize, for: .mediaBox)
                } else if let imgData = UIImage(data: factureData) {
                    // Utiliser la méthode haute qualité pour les factures
                    factureImage = imgData.preparedForInvoiceExport()
                }
                
                if let img = factureImage {
                    // Taille plus grande pour une meilleure lisibilité
                    let maxFactureWidth = contentWidth // Pleine largeur
                    let maxFactureHeight: CGFloat = 500 // Beaucoup plus grand
                    let aspectRatio = img.size.height / img.size.width
                    var factureWidth = maxFactureWidth
                    var factureHeight = factureWidth * aspectRatio
                    
                    // Si trop haute, limiter par la hauteur
                    if factureHeight > maxFactureHeight {
                        factureHeight = maxFactureHeight
                        factureWidth = factureHeight / aspectRatio
                    }
                    
                    let factureRect = CGRect(x: margin, y: yPos, width: factureWidth, height: factureHeight)
                    img.draw(in: factureRect)
                    yPos += factureHeight + 10
                }
            }
            
            // Footer
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            let dateExport = "Exporté le \(dateFormatter.string(from: Date()))"
            dateExport.draw(at: CGPoint(x: margin, y: pageRect.height - 30), withAttributes: footerAttr)
        }
    }
    
    private func genererCataloguePDFMateriels() -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            let margin: CGFloat = 40
            let contentWidth = pageRect.width - (margin * 2)
            
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.systemOrange
            ]
            let subtitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.darkGray
            ]
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]
            let valueAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            // Page de garde
            context.beginPage()
            var yPos: CGFloat = 40
            
            "CATALOGUE MATÉRIELS".draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttr)
            yPos += 35
            
            let totalValeur = materiels.reduce(0) { $0 + $1.valeur }
            let summary = "Exporté le \(dateFormatter.string(from: Date()))\n\(materiels.count) articles • Valeur totale: \(String(format: "%.2f €", totalValeur))"
            summary.draw(at: CGPoint(x: margin, y: yPos), withAttributes: valueAttr)
            yPos += 50
            
            // Ligne
            let headerPath = UIBezierPath()
            headerPath.move(to: CGPoint(x: margin, y: yPos))
            headerPath.addLine(to: CGPoint(x: pageRect.width - margin, y: yPos))
            UIColor.systemOrange.setStroke()
            headerPath.lineWidth = 2
            headerPath.stroke()
            yPos += 30
            
            // Index des matériels
            "INDEX:".draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
            yPos += 20
            
            for (index, materiel) in materiels.enumerated() {
                let hasFacture = materiel.factureImageData != nil ? " 📄" : ""
                let indexLine = "\(index + 1). \(materiel.nom) - \(String(format: "%.2f €", materiel.valeur))\(hasFacture)"
                indexLine.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: valueAttr)
                yPos += 18
                
                if yPos > pageRect.height - 60 {
                    context.beginPage()
                    yPos = 40
                }
            }
            
            // Une fiche par matériel
            for materiel in materiels {
                context.beginPage()
                yPos = 40
                
                // Titre de la fiche
                "FICHE MATÉRIEL".draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttr)
                yPos += 35
                
                // Ligne
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yPos))
                path.addLine(to: CGPoint(x: pageRect.width - margin, y: yPos))
                UIColor.systemOrange.setStroke()
                path.lineWidth = 2
                path.stroke()
                yPos += 20
                
                // Photo du matériel - Amélioré pour meilleure qualité
                if let imageData = materiel.imageData, let originalImage = UIImage(data: imageData) {
                    let image = originalImage.compressedForExport()
                    let maxPhotoHeight: CGFloat = 220 // Augmenté pour meilleure lisibilité
                    let photoWidth = min(contentWidth / 2, 280) // Plus large
                    let aspectRatio = image.size.height / image.size.width
                    let photoHeight = min(photoWidth * aspectRatio, maxPhotoHeight)
                    let photoRect = CGRect(x: margin, y: yPos, width: photoWidth, height: photoHeight)
                    
                    // Cadre autour de la photo
                    let frameRect = CGRect(x: margin - 2, y: yPos - 2, width: photoWidth + 4, height: photoHeight + 4)
                    UIColor.systemGray4.setStroke()
                    let framePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 4)
                    framePath.lineWidth = 1
                    framePath.stroke()
                    
                    image.draw(in: photoRect)
                    yPos += photoHeight + 20
                }
                
                // Nom
                materiel.nom.draw(at: CGPoint(x: margin, y: yPos), withAttributes: subtitleAttr)
                yPos += 28
                
                func drawField(label: String, value: String) {
                    label.draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                    yPos += 16
                    value.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: valueAttr)
                    yPos += 20
                }
                
                drawField(label: "Catégorie:", value: materiel.categorie)
                
                if !materiel.description.isEmpty {
                    drawField(label: "Description:", value: materiel.description)
                }
                
                let lieu = lieuxStockage.first(where: { $0.id == materiel.lieuStockageId })?.nom ?? "Non défini"
                drawField(label: "Lieu de stockage:", value: lieu)
                
                drawField(label: "Date d'acquisition:", value: dateFormatter.string(from: materiel.dateAcquisition))
                
                drawField(label: "Valeur:", value: String(format: "%.2f €", materiel.valeur))
                
                if let vendeur = materiel.vendeur, !vendeur.isEmpty {
                    drawField(label: "Vendeur:", value: vendeur)
                }
                
                if let numFacture = materiel.numeroFacture, !numFacture.isEmpty {
                    drawField(label: "N° Facture:", value: numFacture)
                }
                
                // Photo de la facture ou PDF - Amélioré pour meilleure qualité
                if let factureData = materiel.factureImageData {
                    yPos += 15
                    
                    // Vérifier si on a assez de place, sinon nouvelle page
                    if yPos > pageRect.height - 350 {
                        // Footer de la page actuelle
                        let currentFooter = "Page \(materiels.firstIndex(where: { $0.id == materiel.id })! + 2) - \(materiel.nom)"
                        currentFooter.draw(at: CGPoint(x: margin, y: pageRect.height - 30), withAttributes: footerAttr)
                        
                        context.beginPage()
                        yPos = 40
                        "JUSTIFICATIF D'ACHAT (suite)".draw(at: CGPoint(x: margin, y: yPos), withAttributes: subtitleAttr)
                        yPos += 30
                    } else {
                        "JUSTIFICATIF D'ACHAT:".draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                        yPos += 25
                    }
                    
                    var factureImage: UIImage? = nil
                    
                    // Vérifier si c'est un PDF
                    if materiel.factureIsPDF == true, let pdfDoc = PDFDocument(data: factureData), let pdfPage = pdfDoc.page(at: 0) {
                        // Générer une image très haute qualité du PDF pour lisibilité
                        let pdfRect = pdfPage.bounds(for: .mediaBox)
                        let scale: CGFloat = 3.0 // Très haute résolution pour meilleure lisibilité
                        let thumbSize = CGSize(width: pdfRect.width * scale, height: pdfRect.height * scale)
                        factureImage = pdfPage.thumbnail(of: thumbSize, for: .mediaBox)
                    } else if let imgData = UIImage(data: factureData) {
                        // Utiliser la méthode haute qualité pour les factures
                        factureImage = imgData.preparedForInvoiceExport()
                    }
                    
                    if let img = factureImage {
                        let remainingHeight = pageRect.height - yPos - 50
                        let maxFactureHeight = min(remainingHeight, 450) // Plus grand pour meilleure lisibilité
                        let factureWidth = contentWidth // Pleine largeur
                        let aspectRatio = img.size.height / img.size.width
                        var drawHeight = factureWidth * aspectRatio
                        var drawWidth = factureWidth
                        
                        if drawHeight > maxFactureHeight {
                            drawHeight = maxFactureHeight
                            drawWidth = drawHeight / aspectRatio
                        }
                        
                        // Centrer la facture
                        let xPos = margin + (contentWidth - drawWidth) / 2
                        
                        // Cadre autour de la facture
                        let frameRect = CGRect(x: xPos - 3, y: yPos - 3, width: drawWidth + 6, height: drawHeight + 6)
                        UIColor.systemGray5.setFill()
                        UIBezierPath(roundedRect: frameRect, cornerRadius: 4).fill()
                        UIColor.systemGray3.setStroke()
                        let framePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 4)
                        framePath.lineWidth = 1
                        framePath.stroke()
                        
                        let factureRect = CGRect(x: xPos, y: yPos, width: drawWidth, height: drawHeight)
                        img.draw(in: factureRect)
                        yPos += drawHeight + 15
                    }
                }
                
                // Footer
                let footerText = "Page \(materiels.firstIndex(where: { $0.id == materiel.id })! + 2) - Exporté le \(dateFormatter.string(from: Date()))"
                footerText.draw(at: CGPoint(x: margin, y: pageRect.height - 30), withAttributes: footerAttr)
            }
        }
    }
    
    private func genererFichePDFCoffre(_ item: CoffreItem) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            context.beginPage()
            
            var yPos: CGFloat = 40
            let margin: CGFloat = 40
            let contentWidth = pageRect.width - (margin * 2)
            
            // Titre
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.systemOrange
            ]
            "FICHE OBJET DE VALEUR".draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttr)
            yPos += 35
            
            let subtitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            "Document pour déclaration d'assurance".draw(at: CGPoint(x: margin, y: yPos), withAttributes: subtitleAttr)
            yPos += 25
            
            // Ligne
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: yPos))
            path.addLine(to: CGPoint(x: pageRect.width - margin, y: yPos))
            UIColor.systemOrange.setStroke()
            path.lineWidth = 2
            path.stroke()
            yPos += 20
            
            // Photo
            if let photoData = item.photoData, let originalImage = UIImage(data: photoData) {
                let image = originalImage.compressedForExport()
                let maxPhotoHeight: CGFloat = 200
                let photoWidth = min(contentWidth / 2, 250)
                let aspectRatio = image.size.height / image.size.width
                let photoHeight = min(photoWidth * aspectRatio, maxPhotoHeight)
                let photoRect = CGRect(x: margin, y: yPos, width: photoWidth, height: photoHeight)
                image.draw(in: photoRect)
                yPos += photoHeight + 20
            }
            
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray
            ]
            let valueAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            
            func drawField(label: String, value: String) {
                label.draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                yPos += 18
                value.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: valueAttr)
                yPos += 25
            }
            
            drawField(label: "Nom:", value: item.nom)
            drawField(label: "Catégorie:", value: item.categorie)
            
            if let marque = item.marque, !marque.isEmpty {
                drawField(label: "Marque:", value: marque)
            }
            if let modele = item.modele, !modele.isEmpty {
                drawField(label: "Modèle:", value: modele)
            }
            if let numSerie = item.numeroSerie, !numSerie.isEmpty {
                drawField(label: "N° de série:", value: numSerie)
            }
            
            drawField(label: "Description:", value: item.description)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            drawField(label: "Date d'acquisition:", value: dateFormatter.string(from: item.dateAcquisition))
            
            let valeurStr = String(format: "%.2f €", item.valeurEstimee)
            drawField(label: "Valeur estimée:", value: valeurStr)
            
            if let notes = item.notes, !notes.isEmpty {
                drawField(label: "Notes:", value: notes)
            }
            
            // Photo facture ou PDF
            if let factureData = item.factureData {
                yPos += 10
                "Justificatif d'achat:".draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                yPos += 25
                
                // Vérifier si on est proche du bas de page, commencer une nouvelle page si nécessaire
                if yPos > pageRect.height - 400 {
                    context.beginPage()
                    yPos = 40
                    "Justificatif d'achat (suite):".draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                    yPos += 25
                }
                
                var factureImage: UIImage? = nil
                
                // Vérifier si c'est un PDF
                if item.factureIsPDF == true, let pdfDoc = PDFDocument(data: factureData), let pdfPage = pdfDoc.page(at: 0) {
                    // Générer une image très haute qualité du PDF
                    let pdfRect = pdfPage.bounds(for: .mediaBox)
                    let scale: CGFloat = 3.0 // Très haute résolution pour lisibilité
                    let thumbSize = CGSize(width: pdfRect.width * scale, height: pdfRect.height * scale)
                    factureImage = pdfPage.thumbnail(of: thumbSize, for: .mediaBox)
                } else if let imgData = UIImage(data: factureData) {
                    // Utiliser la méthode haute qualité pour les factures
                    factureImage = imgData.preparedForInvoiceExport()
                }
                
                if let img = factureImage {
                    // Taille plus grande pour une meilleure lisibilité
                    let maxFactureWidth = contentWidth // Pleine largeur
                    let maxFactureHeight: CGFloat = 500 // Beaucoup plus grand
                    let aspectRatio = img.size.height / img.size.width
                    var factureWidth = maxFactureWidth
                    var factureHeight = factureWidth * aspectRatio
                    
                    // Si trop haute, limiter par la hauteur
                    if factureHeight > maxFactureHeight {
                        factureHeight = maxFactureHeight
                        factureWidth = factureHeight / aspectRatio
                    }
                    
                    let factureRect = CGRect(x: margin, y: yPos, width: factureWidth, height: factureHeight)
                    img.draw(in: factureRect)
                    yPos += factureHeight + 10
                }
            }
            
            // Footer
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            "Exporté le \(dateFormatter.string(from: Date()))".draw(at: CGPoint(x: margin, y: pageRect.height - 30), withAttributes: footerAttr)
        }
    }
    
    private func genererInventairePDFCoffre() -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            let margin: CGFloat = 40
            let contentWidth = pageRect.width - (margin * 2)
            
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.systemOrange
            ]
            let subtitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.darkGray
            ]
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]
            let valueAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            // Page de garde
            context.beginPage()
            var yPos: CGFloat = 40
            
            "INVENTAIRE ASSURANCE".draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttr)
            yPos += 35
            
            "Document de preuve de possession".draw(at: CGPoint(x: margin, y: yPos), withAttributes: [
                .font: UIFont.italicSystemFont(ofSize: 14),
                .foregroundColor: UIColor.gray
            ])
            yPos += 30
            
            let totalValeur = coffreItems.reduce(0) { $0 + $1.valeurEstimee }
            let summary = "Exporté le \(dateFormatter.string(from: Date()))\n\(coffreItems.count) objets • Valeur totale à assurer: \(String(format: "%.2f €", totalValeur))"
            summary.draw(at: CGPoint(x: margin, y: yPos), withAttributes: valueAttr)
            yPos += 50
            
            // Ligne
            let headerPath = UIBezierPath()
            headerPath.move(to: CGPoint(x: margin, y: yPos))
            headerPath.addLine(to: CGPoint(x: pageRect.width - margin, y: yPos))
            UIColor.systemOrange.setStroke()
            headerPath.lineWidth = 2
            headerPath.stroke()
            yPos += 30
            
            // Index des objets
            "INDEX DES BIENS:".draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
            yPos += 20
            
            for (index, item) in coffreItems.enumerated() {
                let hasFacture = item.factureData != nil ? " 📄" : ""
                let indexLine = "\(index + 1). \(item.nom) - \(String(format: "%.2f €", item.valeurEstimee))\(hasFacture)"
                indexLine.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: valueAttr)
                yPos += 18
                
                if yPos > pageRect.height - 60 {
                    context.beginPage()
                    yPos = 40
                }
            }
            
            // Une fiche par objet
            for item in coffreItems {
                context.beginPage()
                yPos = 40
                
                // Titre de la fiche
                "FICHE OBJET DE VALEUR".draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttr)
                yPos += 35
                
                // Ligne
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yPos))
                path.addLine(to: CGPoint(x: pageRect.width - margin, y: yPos))
                UIColor.systemOrange.setStroke()
                path.lineWidth = 2
                path.stroke()
                yPos += 20
                
                // Photo de l'objet
                if let photoData = item.photoData, let originalImage = UIImage(data: photoData) {
                    let image = originalImage.compressedForExport()
                    let maxPhotoHeight: CGFloat = 150
                    let photoWidth = min(contentWidth / 2.5, 200)
                    let aspectRatio = image.size.height / image.size.width
                    let photoHeight = min(photoWidth * aspectRatio, maxPhotoHeight)
                    let photoRect = CGRect(x: margin, y: yPos, width: photoWidth, height: photoHeight)
                    image.draw(in: photoRect)
                    yPos += photoHeight + 15
                }
                
                // Nom
                item.nom.draw(at: CGPoint(x: margin, y: yPos), withAttributes: subtitleAttr)
                yPos += 28
                
                func drawField(label: String, value: String) {
                    label.draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                    yPos += 16
                    value.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: valueAttr)
                    yPos += 20
                }
                
                drawField(label: "Catégorie:", value: item.categorie)
                
                if let marque = item.marque, !marque.isEmpty {
                    drawField(label: "Marque:", value: marque)
                }
                if let modele = item.modele, !modele.isEmpty {
                    drawField(label: "Modèle:", value: modele)
                }
                if let numSerie = item.numeroSerie, !numSerie.isEmpty {
                    drawField(label: "N° de série:", value: numSerie)
                }
                
                if !item.description.isEmpty {
                    drawField(label: "Description:", value: item.description)
                }
                
                drawField(label: "Date d'acquisition:", value: dateFormatter.string(from: item.dateAcquisition))
                
                drawField(label: "Valeur estimée:", value: String(format: "%.2f €", item.valeurEstimee))
                
                if let notes = item.notes, !notes.isEmpty {
                    drawField(label: "Notes:", value: notes)
                }
                
                // Photo de la facture - Haute qualité pour lisibilité
                if let factureData = item.factureData {
                    var factureImage: UIImage? = nil
                    
                    // Vérifier si c'est un PDF
                    if item.factureIsPDF == true, let pdfDoc = PDFDocument(data: factureData), let pdfPage = pdfDoc.page(at: 0) {
                        let pdfRect = pdfPage.bounds(for: .mediaBox)
                        let scale: CGFloat = 3.0
                        let thumbSize = CGSize(width: pdfRect.width * scale, height: pdfRect.height * scale)
                        factureImage = pdfPage.thumbnail(of: thumbSize, for: .mediaBox)
                    } else if let originalFacture = UIImage(data: factureData) {
                        factureImage = originalFacture.preparedForInvoiceExport()
                    }
                    
                    if let img = factureImage {
                        yPos += 10
                        "JUSTIFICATIF D'ACHAT:".draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttr)
                        yPos += 20
                        
                        let remainingHeight = pageRect.height - yPos - 50
                        let maxFactureHeight = min(remainingHeight, 450)
                        let factureWidth = contentWidth // Pleine largeur pour lisibilité
                        let aspectRatio = img.size.height / img.size.width
                        var drawHeight = factureWidth * aspectRatio
                        var drawWidth = factureWidth
                        
                        if drawHeight > maxFactureHeight {
                            drawHeight = maxFactureHeight
                            drawWidth = drawHeight / aspectRatio
                        }
                        
                        let xPos = margin + (contentWidth - drawWidth) / 2
                        let factureRect = CGRect(x: xPos, y: yPos, width: drawWidth, height: drawHeight)
                        img.draw(in: factureRect)
                    }
                }
                
                // Footer
                let footerText = "Page \(coffreItems.firstIndex(where: { $0.id == item.id })! + 2) - Document pour déclaration d'assurance"
                footerText.draw(at: CGPoint(x: margin, y: pageRect.height - 30), withAttributes: footerAttr)
            }
        }
    }
}
