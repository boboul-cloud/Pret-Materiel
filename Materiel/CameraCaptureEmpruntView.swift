//
//  CameraCaptureEmpruntView.swift
//  Materiel
//
//  Created on 01/12/2025.
//  Création rapide d'un emprunt avec photo

import SwiftUI
import UIKit

// Fonction helper pour les couleurs de type de personne
private func couleurPourTypePersonne(_ type: TypePersonne?) -> Color {
    switch type {
    case .mecanicien: return .orange
    case .salarie: return .green
    case .alm: return .purple
    case .client, .none: return .blue
    }
}

struct CameraCaptureEmpruntView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var capturedImage: UIImage?
    @State private var showEmpruntForm = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = capturedImage {
                    imagePreviewSection(image: image)
                } else {
                    sourceSelectionSection
                }
            }
            .navigationTitle(LocalizedStringKey("Photo de l'objet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                EmpruntImagePicker(image: $capturedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showPhotoPicker) {
                EmpruntImagePicker(image: $capturedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showEmpruntForm) {
                if let image = capturedImage {
                    EmpruntFormWithImageView(capturedImage: image, onDismiss: {
                        dismiss()
                    })
                }
            }
        }
    }
    
    private func imagePreviewSection(image: UIImage) -> some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            
            HStack(spacing: 20) {
                Button(action: { capturedImage = nil }) {
                    VStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text(LocalizedStringKey("Reprendre"))
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.7))
                    .cornerRadius(10)
                }
                
                Button(action: { showEmpruntForm = true }) {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                        Text(LocalizedStringKey("Continuer"))
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    private var sourceSelectionSection: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text(LocalizedStringKey("Ajouter une photo de l'objet emprunté"))
                .foregroundColor(.white)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 15) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button(action: { showCameraPicker = true }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text(LocalizedStringKey("Prendre une photo"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
                
                Button(action: { showPhotoPicker = true }) {
                    HStack {
                        Image(systemName: "photo.fill")
                        Text(LocalizedStringKey("Choisir une photo"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

// MARK: - Image Picker pour Emprunt
struct EmpruntImagePicker: UIViewControllerRepresentable {
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
        let parent: EmpruntImagePicker
        init(_ parent: EmpruntImagePicker) { self.parent = parent }
        
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

// MARK: - Formulaire d'emprunt avec image
struct EmpruntFormWithImageView: View {
    @EnvironmentObject private var dataManager: DataManager
    let capturedImage: UIImage
    let onDismiss: () -> Void
    
    @State private var nomObjet = ""
    @State private var personneId: UUID?
    @State private var showingAddPerson = false
    @State private var showingPersonneSelection = false
    @State private var dateFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Personne sélectionnée pour affichage
    var personneSelectionnee: Personne? {
        guard let id = personneId else { return nil }
        return dataManager.getPersonne(id: id)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizedStringKey("Photo de l'objet emprunté")) {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(10)
                }
                
                Section(LocalizedStringKey("Informations de l'objet")) {
                    TextField(LocalizedStringKey("Nom de l'objet"), text: $nomObjet)
                }
                
                Section(LocalizedStringKey("Personne qui me prête")) {
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
                        Text(LocalizedStringKey("Aucune personne enregistrée"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(LocalizedStringKey("Détails de l'emprunt")) {
                    DatePicker(LocalizedStringKey("Date de retour prévue"), selection: $dateFin, in: Date()..., displayedComponents: .date)
                    TextField(LocalizedStringKey("Notes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(LocalizedStringKey("Nouvel emprunt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("Annuler")) { onDismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("Créer")) { creerEmprunt() }
                        .fontWeight(.semibold)
                        .disabled(nomObjet.isEmpty || personneId == nil)
                }
            }
            .alert(LocalizedStringKey("Information"), isPresented: $showAlert) {
                Button("OK") {
                    if alertMessage.contains("créé") { onDismiss() }
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingAddPerson) {
                AjouterPersonneView()
            }
            .sheet(isPresented: $showingPersonneSelection) {
                PersonneSelectionView(
                    selectedPersonneId: $personneId,
                    personnes: dataManager.personnes,
                    title: LocalizedStringKey("Choisir le prêteur"),
                    showAddButton: true,
                    onAddPerson: { showingAddPerson = true }
                )
            }
        }
        .onChange(of: dataManager.personnes.count) { oldValue, newValue in
            if newValue > oldValue { personneId = dataManager.personnes.last?.id }
        }
    }
    
    private func creerEmprunt() {
        // Vérifier la limite avant de créer
        guard dataManager.peutAjouterEmprunt() else {
            alertMessage = NSLocalizedString("Limite emprunts atteinte", comment: "")
            showAlert = true
            return
        }
        
        guard let personneId = personneId else {
            alertMessage = NSLocalizedString("Veuillez sélectionner ou créer une personne", comment: "")
            showAlert = true
            return
        }
        
        let imageData = capturedImage.jpegData(compressionQuality: 0.7)
        let nouvelEmprunt = Emprunt(
            nomObjet: nomObjet,
            personneId: personneId,
            dateDebut: Date(),
            dateFin: dateFin,
            notes: notes,
            imageData: imageData
        )
        dataManager.ajouterEmprunt(nouvelEmprunt)
        
        alertMessage = NSLocalizedString("Emprunt créé avec succès !", comment: "")
        showAlert = true
    }
}

#Preview {
    CameraCaptureEmpruntView()
        .environmentObject(DataManager())
}
