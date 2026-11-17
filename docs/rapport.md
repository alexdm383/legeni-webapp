# Rapport – Chaîne CI/CD Legeni WebApp

**Auteure :** Alexandra OLEMBE BOYOMO – Keyce Informatique – travail réalisé seule

## 1. Architecture
_Schéma (reprendre celui de l'énoncé) + description de l'infrastructure :_
Windows + Docker Desktop ; Jenkins en conteneur ; Minikube (driver docker) ; Docker Hub `alexdm38/legeni-webapp`.

## 2. Choix techniques justifiés
| Choix | Justification |
|---|---|
| Dockerfile multi-stage `test` / `runtime` | les tests tournent pendant le build : un test rouge = aucune image produite |
| Utilisateur non-root (UID 10001), HEALTHCHECK, CMD en forme exec | sécurité, supervision, arrêt propre (SIGTERM reçu par gunicorn) |
| Tag `<VERSION>-<build>` | traçabilité : on sait quel build tourne en prod ; jamais `latest` |
| Conteneur "deployer" (Ansible + kubectl) | Ansible ne fonctionne pas sous Windows ; outils versionnés dans le dépôt |
| `maxUnavailable: 0` + readinessProbe `/ready` | un ancien pod n'est retiré que lorsque le nouveau est prêt : zéro coupure |
| `block`/`rescue` Ansible | rollback automatique si rollout ou smoke test échoue |
| Ansible Vault + Secret Kubernetes | aucun mot de passe en clair dans le dépôt |

## 3. Le pipeline, stage par stage
_Capture Stage View + explication de chaque stage._

## 4. Démonstrations
1. Livraison nominale (1.0.0 → 1.1.0) – captures PR, staging, validation, prod, boucle curl sans erreur
2. Code défectueux – pipeline rouge à l'étape tests, aucune image
3. Déploiement raté – rollback automatique visible dans Jenkins
4. `kubectl get all -n legeni-prod`

## 5. Difficultés rencontrées et solutions
- Nom Docker Hub (`alexdm38`) différent du nom GitHub (`alexdm383`) : échec d'authentification au push.
- Port 80 occupé par WAMP : le test HTTP 200 testait Apache ; la vérification du contenu l'a détecté.
- Ansible indisponible sous Windows : exécution dans un conteneur sur le réseau Docker `minikube`.
- Cache Ansible Galaxy corrompu : `--no-cache`.

## 6. Limites et pistes d'amélioration
- Webhook GitHub : Jenkins tourne en local, non joignable depuis Internet → scan périodique du dépôt (une solution serait un tunnel ngrok).
- `provision.yml` écrit pour Ubuntu 24.04 : _préciser s'il a été testé (WSL2/VM) ou non._
- Bonus non réalisés : Ingress/TLS, HPA, Prometheus/Grafana, Argo CD.
