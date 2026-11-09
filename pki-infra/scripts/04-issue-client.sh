#!/usr/bin/env bash
# Émet un certificat CLIENT (clientAuth), 180 jours, + export PKCS#12 pour navigateur/Windows.
# Usage : INTER_PASS=... P12_PASS=... scripts/04-issue-client.sh alice
. "$(dirname "$0")/lib.sh"

NAME="${1:?usage: 04-issue-client.sh <identité>}"
OUT="$ISSUED/$NAME"; mkdir -p "$OUT"

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$OUT/$NAME.key"
chmod 600 "$OUT/$NAME.key"
openssl req -new -sha256 -config "$INTER_CNF" -key "$OUT/$NAME.key" \
  -subj "/O=Homelab PKI/CN=$NAME" -out "$OUT/$NAME.csr"

openssl ca -batch -config "$INTER_CNF" -extensions client_cert -days 180 -notext \
  $(passin INTER_PASS) -in "$OUT/$NAME.csr" -out "$OUT/$NAME.crt"

openssl verify -CAfile "$R/certs/root.crt" -untrusted "$I/certs/inter.crt" "$OUT/$NAME.crt"

# PKCS#12 : clé + certificat + chaîne, protégé par mot de passe (invite si P12_PASS absent)
openssl pkcs12 -export -inkey "$OUT/$NAME.key" -in "$OUT/$NAME.crt" \
  -certfile "$DEPLOY/ca-chain.pem" -name "$NAME" $(passout P12_PASS) -out "$OUT/$NAME.p12"
echo "OK : $OUT/$NAME.p12 prêt à être importé sur le poste client."
