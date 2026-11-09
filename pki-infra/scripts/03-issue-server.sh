#!/usr/bin/env bash
# Émet un certificat SERVEUR (serverAuth + SAN), 180 jours, clé EC P-256.
# Usage : INTER_PASS=... SAN="DNS:app.home.arpa,DNS:ollama.home.arpa" \
#         scripts/03-issue-server.sh app.home.arpa
. "$(dirname "$0")/lib.sh"

NAME="${1:?usage: 03-issue-server.sh <nom-DNS>}"
export SAN="${_SAN_IN:-DNS:$NAME}"
OUT="$ISSUED/$NAME"; mkdir -p "$OUT"

# 1. Bi-clé + CSR (sur l'entité finale ; ici même machine pour la démo)
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$OUT/$NAME.key"
chmod 600 "$OUT/$NAME.key"
openssl req -new -sha256 -config "$INTER_CNF" -key "$OUT/$NAME.key" \
  -subj "/O=Homelab PKI/CN=$NAME" -out "$OUT/$NAME.csr"

# 2. Signature par l'intermédiaire
openssl ca -batch -config "$INTER_CNF" -extensions server_cert -days 180 -notext \
  $(passin INTER_PASS) -in "$OUT/$NAME.csr" -out "$OUT/$NAME.crt"

# 3. Chaîne à servir : certificat serveur puis intermédiaire (jamais la racine)
cat "$OUT/$NAME.crt" "$I/certs/inter.crt" > "$OUT/$NAME-chain.crt"

openssl verify -CAfile "$R/certs/root.crt" -untrusted "$I/certs/inter.crt" "$OUT/$NAME.crt"
openssl x509 -in "$OUT/$NAME.crt" -noout -subject -ext subjectAltName,extendedKeyUsage -dates
