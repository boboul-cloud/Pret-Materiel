# Application de Gestion de Prêt de Matériel

## Version 2.0

[![Télécharger sur l'App Store](https://img.shields.io/badge/App%20Store-Disponible-blue)](https://apps.apple.com/app/prêt-matériel/id6757075000)

**Téléchargez l'application sur l'App Store :**  
🔗 [https://apps.apple.com/app/prêt-matériel/id6757075000](https://apps.apple.com/app/prêt-matériel/id6757075000)

---

## Installation

Si vous voyez des erreurs de compilation concernant des fichiers manquants :

1. **Ouvrez le projet dans Xcode**
2. **Vérifiez que tous les fichiers Swift sont visibles** dans le navigateur de projet
3. Si des fichiers sont grisés ou manquants, **faites un clic droit sur le dossier "Materiel"** → **Add Files to "Materiel"...**
4. Sélectionnez tous les fichiers Swift suivants :
   - Models.swift
   - DataManager.swift
   - MaterielListView.swift
   - PersonneListView.swift
   - LieuListView.swift
   - PretListView.swift

5. Assurez-vous que la case **"Copy items if needed"** est décochée
6. Assurez-vous que la case **"Add to targets: Materiel"** est cochée

## Alternative : Nettoyer et Rebuilder

Dans Xcode :
1. **Product** → **Clean Build Folder** (Shift + Cmd + K)
2. Fermez et rouvrez Xcode
3. **Product** → **Build** (Cmd + B)

## Fichiers créés

- **Models.swift** : Modèles de données (Materiel, Personne, LieuStockage, Pret)
- **DataManager.swift** : Gestionnaire de données avec persistance
- **MaterielListView.swift** : Interface de gestion du matériel
- **PersonneListView.swift** : Interface de gestion des personnes
- **LieuListView.swift** : Interface de gestion des lieux de stockage
- **PretListView.swift** : Interface de gestion des prêts
- **ContentView.swift** : Vue principale avec onglets

## Fonctionnalités

✅ Créer, modifier et supprimer du matériel, des personnes, et des lieux
✅ Créer des prêts avec dates et assignation
✅ Valider les retours de matériel
✅ Effacer les prêts après retour
✅ Recherche multi-critères
✅ Filtrage par statut (disponible, prêté, en retard)
✅ Persistance automatique des données

