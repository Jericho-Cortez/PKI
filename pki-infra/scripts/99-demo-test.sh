#!/usr/bin/env bash
# Test de bout en bout, SANS aucune VM ni nginx : openssl s_server joue le service mTLS.
# Prouve : chaîne valide, refus sans certificat, accès avec certificat, REFUS APRÈS RÉVOCATION
# (CRL), et statut OCSP "revoked". Utilise des mots de passe JETABLES et un dossier temporaire.
# Usage (depuis la racine du dépôt) : scripts/99-demo-test.sh
export PKI_DIR="${PKI_DIR:-pki-test}"
. "$(dirname "$0")/lib.sh"

export ROOT_PASS="test-root-jetable" INTER_PASS="test-inter-jetable" P12_PASS="test-p12-jetable"
PORT=18443; OCSP_PORT=12560; HOST=app.home.arpa
FAIL=0
pass() { echo "  [PASS] $*"; }
fail() { echo "  [FAIL] $*"; FAIL=1; }
SRV_PIDS=()
# Git Bash : "kill" peut laisser vivre le processus Windows natif -> "kill -f" + port neuf à chaque démarrage
cleanup() { for p in "${SRV_PIDS[@]:-}"; do [ -n "$p" ] && { kill -f "$p" 2>/dev/null || kill "$p" 2>/dev/null || true; }; done; SRV_PIDS=(); }
trap cleanup EXIT

rm -rf "$PKI_DIR"
echo "== 1. Construction de la PKI =="
scripts/00-init-root.sh         >/dev/null
scripts/01-init-intermediate.sh >/dev/null
scripts/02-root-signs-intermediate.sh >/dev/null
scripts/02b-intermediate-finalize.sh >/dev/null
SAN="DNS:$HOST" scripts/03-issue-server.sh "$HOST" >/dev/null
scripts/04-issue-client.sh alice >/dev/null
scripts/04-issue-client.sh bob   >/dev/null
openssl verify -CAfile "$R/certs/root.crt" -untrusted "$I/certs/inter.crt" "$ISSUED/$HOST/$HOST.crt" >/dev/null \
  && pass "chaîne serveur valide (racine -> intermédiaire -> serveur)" || fail "chaîne serveur"
openssl x509 -in "$I/certs/inter.crt" -noout -text | grep -q 'pathlen:0' \
  && pass "intermédiaire : CA:TRUE, pathlen:0" || fail "pathlen"

start_server() {
  cleanup
  PORT=$((PORT+1))     # port neuf : évite tout reste de l'ancien serveur
  openssl s_server -accept $PORT -www -tls1_3 \
    -cert "$ISSUED/$HOST/$HOST.crt" -key "$ISSUED/$HOST/$HOST.key" -cert_chain "$I/certs/inter.crt" \
    -Verify 2 -CAfile "$DEPLOY/ca-chain.pem" -CApath "$DEPLOY/crl-dir" -crl_check_all \
    -verify_return_error >/dev/null 2>&1 &
  SRV_PIDS+=("$!")
  sleep 1
}

# try_client [cert key] -> "OK" si la page est servie ; sinon "REFUSE <alerte TLS>"
# (-ign_eof : attendre la réponse du serveur même après la fin de stdin)
try_client() {
  local args=()
  [ $# -eq 2 ] && args=(-cert "$1" -key "$2")
  local out
  out=$(printf 'GET / HTTP/1.0\r\n\r\n' | timeout 10 openssl s_client \
          -connect 127.0.0.1:$PORT -tls1_3 -ign_eof \
          -servername "$HOST" -verify_hostname "$HOST" -CAfile "$DEPLOY/root.crt" -verify_return_error \
          "${args[@]}" 2>&1 || true)
  if echo "$out" | grep -q 'HTTP/1.0 200'; then echo OK
  else echo "REFUSE $(echo "$out" | grep -oiE 'alert [a-z ]+|certificate (revoked|required)' | head -1)"; fi
}

echo "== 2. Service mTLS (avant révocation) =="
start_server
R1=$(try_client); case "$R1" in REFUSE*) pass "sans certificat client -> refusé  [$R1]";; *) fail "sans certificat accepté !";; esac
[ "$(try_client "$ISSUED/alice/alice.crt" "$ISSUED/alice/alice.key")" = OK ] \
  && pass "alice (valide) -> accepté" || fail "alice refusée"
[ "$(try_client "$ISSUED/bob/bob.crt" "$ISSUED/bob/bob.key")" = OK ] \
  && pass "bob (valide) -> accepté" || fail "bob refusé"

echo "== 3. Révocation d'alice (CRL) =="
scripts/05-revoke.sh "$ISSUED/alice/alice.crt" keyCompromise | sed 's/^/    /'
start_server     # équivalent de "nginx -s reload" : recharge la CRL
R2=$(try_client "$ISSUED/alice/alice.crt" "$ISSUED/alice/alice.key")
# le refus doit venir de la révocation (alerte TLS "certificate revoked"), pas d'une autre cause
case "$R2" in
  *revoked*) pass "alice (révoquée) -> REFUSÉE  [$R2]";;
  *)         fail "alice révoquée : résultat inattendu [$R2]";;
esac
[ "$(try_client "$ISSUED/bob/bob.crt" "$ISSUED/bob/bob.key")" = OK ] \
  && pass "bob (non révoqué) -> toujours accepté" || fail "bob refusé à tort"

echo "== 4. OCSP =="
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -config "$INTER_CNF" \
  -subj "/O=Homelab PKI/CN=OCSP Responder" -keyout "$ISSUED/ocsp.key" -out "$ISSUED/ocsp.csr" 2>/dev/null
openssl ca -batch -config "$INTER_CNF" -extensions ocsp_cert -days 90 -notext $(passin INTER_PASS) \
  -in "$ISSUED/ocsp.csr" -out "$ISSUED/ocsp.crt" 2>/dev/null
openssl ocsp -index "$I/index.txt" -port $OCSP_PORT -rsigner "$ISSUED/ocsp.crt" -rkey "$ISSUED/ocsp.key" \
  -CA "$DEPLOY/ca-chain.pem" -nrequest 2 >/dev/null 2>&1 &
OCSP_PID=$!; sleep 1
A=$(openssl ocsp -issuer "$I/certs/inter.crt" -cert "$ISSUED/alice/alice.crt" -url "http://127.0.0.1:$OCSP_PORT" \
     -CAfile "$DEPLOY/ca-chain.pem" 2>&1 | grep -E 'alice.crt:' || true)
B=$(openssl ocsp -issuer "$I/certs/inter.crt" -cert "$ISSUED/bob/bob.crt"   -url "http://127.0.0.1:$OCSP_PORT" \
     -CAfile "$DEPLOY/ca-chain.pem" 2>&1 | grep -E 'bob.crt:' || true)
wait $OCSP_PID 2>/dev/null || true
echo "$A" | grep -q revoked && pass "OCSP alice : revoked" || fail "OCSP alice : '$A'"
echo "$B" | grep -q good    && pass "OCSP bob   : good"    || fail "OCSP bob : '$B'"

echo "== 5. Supervision des expirations =="
scripts/06-check-expiry.sh 30 | sed 's/^/    /' && pass "aucun certificat à renouveler sous 30 j" || fail "expiry"

cleanup
if [ "${KEEP:-0}" != 1 ]; then rm -rf "$PKI_DIR"; fi
[ $FAIL -eq 0 ] && echo "TOUS LES TESTS PASSENT" || { echo "ECHEC"; exit 1; }
