//
//  CoffreFortView.swift
//  Materiel
//
//  Coffre-fort sécurisé pour stocker les preuves de possession (assurance)
//

import SwiftUI
import PhotosUI
import LocalAuthentication
import UniformTypeIdentifiers
import PDFKit

// MARK: - Helper pour l'authentification biométrique (non-Observable)
class BiometricAuthHelper {
    
    // Type de biométrie disponible
    enum BiometricType {
        case none
        case faceID
        case touchID
    }
    
    // Vérifier quel type de biométrie est disponible
    static func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .faceID // Traiter comme FaceID pour Vision Pro
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    static func canUseBiometrics() -> Bool {
        return biometricType() != .none
    }
    
    static func authenticate(reason: String = "Déverrouiller le coffre-fort", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Vérifier si la biométrie est disponible
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("[BiometricAuth] Biométrie non disponible: \(error?.localizedDescription ?? "inconnu")")
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        // Effectuer l'authentification
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    print("[BiometricAuth] Authentification réussie")
                    completion(true)
                } else {
                    print("[BiometricAuth] Authentification échouée: \(authError?.localizedDescription ?? "inconnu")")
                    completion(false)
                }
            }
        }
    }
    
    // Icône à afficher selon le type de biométrie
    static var biometricIconName: String {
        switch biometricType() {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.fill"
        }
    }
    
    // Texte à afficher selon le type de biométrie
    static var biometricDisplayName: String {
        switch biometricType() {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return ""
        }
    }
}

// MARK: - Gestion du mot de passe coffre-fort
@Observable
class CoffrePasswordManager {
    var hasPassword: Bool = false
    
    private let keychainService = "com.materiel.coffrefort"
    private let keychainAccount = "password"
    private let keychainRecoveryAccount = "recoveryAnswer"
    private let hasPasswordKey = "CoffreFort.hasPassword"
    private let recoveryQuestionKey = "CoffreFort.recoveryQuestion"
    
    // Clés pour le fallback UserDefaults (encodé en base64)
    private let fallbackPasswordKey = "CoffreFort.fallbackPassword"
    private let fallbackRecoveryKey = "CoffreFort.fallbackRecovery"
    
    // Questions de récupération prédéfinies
    static let recoveryQuestions = [
        "Quel est le nom de votre premier animal de compagnie ?",
        "Quel est le prénom de votre meilleur ami d'enfance ?",
        "Quelle est la ville de naissance de votre mère ?",
        "Quel est le nom de votre école primaire ?",
        "Quel est votre plat préféré ?",
        "Quelle est la marque de votre première voiture ?"
    ]
    
    init() {
        hasPassword = UserDefaults.standard.bool(forKey: hasPasswordKey)
        print("[CoffrePasswordManager] Init - hasPassword: \(hasPassword)")
    }
    
    func setPassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else {
            print("[CoffrePasswordManager] Erreur: impossible de convertir le mot de passe en data")
            return false
        }
        
        // Supprimer l'ancien mot de passe s'il existe
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        print("[CoffrePasswordManager] Delete status: \(deleteStatus) (\(securityErrorMessage(deleteStatus)))")
        
        // Ajouter le nouveau mot de passe avec kSecAttrAccessible
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        print("[CoffrePasswordManager] Add status: \(status) (\(securityErrorMessage(status)))")
        
        if status == errSecSuccess {
            hasPassword = true
            UserDefaults.standard.set(true, forKey: hasPasswordKey)
            // Supprimer le fallback s'il existe
            UserDefaults.standard.removeObject(forKey: fallbackPasswordKey)
            print("[CoffrePasswordManager] Mot de passe créé avec succès dans Keychain")
            return true
        } else {
            // Fallback: stocker en base64 dans UserDefaults
            print("[CoffrePasswordManager] Keychain échec, utilisation du fallback UserDefaults")
            let base64Password = data.base64EncodedString()
            UserDefaults.standard.set(base64Password, forKey: fallbackPasswordKey)
            hasPassword = true
            UserDefaults.standard.set(true, forKey: hasPasswordKey)
            print("[CoffrePasswordManager] Mot de passe créé dans fallback")
            return true
        }
    }
    
    func setRecoveryQuestion(_ question: String, answer: String) -> Bool {
        // Sauvegarder la question
        UserDefaults.standard.set(question, forKey: recoveryQuestionKey)
        
        // Sauvegarder la réponse dans le Keychain
        guard let data = answer.lowercased().trimmingCharacters(in: .whitespaces).data(using: .utf8) else {
            return false
        }
        
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainRecoveryAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainRecoveryAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        if status == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: fallbackRecoveryKey)
            return true
        } else {
            // Fallback
            let base64Answer = data.base64EncodedString()
            UserDefaults.standard.set(base64Answer, forKey: fallbackRecoveryKey)
            return true
        }
    }
    
    func getRecoveryQuestion() -> String? {
        return UserDefaults.standard.string(forKey: recoveryQuestionKey)
    }
    
    func verifyRecoveryAnswer(_ answer: String) -> Bool {
        // Essayer le Keychain d'abord
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainRecoveryAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let storedAnswer = String(data: data, encoding: .utf8) {
            return answer.lowercased().trimmingCharacters(in: .whitespaces) == storedAnswer
        }
        
        // Fallback UserDefaults
        if let base64Answer = UserDefaults.standard.string(forKey: fallbackRecoveryKey),
           let data = Data(base64Encoded: base64Answer),
           let storedAnswer = String(data: data, encoding: .utf8) {
            return answer.lowercased().trimmingCharacters(in: .whitespaces) == storedAnswer
        }
        
        return false
    }
    
    func verifyPassword(_ password: String) -> Bool {
        // Essayer le Keychain d'abord
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        print("[CoffrePasswordManager] Verify - Keychain status: \(status) (\(securityErrorMessage(status)))")
        
        if status == errSecSuccess,
           let data = result as? Data,
           let storedPassword = String(data: data, encoding: .utf8) {
            print("[CoffrePasswordManager] Mot de passe trouvé dans Keychain")
            return password == storedPassword
        }
        
        // Fallback UserDefaults
        if let base64Password = UserDefaults.standard.string(forKey: fallbackPasswordKey),
           let data = Data(base64Encoded: base64Password),
           let storedPassword = String(data: data, encoding: .utf8) {
            print("[CoffrePasswordManager] Mot de passe trouvé dans fallback")
            return password == storedPassword
        }
        
        print("[CoffrePasswordManager] Aucun mot de passe trouvé")
        return false
    }
    
    func changePassword(oldPassword: String, newPassword: String) -> Bool {
        guard verifyPassword(oldPassword) else { return false }
        return setPassword(newPassword)
    }
    
    func resetPasswordWithRecovery(answer: String, newPassword: String) -> Bool {
        guard verifyRecoveryAnswer(answer) else { return false }
        return setPassword(newPassword)
    }
    
    func removePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        
        // Supprimer aussi la réponse de récupération
        let recoveryQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainRecoveryAccount
        ]
        SecItemDelete(recoveryQuery as CFDictionary)
        UserDefaults.standard.removeObject(forKey: recoveryQuestionKey)
        
        // Supprimer aussi les fallbacks
        UserDefaults.standard.removeObject(forKey: fallbackPasswordKey)
        UserDefaults.standard.removeObject(forKey: fallbackRecoveryKey)
        
        hasPassword = false
        UserDefaults.standard.set(false, forKey: hasPasswordKey)
    }
    
    // Helper pour déboguer les erreurs Keychain
    private func securityErrorMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess: return "Success"
        case errSecItemNotFound: return "Item not found"
        case errSecDuplicateItem: return "Duplicate item"
        case errSecAuthFailed: return "Auth failed"
        case errSecInteractionNotAllowed: return "Interaction not allowed"
        case errSecMissingEntitlement: return "Missing entitlement"
        case -34018: return "Keychain error - possibly missing entitlements"
        default: return "Unknown error \(status)"
        }
    }
}

// MARK: - Vue principale du Coffre-fort
struct CoffreFortView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var passwordManager = CoffrePasswordManager()
    @State private var isUnlocked = false
    @State private var hasCheckedPassword = false
    
    var body: some View {
        Group {
            if !hasCheckedPassword {
                // Écran de chargement pendant la vérification
                ProgressView()
                    .onAppear {
                        hasCheckedPassword = true
                    }
            } else if !passwordManager.hasPassword {
                // Premier lancement: configurer le mot de passe
                SetupPasswordView(passwordManager: passwordManager, onComplete: {
                    isUnlocked = true
                }, onCancel: {
                    dismiss()
                })
            } else if isUnlocked {
                // Coffre-fort déverrouillé
                CoffreContenuView()
            } else {
                // Demander le mot de passe
                UnlockCoffreView(passwordManager: passwordManager, onUnlock: {
                    isUnlocked = true
                }, onCancel: {
                    dismiss()
                })
            }
        }
    }
}

// MARK: - Configuration initiale du mot de passe
struct SetupPasswordView: View {
    var passwordManager: CoffrePasswordManager
    var onComplete: () -> Void
    var onCancel: () -> Void
    
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedQuestion = CoffrePasswordManager.recoveryQuestions[0]
    @State private var recoveryAnswer = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    private func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "fr", ofType: "lproj")
        let bundle = path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.orange.opacity(0.2), Color.red.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(LocalizedStringKey("Configurer le Coffre-fort"))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(LocalizedStringKey("Créez un mot de passe pour protéger vos documents importants."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Mot de passe
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("Mot de passe"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            SecureField(LocalizedStringKey("Mot de passe"), text: $password)
                                .textFieldStyle(.roundedBorder)
                            
                            SecureField(LocalizedStringKey("Confirmer le mot de passe"), text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal)
                        
                        // Question de récupération
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("Question de récupération"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(LocalizedStringKey("En cas d'oubli du mot de passe"))
                                .font(.caption2)
                                .foregroundColor(.orange)
                            
                            Picker(LocalizedStringKey("Question"), selection: $selectedQuestion) {
                                ForEach(CoffrePasswordManager.recoveryQuestions, id: \.self) { question in
                                    Text(LocalizedStringKey(question)).tag(question)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            
                            TextField(LocalizedStringKey("Votre réponse"), text: $recoveryAnswer)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal)
                        
                        // Conseil de sauvegarde
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.down.doc.fill")
                                    .foregroundColor(.blue)
                                Text(LocalizedStringKey("Conseil"))
                                    .fontWeight(.semibold)
                            }
                            
                            Text(LocalizedStringKey("Pensez à effectuer des sauvegardes régulières de votre coffre-fort au format JSON depuis les paramètres. En cas d'oubli total (code + réponse), seule une réinitialisation sera possible et toutes les données seront perdues."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: setupPassword) {
                            HStack {
                                Image(systemName: "lock.fill")
                                Text(LocalizedStringKey("Créer le coffre-fort"))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(password.isEmpty || confirmPassword.isEmpty || recoveryAnswer.isEmpty)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(LocalizedStringKey("Coffre-fort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCancel) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text(LocalizedStringKey("Quitter"))
                        }
                    }
                }
            }
        }
    }
    
    private func setupPassword() {
        guard password.count >= 4 else {
            errorMessage = localizedString("Le mot de passe doit contenir au moins 4 caractères")
            showError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = localizedString("Les mots de passe ne correspondent pas")
            showError = true
            return
        }
        
        guard recoveryAnswer.count >= 2 else {
            errorMessage = localizedString("La réponse doit contenir au moins 2 caractères")
            showError = true
            return
        }
        
        if passwordManager.setPassword(password) {
            _ = passwordManager.setRecoveryQuestion(selectedQuestion, answer: recoveryAnswer)
            onComplete()
        } else {
            errorMessage = localizedString("Erreur lors de la création du mot de passe")
            showError = true
        }
    }
}

// MARK: - Déverrouillage du coffre-fort
struct UnlockCoffreView: View {
    var passwordManager: CoffrePasswordManager
    var onUnlock: () -> Void
    var onCancel: () -> Void
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    @State private var password = ""
    @State private var showError = false
    @State private var attempts = 0
    @State private var isAuthenticating = false
    @State private var showForgotPassword = false
    
    private func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "fr", ofType: "lproj")
        let bundle = path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.orange.opacity(0.2), Color.red.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(LocalizedStringKey("Coffre-fort verrouillé"))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(LocalizedStringKey("Entrez votre mot de passe pour accéder à vos documents"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        SecureField(LocalizedStringKey("Mot de passe"), text: $password)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                            .onSubmit { verifyPassword() }
                        
                        if showError {
                            Text(LocalizedStringKey("Mot de passe incorrect"))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: verifyPassword) {
                            HStack {
                                Image(systemName: "lock.open.fill")
                                Text(LocalizedStringKey("Déverrouiller"))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(password.isEmpty)
                        
                        if BiometricAuthHelper.canUseBiometrics() {
                            Button {
                                isAuthenticating = true
                                BiometricAuthHelper.authenticate(reason: NSLocalizedString("Déverrouiller le coffre-fort", comment: "")) { success in
                                    isAuthenticating = false
                                    if success {
                                        onUnlock()
                                    }
                                }
                            } label: {
                                HStack {
                                    if isAuthenticating {
                                        ProgressView()
                                            .tint(.orange)
                                    } else {
                                        Image(systemName: BiometricAuthHelper.biometricIconName)
                                    }
                                    Text(localizedString("Utiliser \(BiometricAuthHelper.biometricDisplayName)"))
                                }
                                .foregroundColor(.orange)
                            }
                            .disabled(isAuthenticating)
                            .padding(.top, 8)
                        }
                        
                        // Lien mot de passe oublié - toujours visible
                        Button(action: { showForgotPassword = true }) {
                            Text(LocalizedStringKey("Mot de passe oublié ?"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(LocalizedStringKey("Coffre-fort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCancel) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text(LocalizedStringKey("Quitter"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                RecoveryPasswordView(passwordManager: passwordManager, onSuccess: onUnlock)
                    .environmentObject(dataManager)
            }
        }
    }
    
    private func verifyPassword() {
        if passwordManager.verifyPassword(password) {
            onUnlock()
        } else {
            showError = true
            attempts += 1
            password = ""
        }
    }
}

// MARK: - Récupération du mot de passe
struct RecoveryPasswordView: View {
    var passwordManager: CoffrePasswordManager
    var onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var answer = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var step = 1 // 1 = réponse, 2 = nouveau mot de passe
    @State private var showingFullResetSheet = false
    
    private func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "fr", ofType: "lproj")
        let bundle = path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.orange.opacity(0.2), Color.red.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text(LocalizedStringKey("Récupération du mot de passe"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if step == 1 {
                        // Vérifier si une question de récupération existe
                        if let recoveryQuestion = passwordManager.getRecoveryQuestion(), !recoveryQuestion.isEmpty {
                            // Étape 1: Répondre à la question
                            VStack(alignment: .leading, spacing: 12) {
                                Text(LocalizedStringKey("Question de sécurité :"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(LocalizedStringKey(recoveryQuestion))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                
                                TextField(LocalizedStringKey("Votre réponse"), text: $answer)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(.horizontal)
                            
                            if showError {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            Button(action: verifyAnswer) {
                                Text(LocalizedStringKey("Vérifier"))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .disabled(answer.isEmpty)
                            
                            // Bouton pour réinitialisation complète
                            Button(action: { showingFullResetSheet = true }) {
                                Text(LocalizedStringKey("J'ai aussi oublié ma réponse"))
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 8)
                        } else {
                            // Aucune question de récupération configurée
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                
                                Text(LocalizedStringKey("Aucune question de récupération"))
                                    .font(.headline)
                                
                                Text(LocalizedStringKey("Aucune question de sécurité n'a été configurée pour ce coffre-fort. Vous pouvez uniquement réinitialiser complètement le coffre-fort, ce qui supprimera toutes les données."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button(action: { showingFullResetSheet = true }) {
                                    Text(LocalizedStringKey("Réinitialiser le coffre-fort"))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                    } else {
                        // Étape 2: Nouveau mot de passe
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizedStringKey("Créez un nouveau mot de passe"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            SecureField(LocalizedStringKey("Nouveau mot de passe"), text: $newPassword)
                                .textFieldStyle(.roundedBorder)
                            
                            SecureField(LocalizedStringKey("Confirmer le mot de passe"), text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal)
                        
                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: resetPassword) {
                            Text(LocalizedStringKey("Réinitialiser"))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(newPassword.isEmpty || confirmPassword.isEmpty)
                    }
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle(LocalizedStringKey("Récupération"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingFullResetSheet) {
                FullResetCoffreView(passwordManager: passwordManager, onReset: {
                    dismiss()
                })
            }
        }
    }
    
    private func verifyAnswer() {
        if passwordManager.verifyRecoveryAnswer(answer) {
            showError = false
            step = 2
        } else {
            errorMessage = localizedString("Réponse incorrecte")
            showError = true
        }
    }
    
    private func resetPassword() {
        guard newPassword.count >= 4 else {
            errorMessage = localizedString("Le mot de passe doit contenir au moins 4 caractères")
            showError = true
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = localizedString("Les mots de passe ne correspondent pas")
            showError = true
            return
        }
        
        if passwordManager.resetPasswordWithRecovery(answer: answer, newPassword: newPassword) {
            dismiss()
            onSuccess()
        } else {
            errorMessage = localizedString("Erreur lors de la réinitialisation")
            showError = true
        }
    }
}

// MARK: - Réinitialisation complète du coffre-fort
struct FullResetCoffreView: View {
    var passwordManager: CoffrePasswordManager
    var onReset: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var confirmationText = ""
    @State private var step = 1 // 1 = avertissement, 2 = confirmation
    @State private var showingFinalAlert = false
    
    private func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "fr", ofType: "lproj")
        let bundle = path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    private var itemCount: Int {
        dataManager.coffreItems.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.red.opacity(0.2), Color.orange.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text(LocalizedStringKey("Réinitialisation complète"))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if step == 1 {
                            // Étape 1: Avertissement
                            VStack(spacing: 16) {
                                Text(LocalizedStringKey("⚠️ ATTENTION"))
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.red)
                                        Text(LocalizedStringKey("Cette action supprimera DÉFINITIVEMENT :"))
                                            .fontWeight(.semibold)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(LocalizedStringKey("Tous vos \(itemCount) objets du coffre-fort"), systemImage: "cube.box.fill")
                                        Label(LocalizedStringKey("Toutes les photos associées"), systemImage: "photo.fill")
                                        Label(LocalizedStringKey("Toutes les factures stockées"), systemImage: "doc.fill")
                                        Label(LocalizedStringKey("Le code d'accès actuel"), systemImage: "lock.fill")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 28)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                
                                // Conseil sauvegarde
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.yellow)
                                        Text(LocalizedStringKey("Conseil important"))
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Text(LocalizedStringKey("Avant de réinitialiser, pensez à exporter vos données en JSON depuis les paramètres du coffre-fort. Cela vous permettra de récupérer vos informations si vous retrouvez votre code plus tard."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.yellow.opacity(0.15))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            Button(action: { step = 2 }) {
                                Text(LocalizedStringKey("Je comprends, continuer"))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                        } else {
                            // Étape 2: Confirmation finale
                            VStack(spacing: 16) {
                                Text(LocalizedStringKey("Pour confirmer, tapez « SUPPRIMER » ci-dessous :"))
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                
                                TextField("SUPPRIMER", text: $confirmationText)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.allCharacters)
                                    .padding(.horizontal)
                                
                                Text(LocalizedStringKey("Cette action est IRRÉVERSIBLE"))
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            Button(action: { showingFinalAlert = true }) {
                                Text(LocalizedStringKey("Réinitialiser le coffre-fort"))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(confirmationText == "SUPPRIMER" ? Color.red : Color.gray)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .disabled(confirmationText != "SUPPRIMER")
                            
                            Button(action: { step = 1 }) {
                                Text(LocalizedStringKey("Retour"))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 30)
                }
            }
            .navigationTitle(LocalizedStringKey("Réinitialisation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert(LocalizedStringKey("Dernière confirmation"), isPresented: $showingFinalAlert) {
                Button(LocalizedStringKey("Annuler"), role: .cancel) {}
                Button(LocalizedStringKey("Supprimer tout"), role: .destructive) {
                    performFullReset()
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous absolument sûr ? Toutes les données du coffre-fort seront perdues définitivement."))
            }
        }
    }
    
    private func performFullReset() {
        // Supprimer tous les éléments du coffre-fort
        dataManager.supprimerTousCoffreItems()
        // Supprimer le mot de passe et la question de récupération
        passwordManager.removePassword()
        // Fermer et notifier
        dismiss()
        onReset()
    }
}

// MARK: - Changement de mot de passe
struct ChangePasswordView: View {
    var passwordManager: CoffrePasswordManager
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    private func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "fr", ofType: "lproj")
        let bundle = path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    // Question de récupération
    @State private var selectedQuestion = 0
    @State private var recoveryAnswer = ""
    
    let recoveryQuestions = [
        "Quel est le nom de votre premier animal de compagnie ?",
        "Quel est le prénom de votre meilleur ami d'enfance ?",
        "Quelle est la ville de naissance de votre mère ?",
        "Quel est le nom de votre école primaire ?",
        "Quel est votre plat préféré ?",
        "Quelle est la marque de votre première voiture ?"
    ]
    
    var hasExistingRecovery: Bool {
        passwordManager.getRecoveryQuestion() != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.orange.opacity(0.2), Color.red.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text(LocalizedStringKey("Changer le mot de passe"))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Ancien mot de passe
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey("Ancien mot de passe"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField(LocalizedStringKey("Ancien mot de passe"), text: $oldPassword)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Divider()
                            
                            // Nouveau mot de passe
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey("Nouveau mot de passe"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField(LocalizedStringKey("Nouveau mot de passe"), text: $newPassword)
                                    .textFieldStyle(.roundedBorder)
                                
                                SecureField(LocalizedStringKey("Confirmer le nouveau mot de passe"), text: $confirmPassword)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Divider()
                            
                            // Question de récupération
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .foregroundColor(.orange)
                                    Text(LocalizedStringKey("Question de récupération"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                if hasExistingRecovery {
                                    Text(LocalizedStringKey("Une question de récupération existe déjà. Vous pouvez la modifier ci-dessous."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(LocalizedStringKey("Définissez une question pour récupérer votre mot de passe en cas d'oubli."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Picker(LocalizedStringKey("Question"), selection: $selectedQuestion) {
                                    ForEach(0..<recoveryQuestions.count, id: \.self) { index in
                                        Text(LocalizedStringKey(recoveryQuestions[index]))
                                            .tag(index)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.orange)
                                
                                TextField(LocalizedStringKey("Votre réponse"), text: $recoveryAnswer)
                                    .textFieldStyle(.roundedBorder)
                                
                                if !recoveryAnswer.isEmpty && recoveryAnswer.count < 2 {
                                    Text(LocalizedStringKey("La réponse doit contenir au moins 2 caractères"))
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if showSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(LocalizedStringKey("Mot de passe modifié avec succès"))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button(action: changePassword) {
                            Text(LocalizedStringKey("Modifier le mot de passe"))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || (recoveryAnswer.count > 0 && recoveryAnswer.count < 2))
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(LocalizedStringKey("Sécurité"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func changePassword() {
        guard passwordManager.verifyPassword(oldPassword) else {
            errorMessage = localizedString("Ancien mot de passe incorrect")
            showError = true
            return
        }
        
        guard newPassword.count >= 4 else {
            errorMessage = localizedString("Le mot de passe doit contenir au moins 4 caractères")
            showError = true
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = localizedString("Les mots de passe ne correspondent pas")
            showError = true
            return
        }
        
        // Sauvegarder la question de récupération si remplie
        if recoveryAnswer.count >= 2 {
            _ = passwordManager.setRecoveryQuestion(recoveryQuestions[selectedQuestion], answer: recoveryAnswer)
        }
        
        if passwordManager.changePassword(oldPassword: oldPassword, newPassword: newPassword) {
            showError = false
            showSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } else {
            errorMessage = localizedString("Erreur lors du changement de mot de passe")
            showError = true
        }
    }
}

// MARK: - Contenu du coffre-fort
struct CoffreContenuView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingAddSheet = false
    @State private var showingLimitAlert = false
    @State private var showPremiumSheet = false
    @State private var searchText = ""
    @State private var selectedCategorie = "Tous"
    @State private var showingExportSheet = false
    @State private var shareURL: IdentifiableURL?
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var showChangePassword = false
    @State private var passwordManager = CoffrePasswordManager()
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    
    var categories: [String] {
        let cats = Set(dataManager.coffreItems.map { $0.categorie })
        return ["Tous"] + cats.sorted()
    }
    
    var itemsFiltres: [CoffreItem] {
        dataManager.coffreItems.filter { item in
            let matchSearch = searchText.isEmpty ||
                item.nom.localizedCaseInsensitiveContains(searchText) ||
                item.description.localizedCaseInsensitiveContains(searchText)
            let matchCategorie = selectedCategorie == "Tous" || item.categorie == selectedCategorie
            return matchSearch && matchCategorie
        }
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
                
                VStack(spacing: 0) {
                    // Résumé valeur totale
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Valeur totale estimée"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(dataManager.valeurTotaleCoffre, format: .currency(code: "EUR"))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(LocalizedStringKey("Objets"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(dataManager.coffreItems.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    List {
                        // Bouton ajouter
                        Section {
                            Button(action: {
                                if dataManager.peutAjouterCoffreItem() {
                                    showingAddSheet = true
                                } else {
                                    showingLimitAlert = true
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text(LocalizedStringKey("Ajouter un objet"))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                        
                        // Filtre par catégorie
                        if categories.count > 1 {
                            Section {
                                Picker(LocalizedStringKey("Catégorie"), selection: $selectedCategorie) {
                                    ForEach(categories, id: \.self) { cat in
                                        Text(LocalizedStringKey(cat)).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        // Liste des objets
                        ForEach(itemsFiltres) { item in
                            NavigationLink(destination: CoffreItemDetailView(item: item)) {
                                CoffreItemRowView(item: item)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            if storeManager.hasUnlockedPremium {
                                // Suppression directe en mode Premium
                                for index in offsets {
                                    let item = itemsFiltres[index]
                                    dataManager.supprimerCoffreItem(item)
                                }
                            } else {
                                // Alerte de confirmation en version gratuite
                                indexSetToDelete = offsets
                                showingDeleteAlert = true
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: LocalizedStringKey("Rechercher un objet"))
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(LocalizedStringKey("Coffre-fort"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section(header: Text(LocalizedStringKey("Export PDF"))) {
                            Button(action: exporterInventairePDF) {
                                Label(LocalizedStringKey("Inventaire Assurance (PDF)"), systemImage: "doc.richtext")
                            }
                        }
                        
                        Section(header: Text(LocalizedStringKey("Sauvegarde"))) {
                            Button(action: exporterCoffreFortJSON) {
                                Label(LocalizedStringKey("Export JSON"), systemImage: "arrow.up.doc")
                            }
                            Button(action: { showImportPicker = true }) {
                                Label(LocalizedStringKey("Import JSON"), systemImage: "arrow.down.doc")
                            }
                        }
                        
                        Section(header: Text(LocalizedStringKey("Sécurité"))) {
                            Button(action: { showChangePassword = true }) {
                                Label(LocalizedStringKey("Changer le mot de passe"), systemImage: "key.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AjouterCoffreItemView()
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView(passwordManager: passwordManager)
            }
            .sheet(item: $shareURL) { item in
                ShareSheet(activityItems: [item.url])
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json, .data, .text, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        print("[CoffreFortView] Fichier sélectionné: \(url.path)")
                        
                        let accessing = url.startAccessingSecurityScopedResource()
                        print("[CoffreFortView] Accès sécurisé: \(accessing)")
                        
                        let success = dataManager.importerCoffreFort(from: url)
                        
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                        
                        if success {
                            showImportSuccess = true
                        } else {
                            showImportError = true
                        }
                    }
                case .failure(let error):
                    print("[CoffreFortView] Erreur sélection fichier: \(error)")
                    showImportError = true
                }
            }
            .alert(LocalizedStringKey("Import réussi"), isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Les données ont été importées avec succès"))
            }
            .alert(LocalizedStringKey("Erreur d'import"), isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Impossible d'importer le fichier"))
            }
            .alert(LocalizedStringKey("Suppression définitive"), isPresented: $showingDeleteAlert) {
                Button(LocalizedStringKey("Supprimer"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        for index in offsets {
                            let item = itemsFiltres[index]
                            dataManager.supprimerCoffreItem(item)
                        }
                    }
                    indexSetToDelete = nil
                }
                Button(LocalizedStringKey("Annuler"), role: .cancel) {
                    indexSetToDelete = nil
                }
            } message: {
                Text(LocalizedStringKey("Êtes-vous sûr de vouloir supprimer cet objet du coffre-fort ? Cette action est irréversible."))
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumSheet = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Limite coffre-fort atteinte"))
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
    }
    
    func supprimerItems(at offsets: IndexSet) {
        for index in offsets {
            let item = itemsFiltres[index]
            dataManager.supprimerCoffreItem(item)
        }
    }
    
    func exporterInventairePDF() {
        if let url = dataManager.exporterCoffreFortPDF() {
            shareURL = IdentifiableURL(url: url)
        }
    }
    
    func exporterCoffreFortJSON() {
        if let url = dataManager.exporterCoffreFort() {
            shareURL = IdentifiableURL(url: url)
        }
    }
}

// MARK: - Ligne d'un objet du coffre-fort
struct CoffreItemRowView: View {
    let item: CoffreItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Vignette photo
            if let data = item.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.15))
                    Image(systemName: "photo")
                        .foregroundColor(.orange)
                }
                .frame(width: 56, height: 56)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.nom)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if item.factureData != nil {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(item.categorie)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Text(item.valeurEstimee, format: .currency(code: "EUR"))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        .padding(.vertical, 4)
    }
}

// MARK: - Détail d'un objet du coffre-fort
struct CoffreItemDetailView: View {
    let item: CoffreItem
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    @State private var showingEditSheet = false
    @State private var showingFullPhoto = false
    @State private var showingFullFacture = false
    @State private var shareURL: IdentifiableURL?
    
    // Helper function pour la localisation avec la langue sélectionnée
    private func localizedString(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    var itemCourant: CoffreItem {
        dataManager.getCoffreItem(id: item.id) ?? item
    }
    
    var body: some View {
        List {
            // Photo de l'objet
            Section(LocalizedStringKey("Photo de l'objet")) {
                if let data = itemCourant.photoData, let uiImage = UIImage(data: data) {
                    Button(action: { showingFullPhoto = true }) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Text(LocalizedStringKey("Aucune photo"))
                        .foregroundColor(.secondary)
                }
            }
            
            // Informations
            Section(LocalizedStringKey("Informations")) {
                LabeledContent(LocalizedStringKey("Nom"), value: itemCourant.nom)
                if !itemCourant.description.isEmpty {
                    LabeledContent(LocalizedStringKey("Description"), value: itemCourant.description)
                }
                LabeledContent(LocalizedStringKey("Catégorie"), value: itemCourant.categorie)
                LabeledContent(LocalizedStringKey("Valeur estimée"), value: String(format: "%.2f €", itemCourant.valeurEstimee))
                LabeledContent(LocalizedStringKey("Date d'acquisition"), value: itemCourant.dateAcquisition.formatted(date: .long, time: .omitted))
                
                if let marque = itemCourant.marque, !marque.isEmpty {
                    LabeledContent(LocalizedStringKey("Marque"), value: marque)
                }
                if let modele = itemCourant.modele, !modele.isEmpty {
                    LabeledContent(LocalizedStringKey("Modèle"), value: modele)
                }
                if let numeroSerie = itemCourant.numeroSerie, !numeroSerie.isEmpty {
                    LabeledContent(LocalizedStringKey("N° de série"), value: numeroSerie)
                }
            }
            
            // Facture / Preuve d'achat
            Section(LocalizedStringKey("Facture / Preuve d'achat")) {
                if let data = itemCourant.factureData {
                    Button(action: { showingFullFacture = true }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text(LocalizedStringKey("Facture enregistrée"))
                                    .foregroundColor(.green)
                                if itemCourant.factureIsPDF == true {
                                    Spacer()
                                    Label("PDF", systemImage: "doc.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .font(.caption)
                            
                            if itemCourant.factureIsPDF == true {
                                PDFThumbnailView(data: data)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(LocalizedStringKey("Aucune facture enregistrée"))
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            
            // Notes
            if let notes = itemCourant.notes, !notes.isEmpty {
                Section(LocalizedStringKey("Notes")) {
                    Text(notes)
                        .font(.subheadline)
                }
            }
            
            // Date d'ajout au coffre
            Section {
                LabeledContent(LocalizedStringKey("Ajouté au coffre"), value: itemCourant.dateCreation.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    Button(action: { exporterFichePDF() }) {
                        Label(LocalizedStringKey("Exporter la fiche"), systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $shareURL) { item in
            ShareSheet(activityItems: [item.url])
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCoffreItemView(item: itemCourant)
        }
        .fullScreenCover(isPresented: $showingFullPhoto) {
            if let data = itemCourant.photoData, let uiImage = UIImage(data: data) {
                FullScreenImageView(image: uiImage, title: LocalizedStringKey("Photo de l'objet"))
            }
        }
        .fullScreenCover(isPresented: $showingFullFacture) {
            if let data = itemCourant.factureData {
                if itemCourant.factureIsPDF == true {
                    CoffrePDFViewerView(data: data)
                } else if let uiImage = UIImage(data: data) {
                    FullScreenImageView(image: uiImage, title: LocalizedStringKey("Facture"))
                }
            }
        }
    }
    
    // MARK: - Export PDF de la fiche
    private func exporterFichePDF() {
        let pageWidth: CGFloat = 595.2  // A4
        let pageHeight: CGFloat = 841.8 // A4
        let margin: CGFloat = 40
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            
            var yPosition: CGFloat = margin
            let contentWidth = pageWidth - 2 * margin
            
            // Titre
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let title = itemCourant.nom
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 30)
            title.draw(in: titleRect, withAttributes: titleAttributes)
            yPosition += 40
            
            // Sous-titre catégorie
            let subtitleFont = UIFont.systemFont(ofSize: 14, weight: .medium)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.darkGray
            ]
            let categorie = itemCourant.categorie
            categorie.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition += 30
            
            // Ligne séparatrice
            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: yPosition))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            cgContext.strokePath()
            yPosition += 20
            
            // Photo de l'objet
            if let photoData = itemCourant.photoData, let originalImage = UIImage(data: photoData) {
                let image = originalImage.compressedForExport()
                let sectionTitle = localizedString("Photo de l'objet")
                sectionTitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ])
                yPosition += 25
                
                let maxImageHeight: CGFloat = 180
                let maxImageWidth = contentWidth
                let aspectRatio = image.size.width / image.size.height
                var imageWidth = maxImageWidth
                var imageHeight = imageWidth / aspectRatio
                if imageHeight > maxImageHeight {
                    imageHeight = maxImageHeight
                    imageWidth = imageHeight * aspectRatio
                }
                let imageRect = CGRect(x: margin, y: yPosition, width: imageWidth, height: imageHeight)
                image.draw(in: imageRect)
                yPosition += imageHeight + 20
            }
            
            // Informations
            let infoTitle = localizedString("Informations")
            infoTitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ])
            yPosition += 25
            
            let labelFont = UIFont.systemFont(ofSize: 12, weight: .medium)
            let valueFont = UIFont.systemFont(ofSize: 12)
            let labelColor = UIColor.darkGray
            let valueColor = UIColor.black
            let lineHeight: CGFloat = 20
            
            func drawInfoLine(label: String, value: String) {
                let labelAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: labelColor]
                let valueAttr: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: valueColor]
                label.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttr)
                value.draw(at: CGPoint(x: margin + 150, y: yPosition), withAttributes: valueAttr)
                yPosition += lineHeight
            }
            
            drawInfoLine(label: localizedString("Nom") + ":", value: itemCourant.nom)
            if !itemCourant.description.isEmpty {
                drawInfoLine(label: localizedString("Description") + ":", value: itemCourant.description)
            }
            drawInfoLine(label: localizedString("Catégorie") + ":", value: itemCourant.categorie)
            drawInfoLine(label: localizedString("Valeur estimée") + ":", value: String(format: "%.2f €", itemCourant.valeurEstimee))
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.locale = Locale(identifier: appLanguage)
            drawInfoLine(label: localizedString("Date d'acquisition") + ":", value: dateFormatter.string(from: itemCourant.dateAcquisition))
            
            if let marque = itemCourant.marque, !marque.isEmpty {
                drawInfoLine(label: localizedString("Marque") + ":", value: marque)
            }
            if let modele = itemCourant.modele, !modele.isEmpty {
                drawInfoLine(label: localizedString("Modèle") + ":", value: modele)
            }
            if let numeroSerie = itemCourant.numeroSerie, !numeroSerie.isEmpty {
                drawInfoLine(label: localizedString("N° de série") + ":", value: numeroSerie)
            }
            
            yPosition += 10
            
            // Notes
            if let notes = itemCourant.notes, !notes.isEmpty {
                let notesTitle = localizedString("Notes")
                notesTitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ])
                yPosition += 20
                notes.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.darkGray
                ])
                yPosition += 30
            }
            
            // Facture / Preuve d'achat (sur une nouvelle page si nécessaire)
            if let factureData = itemCourant.factureData {
                // Nouvelle page pour la facture si on manque d'espace
                if yPosition > pageHeight - 300 {
                    context.beginPage()
                    yPosition = margin
                }
                
                let factureTitle = localizedString("Facture / Preuve d'achat")
                factureTitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ])
                yPosition += 25
                
                var factureImage: UIImage? = nil
                
                // Vérifier si c'est un PDF
                if itemCourant.factureIsPDF == true, let pdfDoc = PDFDocument(data: factureData), let pdfPage = pdfDoc.page(at: 0) {
                    // Générer une image haute qualité du PDF
                    let pdfRect = pdfPage.bounds(for: .mediaBox)
                    let scale: CGFloat = 2.0 // Haute résolution
                    let thumbSize = CGSize(width: pdfRect.width * scale, height: pdfRect.height * scale)
                    factureImage = pdfPage.thumbnail(of: thumbSize, for: .mediaBox)
                } else if let imgData = UIImage(data: factureData) {
                    factureImage = imgData.compressedForExport()
                }
                
                if let img = factureImage {
                    let maxFactureHeight: CGFloat = pageHeight - yPosition - margin - 50
                    let maxFactureWidth = contentWidth
                    let aspectRatio = img.size.width / img.size.height
                    var factureWidth = maxFactureWidth
                    var factureHeight = factureWidth / aspectRatio
                    if factureHeight > maxFactureHeight {
                        factureHeight = maxFactureHeight
                        factureWidth = factureHeight * aspectRatio
                    }
                    let factureRect = CGRect(x: margin, y: yPosition, width: factureWidth, height: factureHeight)
                    img.draw(in: factureRect)
                }
            }
        }
        
        // Sauvegarder et partager
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = dateFormatter.string(from: Date())
        let safeFileName = itemCourant.nom.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let fileName = "Fiche_\(safeFileName)_\(dateString).pdf"
        
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let fileURL = cachePath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            shareURL = IdentifiableURL(url: fileURL)
        } catch {
            print("Erreur création fichier PDF: \(error)")
        }
    }
}

// MARK: - Vue plein écran pour les images
struct FullScreenImageView: View {
    let image: UIImage
    let title: LocalizedStringKey
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - PDF Full Viewer pour Coffre-Fort
struct CoffrePDFViewerView: View {
    let data: Data
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            CoffrePDFKitView(data: data)
                .navigationTitle(LocalizedStringKey("Facture PDF"))
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

// MARK: - PDFKit SwiftUI Wrapper pour Coffre-Fort
struct CoffrePDFKitView: UIViewRepresentable {
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

// MARK: - Ajouter un objet au coffre-fort
struct AjouterCoffreItemView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var nom = ""
    @State private var description = ""
    @State private var categorie = "Électronique"
    @State private var valeurEstimee = ""
    @State private var dateAcquisition = Date()
    @State private var marque = ""
    @State private var modele = ""
    @State private var numeroSerie = ""
    @State private var notes = ""
    
    @State private var photoData: Data? = nil
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var factureData: Data? = nil
    @State private var factureIsPDF: Bool = false
    @State private var showCameraFacturePicker = false
    @State private var showPhotoLibraryFacturePicker = false
    @State private var showPDFPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                // Photo de l'objet
                Section(LocalizedStringKey("Photo de l'objet")) {
                    VStack(spacing: 12) {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            HStack {
                                Spacer()
                                Button(role: .destructive) { photoData = nil } label: {
                                    Label(LocalizedStringKey("Retirer"), systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(height: 120)
                                VStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.orange)
                                    Text(LocalizedStringKey("Photo de l'objet"))
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
                                Label(LocalizedStringKey(photoData == nil ? "Ajouter une photo" : "Changer la photo"), systemImage: "photo.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Informations générales
                Section(LocalizedStringKey("Informations")) {
                    TextField(LocalizedStringKey("Nom de l'objet"), text: $nom)
                    TextField(LocalizedStringKey("Description"), text: $description)
                    
                    Picker(LocalizedStringKey("Catégorie"), selection: $categorie) {
                        ForEach(CoffreItem.categoriesPredefinies, id: \.self) { cat in
                            Text(LocalizedStringKey(cat)).tag(cat)
                        }
                    }
                    
                    TextField(LocalizedStringKey("Valeur estimée (€)"), text: $valeurEstimee)
                        .keyboardType(.decimalPad)
                    
                    DatePicker(LocalizedStringKey("Date d'acquisition"), selection: $dateAcquisition, displayedComponents: .date)
                }
                
                // Détails techniques
                Section(LocalizedStringKey("Détails (optionnel)")) {
                    TextField(LocalizedStringKey("Marque"), text: $marque)
                    TextField(LocalizedStringKey("Modèle"), text: $modele)
                    TextField(LocalizedStringKey("N° de série"), text: $numeroSerie)
                }
                
                // Facture
                Section(LocalizedStringKey("Facture / Preuve d'achat")) {
                    VStack(spacing: 12) {
                        if let data = factureData {
                            if factureIsPDF {
                                // Affichage PDF
                                PDFThumbnailView(data: data)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if let uiImage = UIImage(data: data) {
                                // Affichage Image
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            HStack {
                                if factureIsPDF {
                                    Label("PDF", systemImage: "doc.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                Spacer()
                                Button(role: .destructive) { 
                                    factureData = nil
                                    factureIsPDF = false
                                } label: {
                                    Label(LocalizedStringKey("Retirer"), systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(height: 100)
                                VStack(spacing: 6) {
                                    Image(systemName: "doc.text.image")
                                        .font(.system(size: 28))
                                        .foregroundColor(.green)
                                    Text(LocalizedStringKey("Preuve d'achat"))
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
                
                // Notes
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Nouvel objet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !storeManager.hasUnlockedPremium {
                        VStack(spacing: 2) {
                            Text(LocalizedStringKey("Nouvel objet"))
                                .font(.headline)
                            Text("\(dataManager.totalCoffreItemsCreated)/\(StoreManager.freeCoffreLimit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Ajouter")) { ajouter() }
                        .disabled(nom.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            CoffreImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        photoData = image.jpegData(compressionQuality: 0.7)
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            CoffreImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        photoData = image.jpegData(compressionQuality: 0.7)
                    }
                }
            ), sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCameraFacturePicker) {
            CoffreImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        factureData = image.jpegData(compressionQuality: 0.7)
                        factureIsPDF = false
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showPhotoLibraryFacturePicker) {
            CoffreImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        factureData = image.jpegData(compressionQuality: 0.7)
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
                            factureData = data
                            factureIsPDF = true
                        }
                    }
                }
            case .failure(let error):
                print("Erreur import PDF: \(error)")
            }
        }
    }
    
    private func ajouter() {
        let item = CoffreItem(
            nom: nom,
            description: description,
            categorie: categorie,
            valeurEstimee: Double(valeurEstimee.replacingOccurrences(of: ",", with: ".")) ?? 0,
            dateAcquisition: dateAcquisition,
            photoData: photoData,
            factureData: factureData,
            factureIsPDF: factureIsPDF ? true : nil,
            numeroSerie: numeroSerie.isEmpty ? nil : numeroSerie,
            marque: marque.isEmpty ? nil : marque,
            modele: modele.isEmpty ? nil : modele,
            notes: notes.isEmpty ? nil : notes
        )
        dataManager.ajouterCoffreItem(item)
        dismiss()
    }
}

// MARK: - Modifier un objet du coffre-fort
struct EditCoffreItemView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    let original: CoffreItem
    
    @State private var nom: String
    @State private var description: String
    @State private var categorie: String
    @State private var valeurEstimee: String
    @State private var dateAcquisition: Date
    @State private var marque: String
    @State private var modele: String
    @State private var numeroSerie: String
    @State private var notes: String
    
    @State private var photoData: Data?
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var factureData: Data?
    @State private var factureIsPDF: Bool = false
    @State private var showCameraFacturePicker = false
    @State private var showPhotoLibraryFacturePicker = false
    @State private var showPDFPicker = false
    
    init(item: CoffreItem) {
        self.original = item
        _nom = State(initialValue: item.nom)
        _description = State(initialValue: item.description)
        _categorie = State(initialValue: item.categorie)
        _valeurEstimee = State(initialValue: String(format: "%.2f", item.valeurEstimee))
        _dateAcquisition = State(initialValue: item.dateAcquisition)
        _marque = State(initialValue: item.marque ?? "")
        _modele = State(initialValue: item.modele ?? "")
        _numeroSerie = State(initialValue: item.numeroSerie ?? "")
        _notes = State(initialValue: item.notes ?? "")
        _photoData = State(initialValue: item.photoData)
        _factureData = State(initialValue: item.factureData)
        _factureIsPDF = State(initialValue: item.factureIsPDF ?? false)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Photo de l'objet
                Section(LocalizedStringKey("Photo de l'objet")) {
                    VStack(spacing: 12) {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            HStack {
                                Spacer()
                                Button(role: .destructive) { photoData = nil } label: {
                                    Label(LocalizedStringKey("Retirer"), systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(height: 120)
                                VStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.orange)
                                    Text(LocalizedStringKey("Photo de l'objet"))
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
                                Label(LocalizedStringKey(photoData == nil ? "Ajouter une photo" : "Changer la photo"), systemImage: "photo.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Informations générales
                Section(LocalizedStringKey("Informations")) {
                    TextField(LocalizedStringKey("Nom de l'objet"), text: $nom)
                    TextField(LocalizedStringKey("Description"), text: $description)
                    
                    Picker(LocalizedStringKey("Catégorie"), selection: $categorie) {
                        ForEach(CoffreItem.categoriesPredefinies, id: \.self) { cat in
                            Text(LocalizedStringKey(cat)).tag(cat)
                        }
                    }
                    
                    TextField(LocalizedStringKey("Valeur estimée (€)"), text: $valeurEstimee)
                        .keyboardType(.decimalPad)
                    
                    DatePicker(LocalizedStringKey("Date d'acquisition"), selection: $dateAcquisition, displayedComponents: .date)
                }
                
                // Détails techniques
                Section(LocalizedStringKey("Détails (optionnel)")) {
                    TextField(LocalizedStringKey("Marque"), text: $marque)
                    TextField(LocalizedStringKey("Modèle"), text: $modele)
                    TextField(LocalizedStringKey("N° de série"), text: $numeroSerie)
                }
                
                // Facture
                Section(LocalizedStringKey("Facture / Preuve d'achat")) {
                    VStack(spacing: 12) {
                        if let data = factureData {
                            if factureIsPDF {
                                // Affichage PDF
                                PDFThumbnailView(data: data)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if let uiImage = UIImage(data: data) {
                                // Affichage Image
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            HStack {
                                if factureIsPDF {
                                    Label("PDF", systemImage: "doc.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                Spacer()
                                Button(role: .destructive) { 
                                    factureData = nil
                                    factureIsPDF = false
                                } label: {
                                    Label(LocalizedStringKey("Retirer"), systemImage: "trash")
                                }
                                .font(.caption)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(height: 100)
                                VStack(spacing: 6) {
                                    Image(systemName: "doc.text.image")
                                        .font(.system(size: 28))
                                        .foregroundColor(.green)
                                    Text(LocalizedStringKey("Preuve d'achat"))
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
                
                // Notes
                Section(LocalizedStringKey("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizedStringKey("Modifier"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Enregistrer")) { enregistrer() }
                        .disabled(nom.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            CoffreImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        photoData = image.jpegData(compressionQuality: 0.7)
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            CoffreImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        photoData = image.jpegData(compressionQuality: 0.7)
                    }
                }
            ), sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCameraFacturePicker) {
            CoffreImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        factureData = image.jpegData(compressionQuality: 0.7)
                        factureIsPDF = false
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showPhotoLibraryFacturePicker) {
            CoffreImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        factureData = image.jpegData(compressionQuality: 0.7)
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
                            factureData = data
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
        var updated = original
        updated.nom = nom
        updated.description = description
        updated.categorie = categorie
        updated.valeurEstimee = Double(valeurEstimee.replacingOccurrences(of: ",", with: ".")) ?? original.valeurEstimee
        updated.dateAcquisition = dateAcquisition
        updated.marque = marque.isEmpty ? nil : marque
        updated.modele = modele.isEmpty ? nil : modele
        updated.numeroSerie = numeroSerie.isEmpty ? nil : numeroSerie
        updated.notes = notes.isEmpty ? nil : notes
        updated.photoData = photoData
        updated.factureData = factureData
        updated.factureIsPDF = factureIsPDF ? true : nil
        
        dataManager.modifierCoffreItem(updated)
        dismiss()
    }
}

// MARK: - Image Picker pour Coffre-Fort (Caméra)
struct CoffreImagePicker: UIViewControllerRepresentable {
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
        let parent: CoffreImagePicker
        init(_ parent: CoffreImagePicker) { self.parent = parent }
        
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

#Preview {
    CoffreFortView()
        .environmentObject(DataManager())
}
