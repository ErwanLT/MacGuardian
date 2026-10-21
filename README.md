# MacGuardian

Application macOS de barre de menus qui verrouille la session lorsque l'iPhone associé semble s'éloigner du Mac, sans application compagnon. Voir la [spécification](doc/spec.md).

> Outil de confort, pas une garantie de sécurité : il réduit le risque d'oublier de verrouiller son Mac.

## Prérequis

- macOS 13 Ventura ou suivant
- Swift 6 (Xcode ou Command Line Tools)

## Installer

Après avoir cloné le projet :

```bash
scripts/package.sh
```

Le script construit l'app en release, l'installe dans `/Applications` (ou `~/Applications` sans droit d'écriture), remplace une version déjà installée et la lance. Options : `--no-launch`, `--dest <dossier>`, `--uninstall`.

L'app est signée en ad hoc : macOS peut redemander l'autorisation Bluetooth après chaque réinstallation. Pour conserver les autorisations, indiquer une identité de signature du trousseau :

```bash
MACGUARDIAN_SIGN_IDENTITY="Apple Development: Prénom Nom (XXXXXXXXXX)" scripts/package.sh
```

## Construire et lancer (développement)

```bash
scripts/build-app.sh
```

```bash
open build/MacGuardian.app
```

Le script assemble `build/MacGuardian.app` (avec l'`Info.plist` qui déclare l'usage du Bluetooth) et le signe en ad hoc. L'exécutable lancé hors bundle (`swift run`) est arrêté par macOS au premier accès Bluetooth.

Au premier lancement, macOS demande l'autorisation d'utiliser le Bluetooth.

### Icône

L'icône (`Resources/AppIcon.icns`) est dessinée par code dans `scripts/make-icon.swift`. Pour la régénérer après modification :

```bash
swift scripts/make-icon.swift build/AppIcon.iconset && iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
```

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
