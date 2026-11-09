# pki-infra : PKI OpenSSL pour un homelab (option A)

CA racine hors ligne → CA intermédiaire → certificats serveur/client → **mTLS** → **révocation CRL/OCSP**.
Projet de formation (RNCP37680 : BC01·C3, BC02·C5, BC02·C6, BC03·C9), appliqué à un homelab réel.

- Rapport technique : [`docs/rapport.md`](docs/rapport.md)
- Politique de certification : [`docs/CP-CPS.md`](docs/CP-CPS.md)

## Test express (aucune VM, aucun nginx)
Prérequis : `bash` (Git Bash sous Windows ou Linux/WSL) et OpenSSL ≥ 3.0. Depuis la racine du dépôt :

```bash
bash scripts/99-demo-test.sh
```

Construit toute la PKI dans `pki-test/` (mots de passe jetables), lance un serveur mTLS (`openssl s_server`),
puis vérifie : refus sans certificat, accès avec certificat, **refus après révocation** (alerte TLS
`certificate revoked`), statut OCSP, supervision d'expiration. Le dossier est supprimé à la fin (`KEEP=1` pour le garder).

## Utilisation réelle (une étape = une machine)
Toujours depuis la racine du dépôt. Sans variable `*_PASS`, OpenSSL demande la passphrase au clavier (recommandé).

| # | Machine | Commande | Effet |
|---|---|---|---|
| 0 | **Racine, hors ligne** | `scripts/00-init-root.sh` | clé P-384 chiffrée, certificat 20 ans, CRL |
| 1 | **Hôte PKI en ligne** | `scripts/01-init-intermediate.sh` | clé + CSR de l'intermédiaire |
| 2 | **Racine, hors ligne** | `scripts/02-root-signs-intermediate.sh` | signe l'intermédiaire (5 ans), CRL racine |
| 2b | Hôte PKI en ligne | `scripts/02b-intermediate-finalize.sh` | 1re CRL intermédiaire + chaîne + bundle de CRL |
| 3 | Hôte PKI | `SAN="DNS:app.home.arpa" scripts/03-issue-server.sh app.home.arpa` | certificat serveur + chaîne |
| 4 | Hôte PKI | `scripts/04-issue-client.sh alice` | certificat client + `.p12` |
| 5 | Hôte PKI | `scripts/05-revoke.sh pki-data/issued/alice/alice.crt keyCompromise` | révocation + CRL + bundle |
| 6 | Hôte PKI (cron) | `scripts/06-check-expiry.sh 30` | alerte avant expiration |

> En production, la CSR voyage par clé USB vers la machine racine (étape 2), puis `inter.crt`, `root.crt` et
> `root.crl` reviennent sur l'hôte PKI (étape 2b). Pour simplifier, les scripts utilisent un seul dossier
> `pki-data/` avec les sous-dossiers `root-ca/` et `inter-ca/` : en production, chaque machine n'a que le sien.

## Déployer sur le service
`nginx/app.home.arpa.conf` : reverse proxy mTLS avec `ssl_verify_client on` et `ssl_crl`. Après chaque révocation :
copier `deploy/crl-bundle.pem` puis `nginx -s reload`. (Config **non testée** ici, à valider sur la machine cible.)

Faire confiance à la racine sur un poste Windows : `certutil -user -addstore Root pki-data\deploy\root.crt`.
Importer l'identité client : double-clic sur le `.p12`. Attention : Firefox, Python (`certifi`), Java et les images Docker
ont **leur propre truststore**.

## Sécurité du dépôt
Le `.gitignore` exclut clés, `.p12`, CSR et bases `index.txt`. **Ne jamais publier une clé privée**, même jetable.
