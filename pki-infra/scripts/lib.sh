#!/usr/bin/env bash
# Fonctions communes. À sourcer : . scripts/lib.sh
# Les scripts se lancent TOUJOURS depuis la racine du dépôt (chemins relatifs :
# compatible OpenSSL natif Windows (Git Bash) et Linux).
set -euo pipefail
export MSYS_NO_PATHCONV=1                  # Git Bash : ne pas réécrire "-subj /O=..."

# OpenSSL développe $ENV::SAN au chargement de inter.cnf, même pour les commandes qui
# n'émettent pas de certificat serveur : valeur neutre par défaut (03-issue-server.sh la remplace).
_SAN_IN="${SAN:-}"
export SAN="${SAN:-DNS:unset.invalid}"
export PKI_DIR="${PKI_DIR:-pki-data}"      # dossier des données générées (ignoré par git)
ROOT_CNF="config/root.cnf"
INTER_CNF="config/inter.cnf"
R="$PKI_DIR/root-ca"
I="$PKI_DIR/inter-ca"
ISSUED="$PKI_DIR/issued"
DEPLOY="$PKI_DIR/deploy"

# passin VAR / passout VAR : si la variable d'environnement VAR est définie,
# OpenSSL l'utilise (usage non interactif / tests) ; sinon il demande la
# passphrase au clavier (usage réel).
passin()  { if [ -n "${!1:-}" ]; then echo "-passin env:$1";  fi; }
passout() { if [ -n "${!1:-}" ]; then echo "-passout env:$1"; fi; }
passgen() { if [ -n "${!1:-}" ]; then echo "-pass env:$1";    fi; }   # genpkey utilise -pass

die() { echo "ERREUR: $*" >&2; exit 1; }

# Reconstruit les fichiers de déploiement : chaîne de confiance + bundle de CRL
rebuild_deploy() {
  mkdir -p "$DEPLOY"
  cat "$I/certs/inter.crt" "$R/certs/root.crt" > "$DEPLOY/ca-chain.pem"
  cp  "$R/certs/root.crt" "$DEPLOY/root.crt"
  : > "$DEPLOY/crl-bundle.pem"
  [ -f "$I/crl/inter.crl" ] && cat "$I/crl/inter.crl" >> "$DEPLOY/crl-bundle.pem"
  [ -f "$R/crl/root.crl"  ] && cat "$R/crl/root.crl"  >> "$DEPLOY/crl-bundle.pem"
  # Variante "dossier haché" (<hash>.r0) pour les outils OpenSSL qui ne lisent qu'une CRL par
  # fichier (openssl s_server, -CApath). nginx, lui, lit directement crl-bundle.pem.
  rm -rf "$DEPLOY/crl-dir"; mkdir -p "$DEPLOY/crl-dir"
  for f in "$I/crl/inter.crl" "$R/crl/root.crl"; do
    [ -f "$f" ] && cp "$f" "$DEPLOY/crl-dir/$(openssl crl -in "$f" -noout -hash).r0"
  done
  return 0
}
