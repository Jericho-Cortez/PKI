#!/usr/bin/env bash
# Révoque un certificat final, régénère la CRL de l'intermédiaire et le bundle.
# Il faut ENSUITE recharger le service (nginx -s reload) : nginx lit la CRL au chargement.
# Usage : INTER_PASS=... scripts/05-revoke.sh pki-data/issued/alice/alice.crt [raison]
#   raison : unspecified | keyCompromise | affiliationChanged | superseded | cessationOfOperation
. "$(dirname "$0")/lib.sh"

CRT="${1:?usage: 05-revoke.sh <certificat.crt> [raison]}"
REASON="${2:-keyCompromise}"
[ -f "$CRT" ] || die "Certificat introuvable : $CRT"

openssl ca -config "$INTER_CNF" $(passin INTER_PASS) -revoke "$CRT" -crl_reason "$REASON"
openssl ca -config "$INTER_CNF" $(passin INTER_PASS) -gencrl -out "$I/crl/inter.crl"
rebuild_deploy

echo "--- index.txt (ligne R = révoqué) ---"; grep -E '^R' "$I/index.txt" || true
echo "--- CRL ---"; openssl crl -in "$I/crl/inter.crl" -noout -lastupdate -nextupdate
openssl crl -in "$I/crl/inter.crl" -noout -text | grep -A3 'Serial Number' || true
echo "OK : déployez $DEPLOY/crl-bundle.pem puis rechargez le service."
