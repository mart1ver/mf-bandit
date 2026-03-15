#!/bin/bash

# projet d'un script simplifiant la sauvegarde et la restauration de badges rfid

# set -x #pour activer le deboggage

DICT="assets/dictionaire.keys"
DATA="data"
CURDIR=$(pwd)

usage() {
	echo ""
	echo "Usage: $0 backup|restore -n (file)|clone|format|verify -n (file)|optimize"
	echo ""
}

presence() {
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

checkIfIndexed() {
	CHECK_TEMP_1=$(mktemp)
	CHECK_TEMP_2=$(mktemp)
	CHECK_TEMP_3=$(mktemp)
	>&2 echo "Vérification de l'index.."
	grep "$1" assets/index.csv > "$CHECK_TEMP_1"
	cut -d, -f1 --complement "$CHECK_TEMP_1" > "$CHECK_TEMP_2"
	cat "$DICT" > "$CHECK_TEMP_3"
	cat "$CHECK_TEMP_3" >> "$CHECK_TEMP_2"
	cat "$CHECK_TEMP_2" > "$DICT"
	rm -f "$CHECK_TEMP_1" "$CHECK_TEMP_2" "$CHECK_TEMP_3"
}

optimize() {
	>&2 echo "Optimisation du dictionnaire.."
	OPTIMIZE_TEMP_2=$(mktemp)
	OPTIMIZE_TEMP_3=$(mktemp)
	OPTIMIZE_TEMP_4=$(mktemp)
	INDEX_TEMP_1=$(mktemp)
	INDEX_TEMP_2=$(mktemp)
	# Extraction des clés trouvées — compatible 1K, 4K et toutes versions de mfoc
	grep -oE 'Found[[:space:]]+Key [AB]: [0-9a-fA-F]{12}' LastMfocOut.tmp \
		| grep -oE '[0-9a-fA-F]{12}' > "$OPTIMIZE_TEMP_2"
	if [ ! -s "$OPTIMIZE_TEMP_2" ]; then
		>&2 echo "Aucune clé extraite, optimisation ignorée"
		rm -f "$OPTIMIZE_TEMP_2" "$OPTIMIZE_TEMP_3" "$OPTIMIZE_TEMP_4" "$INDEX_TEMP_1" "$INDEX_TEMP_2" LastMfocOut.tmp
		cd "$CURDIR"
		return 1
	fi
	cat -n "$OPTIMIZE_TEMP_2" | sort -uk2 | sort -nk1 | cut -f2- > "$OPTIMIZE_TEMP_3"
	cat assets/dictionaire.keys >> "$OPTIMIZE_TEMP_3"
	sed 's/.*/\L&/g' "$OPTIMIZE_TEMP_3" > "$OPTIMIZE_TEMP_4"
	cat -n "$OPTIMIZE_TEMP_4" | sort -uk2 | sort -nk1 | cut -f2- > "$DICT"
	sed -i '/^[[:space:]]*#/d; /^$/d' "$DICT"
	>&2 echo "Optimisation de l'index.."
	sed -e 's/^/'"$1"',/' "$OPTIMIZE_TEMP_2" > "$INDEX_TEMP_1"
	cat -n "$INDEX_TEMP_1" | sort -uk2 | sort -nk1 | cut -f2- >> "$INDEX_TEMP_2"
	cat assets/index.csv >> "$INDEX_TEMP_2"
	cat -n "$INDEX_TEMP_2" | sort -uk2 | sort -nk1 | cut -f2- > assets/index.csv
	rm -f "$INDEX_TEMP_1" "$INDEX_TEMP_2"
	rm -f "$OPTIMIZE_TEMP_2" "$OPTIMIZE_TEMP_3" "$OPTIMIZE_TEMP_4" LastMfocOut.tmp
	cd "$CURDIR"
}

manualOptimize() {
	cd "$CURDIR"
	>&2 echo "Optimisation du dictionnaire.."
	OPTIMIZE_TEMP=$(mktemp)
	sed 's/.*/\L&/g' "$DICT" > "$OPTIMIZE_TEMP"
	cat -n "$OPTIMIZE_TEMP" | sort -uk2 | sort -nk1 | cut -f2- > "$DICT"
	sed -i '/^[[:space:]]*#/d; /^$/d' "$DICT"
	rm -f "$OPTIMIZE_TEMP"
	>&2 echo "Optimisation de l'index.."
	INDEX_TEMP=$(mktemp)
	cat -n "assets/index.csv" | sort -uk2 | sort -nk1 | cut -f2- > "$INDEX_TEMP"
	sed -i '/^$/d' "$INDEX_TEMP"
	mv "$INDEX_TEMP" "assets/index.csv"
	>&2 echo "Dictionnaire et index optimisés."
}

mfocWithFallback() {              # Tente mfoc, puis mfcuk en cas d'echec, avec ajout des clés au dictionnaire
	local badge_uid="$1"
	local output_file="$2"
	mfoc -f "$DICT" -O "$output_file" | tee LastMfocOut.tmp > /dev/null
	if [ ${PIPESTATUS[0]} -eq 0 ]; then
		return 0
	fi
	rm -f LastMfocOut.tmp
	>&2 echo "mfoc échoué, tentative avec mfcuk (darkside attack)..."
	local MFCUK_TEMP
	MFCUK_TEMP=$(mktemp)
	mfcuk -C -R 0:A -s 250 -S 250 2>&1 | tee "$MFCUK_TEMP" > /dev/null
	local found_keys
	found_keys=$(grep -oiE '\b[0-9a-f]{12}\b' "$MFCUK_TEMP")
	rm -f "$MFCUK_TEMP"
	if [ -z "$found_keys" ]; then
		return 1
	fi
	>&2 echo "Clés trouvées par mfcuk, mise à jour du dictionnaire..."
	local DICT_TEMP
	DICT_TEMP=$(mktemp)
	echo "$found_keys" > "$DICT_TEMP"
	cat "$DICT" >> "$DICT_TEMP"
	cat -n "$DICT_TEMP" | sort -uk2 | sort -nk1 | cut -f2- > "$DICT"
	sed -i '/^[[:space:]]*#/d; /^$/d' "$DICT"
	rm -f "$DICT_TEMP"
	>&2 echo "Nouvelle tentative mfoc avec les clés mfcuk..."
	mfoc -f "$DICT" -O "$output_file" | tee LastMfocOut.tmp > /dev/null
	return ${PIPESTATUS[0]}
}

backup() {
	while true; do
		BADGE_UID=$(presence)
		case $? in
			0) >&2 echo "Badge détecté avec l'UID: $BADGE_UID.." ; break ;;
			1) read -p "Placez le badge à copier sur le lecteur puis appuyez sur ENTRÉE.." ;;
			2) >&2 echo "Erreur: lecteur NFC non disponible. Vérifiez la connexion." ; exit 1 ;;
		esac
	done
	read -p "Entrez le nom du badge (informatif): " BADGE_NAME
	local TIMESTAMP
	TIMESTAMP=$(date +'%F_%H-%M-%S')
	BADGE_DUMP="$DATA/$BADGE_NAME-$BADGE_UID-$TIMESTAMP.dmp"
	BADGE_DUMP_NAME="$BADGE_NAME-$BADGE_UID-$TIMESTAMP.dmp"
	checkIfIndexed "$BADGE_UID"
	>&2 echo "Décodage du badge avec mfoc .. peut prendre longtemps.."
	mfocWithFallback "$BADGE_UID" "$BADGE_DUMP"
	if [ $? -eq 0 ]; then
		>&2 echo "Badge sauvegardé dans le fichier: $BADGE_DUMP_NAME"
		optimize "$BADGE_UID"
	else
		>&2 echo "Impossible de décoder le badge avec mfoc et mfcuk"
		rm -f LastMfocOut.tmp
	fi
	echo "$BADGE_DUMP"
}

restore() {
	local OPTIND
	OPTIND=2
	while getopts ":n:" OPTION; do
		case $OPTION in
			n)
			read -p "Placez le badge cible sur le lecteur (ATTENTION ECRASEMENT DU BADGE), puis appuyez sur ENTRÉE.."
			while true; do
				BADGE_UID=$(presence)
				case $? in
					0) >&2 echo "Badge cible détecté avec l'UID $BADGE_UID.." ; break ;;
					1) read -p "Placez le badge cible sur le lecteur (ATTENTION ECRASEMENT DU BADGE), puis appuyez sur ENTRÉE.." ;;
					2) >&2 echo "Erreur: lecteur NFC non disponible. Vérifiez la connexion." ; exit 1 ;;
				esac
			done

			BADGE_DUMP="$OPTARG"
			TEMP_DUMP=$(mktemp)
			checkIfIndexed "$BADGE_UID"
			>&2 echo "Décodage des clefs du badge cible.."
			mfocWithFallback "$BADGE_UID" "$TEMP_DUMP"
			if [ $? -ne 0 ]; then
				>&2 echo "Impossible de décoder le badge cible avec mfoc et mfcuk"
				rm -f LastMfocOut.tmp "$TEMP_DUMP"
				exit 1
			fi
			optimize "$BADGE_UID"
			>&2 echo "Écriture du contenu du badge cible.."
			nfc-mfclassic W a "$BADGE_DUMP" "$TEMP_DUMP" f >/dev/null
			rm -f "$TEMP_DUMP"
			BADGE_DUMP_UID=$(xxd -ps -c 4 "$BADGE_DUMP" | head -n1)
			>&2 echo "Écriture de l'UID $BADGE_DUMP_UID vers le badge cible.."
			nfc-mfsetuid "$BADGE_DUMP_UID" >/dev/null
			>&2 echo "Badge cible écrit!"
			return 0
			;;
		esac
	done

	>&2 echo ""
	>&2 echo "Nom du fichier manquant [restore -n (file)]"
	>&2 echo ""
	usage
	exit 1
}

format() {
		read -p "Placez le badge cible sur le lecteur (ATTENTION, LE CONTENU DU BADGE VA ETRE FORMATÉ ET L'UID RANDOMISÉ), puis appuyez sur ENTRÉE.."
		while true; do
			BADGE_UID=$(presence)
			case $? in
				0) >&2 echo "Badge cible détecté avec l'UID $BADGE_UID.." ; break ;;
				1) read -p "Placez le badge cible sur le lecteur (ATTENTION, LE CONTENU DU BADGE VA ETRE FORMATÉ ET L'UID RANDOMISÉ), puis appuyez sur ENTRÉE.." ;;
				2) >&2 echo "Erreur: lecteur NFC non disponible. Vérifiez la connexion." ; exit 1 ;;
			esac
		done

		BADGE_DUMP="assets/dumb.dmb"
		TEMP_DUMP=$(mktemp)
		checkIfIndexed "$BADGE_UID"
		>&2 echo "Décodage des clefs du badge cible.."
		mfocWithFallback "$BADGE_UID" "$TEMP_DUMP"
		if [ $? -ne 0 ]; then
			>&2 echo "Impossible de décoder le badge cible avec mfoc et mfcuk"
			rm -f LastMfocOut.tmp "$TEMP_DUMP"
			exit 1
		fi
		optimize "$BADGE_UID"
		BADGE_DUMP_UID=$(head -c4 </dev/urandom|xxd -p -u)
		>&2 echo "Écriture de l'UID randomisée $BADGE_DUMP_UID vers le badge cible.."
		>&2 echo "Écriture d'un contenu vierge sur le badge cible.."
		nfc-mfclassic W a "$BADGE_DUMP" "$TEMP_DUMP" f >/dev/null
		rm -f "$TEMP_DUMP"
		nfc-mfsetuid "$BADGE_DUMP_UID" >/dev/null
		>&2 echo "Badge cible formaté!"
		return 0
}

verify() {
	local OPTIND
	OPTIND=2
	while getopts ":n:" OPTION; do
		case $OPTION in
			n)
			read -p "Placez le badge à verifier sur le lecteur , puis appuyez sur ENTRÉE.."
			while true; do
				BADGE_UID=$(presence)
				case $? in
					0) >&2 echo "Badge à verifier détecté avec l'UID $BADGE_UID.." ; break ;;
					1) read -p "Placez le badge à verifier sur le lecteur , puis appuyez sur ENTRÉE.." ;;
					2) >&2 echo "Erreur: lecteur NFC non disponible. Vérifiez la connexion." ; exit 1 ;;
				esac
			done

			BADGE_DUMP="$OPTARG"
			BADGE_DUMP_UID=$(xxd -ps -c 4 "$BADGE_DUMP" | head -n1)
			TEMP_DUMP=$(mktemp)
			checkIfIndexed "$BADGE_UID"
			>&2 echo "Décodage des clefs du badge à vérifier.."
			mfocWithFallback "$BADGE_UID" "$TEMP_DUMP"
			if [ $? -ne 0 ]; then
				>&2 echo "Impossible de décoder le badge avec mfoc et mfcuk"
				rm -f LastMfocOut.tmp "$TEMP_DUMP"
				exit 1
			fi
			optimize "$BADGE_UID"
			>&2 echo "Comparaison des UIDs.."
			if test "$BADGE_DUMP_UID" = "$BADGE_UID"; then
				>&2 echo "<L'UID DU BADGE CORRESPOND AU FICHIER INDIQUÉ!>"
			else
				>&2 echo "<L'UID DU BADGE NE CORRESPOND PAS AU FICHIER INDIQUÉ!>"
			fi
			>&2 echo "Comparaison du contenu des badges.."
			if cmp --ignore-initial=32 "$TEMP_DUMP" "$BADGE_DUMP" >/dev/null; then
				>&2 echo '<LE CONTENU DU BADGE CORRESPOND AU FICHIER INDIQUÉ!>'
			else
				>&2 echo '<LE CONTENU DU BADGE NE CORRESPOND PAS AU FICHIER INDIQUÉ!>'
			fi
			rm -f "$TEMP_DUMP"
			return 0
			;;
		esac
	done

	>&2 echo ""
	>&2 echo "Nom du fichier manquant [verify -n (file)]"
	>&2 echo ""
	usage
	exit 1
}

buildFromSource() {               # Compile et installe un outil depuis les sources locales
	local name="$1"
	local srcdir="$CURDIR/$name"
	>&2 echo "Compilation de $name en cours..."
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
		>&2 echo "Echec de la compilation de $name."
		exit 1
	fi
	>&2 echo "$name installé avec succès."
}
checkDependencies() {              # Vérifie et installe les outils requis
	local -a missing=()
	for cmd in nfc-list mfoc mfcuk nfc-mfclassic nfc-mfsetuid xxd; do
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
	[ $need_libnfc -eq 1 ] && buildFromSource "libnfc"
	[ $need_mfoc -eq 1 ]   && buildFromSource "mfoc"
	[ $need_mfcuk -eq 1 ]  && buildFromSource "mfcuk"
	# Vérification finale
	local -a still_missing=()
	for cmd in nfc-list mfoc mfcuk nfc-mfclassic nfc-mfsetuid xxd; do
		command -v "$cmd" &>/dev/null || still_missing+=("$cmd")
	done
	if [ ${#still_missing[@]} -gt 0 ]; then
		>&2 echo "Outils toujours manquants : ${still_missing[*]}"
		exit 1
	fi
}

mkdir -p "$DATA"
checkDependencies
>&2 echo ""
>&2 echo ""
>&2 echo "==== Nfc-bandit simplifie la copie! ===="
>&2 echo ""

case "$1" in
	backup)
		backup "$@"
		;;
	restore)
		restore "$@"
		;;
	clone)
		BADGE_DUMP=$(backup "$@")
		restore abcd -n "$BADGE_DUMP" # abcd to accomodate getopts behavior
		;;
	format)
		format "$@"
		;;
	verify)
		verify "$@"
		;;
	optimize)
		manualOptimize
		;;
	*)
		usage
		;;
esac
