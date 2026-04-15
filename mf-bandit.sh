#!/bin/bash
                                   # Script simplifiant la manipulation de badges rfid mifare premiere generation ,tres repandus et pourtant si peut securises...
function backup(){                 # Sauvegarde des badges dans le dossier $DATA [UID]-[nom].dmp
	cd "$CURDIR"	
	while true; do
		BADGE_UID=$(presence)
		case $? in
			0) whiptail --title "mf-bandit Backup" --msgbox "Ok, badge detecte avec l'UID: $BADGE_UID.." 8 78 ; break ;;
			1) whiptail --title "mf-bandit Backup" --msgbox "Placez le badge à copier sur le lecteur puis appuyez sur OK.." 8 78 ;;
			2) whiptail --title "mf-bandit Backup" --msgbox "Erreur: lecteur NFC non disponible. Verifiez la connexion." 8 78 ; basemenu ; return ;;
		esac
	done
	BADGE_NAME=$(whiptail --title "Nom du badge" --inputbox "Entrez le nom de la sauvegarde:" 10 60  3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus != 0 ]; then
	    basemenu
	fi
	BADGE_DUMP="$DATA/$BADGE_NAME-$BADGE_UID.dmp"
	BADGE_DUMP_NAME="$BADGE_NAME-$BADGE_UID.dmp"
	if [ "$BADGE_NAME" == "" ]; then
		whiptail --title "mf-bandit Backup" --msgbox "Merci de donner un nom à la sauvegarde.." 8 78
		basemenu 
	fi
	if [ -f "$BADGE_DUMP" ]; then
		CHOICE=$(whiptail --title "mf-bandit Backup" --menu "Une sauvegarde porte déjà ce nom :" 12 60 3 \
			"1" "Ajouter un timestamp (garder les deux)" \
			"2" "Écraser la sauvegarde existante" \
			"3" "Annuler" 3>&1 1>&2 2>&3)
		case "$CHOICE" in
			1)
				local TIMESTAMP
				TIMESTAMP=$(date +'%F_%H-%M-%S')
				BADGE_DUMP="$DATA/$BADGE_NAME-$BADGE_UID-$TIMESTAMP.dmp"
				BADGE_DUMP_NAME="$BADGE_NAME-$BADGE_UID-$TIMESTAMP.dmp"
				;;
			2) ;;
			*) basemenu ; return ;;
		esac
	fi
	checkIfIndexed "$BADGE_UID"
	whiptail --title "mf-bandit Backup" --msgbox "Decodage du badge avec mfoc, peu prendre longtemps, appuyez sur ENTReE.." 8 78 
	>&2 echo -e "${COULEUR}MF-BANDIT Backup:             <Decodage du badge avec mfoc, peut prendre un peut de temps..>${NC}"
	mfocWithFallback "$BADGE_UID" "$BADGE_DUMP"
	if [ $? -eq 0 ]; then
		optimize "$BADGE_UID"
		whiptail --title "mf-bandit Backup" --msgbox "Ok, badge sauvegarde dans le fichier: $BADGE_DUMP_NAME.." 8 78
	else
		rm -f LastMfocOut.tmp
		whiptail --title "mf-bandit Backup" --msgbox "erreur, Impossible de decoder le badge à copier avec mfoc et mfcuk.." 8 78
	fi
        basemenu
}
function backupMfcuk(){            # Sauvegarde en forçant mfcuk (badge récalcitrant)
	cd "$CURDIR"
	while true; do
		BADGE_UID=$(presence)
		case $? in
			0) whiptail --title "mf-bandit Backup mfcuk" --msgbox "Ok, badge detecte avec l'UID: $BADGE_UID.." 8 78 ; break ;;
			1) whiptail --title "mf-bandit Backup mfcuk" --msgbox "Placez le badge à copier sur le lecteur puis appuyez sur OK.." 8 78 ;;
			2) whiptail --title "mf-bandit Backup mfcuk" --msgbox "Erreur: lecteur NFC non disponible. Verifiez la connexion." 8 78 ; basemenu ; return ;;
		esac
	done
	BADGE_NAME=$(whiptail --title "Nom du badge" --inputbox "Entrez le nom de la sauvegarde:" 10 60 3>&1 1>&2 2>&3)
	if [ $? -ne 0 ]; then basemenu ; return ; fi
	if [ -z "$BADGE_NAME" ]; then
		whiptail --title "mf-bandit Backup mfcuk" --msgbox "Merci de donner un nom à la sauvegarde.." 8 78
		basemenu ; return
	fi
	BADGE_DUMP="$DATA/$BADGE_NAME-$BADGE_UID.dmp"
	BADGE_DUMP_NAME="$BADGE_NAME-$BADGE_UID.dmp"
	if [ -f "$BADGE_DUMP" ]; then
		CHOICE=$(whiptail --title "mf-bandit Backup mfcuk" --menu "Une sauvegarde porte déjà ce nom :" 12 60 3 \
			"1" "Ajouter un timestamp (garder les deux)" \
			"2" "Écraser la sauvegarde existante" \
			"3" "Annuler" 3>&1 1>&2 2>&3)
		case "$CHOICE" in
			1)
				local TIMESTAMP
				TIMESTAMP=$(date +'%F_%H-%M-%S')
				BADGE_DUMP="$DATA/$BADGE_NAME-$BADGE_UID-$TIMESTAMP.dmp"
				BADGE_DUMP_NAME="$BADGE_NAME-$BADGE_UID-$TIMESTAMP.dmp"
				;;
			2) ;;
			*) basemenu ; return ;;
		esac
	fi
	whiptail --title "mf-bandit Backup mfcuk" --msgbox "Attaque mfcuk (darkside) en cours, peut prendre très longtemps.. appuyez sur ENTRÉE." 8 78
	>&2 echo -e "${COULEUR}MF-BANDIT Backup mfcuk:       <Attaque darkside avec mfcuk..>${NC}"
	local MFCUK_TEMP
	MFCUK_TEMP=$(mktemp)
	if [ "$MFOC_VERBOSE" -eq 1 ]; then
		mfcuk -C -R 0:A -v 3 -s 50 -S 50 2>&1 | tee "$MFCUK_TEMP" >&2
	else
		mfcuk -C -R 0:A -v 3 -s 50 -S 50 > "$MFCUK_TEMP" 2>&1
	fi
	local found_keys
	found_keys=$(grep -oiE '\b[0-9a-f]{12}\b' "$MFCUK_TEMP")
	rm -f "$MFCUK_TEMP"
	if [ -z "$found_keys" ]; then
		whiptail --title "mf-bandit Backup mfcuk" --msgbox "Erreur: mfcuk n'a pas trouvé de clés." 8 78
		basemenu ; return
	fi
	>&2 echo -e "${COULEUR}MF-BANDIT Backup mfcuk:       <Clés trouvées, injection dans le dictionnaire..>${NC}"
	local DICT_TEMP
	DICT_TEMP=$(mktemp)
	echo "$found_keys" > "$DICT_TEMP"
	cat "$DICT" >> "$DICT_TEMP"
	cat -n "$DICT_TEMP" | sort -uk2 | sort -nk1 | cut -f2- > "$DICT"
	sed -i '/^[[:space:]]*#/d; /^$/d' "$DICT"
	rm -f "$DICT_TEMP"
	>&2 echo -e "${COULEUR}MF-BANDIT Backup mfcuk:       <Dump du badge avec mfoc..>${NC}"
	if [ "$MFOC_VERBOSE" -eq 1 ]; then
		mfoc -P "$MFOC_PROBES" -f "$DICT" -O "$BADGE_DUMP" | tee LastMfocOut.tmp >&2
	else
		mfoc -P "$MFOC_PROBES" -f "$DICT" -O "$BADGE_DUMP" | tee LastMfocOut.tmp > /dev/null
	fi
	if [ ${PIPESTATUS[0]} -eq 0 ]; then
		optimize "$BADGE_UID"
		whiptail --title "mf-bandit Backup mfcuk" --msgbox "Ok, badge sauvegarde dans le fichier: $BADGE_DUMP_NAME.." 8 78
	else
		rm -f LastMfocOut.tmp "$BADGE_DUMP"
		whiptail --title "mf-bandit Backup mfcuk" --msgbox "Erreur: mfoc n'a pas pu dumper le badge avec les clés mfcuk." 8 78
	fi
	basemenu
}
function restore(){                # Restore des badges à partir du dossier $DATA (doit avoir pour extention .dmp)
	STARTDIR=$DATA
	Filebrowser "Selectionez une sauvegarde à restaurer" "$STARTDIR"
	exitstatus=$?
	if [ $exitstatus -eq 0 ]; then
    	if [ "$selection" == "" ]; then	
		basemenu
    	fi
	else
    	basemenu
	fi
	DUMP_TO_RESTORE="$filename"
	whiptail --title "mf-bandit Restore" --msgbox "Placez le badge cible sur le lecteur (ATTENTION ECRASEMENT DU BADGE), puis appuyez ENTReE.." 8 78
	while true; do
		BADGE_UID=$(presence)
		case $? in
			0) whiptail --title "mf-bandit Restore" --msgbox "Badge cible detecte avec l'UID: $BADGE_UID.. , appuyez OK.." 8 78 ; break ;;
			1) whiptail --title "mf-bandit Restore" --msgbox "Placez le badge cible sur le lecteur (ATTENTION ECRASEMENT DU BADGE), puis appuyez ENTReE.." 8 78 ;;
			2) whiptail --title "mf-bandit Restore" --msgbox "Erreur: lecteur NFC non disponible. Verifiez la connexion." 8 78 ; basemenu ; return ;;
		esac
	done
	cd "$CURDIR"
	>&2 echo -e "${COULEUR}MF-BANDIT Restore:            <Decodage des clefs du badge cible..>${NC}"
	RESTORE_TEMP_1=$(mktemp)
	checkIfIndexed "$BADGE_UID"
	>&2 echo -e "${COULEUR}MF-BANDIT Restore:            <Decodage du badge cible avec mfoc, peu prendre un peut de temps..>${NC}"
	mfocWithFallback "$BADGE_UID" "$RESTORE_TEMP_1"
	if [ $? -ne 0 ]; then
		rm -f LastMfocOut.tmp "$RESTORE_TEMP_1"
		whiptail --title "mf-bandit Restore" --msgbox "erreur, Impossible de decoder le badge cible avec mfoc et mfcuk.." 8 78
		basemenu
		return
	fi
	optimize "$BADGE_UID"
	>&2 echo -e "${COULEUR}MF-BANDIT Restore:            <ecriture du contenu du badge cible..>${NC}"
	nfc-mfclassic W a "$DATA/$DUMP_TO_RESTORE" "$RESTORE_TEMP_1" f
	BADGE_DUMP_UID=$(xxd -ps -c 4 "$DATA/$DUMP_TO_RESTORE" | head -n1)
	>&2 echo -e "${COULEUR}MF-BANDIT Restore:            <ecriture de l'UID $BADGE_DUMP_UID vers le badge cible..>${NC}"
	nfc-mfsetuid "$BADGE_DUMP_UID"
	rm -f "$RESTORE_TEMP_1"
	>&2 echo -e "${COULEUR}MF-BANDIT Restore:            <Badge cible ecrit!>${NC}"
	whiptail --title "mf-bandit Restore" --msgbox "Badge cible ecrit!" 8 78
	basemenu	
}
function displayDump(){            #affiche dans une fenetre le contenu d'une sauvegarde
	STARTDIR=$DATA
	Filebrowser "Selectionez une sauvegarde à visualiser" "$STARTDIR"
	exitstatus=$?
	if [ $exitstatus -eq 0 ]; then
    	if [ "$selection" == "" ]; then	
		basemenu
    	fi
	else
    	basemenu
	fi
	DUMP_TO_RESTORE="$filename"
	DISPLAY_TEMP=$(mktemp)
	od -A x -t x1z -v "$CURDIR/data/$DUMP_TO_RESTORE" > "$DISPLAY_TEMP"
	dialog --title "mf-bandit viz $DUMP_TO_RESTORE" --textbox "$DISPLAY_TEMP" $(tput lines) $(tput cols)
	rm -f "$DISPLAY_TEMP"
	basemenu
}
function clone(){                  # Fonction de Clonage des badges (pas de sauvegarde)
	cd "$CURDIR"	
	while true; do
		BADGE_UID=$(presence)
		case $? in
			0) whiptail --title "mf-bandit Clone" --msgbox "Ok, badge detecte avec l'UID: $BADGE_UID.." 8 78 ; break ;;
			1) whiptail --title "mf-bandit Clone" --msgbox "Placez le badge à copier sur le lecteur puis appuyez sur OK.." 8 78 ;;
			2) whiptail --title "mf-bandit Clone" --msgbox "Erreur: lecteur NFC non disponible. Verifiez la connexion." 8 78 ; basemenu ; return ;;
		esac
	done
	BADGE_NAME="clone" 
	BADGE_DUMP="$DATA/$BADGE_NAME-$BADGE_UID.dmp"
	checkIfIndexed "$BADGE_UID"
	>&2 echo -e "${COULEUR}MF-BANDIT clone:              <Decodage des clefs du badge à cloner, peut prendre un peut de temps..>${NC}"
	mfocWithFallback "$BADGE_UID" "$BADGE_DUMP"
	if [ $? -ne 0 ]; then
		rm -f LastMfocOut.tmp "$BADGE_DUMP"
		whiptail --title "mf-bandit Clone" --msgbox "erreur, Impossible de decoder le badge source avec mfoc et mfcuk.." 8 78
		basemenu
		return
	fi
	optimize "$BADGE_UID"
	whiptail --title "mf-bandit Clone" --msgbox "Placez le badge cible sur le lecteur (ATTENTION ECRASEMENT DU BADGE), puis appuyez OK.." 8 78
	while true; do
		BADGE_UID=$(presence)
		case $? in
			0) whiptail --title "mf-bandit Clone" --msgbox "Ok badge cible detecte avec l'UID: $BADGE_UID.. , appuyez OK.." 8 78 ; break ;;
			1) whiptail --title "mf-bandit Clone" --msgbox "Placez le badge cible sur le lecteur (ATTENTION ECRASEMENT DU BADGE), puis appuyez OK.." 8 78 ;;
			2) whiptail --title "mf-bandit Clone" --msgbox "Erreur: lecteur NFC non disponible. Verifiez la connexion." 8 78 ; basemenu ; return ;;
		esac
	done
	TEMP_DUMP=$(mktemp)
	checkIfIndexed "$BADGE_UID"
	>&2 echo -e "${COULEUR}MF-BANDIT clone:              <Decodage des clefs du badge à cible, peut prendre un peut de temps..>${NC}"
	mfocWithFallback "$BADGE_UID" "$TEMP_DUMP"
	if [ $? -ne 0 ]; then
		rm -f LastMfocOut.tmp "$TEMP_DUMP" "$BADGE_DUMP"
		whiptail --title "mf-bandit Clone" --msgbox "erreur, Impossible de decoder le badge cible avec mfoc et mfcuk.." 8 78
		basemenu
		return
	fi
	optimize "$BADGE_UID"
	>&2 echo -e "${COULEUR}MF-BANDIT Clone:              <ecriture du contenu du badge cible..>${NC}"
	nfc-mfclassic W a "$BADGE_DUMP" "$TEMP_DUMP" "$DICT" //f 
	BADGE_DUMP_UID=$(xxd -ps -c 4 "$BADGE_DUMP" | head -n1)
	>&2 echo -e "\n"
	>&2 echo -e "${COULEUR}MF-BANDIT Clone:              <ecriture de l'UID: $BADGE_DUMP_UID, vers le badge cible..>${NC}"
	nfc-mfsetuid "$BADGE_DUMP_UID"
	>&2 echo -e "${COULEUR}MF-BANDIT Clone:              <Badge clone!>${NC}"
	whiptail --title "mf-bandit Clone" --msgbox "Badge cible ecrit!" 8 78
	rm -f "$BADGE_DUMP" "$TEMP_DUMP"
	basemenu	
}
function format(){                 # Randomise l'UID du badge et remplace le contenu par celui de assets/dumb.dmb 
	STARTDIR=$DATA
	DUMP_TO_RESTORE="assets/dumb.dmb"
	whiptail --title "mf-bandit Format" --msgbox "Placez le badge cible sur le lecteur (ATTENTION, LE CONTENU DU BADGE VA ETRE FORMATe ET L'UID RANDOMISe), puis appuyez sur ENTReE.." 8 78
	while true; do
		BADGE_UID=$(presence)
		case $? in
			0) whiptail --title "mf-bandit Format" --msgbox "Badge cible detecte avec l'UID: $BADGE_UID.. , appuyez OK.." 8 78 ; break ;;
			1) whiptail --title "mf-bandit Format" --msgbox "Placez le badge cible sur le lecteur (ATTENTION, LE CONTENU DU BADGE VA ETRE FORMATe ET L'UID RANDOMISe), puis appuyez sur ENTReE.." 8 78 ;;
			2) whiptail --title "mf-bandit Format" --msgbox "Erreur: lecteur NFC non disponible. Verifiez la connexion." 8 78 ; basemenu ; return ;;
		esac
	done
	cd "$CURDIR"	
	>&2 echo -e "${COULEUR}MF-BANDIT Format:             <Decodage des clefs du badge cible..>${NC}"
	FORMAT_TEMP_1=$(mktemp)
	mfocWithFallback "$BADGE_UID" "$FORMAT_TEMP_1"
	if [ $? -ne 0 ]; then
		rm -f LastMfocOut.tmp "$FORMAT_TEMP_1"
		whiptail --title "mf-bandit Format" --msgbox "erreur, Impossible de decoder le badge cible avec mfoc et mfcuk.." 8 78
		basemenu
		return
	fi
	optimize "$BADGE_UID"
	>&2 echo -e "${COULEUR}MF-BANDIT Format:             <ecriture du contenu vierge sur le badge cible..>${NC}"
	nfc-mfclassic W a "$CURDIR/$DUMP_TO_RESTORE" $FORMAT_TEMP_1 f
	BADGE_DUMP_UID=$(head -c4 </dev/urandom|xxd -p -u)
	>&2 echo -e "${COULEUR}MF-BANDIT Format:             <ecriture de l'UID randomisee: $BADGE_DUMP_UID, vers le badge cible..>${NC}"
	nfc-mfsetuid "$BADGE_DUMP_UID" 
	rm -f $FORMAT_TEMP_1
	>&2 echo -e "${COULEUR}MF-BANDIT Format:             <Badge cible ecrit!>${NC}"
	whiptail --title "mf-bandit Format" --msgbox "Ok, badge cible efface, UID randomise.." 8 78
	basemenu	
}
function search(){                 # Recherche l'UID d'un badge dans les noms des sauvegardes realisees avec mf-bandit
	cd "$CURDIR"
	whiptail --title "mf-bandit Search" --msgbox "Placez le badge à verifier sur le lecteur , puis appuyez sur ENTReE.." 8 78
	while true; do
		BADGE_UID=$(presence)
		case $? in
			0) whiptail --title "mf-bandit Search" --msgbox "Badge à verifier detecte avec l'UID $BADGE_UID.." 8 78 ; break ;;
			1) whiptail --title "mf-bandit Search" --msgbox "Placez le badge à verifier sur le lecteur , puis appuyez sur ENTReE.." 8 78 ;;
			2) whiptail --title "mf-bandit Search" --msgbox "Erreur: lecteur NFC non disponible. Verifiez la connexion." 8 78 ; basemenu ; return ;;
		esac
	done
		SEARCH1=$(ls data/ | grep "$BADGE_UID")
		
	if [ "$SEARCH1" == "" ]; then
			whiptail --title "mf-bandit Search" --msgbox "Desole, recherche par UID infructueuse dans le dossier: $CURDIR/$DATA, appuyez sur ENTReE.. " 8 78
			
	else
			 whiptail --title "mf-bandit Search" --msgbox "Ok, Une sauvergarde avec le meme UID à ete identifiee dans le dossier: $CURDIR/$DATA: $SEARCH1, appuyez sur ENTReE.." 8 78 
			
	fi 	
	basemenu
}
function importKeys(){	           # Importe un fichier de clees au dictionaire (doit avoir pour extention .keys)
	FILEXT='keys'
	Filebrowser "Selectionez un fichier de clees à importer" "$CURDIR"
	exitstatus=$?
	if [ $exitstatus -eq 0 ]; then
    	if [ "$selection" == "" ]; then	
		basemenu
    	fi
	else
    	basemenu
	fi
	FileToImport="$selection"
	cat "$CURDIR/$DICT" > "$CURDIR/$DICT.sav"
	IMPORT_TEMP_1=$(mktemp)
	cat "$FileToImport" > "$IMPORT_TEMP_1"
	echo "" >> "$IMPORT_TEMP_1"
	cat "$CURDIR/$DICT" >> "$IMPORT_TEMP_1"
	cat -n "$IMPORT_TEMP_1" | sort -uk2 | sort -nk1 | cut -f2- > "$CURDIR/$DICT"
	rm -f "$IMPORT_TEMP_1"
	FILEXT='dmp'
	whiptail --title "mf-bandit Import" --msgbox "Fichier importe, , appuyez sur ENTReE.." 8 78
	basemenu	
}
function eraseBackup(){            # Permet de supprimer une sauvegarde du dossier $DATA
	STARTDIR=$DATA
	FILEXT='dmp'	
	Filebrowser "Supprimer une sauvegarde" "$STARTDIR"
	exitstatus=$?
	if [ $exitstatus -eq 0 ]; then
    if [ "$selection" == "" ]; then
	basemenu
    else
	rm "$filename"
	whiptail --title "mf-bandit REM-Backup" --msgbox "La sauvegarde selectionee à ete supprimee " 8 78
	basemenu
    fi
	else
    	basemenu
	fi
	basemenu
}
function compare(){                # Compare un badge avec une sauvegarde specifiee
	Filebrowser "Comparer un badge avec une sauvegarde" "$DATA"
	exitstatus=$?
	if [ $exitstatus -eq 0 ]; then
	    if [ "$selection" == "" ]; then	
		basemenu
	    else
		whiptail --title "mf-bandit Compare" --msgbox "Placez le badge à verifier sur le lecteur , puis appuyez sur ENTReE.." 8 78
		while true; do
			BADGE_UID=$(presence)
			case $? in
				0) whiptail --title "mf-bandit Compare" --msgbox "Ok badge à verifier detecte avec l'UID $BADGE_UID.." 8 78 ; break ;;
				1) whiptail --title "mf-bandit Compare" --msgbox "Placez le badge à verifier sur le lecteur , puis appuyez sur ENTReE.." 8 78 ;;
				2) whiptail --title "mf-bandit Compare" --msgbox "Erreur: lecteur NFC non disponible. Verifiez la connexion." 8 78 ; basemenu ; return ;;
			esac
		done
			cd "$CURDIR"
	        CHECK1="0"
	        CHECK2="0"
		    BADGE_DUMP="$selection"
	    	BADGE_DUMP_UID=$(xxd -ps -c 4 "$DATA/$BADGE_DUMP" | head -n1)
			TEMP_DUMP=$(mktemp)
			checkIfIndexed "$BADGE_UID"
			>&2 echo -e "${COULEUR}MF-BANDIT Compare:            <Decodage des clefs du badge à verifier..>${NC}"
			mfocWithFallback "$BADGE_UID" "$TEMP_DUMP"
			if [ $? -ne 0 ]; then
				rm -f LastMfocOut.tmp "$TEMP_DUMP"
				whiptail --title "mf-bandit Compare" --msgbox "erreur, Impossible de decoder le badge avec mfoc et mfcuk.." 8 78
				basemenu
				return
			fi
			optimize "$BADGE_UID"
			>&2 echo -e "${COULEUR}MF-BANDIT Compare:            <Comparaison des UIDs..>${NC}"
			if test "$BADGE_DUMP_UID" = "$BADGE_UID"; then
				 >&2 echo -e "${COULEUR}MF-BANDIT Compare:            <L'UID du badge correspond au fichier indique!..>${NC}" 
				CHECK1="1"
			else
				 >&2 echo -e "${COULEUR}MF-BANDIT Compare:            <L'UID du badge ne correspond pas au fichier indique!..>${NC}" 
				CHECK1="0"
			fi
			cd "$CURDIR"
			>&2 echo -e "${COULEUR}MF-BANDIT Compare:            <Comparaison du contenu des badges..>${NC}"
			if cmp --ignore-initial=32 "$TEMP_DUMP" "$DATA/$BADGE_DUMP"; then
				 >&2 echo -e "${COULEUR}MF-BANDIT Compare:            <Le contenu du badge correspond au fichier indique!..>${NC}"
				CHECK2="1"	 
			else
				 >&2 echo -e "${COULEUR}MF-BANDIT Compare:            <Le contenu du badge ne correspond pas au fichier indique!..>${NC}" 
				CHECK2="0"
			fi
		rm -f "$TEMP_DUMP"
		if [ "$CHECK1" == "1" ]; then
				whiptail --title "mf-bandit Compare" --msgbox "OK!, l'UID du badge correspond au fichier indique, appuyez sur ENTReE.." 8 78
		else
				 whiptail --title "mf-bandit Compare" --msgbox "eRREUR!, l'UID du badge ne correspond pas au fichier indique, appuyez sur ENTReE.." 8 78 
		fi
		if [ "$CHECK2" == "1" ]; then
				whiptail --title "mf-bandit Compare" --msgbox "OK!, le contenu du badge correspond au fichier indique, appuyez sur ENTReE.." 8 78
		else
				 whiptail --title "mf-bandit Compare" --msgbox "eRREUR!, le contenu du badge ne correspond pas au fichier indique, appuyez sur ENTReE.." 8 78 
		fi					
	    fi
	else
	    basemenu
	fi
	basemenu
}
function basemenu(){               # Menu de base avec whiptail
	cd "$CURDIR"
	ADVSEL=$(whiptail --nocancel --title "mf-bandit" --menu " " 28 78 20 \
	"1" "Sauvegarder un badge" \
	"2" "Sauvegarder un badge (forcer mfcuk)" \
	"3" "Restaurer un badge" \
	"4" "Cloner un badge" \
	"5" "effacer le contenu d'un badge et randomiser son UID" \
	"6" "Verifier si un badge est deja sauvegarde" \
	"7" "Comparer un badge avec une sauvegarde" \
	"8" "Importer un fichier de clees" \
	"9" "Supprimer une sauvegarde" \
	"10" "Visualiser une sauvegarde" \
	"11" "Optimiser le dictionnaire et l'index" \
	"12" "Regler le nombre de probes mfoc (actuel: $MFOC_PROBES)" \
	"13" "Verbosité mfoc/mfcuk (actuel: $([ "$MFOC_VERBOSE" -eq 1 ] && echo ON || echo OFF))" \
	"14" "Blacklister pn533 (fix lecteur NFC)" \
	"15" "Quitter mf-bandit" 3>&1 1>&2 2>&3)
	case $ADVSEL in
        1)
            backup
	    	basemenu
        ;;
        2)
            backupMfcuk
	    	basemenu
        ;;
        3)
            restore
	    	basemenu
        ;;
        4)
           clone
	    	basemenu
        ;;
		5)
            format
        	basemenu
        ;;
		6)
            search
	    	basemenu
        ;;
		7)
	    	compare
        	basemenu
        ;;
		8)
            importKeys
	    	basemenu
        ;;
		9)
            eraseBackup
            basemenu
        ;;
        10)
            displayDump
            basemenu
        ;;
		11)
            manualOptimize
            basemenu
        ;;
		12)
            setMfocProbes
            basemenu
        ;;
		13)
            toggleVerbose
            basemenu
        ;;
		14)
            blacklistPn533
            basemenu
        ;;
		15)
            whiptail --title "Bye Bye" --msgbox "Merci d'avoir utilise mf-bandit!" 8 45
	    exit 0
        ;;
    	esac
}
function toggleVerbose(){          # Active/désactive la verbosité mfoc/mfcuk
	if [ "$MFOC_VERBOSE" -eq 1 ]; then
		MFOC_VERBOSE=0
		saveConfig
		whiptail --title "mf-bandit Verbosité" --msgbox "Verbosité mfoc/mfcuk désactivée (mode silencieux)." 8 55
	else
		MFOC_VERBOSE=1
		saveConfig
		whiptail --title "mf-bandit Verbosité" --msgbox "Verbosité mfoc/mfcuk activée." 8 55
	fi
}
function setMfocProbes(){          # Regle le nombre de probes mfoc (-P)
	local input
	input=$(whiptail --title "mf-bandit Probes mfoc" \
		--inputbox "Nombre de probes mfoc par secteur:\n(defaut=20, moins=plus rapide, plus=plus fiable)" \
		10 60 "$MFOC_PROBES" 3>&1 1>&2 2>&3)
	if [ $? -ne 0 ] || [ -z "$input" ]; then
		return
	fi
	if ! [[ "$input" =~ ^[0-9]+$ ]] || [ "$input" -lt 1 ]; then
		whiptail --title "mf-bandit Probes mfoc" --msgbox "Valeur invalide, doit etre un entier >= 1." 8 50
		return
	fi
	MFOC_PROBES="$input"
	saveConfig
	whiptail --title "mf-bandit Probes mfoc" --msgbox "Probes mfoc regle a $MFOC_PROBES." 8 50
}
function blacklistPn533(){         # Décharge les modules pn533 et les blackliste au démarrage
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Droits sudo requis, entrez votre mot de passe:>${NC}"
	sudo -v || { whiptail --title "mf-bandit pn533" --msgbox "Droits sudo requis." 8 50 ; return ; }
	whiptail --title "mf-bandit pn533" --msgbox "Desactivation des modules pn533 (conflit avec le lecteur ACR122U).." 8 78
	sudo modprobe -r pn533_usb pn533 nfc 2>/dev/null
	sudo tee /etc/modprobe.d/blacklist-pn533.conf > /dev/null <<EOF
blacklist pn533_usb
blacklist pn533
blacklist nfc
EOF
	if [ $? -eq 0 ]; then
		whiptail --title "mf-bandit pn533" --msgbox "Ok, modules pn533 desactives et blacklistes. Le lecteur ACR122U devrait fonctionner." 8 78
	else
		whiptail --title "mf-bandit pn533" --msgbox "Erreur lors du blacklistage (droits sudo requis)." 8 78
	fi
}
function Filebrowser(){            # Selectioner des fichiers avec whiptail
    if [ -n "$2" ] ; then
        cd "$2"
    fi

    local curdir
    curdir=$(pwd)
    local -a dir_list=()
    while IFS= read -r -d $'\0' entry; do
        local size
        if [ -d "$entry" ]; then
            size="DIR"
        else
            size=$(stat -c '%s' "$entry" 2>/dev/null || echo '-')
        fi
        dir_list+=("$entry" "$size")
    done < <(find . -maxdepth 1 ! -name . -printf '%P\0' | sort -z)

    if [ "$curdir" == "/" ] ; then  # Check if you are at root folder
        selection=$(whiptail --title "$1" \
                              --menu "$curdir" 0 0 0 \
                              --cancel-button Retour \
                              --ok-button Confirmer \
                              "${dir_list[@]}" 3>&1 1>&2 2>&3)
    else                                                                     # Not Root Dir so show ../ BACK Selection in Menu
        selection=$(whiptail --title "$1" \
                              --menu "$curdir" 0 0 0 \
                              --cancel-button Retour \
                              --ok-button Confirmer \
                              "../" "BACK" "${dir_list[@]}" 3>&1 1>&2 2>&3)
    fi
    RET=$?
    if [ $RET -eq 1 ]; then                                                                # Check if User Selected Cancel
       return 1
    elif [ $RET -eq 0 ]; then
       if [[ -d "$selection" ]]; then                                                      # Check if Directory Selected
          Filebrowser "$1" "$selection"
       elif [[ -f "$selection" ]]; then                                                 # Check if File Selected
          if [[ $selection == *$FILEXT ]]; then                                           # Check if selected File has .jpg extension
            if (whiptail --title "Confirmez vous la selection?" --yesno "Dossier de travail : $curdir\nFichier : $selection" 0 0 \
                         --yes-button "Confirmer" \
                         --no-button "Retour"); then
                filename="$selection"
                filepath="$curdir"                                                         # Return full filepath  and filename as selection variables
            else
                Filebrowser "$1" "$curdir"
            fi
          else   # Not correct extension so Inform User and restart
             whiptail --title "ERREUR: le fichier doit avoir $FILEXT pour extention.." \
                      --msgbox "$selection\nVous devez selectioner un fichier $FILEXT " 0 0
             Filebrowser "$1" "$curdir"
          fi
       else
          # Could not detect a file or folder so Try Again
          whiptail --title "ERREUR: erreur de selection.." \
                   --msgbox "ERREUR: acces à: $selection" 0 0
          Filebrowser "$1" "$curdir"
       fi
    fi
}
function initialize(){             # Fonction d'nitialisation du script
	DICT="assets/dictionaire.keys" # On renseigne ici le nom du fichier dictionaire
	DATA="data"                    # On renseigne ici le nom du dossier contenant les sauvegardes
	CONF="assets/mf-bandit.conf"   # Fichier de configuration
	COULEUR='\033[1;96m'           # couleur du texte dans la console
	NC='\033[0m'                   # No Color
	STARTDIR=$DATA                 # Pour le filebrowser
	CURDIR=$(pwd)                  # On stocke pwd à l'initialisation du script
	FILEXT='dmp'                   # Extention utilisee par defaut dans le filebrowser
	MFOC_PROBES=20                 # Valeurs par défaut (écrasées par le fichier de config si existant)
	MFOC_VERBOSE=0
	mkdir -p "$DATA"               # On creee le dossier des sauvegardes si il n'existe pas
	[ -f "$CONF" ] && source "$CONF"
}
function checkReader(){             # Vérifie la présence du lecteur NFC au démarrage
	NFC_OUT=$(nfc-list 2>&1)
	if echo "$NFC_OUT" | grep -qi 'error\|unable\|No NFC device'; then
		local msg="Lecteur NFC non détecté.\n\n$(echo "$NFC_OUT" | head -5)\n\nVérifiez la connexion USB ou blacklistez le module pn533 (menu → Blacklister pn533)."
		whiptail --title "mf-bandit — Lecteur absent" --msgbox "$msg" 16 72
	fi
}
function saveConfig(){             # Sauvegarde les réglages dans assets/mf-bandit.conf
	cat > "$CURDIR/$CONF" <<EOF
MFOC_PROBES=$MFOC_PROBES
MFOC_VERBOSE=$MFOC_VERBOSE
EOF
}
function presence(){               # Retourne l'UID du badge: 0=trouvé, 1=absent, 2=erreur hardware
	NFC_OUT=$(nfc-list 2>&1)
	NFC_RET=$?
	if [ $NFC_RET -ne 0 ] || echo "$NFC_OUT" | grep -qi 'error\|unable'; then
		return 2
	fi
	BADGE_UID=$(echo "$NFC_OUT" | grep -Po '(?<=UID \(NFCID1\): ).+')
	if [ -z "$BADGE_UID" ]; then
		return 1
	fi
	sed 's/ //g' <<< "$BADGE_UID"
	return 0
}
function optimize(){               # Optimisation du dictionnaire et de l'index apres un mfoc reussi
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Optimisation du dictionnaire..>${NC}"
	OPTIMIZE_TEMP_2=$(mktemp)
	OPTIMIZE_TEMP_3=$(mktemp)
	OPTIMIZE_TEMP_4=$(mktemp)
	INDEX_TEMP_1=$(mktemp)
	INDEX_TEMP_2=$(mktemp)
	# Extraction des clés trouvées — compatible 1K, 4K et toutes versions de mfoc
	grep -oE 'Found[[:space:]]+Key [AB]: [0-9a-fA-F]{12}' LastMfocOut.tmp \
		| grep -oE '[0-9a-fA-F]{12}' > "$OPTIMIZE_TEMP_2"
	if [ ! -s "$OPTIMIZE_TEMP_2" ]; then
		>&2 echo -e "${COULEUR}MF-BANDIT:                    <Aucune clé extraite, optimisation ignorée>${NC}"
		rm -f "$OPTIMIZE_TEMP_2" "$OPTIMIZE_TEMP_3" "$OPTIMIZE_TEMP_4" "$INDEX_TEMP_1" "$INDEX_TEMP_2" LastMfocOut.tmp
		cd "$CURDIR"
		return 1
	fi
	cat -n "$OPTIMIZE_TEMP_2" | sort -uk2 | sort -nk1 | cut -f2- > "$OPTIMIZE_TEMP_3"
	cat assets/dictionaire.keys >> "$OPTIMIZE_TEMP_3"
	sed 's/.*/\L&/g' "$OPTIMIZE_TEMP_3" > "$OPTIMIZE_TEMP_4"
	cat -n "$OPTIMIZE_TEMP_4" | sort -uk2 | sort -nk1 | cut -f2- > "$DICT"
	sed -i '/^[[:space:]]*#/d; /^$/d' "$DICT"
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Optimisation de l'index..>${NC}"
	sed -e 's/^/'"$1"',/' "$OPTIMIZE_TEMP_2" > "$INDEX_TEMP_1"
	cat -n "$INDEX_TEMP_1" | sort -uk2 | sort -nk1 | cut -f2- >> "$INDEX_TEMP_2"
	cat assets/index.csv >> "$INDEX_TEMP_2"
	cat -n "$INDEX_TEMP_2" | sort -uk2 | sort -nk1 | cut -f2- > assets/index.csv
	rm -f "$INDEX_TEMP_1" "$INDEX_TEMP_2"
	rm -f "$OPTIMIZE_TEMP_2" "$OPTIMIZE_TEMP_3" "$OPTIMIZE_TEMP_4" LastMfocOut.tmp
	cd "$CURDIR"
}
function manualOptimize(){         # Nettoyage manuel du dictionnaire et de l'index
	cd "$CURDIR"
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Optimisation du dictionnaire..>${NC}"
	OPTIMIZE_TEMP=$(mktemp)
	sed 's/.*/\L&/g' "$DICT" > "$OPTIMIZE_TEMP"
	cat -n "$OPTIMIZE_TEMP" | sort -uk2 | sort -nk1 | cut -f2- > "$DICT"
	sed -i '/^[[:space:]]*#/d; /^$/d' "$DICT"
	rm -f "$OPTIMIZE_TEMP"
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Optimisation de l'index..>${NC}"
	INDEX_TEMP=$(mktemp)
	cat -n "assets/index.csv" | sort -uk2 | sort -nk1 | cut -f2- > "$INDEX_TEMP"
	sed -i '/^$/d' "$INDEX_TEMP"
	mv "$INDEX_TEMP" "assets/index.csv"
	whiptail --title "mf-bandit Optimize" --msgbox "Dictionnaire et index optimises." 8 78
	basemenu
}
function mfocWithFallback(){       # Tente mfoc, puis mfcuk en cas d'echec, avec ajout des clés au dictionnaire
	local badge_uid="$1"
	local output_file="$2"
	# Construit un fichier de clés combiné : UID-spécifique → tout index.csv → dictionnaire
	local COMBINED_KEYS
	COMBINED_KEYS=$(mktemp)
	grep "^$badge_uid," "$CURDIR/assets/index.csv" 2>/dev/null | cut -d, -f2- | tr ',' '\n' > "$COMBINED_KEYS"
	cut -d, -f2- "$CURDIR/assets/index.csv" 2>/dev/null | tr ',' '\n' >> "$COMBINED_KEYS"
	cat "$DICT" >> "$COMBINED_KEYS"
	local COMBINED_DEDUP
	COMBINED_DEDUP=$(mktemp)
	cat -n "$COMBINED_KEYS" | sort -uk2 | sort -nk1 | cut -f2- | grep -v '^$' > "$COMBINED_DEDUP"
	rm -f "$COMBINED_KEYS"
	if [ "$MFOC_VERBOSE" -eq 1 ]; then
		mfoc -P "$MFOC_PROBES" -f "$COMBINED_DEDUP" -O "$output_file" | tee LastMfocOut.tmp >&2
	else
		mfoc -P "$MFOC_PROBES" -f "$COMBINED_DEDUP" -O "$output_file" | tee LastMfocOut.tmp > /dev/null
	fi
	if [ ${PIPESTATUS[0]} -eq 0 ]; then
		rm -f "$COMBINED_DEDUP"
		return 0
	fi
	rm -f LastMfocOut.tmp "$COMBINED_DEDUP"
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <mfoc echoue, tentative avec mfcuk (darkside attack)..>${NC}"
	command -v whiptail &>/dev/null && \
		whiptail --title "mf-bandit" --infobox "mfoc echoue, tentative avec mfcuk..." 6 55
	local MFCUK_TEMP
	MFCUK_TEMP=$(mktemp)
	if [ "$MFOC_VERBOSE" -eq 1 ]; then
		mfcuk -C -R 0:A -v 3 -s 50 -S 50 2>&1 | tee "$MFCUK_TEMP" >&2
	else
		mfcuk -C -R 0:A -v 3 -s 50 -S 50 > "$MFCUK_TEMP" 2>&1
	fi
	local found_keys
	found_keys=$(grep -oiE '\b[0-9a-f]{12}\b' "$MFCUK_TEMP")
	rm -f "$MFCUK_TEMP"
	if [ -z "$found_keys" ]; then
		return 1
	fi
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Clés trouvées par mfcuk, mise à jour du dictionnaire..>${NC}"
	local DICT_TEMP
	DICT_TEMP=$(mktemp)
	echo "$found_keys" > "$DICT_TEMP"
	cat "$DICT" >> "$DICT_TEMP"
	cat -n "$DICT_TEMP" | sort -uk2 | sort -nk1 | cut -f2- > "$DICT"
	sed -i '/^[[:space:]]*#/d; /^$/d' "$DICT"
	rm -f "$DICT_TEMP"
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Nouvelle tentative mfoc avec les clés mfcuk..>${NC}"
	if [ "$MFOC_VERBOSE" -eq 1 ]; then
		mfoc -P "$MFOC_PROBES" -f "$DICT" -O "$output_file" | tee LastMfocOut.tmp >&2
	else
		mfoc -P "$MFOC_PROBES" -f "$DICT" -O "$output_file" | tee LastMfocOut.tmp > /dev/null
	fi
	return ${PIPESTATUS[0]}
}
function checkIfIndexed(){		   # Verifie si l'uid transmit en argument et presen dans le csv, auquel cas on remonte les clees correspondantes dans le fichier de clees
	CHECK_TEMP_1=$(mktemp)                                                                                          # creation des fichier temporaires
	CHECK_TEMP_2=$(mktemp) 
	CHECK_TEMP_3=$(mktemp)
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Verification de l'index.. >${NC}"           
	grep $1 assets/index.csv > $CHECK_TEMP_1 
	cut -d, -f1 --complement $CHECK_TEMP_1 > $CHECK_TEMP_2  
	cat $DICT > $CHECK_TEMP_3 
	cat $CHECK_TEMP_3 >> $CHECK_TEMP_2
	cat $CHECK_TEMP_2 >$DICT
	rm -f $CHECK_TEMP_1 $CHECK_TEMP_2 $CHECK_TEMP_3
}
function buildFromSource(){        # Compile et installe un outil depuis les sources locales
	local name="$1"
	local srcdir="$CURDIR/$name"
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <Compilation de $name..>${NC}"
	command -v whiptail &>/dev/null && \
		whiptail --title "mf-bandit" --infobox "Compilation de $name en cours, patientez..." 6 55
	cd "$srcdir"
	case "$name" in
		libnfc) sudo apt-get install -y libusb-dev build-essential pkg-config autoconf automake libtool ;;
		mfoc)   sudo apt-get install -y build-essential pkg-config autoconf automake libtool ;;
		mfcuk)  sudo apt-get install -y build-essential pkg-config autoconf automake libtool ;;
	esac
	autoreconf -i
	./configure && make && sudo make install && sudo ldconfig
	local ret=$?
	cd "$CURDIR"
	if [ $ret -ne 0 ]; then
		>&2 echo -e "${COULEUR}MF-BANDIT:                    <Echec de la compilation de $name>${NC}"
		command -v whiptail &>/dev/null && \
			whiptail --title "mf-bandit" --msgbox "Echec de la compilation de $name." 8 50
		exit 1
	fi
	>&2 echo -e "${COULEUR}MF-BANDIT:                    <$name installe avec succes>${NC}"
}
function checkDependencies(){      # Vérifie et installe les outils requis
	local -a missing=()
	for cmd in nfc-list mfoc mfcuk nfc-mfclassic nfc-mfsetuid xxd whiptail dialog; do
		command -v "$cmd" &>/dev/null || missing+=("$cmd")
	done
	[ ${#missing[@]} -eq 0 ] && return
	local need_libnfc=0 need_mfoc=0 need_mfcuk=0
	for dep in "${missing[@]}"; do
		case "$dep" in
			nfc-list|nfc-mfclassic|nfc-mfsetuid) need_libnfc=1 ;;
			mfoc)  need_mfoc=1 ;;
			mfcuk) need_mfcuk=1 ;;
		esac
	done
	if [ $need_libnfc -eq 1 ] || [ $need_mfoc -eq 1 ] || [ $need_mfcuk -eq 1 ]; then
		>&2 echo -e "${COULEUR}MF-BANDIT:                    <Installation requise, mot de passe sudo:>${NC}"
		sudo -v || { whiptail --title "mf-bandit" --msgbox "Droits sudo requis pour l'installation." 8 50 ; exit 1 ; }
	fi
	[ $need_libnfc -eq 1 ] && buildFromSource "libnfc"
	[ $need_mfoc -eq 1 ]   && buildFromSource "mfoc"
	[ $need_mfcuk -eq 1 ]  && buildFromSource "mfcuk"
	# Vérification finale
	local -a still_missing=()
	for cmd in nfc-list mfoc mfcuk nfc-mfclassic nfc-mfsetuid xxd whiptail dialog; do
		command -v "$cmd" &>/dev/null || still_missing+=("$cmd")
	done
	if [ ${#still_missing[@]} -gt 0 ]; then
		local msg="Outils toujours manquants : ${still_missing[*]}"
		>&2 echo "$msg"
		command -v whiptail &>/dev/null && whiptail --title "mf-bandit" --msgbox "$msg" 8 60
		exit 1
	fi
}
CURDIR=$(pwd)                      # Init anticipée pour checkDependencies
checkDependencies                  # Vérifie et installe les dépendances
initialize                         # Initialise le script
checkReader                        # Vérifie la présence du lecteur NFC
basemenu				           # Menu de base
