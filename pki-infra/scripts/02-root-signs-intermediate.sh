#!/usr/bin/env bash
# CÉRÉMONIE 2 : la racine (hors ligne) signe la CSR de l'intermédiaire pour 5 ans
# et renouvelle sa CRL. Ensuite le certificat est rapatrié sur l'hôte PKI en ligne.
# Usage : ROOT_PASS=... scripts/02-root-signs-intermediate.sh
. "$(dirname "$0")/lib.sh"

CSR="$I/csr/inter.csr"
[ -f "$CSR" ] || die "CSR introuvable : $CSR (lancez 01-init-intermediate.sh)"

openssl ca -batch -config "$ROOT_CNF" -extensions v3_intermediate_ca -days 1825 \
  -notext $(passin ROOT_PASS) -in "$CSR" -out "$I/certs/inter.crt"
openssl ca -config "$ROOT_CNF" -gencrl $(passin ROOT_PASS) -out "$R/crl/root.crl"

openssl verify -CAfile "$R/certs/root.crt" "$I/certs/inter.crt"

# Sur la machine racine réelle, la clé de l'intermédiaire n'existe pas : la suite
# (CRL intermédiaire + bundle) se fait avec scripts/02b-intermediate-finalize.sh sur l'hôte PKI.
echo "OK : intermédiaire signée ($I/certs/inter.crt). Rapatriez inter.crt + root.crt + root.crl"
echo "     sur l'hôte PKI puis lancez scripts/02b-intermediate-finalize.sh"
