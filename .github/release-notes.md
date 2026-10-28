## Installation

1. Télécharger `MacGuardian-{{VERSION}}.dmg`, l'ouvrir et glisser **MacGuardian** dans **Applications**.
2. L'application n'est pas signée avec un certificat Apple Developer : au premier lancement, macOS la bloque.
   Ouvrir **Réglages Système › Confidentialité et sécurité** et cliquer sur **Ouvrir quand même**,
   ou lever la quarantaine dans le Terminal :
   ```
   xattr -dr com.apple.quarantine /Applications/MacGuardian.app
   ```
3. Autoriser l'accès au Bluetooth, puis choisir son iPhone dans **Réglages… › Téléphone**.

Nécessite macOS 13 ou suivant. Binaire universel (Apple Silicon et Intel).
Les sommes de contrôle sont dans `SHA256SUMS.txt`.
