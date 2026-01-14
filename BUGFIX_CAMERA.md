import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("App.Language") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "fr"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15), Color.cyan.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView {
                HomeView()
                    .tabItem { 
                        Label("Accueil", systemImage: "house.fill") 
                    }
                MaterielListView()
                    .tabItem { 
                        Label("Matériel", systemImage: "shippingbox") 
                    }
                PretListView()
                    .tabItem { 
                        Label("Prêts", systemImage: "arrow.left.arrow.right") 
                    }
                EmpruntListView()
                    .tabItem { 
                        Label("Emprunts", systemImage: "clock.arrow.circlepath") 
                    }
                PersonneListView()
                    .tabItem { 
                        Label("Personnes", systemImage: "person.2") 
                    }
                LieuListView()
                    .tabItem { 
                        Label("Lieux", systemImage: "location") 
                    }
            }
            .tint(.blue)
        }
        .environment(\.locale, .init(identifier: appLanguage))
    }
}

#Preview { ContentView() }
