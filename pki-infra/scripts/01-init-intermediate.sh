#!/usr/bin/env bash
# Sur l'hôte PKI EN LIGNE : crée la clé de la CA intermédiaire et sa CSR.
# La clé privée ne quitte jamais cet hôte ; seule la CSR part vers la racine.
# Usage : INTER_PASS=... scripts/01-init-intermediate.sh
. "$(dirname "$0")/lib.sh"

[ -e "$I/private/inter.key" ] && die "L'intermédiaire existe déjà ($I). Abandon."

mkdir -p "$I"/{private,certs,newcerts,crl,csr}
: > "$I/index.txt"; echo 1000 > "$I/serial"; echo 1000 > "$I/crlnumber"

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 \
  -aes-256-cbc $(passgen INTER_PASS) -out "$I/private/inter.key"
chmod 400 "$I/private/inter.key"

openssl req -new -sha384 -config "$INTER_CNF" \
  -key "$I/private/inter.key" $(passin INTER_PASS) -out "$I/csr/inter.csr"

echo "OK : CSR dans $I/csr/inter.csr -> à transporter (clé USB) vers la racine hors ligne."
