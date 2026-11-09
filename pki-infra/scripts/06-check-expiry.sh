#!/usr/bin/env bash
# Supervision : alerte pour tout certificat qui expire dans moins de N jours (défaut 30).
# À lancer chaque jour : 0 7 * * * cd /opt/pki-infra && scripts/06-check-expiry.sh | mail ...
# Code retour : 0 = tout va bien, 1 = au moins un certificat à renouveler.
. "$(dirname "$0")/lib.sh"
DAYS="${1:-30}"; SEC=$((DAYS*86400)); rc=0

for c in "$R/certs/root.crt" "$I/certs/inter.crt" "$ISSUED"/*/*.crt; do
  [ -f "$c" ] || continue
  case "$c" in *-chain.crt) continue;; esac
  end=$(openssl x509 -in "$c" -noout -enddate | cut -d= -f2)
  if openssl x509 -in "$c" -noout -checkend "$SEC" >/dev/null; then
    echo "ok        $c  (expire : $end)"
  else
    echo "A RENOUVELER  $c  (expire : $end)"; rc=1
  fi
done
exit $rc
