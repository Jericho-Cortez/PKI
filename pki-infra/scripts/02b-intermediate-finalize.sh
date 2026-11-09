#!/usr/bin/env bash
# Sur l'hôte PKI EN LIGNE, après la cérémonie 2 : vérifie la chaîne, génère la première CRL
# de l'intermédiaire et construit les fichiers de déploiement (chaîne + bundle de CRL).
# Usage : INTER_PASS=... scripts/02b-intermediate-finalize.sh
. "$(dirname "$0")/lib.sh"

[ -f "$I/certs/inter.crt" ] || die "inter.crt absent : cérémonie 2 non faite ?"
openssl verify -CAfile "$R/certs/root.crt" "$I/certs/inter.crt"
openssl ca -config "$INTER_CNF" -gencrl $(passin INTER_PASS) -out "$I/crl/inter.crl"
rebuild_deploy
echo "OK : fichiers à déployer dans $DEPLOY/ (ca-chain.pem, crl-bundle.pem, root.crt)"
