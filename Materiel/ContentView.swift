import SwiftUI

// MARK: - Extension pour masquer le clavier
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Modificateur pour masquer le clavier quand on tape en dehors des champs de saisie
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
    
    /// Modificateur pour masquer le clavier avec un geste simultané (ne bloque pas les autres interactions)
    func dismissKeyboardOnTap() -> some View {
        self.gesture(
            TapGesture()
                .onEnded { _ in
                    hideKeyboard()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { _ in
                    hideKeyboard()
                }
        )
    }
}

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"
    
    // États pour la navigation Mac
    @State private var selectedTab = 0
    @State private var showNewMateriel = false
    @State private var showNewPret = false
    @State private var showNewEmprunt = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15), Color.cyan.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label(LocalizedStringKey("Accueil"), systemImage: "house.fill") }
                    .tag(0)
                    .id("home-\(appLanguage)")
                MaterielListView()
                    .tabItem { Label(LocalizedStringKey("Matériel"), systemImage: "shippingbox") }
                    .tag(1)
                    .id("materiel-\(appLanguage)")
                PretListView()
                    .tabItem { Label(LocalizedStringKey("Prêts"), systemImage: "arrow.up.forward") }
                    .tag(2)
                    .id("prets-\(appLanguage)")
                EmpruntListView()
                    .tabItem { Label(LocalizedStringKey("Emprunts"), systemImage: "arrow.down.backward") }
                    .tag(3)
                    .id("emprunts-\(appLanguage)")
                AutreView()
                    .tabItem { Label(LocalizedStringKey("Autre"), systemImage: "ellipsis.circle") }
                    .tag(4)
                    .id("autre-\(appLanguage)")
            }
            .tint(.blue)
        }
        .environment(\.locale, .init(identifier: appLanguage))
        #if targetEnvironment(macCatalyst)
        .onReceive(NotificationCenter.default.publisher(for: .showMateriels)) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPrets)) { _ in
            selectedTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: .showEmprunts)) { _ in
            selectedTab = 3
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCoffreFort)) { _ in
            selectedTab = 4
        }
        #endif
    }
}

#Preview { ContentView() }
