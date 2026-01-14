//
//  HomeView.swift
//  Materiel
//
//  Created on 01/12/2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showCameraPret = false
    @State private var showCameraEmprunt = false
    @State private var showPremiumView = false
    @State private var showUserGuide = false
    @State private var showingPretLimitAlert = false
    @State private var showingEmpruntLimitAlert = false
    @State private var showingMaterielLimitAlert = false
    @StateObject private var storeManager = StoreManager.shared
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    private let languages = [
        ("fr", "🇫🇷", "Français"),
        ("en", "🇬🇧", "English"),
        ("de", "🇩🇪", "Deutsch"),
        ("es", "🇪🇸", "Español"),
        ("it", "🇮🇹", "Italiano"),
        ("pt", "🇵🇹", "Português"),
        ("nl", "🇳🇱", "Nederlands")
    ]
    
    private var currentFlag: String {
        languages.first { $0.0 == appLanguage }?.1 ?? "🇫🇷"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Titre de l'application avec icône
                    VStack(spacing: 15) {
                        // Icône de l'app cliquable pour ouvrir le mode d'emploi
                        Button {
                            showUserGuide = true
                        } label: {
                            Image("AppIconImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                )
                                .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        
                        Text(LocalizedStringKey("Gestion de prêts simplifiée"))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    
                    // Boutons d'action rapide
                    VStack(spacing: 15) {
                        // Bouton Prêt rapide
                        Button(action: {
                            if !dataManager.peutAjouterMateriel() {
                                showingMaterielLimitAlert = true
                            } else if !dataManager.peutAjouterPret() {
                                showingPretLimitAlert = true
                            } else {
                                showCameraPret = true
                            }
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "arrow.up.forward.circle.fill")
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(LocalizedStringKey("Créer un prêt rapide"))
                                        .font(.headline)
                                    Text(LocalizedStringKey("Je prête quelque chose"))
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 20)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        
                        // Bouton Emprunt rapide
                        Button(action: {
                            if dataManager.peutAjouterEmprunt() {
                                showCameraEmprunt = true
                            } else {
                                showingEmpruntLimitAlert = true
                            }
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "arrow.down.backward.circle.fill")
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(LocalizedStringKey("Créer un emprunt rapide"))
                                        .font(.headline)
                                    Text(LocalizedStringKey("On me prête quelque chose"))
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 20)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Bouton Version gratuite (si pas Premium)
                    if !storeManager.hasUnlockedPremium {
                        Button(action: {
                            showPremiumView = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.title3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("Version gratuite"))
                                        .font(.headline)
                                    Text(LocalizedStringKey("Passer à Premium"))
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title2)
                                    .opacity(0.6)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(languages, id: \.0) { lang in
                            Button {
                                appLanguage = lang.0
                            } label: {
                                HStack {
                                    Text("\(lang.1) \(lang.2)")
                                    if appLanguage == lang.0 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(currentFlag)
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showCameraPret) {
                CameraCapturePretView()
            }
            .sheet(isPresented: $showCameraEmprunt) {
                CameraCaptureEmpruntView()
            }
            .sheet(isPresented: $showPremiumView) {
                PremiumView()
            }
            .sheet(isPresented: $showUserGuide) {
                UserGuideView()
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingPretLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumView = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Limite prêts atteinte"))
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingEmpruntLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumView = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Limite emprunts atteinte"))
            }
            .alert(LocalizedStringKey("Limite atteinte"), isPresented: $showingMaterielLimitAlert) {
                Button(LocalizedStringKey("Passer à Premium")) {
                    showPremiumView = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("Limite matériels atteinte"))
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(DataManager())
}
