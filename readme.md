# mf-bandit

Script simplifiant l'utilisation de mfoc/mfcuk pour l'archivage et la copie de badges NFC MIFARE Classic.

Interface graphique TUI via Whiptail : `mf-bandit.sh`

## Fonctionnalités

- Cloner un badge vers une cible vierge
- Sauvegarder un badge (dump chiffré .dmp avec timestamp)
- Sauvegarder un badge en forçant mfcuk (darkside attack, pour badges récalcitrants)
- Restaurer un badge depuis une sauvegarde
- Optimiser le dictionnaire de clés (clés trouvées remontées en tête, doublons supprimés)
- Indexer les badges déjà vus (UID → clés connues) pour éviter de re-cracker
- Fallback automatique vers mfcuk si mfoc échoue, avec injection des clés dans le dictionnaire
- Vérification et installation automatique des dépendances depuis les sources locales (libnfc, mfoc, mfcuk)
- Blacklistage du module pn533 (fix pour lecteur ACR122U-A9)
- Réglage du nombre de probes mfoc et de la verbosité, persistés en configuration

## Usage

```bash
bash mf-bandit.sh
```

Le script doit être lancé depuis le répertoire racine du projet avec `bash` (pas `sh`).

## Dépendances

- libnfc (version 1.7.1 recommandée — un bug dans les versions récentes empêche l'utilisation du lecteur ACR122U-A9)
- mfoc
- mfcuk
- nfc-list, nfc-mfclassic, nfc-mfsetuid (libnfc tools)

Les sources de libnfc, mfoc et mfcuk doivent être placées dans les sous-dossiers correspondants du répertoire du script. L'installation automatique sera proposée si les outils sont absents.

## Notes

- Ne sauvegarde pas l'image des badges cibles (seulement la source)
- L'index CSV (assets/index.csv) mémorise les clés par UID pour accélérer les passages suivants
- Le dictionnaire est nettoyé automatiquement (commentaires supprimés, doublons éliminés, lowercase)
- La configuration (probes, verbosité) est persistée dans assets/mf-bandit.conf

