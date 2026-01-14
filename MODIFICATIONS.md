# Page d'Accueil et Prêt Rapide - Documentation

## Version 2.0

**📲 App Store :** [https://apps.apple.com/app/prêt-matériel/id6757075000](https://apps.apple.com/app/prêt-matériel/id6757075000)

---

## Résumé des modifications

J'ai ajouté une page d'accueil avec la fonctionnalité de création rapide de prêt par photo.

## Nouveaux fichiers créés

### 1. HomeView.swift
- **Page d'accueil** de l'application
- Présentation : "Gestion de prêts simplifiée" (7 mots)
- Bouton "Créer un prêt rapide" avec icône caméra
- Déclenche l'appareil photo de l'iPhone

### 2. CameraCapturePretView.swift
- **Interface de capture photo** intégrée
- Permet de prendre une photo du matériel
- Possibilité de reprendre la photo si nécessaire
- **Formulaire de création de prêt** avec :
  - Photo capturée affichée
  - Informations du matériel (nom, description, catégorie)
  - Sélection d'une personne existante OU création d'une nouvelle personne
  - Date de retour prévue
  - Notes optionnelles
- Le matériel et le prêt sont automatiquement créés ensemble

## Modifications des fichiers existants

### 3. ContentView.swift
- Ajout de la HomeView comme premier onglet "Accueil" avec icône maison
- Tous les autres onglets restent inchangés

### 4. project.pbxproj
- Ajout de la permission caméra : `NSCameraUsageDescription`
- Message affiché à l'utilisateur : "L'application a besoin d'accéder à la caméra pour prendre des photos du matériel prêté."

## Fonctionnalités implémentées

✅ Page d'accueil avec présentation courte (< 10 mots)
✅ Bouton photo qui déclenche l'appareil photo
✅ Interface de prise de vue intégrée
✅ Formulaire de création de prêt après la photo
✅ Possibilité de créer une nouvelle personne directement
✅ Possibilité d'utiliser une personne existante
✅ Photo enregistrée avec le matériel (imageData)
✅ Création automatique du matériel et du prêt en une seule action

## Comment utiliser

1. Ouvrir l'application → Page d'accueil s'affiche
2. Appuyer sur "Créer un prêt rapide"
3. L'appareil photo s'ouvre automatiquement
4. Prendre une photo du matériel
5. Confirmer la photo ou en reprendre une
6. Remplir les informations du matériel et du prêt
7. Sélectionner une personne existante ou en créer une nouvelle
8. Valider → Le matériel et le prêt sont créés !

## Notes techniques

- Utilise UIImagePickerController pour l'accès à la caméra
- Compatible iOS 17.0+
- La photo est compressée en JPEG (qualité 70%) avant enregistrement
- Les fichiers Swift sont automatiquement détectés par Xcode (PBXFileSystemSynchronizedRootGroup)
