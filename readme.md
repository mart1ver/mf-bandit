# mf-bandit

Scripts simplifiant l'utilisation de mfoc/mfcuk pour l'archivage et la copie de badges NFC MIFARE Classic.

Deux interfaces disponibles :
- `nfc-bandit.sh` — interface ligne de commande
- `mf-bandit.sh` — interface graphique TUI (Whiptail)

## Fonctionnalités

- Cloner un badge vers une cible vierge
- Sauvegarder un badge (dump chiffré .dmp avec timestamp)
- Restaurer un badge depuis une sauvegarde
- Optimiser le dictionnaire de clés (clés trouvées remontées en tête, doublons supprimés)
- Indexer les badges déjà vus (UID → clés connues) pour éviter de re-cracker
- Fallback automatique vers mfcuk si mfoc échoue, avec injection des clés dans le dictionnaire
- Vérification et installation automatique des dépendances depuis les sources locales (libnfc, mfoc, mfcuk)

## Usage (nfc-bandit.sh)

```
./nfc-bandit.sh clone
./nfc-bandit.sh backup
./nfc-bandit.sh restore -n [nom_du_fichier.dmp]
./nfc-bandit.sh optimize
```

## Dépendances

- libnfc (version 1.7.1 recommandée — un bug dans les versions récentes empêche l'utilisation du lecteur ACR122U-A9)
- mfoc
- mfcuk
- nfc-list, nfc-mfclassic, nfc-mfsetuid (libnfc tools)

Les sources de libnfc, mfoc et mfcuk doivent être placées dans les sous-dossiers correspondants du répertoire du script. L'installation automatique sera proposée si les outils sont absents.

## Notes

- Ne sauvegarde pas l'image des badges cibles (seulement la source)
- L'index CSV (uid_index.csv) mémorise les clés par UID pour accélérer les passages suivants
- Le dictionnaire est nettoyé automatiquement (commentaires supprimés, doublons éliminés, lowercase)

## Pistes d'améliorations restantes

- Tester avec d'autres lecteurs NFC
- Gérer le cas où on veut donner un nom déjà existant (sauter le timestamp)
- Mieux gérer les dossiers de données
- Valider l'extraction des clés mfcuk sur un badge récalcitrant réel
