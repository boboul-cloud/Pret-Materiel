# Configuration StoreKit - Matériel App

## 📦 Structure des achats in-app

### Fichiers créés

1. **`StoreManager.swift`** - Gestionnaire principal des achats
   - Utilise StoreKit 2 (moderne, async/await)
   - Gère le chargement des produits
   - Gère les achats et la vérification
   - Gère la restauration des achats
   - Vérifie les limites gratuites

2. **`PremiumView.swift`** - Interface d'achat
   - Affiche les avantages Premium
   - Affiche les options d'achat
   - Gère les animations et confirmations

3. **`Products.storekit`** - Configuration de test
   - Permet de tester les achats en local
   - Configuration des produits et abonnements

---

## 🏷️ Produits configurés

### Achat unique (Non-Consumable)
| Product ID | Prix | Description |
|------------|------|-------------|
| `com.materiel.premium.unlock` | 4.99€ | Premium à vie |

### Abonnements (Auto-Renewable)
| Product ID | Prix | Période | Essai gratuit |
|------------|------|---------|---------------|
| `com.materiel.subscription.monthly` | 0.99€ | Mensuel | 1 semaine |
| `com.materiel.subscription.yearly` | 7.99€ | Annuel | 1 mois |

### Pourboires (Consumable)
| Product ID | Prix | Description |
|------------|------|-------------|
| `com.materiel.tip.small` | 0.99€ | Petit pourboire ☕️ |
| `com.materiel.tip.medium` | 2.99€ | Pourboire moyen 🍕 |
| `com.materiel.tip.large` | 4.99€ | Grand pourboire 🎁 |

---

## 🚀 Configuration dans App Store Connect

### 1. Créer les produits

1. Aller dans **App Store Connect** → Votre app → **Abonnements** / **Achats intégrés**
2. Cliquer sur **+** pour créer un nouvel achat
3. Utiliser les Product IDs exactement comme définis ci-dessus

### 2. Pour l'achat unique "Premium à vie"

```
Type: Non-Consumable
Product ID: com.materiel.premium.unlock
Reference Name: Premium Unlock
Price: Tier 5 (4.99€)

Localizations:
- FR: "Premium à vie" - "Débloquez toutes les fonctionnalités Premium à vie"
- EN: "Lifetime Premium" - "Unlock all Premium features forever"
- ES: "Premium de por vida" - "Desbloquea todas las funciones Premium de por vida"
- DE: "Lebenslanges Premium" - "Schalten Sie alle Premium-Funktionen für immer frei"
```

### 3. Pour les abonnements

1. Créer un **Subscription Group** nommé "Matériel Premium"
2. Ajouter les deux abonnements dans ce groupe
3. Configurer les prix et périodes
4. Ajouter les offres d'essai gratuit

### 4. Capture d'écran de l'achat

Préparer une capture d'écran de la `PremiumView` pour la validation Apple.

---

## 🧪 Tests

### Test en local avec Xcode

1. Dans Xcode, aller dans **Product** → **Scheme** → **Edit Scheme**
2. Dans **Run** → **Options** → **StoreKit Configuration**
3. Sélectionner `Products.storekit`
4. Les achats seront simulés sans paiement réel

### Test avec Sandbox

1. Créer un compte Sandbox dans App Store Connect
2. Sur l'appareil, se déconnecter d'iCloud
3. Lancer l'app et effectuer un achat
4. Utiliser les identifiants Sandbox

---

## 🔒 Limites version gratuite

La version gratuite est limitée à :
- **10 matériels** maximum
- **20 prêts** maximum

Ces limites sont définies dans `StoreManager.swift` :
```swift
static let freeMaterielLimit = 10
static let freePretLimit = 20
```

---

## ✅ Fonctionnalités Premium

- ♾️ Matériels illimités
- ♾️ Prêts illimités
- ☁️ Sauvegarde iCloud (à implémenter)
- 🔔 Notifications avancées (à implémenter)
- 📊 Statistiques détaillées (à implémenter)

---

## 📝 Checklist avant soumission

- [ ] Créer les produits dans App Store Connect
- [ ] Attendre la validation des produits (peut prendre 24-48h)
- [ ] Tester avec un compte Sandbox
- [ ] Ajouter les liens CGV et Confidentialité
- [ ] Préparer les captures d'écran
- [ ] Vérifier la restauration des achats

---

## 🔧 Intégration dans l'app

Le `StoreManager` est injecté via `@EnvironmentObject` :

```swift
// Dans MaterielApp.swift
@StateObject private var storeManager = StoreManager.shared

// Dans une vue
@EnvironmentObject var storeManager: StoreManager

// Vérifier si Premium
if storeManager.hasUnlockedPremium {
    // Accès complet
} else {
    // Version limitée
}

// Vérifier les limites
if storeManager.canAddMoreMateriel(currentCount: materiels.count) {
    // Autoriser l'ajout
} else {
    // Afficher PremiumView
}
```

---

## 📱 Afficher la vue Premium

```swift
@State private var showPremiumSheet = false

Button("Passer à Premium") {
    showPremiumSheet = true
}
.sheet(isPresented: $showPremiumSheet) {
    PremiumView()
}
```
