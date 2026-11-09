#!/usr/bin/env bash
# CÉRÉMONIE 1 : création de la CA racine (à faire sur la machine HORS LIGNE).
# Clé EC P-384 chiffrée AES-256, certificat auto-signé 20 ans, CRL initiale.
# Usage : ROOT_PASS=... scripts/00-init-root.sh     (sans ROOT_PASS : saisie interactive)
. "$(dirname "$0")/lib.sh"

[ -e "$R/private/root.key" ] && die "La racine existe déjà ($R). Abandon pour ne rien écraser."

mkdir -p "$R"/{private,certs,newcerts,crl}
: > "$R/index.txt"; echo 1000 > "$R/serial"; echo 1000 > "$R/crlnumber"

# Clé : générée par le CSPRNG d'OpenSSL (jamais de valeur "maison", cf. incident eMudhra)
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 \
  -aes-256-cbc $(passgen ROOT_PASS) -out "$R/private/root.key"
chmod 400 "$R/private/root.key"

# Certificat auto-signé, 7300 jours = 20 ans
openssl req -new -x509 -sha384 -days 7300 -config "$ROOT_CNF" -extensions v3_ca \
  -key "$R/private/root.key" $(passin ROOT_PASS) -out "$R/certs/root.crt"

# CRL racine initiale (vide)
openssl ca -config "$ROOT_CNF" -gencrl $(passin ROOT_PASS) -out "$R/crl/root.crl"

openssl x509 -in "$R/certs/root.crt" -noout -subject -issuer -dates -fingerprint -sha256
echo "OK : racine créée. Rangez/éteignez cette machine après la cérémonie 2."
