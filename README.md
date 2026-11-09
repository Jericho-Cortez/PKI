# PKI : projet de formation (RNCP37680)

Mise en place d'une PKI OpenSSL pour un homelab : CA racine hors ligne, CA intermédiaire,
certificats serveur/client, mTLS et révocation (CRL/OCSP).

## Organisation du dépôt

| Dossier | Contenu |
|---|---|
| [`pki-infra/`](pki-infra/) | Le projet technique : scripts, configurations OpenSSL, config nginx |
| [`pki-infra/docs/`](pki-infra/docs/) | Rapport technique ([`rapport.md`](pki-infra/docs/rapport.md)) et politique de certification ([`CP-CPS.md`](pki-infra/docs/CP-CPS.md)) |
| [`livrables/`](livrables/) | Diaporama de présentation et réponses au QCM (PDF) |

## Démarrer

Le mode d'emploi complet est dans [`pki-infra/README.md`](pki-infra/README.md). Test express (bash + OpenSSL ≥ 3.0) :

```bash
cd pki-infra
bash scripts/99-demo-test.sh
```

## Sécurité

Aucune clé privée, `.p12`, CSR ni base de CA n'est versionnée (voir `pki-infra/.gitignore`).
