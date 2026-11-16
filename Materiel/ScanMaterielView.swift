//
//  ScanMaterielView.swift
//  Materiel
//
//  Scanner intelligent avec OpenAI Vision
//

import SwiftUI
import PhotosUI

struct ScanMaterielView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var aiService = OpenAIVisionService.shared
    
    @State private var selectedImage: UIImage?
    @State private var showingCameraPicker = false
    @State private var showingGalleryPicker = false
    
    // Résultats IA
    @State private var aiResult: AIRecognitionResult?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    
    // Champs modifiables par l'utilisateur
    @State private var nom: String = ""
    @State private var selectedCategorie: String = ""
    @State private var description: String = ""
    @State private var notes: String = ""
    
    // Configuration clé API
    @State private var showingAPIKeySheet = false
    @State private var apiKeyInput: String = ""
    
    // Catégories disponibles
    let categories = [
        "Électronique", "Outillage", "Audiovisuel", "Informatique", 
        "Mobilier", "Jardinage", "Sport", "Cuisine", "Bricolage", 
        "Véhicule", "Médical", "Bureautique", "Instruments de musique", "Autre"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Vérifier si la clé API est configurée
                    if !aiService.hasAPIKey {
                        apiKeyRequiredSection
                    } else {
                        // Zone d'image
                        imageSection
                        
                        if isAnalyzing {
                            analyzingSection
                        } else if let result = aiResult {
                            resultsSection(result)
                        } else if selectedImage != nil {
                            analyzeButton
                        }
                        
                        // Afficher erreur si présente
                        if let error = errorMessage {
                            errorSection(error)
                        }
                        
                        // Formulaire de création
                        if aiResult != nil {
                            formSection
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Scanner IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if aiResult != nil && !nom.isEmpty && !selectedCategorie.isEmpty {
                        Button("Créer") {
                            createMateriel()
                        }
                        .fontWeight(.semibold)
                    }
                }
                
                // Bouton pour modifier la clé API
                ToolbarItem(placement: .primaryAction) {
                    if aiService.hasAPIKey {
                        Menu {
                            Button(action: { showingAPIKeySheet = true }) {
                                Label("Modifier la clé API", systemImage: "key")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCameraPicker) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingGalleryPicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingAPIKeySheet) {
                apiKeySheet
            }
            .onChange(of: selectedImage) { _, newImage in
                if newImage != nil {
                    aiResult = nil
                    errorMessage = nil
                }
            }
        }
    }
    
    // MARK: - Sections de la vue
    
    private var apiKeyRequiredSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Clé API OpenAI requise")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Pour utiliser la reconnaissance intelligente, vous devez configurer votre clé API OpenAI.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Créez un compte sur platform.openai.com", systemImage: "1.circle.fill")
                Label("Générez une clé API", systemImage: "2.circle.fill")
                Label("Collez-la ci-dessous", systemImage: "3.circle.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button(action: { showingAPIKeySheet = true }) {
                Label("Configurer la clé API", systemImage: "key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(30)
    }
    
    private var imageSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(radius: 3)
                
                Button(action: { 
                    selectedImage = nil
                    aiResult = nil
                    errorMessage = nil
                    nom = ""
                    selectedCategorie = ""
                    description = ""
                }) {
                    Label("Changer d'image", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("Reconnaissance intelligente")
                        .font(.headline)
                    
                    Text("Prenez une photo, l'IA identifiera le matériel et remplira automatiquement le formulaire")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            showingCameraPicker = true
                        }) {
                            Label("Caméra", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        
                        Button(action: {
                            showingGalleryPicker = true
                        }) {
                            Label("Galerie", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(40)
                .background(
                    LinearGradient(colors: [.purple.opacity(0.05), .blue.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    private var analyzingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyse en cours...")
                .font(.headline)
            
            Text("L'IA identifie le matériel")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [.purple.opacity(0.1), .blue.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func resultsSection(_ result: AIRecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // En-tête avec confiance
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                
                Text("Matériel identifié")
                    .font(.headline)
                
                Spacer()
                
                Text(confidenceLabel(result.confidence))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidenceColor(result.confidence).opacity(0.2))
                    .foregroundStyle(confidenceColor(result.confidence))
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Informations détectées
            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "tag.fill", label: "Nom", value: result.nom, color: .blue)
                infoRow(icon: "folder.fill", label: "Catégorie", value: result.categorie, color: .purple)
                
                if let marque = result.marque {
                    infoRow(icon: "building.2.fill", label: "Marque", value: marque, color: .orange)
                }
                
                if let modele = result.modele {
                    infoRow(icon: "number", label: "Modèle", value: modele, color: .green)
                }
                
                if !result.description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(result.description)
                            .font(.subheadline)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("Erreur")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Réessayer") {
                errorMessage = nil
                if selectedImage != nil {
                    analyzeImage()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var analyzeButton: some View {
        Button(action: analyzeImage) {
            HStack {
                Image(systemName: "sparkles")
                Text("Identifier avec l'IA")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
    }
    
    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Créer le matériel")
                    .font(.headline)
                Spacer()
                Text("Modifiez si nécessaire")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Nom
            VStack(alignment: .leading, spacing: 4) {
                Text("Nom *")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Nom du matériel", text: $nom)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Catégorie
            VStack(alignment: .leading, spacing: 4) {
                Text("Catégorie *")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(action: { selectedCategorie = category }) {
                            HStack {
                                Text(category)
                                if category == selectedCategorie {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategorie.isEmpty ? "Sélectionner" : selectedCategorie)
                            .foregroundStyle(selectedCategorie.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
            
            // Notes (avec marque/modèle IA)
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Notes (marque, modèle...)", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var apiKeySheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "key.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
                
                Text("Clé API OpenAI")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Votre clé est stockée localement sur votre appareil et n'est jamais partagée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                SecureField("sk-...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !apiKeyInput.isEmpty && !apiKeyInput.hasPrefix("sk-") {
                    Text("La clé doit commencer par 'sk-'")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                Button(action: {
                    aiService.apiKey = apiKeyInput
                    showingAPIKeySheet = false
                }) {
                    Text("Enregistrer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty || !apiKeyInput.hasPrefix("sk-"))
                
                if aiService.hasAPIKey {
                    Button(role: .destructive, action: {
                        aiService.apiKey = nil
                        apiKeyInput = ""
                        showingAPIKeySheet = false
                    }) {
                        Text("Supprimer la clé")
                    }
                }
            }
            .padding()
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        showingAPIKeySheet = false
                    }
                }
            }
            .onAppear {
                apiKeyInput = aiService.apiKey ?? ""
            }
        }
    }
    
    // MARK: - Fonctions
    
    private func analyzeImage() {
        guard let image = selectedImage else { return }
        
        isAnalyzing = true
        errorMessage = nil
        
        aiService.analyzeImage(image) { result in
            isAnalyzing = false
            
            switch result {
            case .success(let recognition):
                aiResult = recognition
                
                // Pré-remplir les champs
                nom = recognition.nom
                selectedCategorie = recognition.categorie
                description = recognition.description
                
                // Ajouter marque/modèle dans les notes si détectés
                var notesAI: [String] = []
                if let marque = recognition.marque, !marque.isEmpty {
                    notesAI.append("🏷️ Marque: \(marque)")
                }
                if let modele = recognition.modele, !modele.isEmpty {
                    notesAI.append("📦 Modèle: \(modele)")
                }
                notes = notesAI.joined(separator: "\n")
                
            case .failure(let error):
                errorMessage = error.localizedDescription
                aiResult = nil
            }
        }
    }
    
    private func createMateriel() {
        let nouveauMateriel = Materiel(
            nom: nom,
            description: description,
            categorie: selectedCategorie,
            lieuStockageId: nil,
            notesMateriel: notes.isEmpty ? nil : notes,
            dateAcquisition: Date(),
            valeur: 0,
            imageData: selectedImage?.jpegData(compressionQuality: 0.8)
        )
        
        dataManager.ajouterMateriel(nouveauMateriel)
        dismiss()
    }
    
    private func confidenceLabel(_ confidence: String) -> String {
        switch confidence.lowercased() {
        case "haute": return "Confiance élevée"
        case "moyenne": return "Confiance moyenne"
        case "faible": return "Confiance faible"
        default: return confidence
        }
    }
    
    private func confidenceColor(_ confidence: String) -> Color {
        switch confidence.lowercased() {
        case "haute": return .green
        case "moyenne": return .orange
        case "faible": return .red
        default: return .gray
        }
    }
}

#Preview {
    ScanMaterielView()
        .environmentObject(DataManager())
}
