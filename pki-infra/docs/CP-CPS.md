# Mini CP/CPS : PKI du homelab « Homelab PKI »

*Politique de certification simplifiée (compétence BC03·C9). Version 1.0, novembre 2026.*

## 1. Identification et périmètre
| Élément | Valeur |
|---|---|
| Autorité racine | `O=Homelab PKI, CN=Homelab Root CA` (hors ligne) |
| Autorité intermédiaire | `O=Homelab PKI, CN=Homelab Intermediate CA` (en ligne, `pathlen:0`) |
| Périmètre | Services internes du homelab sous `*.home.arpa` (RFC 8375) et identités de l'administratrice (client mTLS) |
| Hors périmètre | Tout service exposé à Internet (utiliser une AC publique), e-mail S/MIME (option C) |
| Public concerné | Une seule personne, propriétaire du homelab |

## 2. Choix cryptographiques
| Objet | Algorithme | Hachage | Durée de vie |
|---|---|---|---|
| CA racine | EC P-384 | SHA-384 | 20 ans (7300 j) |
| CA intermédiaire | EC P-384 | SHA-384 | 5 ans (1825 j) |
| Certificat serveur / client | EC P-256 | SHA-256 | 180 jours (< 200 j) |
| CRL racine / intermédiaire | n/a | idem CA émettrice | 365 j / 30 j |

SHA-1 est proscrit. Justification détaillée dans `docs/rapport.md` §5.

## 3. Gestion des clés
- **Génération** : par OpenSSL (CSPRNG du système), jamais par une valeur choisie à la main.
- **Racine** : clé chiffrée (AES-256) par passphrase, générée et stockée sur une machine **déconnectée du réseau** ; la machine n'est allumée que pour une *cérémonie* (signature de l'intermédiaire, renouvellement de la CRL racine). Deux copies chiffrées de la clé sur supports distincts.
- **Intermédiaire** : clé chiffrée (AES-256) sur l'hôte PKI en ligne, `chmod 400`, propriétaire dédié, jamais copiée ailleurs ni versionnée.
- **Clés finales** : générées sur l'entité qui les utilise ; la CA ne reçoit que la CSR. Clé serveur `chmod 600`.
- **Rotation** : certificats finaux renouvelés avant 30 j d'échéance (script `06-check-expiry.sh`) ; intermédiaire renouvelée avant l'an 4 ; racine planifiée à l'an 18.
- **Sauvegarde/destruction** : les passphrases ne sont jamais écrites dans le dépôt ni dans un script ; un support remplacé est détruit.

## 4. Émission des certificats
1. Le demandeur génère sa bi-clé et une CSR.
2. L'opératrice vérifie l'identité demandée : nom DNS appartenant à `home.arpa` et au bon hôte, ou identité de l'utilisateur client.
3. Signature par l'intermédiaire avec un profil imposé (la CA ignore les extensions de la CSR) :

| Profil | `basicConstraints` | `keyUsage` | `extendedKeyUsage` | SAN |
|---|---|---|---|---|
| `server_cert` | `CA:FALSE` | `digitalSignature` | `serverAuth` | obligatoire (DNS) |
| `client_cert` | `CA:FALSE` | `digitalSignature` | `clientAuth` | non |
| `ocsp_cert` | `CA:FALSE` | `digitalSignature` | `OCSPSigning` | non |

## 5. Révocation
- **Motifs** : compromission ou perte de la clé privée, changement d'usage de la machine, départ/remplacement de l'appareil, doute sur l'intégrité de l'hôte.
- **Qui décide** : l'opératrice de la PKI (propriétaire du homelab), seule détentrice de la passphrase de l'intermédiaire.
- **Comment** : `scripts/05-revoke.sh <cert> <motif>` → mise à jour de `index.txt` (ligne `R`) → nouvelle CRL → déploiement du bundle → `nginx -s reload`.
- **Mécanismes** : CRL (obligatoire, lue par nginx) et OCSP (répondeur de démonstration, `openssl ocsp`).
- **Compromission de l'intermédiaire** : la racine révoque l'intermédiaire (CRL racine), une nouvelle intermédiaire est émise ; la racine n'a pas à être redistribuée.
- **Compromission de la racine** : reconstruction complète et redistribution de la nouvelle racine dans tous les truststores (Windows, Firefox, images Docker, `certifi`…).

## 6. Responsabilités
| Rôle | Responsabilité |
|---|---|
| Opératrice de la CA (propriétaire) | Cérémonies racine, émission, révocation, supervision des échéances, sauvegardes |
| Hôte PKI en ligne | Durcissement : accès SSH par clé, pare-feu, mises à jour, aucun autre service |
| Utilisateurs des certificats | Protéger leur clé privée, signaler toute perte |
