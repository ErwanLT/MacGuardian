# MacGuardian

Application macOS de barre de menus qui verrouille la session lorsque l'iPhone associé semble s'éloigner du Mac, sans application compagnon. Voir la [spécification](doc/spec.md).

> Outil de confort, pas une garantie de sécurité : il réduit le risque d'oublier de verrouiller son Mac.

## Prérequis

- macOS 13 Ventura ou suivant
- Swift 6 (Xcode ou Command Line Tools)

## Construire et lancer

```bash
scripts/build-app.sh
```

```bash
open build/MacGuardian.app
```

Le script assemble `build/MacGuardian.app` (avec l'`Info.plist` qui déclare l'usage du Bluetooth) et le signe en ad hoc. L'exécutable lancé hors bundle (`swift run`) est arrêté par macOS au premier accès Bluetooth.

Au premier lancement, macOS demande l'autorisation d'utiliser le Bluetooth.

## Tests

```bash
scripts/test.sh
```

Le script ajoute le chemin du plugin de macros de Swift Testing, que `swift test` ne trouve pas seul avec les Command Line Tools.

## Utilisation

1. Ouvrir **Réglages… › Téléphone**, rapprocher l'iPhone du Mac et le choisir dans la liste (signal le plus fort).
2. La protection s'arme lorsque le téléphone est détecté à proximité.
3. **Réglages… › Verrouillage › Tester le verrouillage** pour valider le mécanisme sur ce Mac.
4. **Réglages… › Diagnostic** permet d'enregistrer une trace des mesures (`~/Library/Application Support/MacGuardian/Traces`), rejouable dans le moteur via `MeasurementTrace.replay` pour calibrer les seuils.

## Organisation

| Dossier | Contenu |
|---|---|
| `Sources/MacGuardianCore` | Logique pure et testée : machine à états, filtre médian, configuration, traces |
| `Sources/MacGuardian/App` | Point d'entrée, `GuardianController` qui relie les modules, enregistrement des traces |
| `Sources/MacGuardian/Bluetooth` | Scan BLE, connexion au téléphone, lecture du RSSI |
| `Sources/MacGuardian/Security` | Mécanismes de verrouillage, suivi verrouillage / déverrouillage / veille |
| `Sources/MacGuardian/Settings` | Préférences persistées |
| `Sources/MacGuardian/UI` | Barre de menus et fenêtre de réglages |
| `Tests/MacGuardianCoreTests` | Tests du moteur de proximité |

## Limites connues

- L'identifiant Bluetooth d'un iPhone peut changer (adresses privées aléatoires) : la stabilité du suivi reste à valider sur le matériel réel (étape 1 de la spec).
- Le verrouillage par défaut utilise une API privée (`SACLockScreenImmediate`), qui exclut le Mac App Store et peut cesser de fonctionner après une mise à jour de macOS. L'alternative par raccourci clavier nécessite l'autorisation Accessibilité.
