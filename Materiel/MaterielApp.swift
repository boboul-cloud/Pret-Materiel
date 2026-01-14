//
//  MaterielApp.swift
//  Materiel
//
//  Created by Robert Oulhen on 10/11/2025.
//

import SwiftUI

@main
struct MaterielApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(storeManager)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background || phase == .inactive {
                        dataManager.sauvegarderDonnees()
                    } else if phase == .active {
                        // Mettre à jour le badge quand l'app revient au premier plan
                        dataManager.mettreAJourBadgeApp()
                    }
                }
        }
        #if targetEnvironment(macCatalyst)
        .commands {
            // Menu Fichier
            CommandGroup(after: .newItem) {
                Button("Nouveau Matériel") {
                    NotificationCenter.default.post(name: .newMateriel, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                
                Button("Nouveau Prêt") {
                    NotificationCenter.default.post(name: .newPret, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Button("Nouvel Emprunt") {
                    NotificationCenter.default.post(name: .newEmprunt, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Exporter les données...") {
                    NotificationCenter.default.post(name: .exportData, object: nil)
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])
                
                Button("Importer les données...") {
                    NotificationCenter.default.post(name: .importData, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            
            // Menu Affichage
            CommandGroup(after: .sidebar) {
                Button("Matériels") {
                    NotificationCenter.default.post(name: .showMateriels, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command])
                
                Button("Prêts") {
                    NotificationCenter.default.post(name: .showPrets, object: nil)
                }
                .keyboardShortcut("2", modifiers: [.command])
                
                Button("Emprunts") {
                    NotificationCenter.default.post(name: .showEmprunts, object: nil)
                }
                .keyboardShortcut("3", modifiers: [.command])
                
                Button("Coffre-fort") {
                    NotificationCenter.default.post(name: .showCoffreFort, object: nil)
                }
                .keyboardShortcut("4", modifiers: [.command])
            }
        }
        #endif
    }
}

// MARK: - Notifications pour Mac
extension Notification.Name {
    static let newMateriel = Notification.Name("newMateriel")
    static let newPret = Notification.Name("newPret")
    static let newEmprunt = Notification.Name("newEmprunt")
    static let newLocation = Notification.Name("newLocation")
    static let exportData = Notification.Name("exportData")
    static let importData = Notification.Name("importData")
    static let showMateriels = Notification.Name("showMateriels")
    static let showPrets = Notification.Name("showPrets")
    static let showEmprunts = Notification.Name("showEmprunts")
    static let showLocations = Notification.Name("showLocations")
    static let showCoffreFort = Notification.Name("showCoffreFort")
}
