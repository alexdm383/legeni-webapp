# Legeni WebApp – chaîne CI/CD

Projet final DevOps (Keyce) – Alexandra OLEMBE.

| Dossier / fichier | Rôle |
|---|---|
| `app.py`, `tests/` | application Flask + Redis et ses tests |
| `Dockerfile` | multi-stage : `test` (flake8 + pytest + couverture ≥ 80 %) puis `runtime` (non-root, healthcheck) |
| `VERSION` | version sémantique ; tag d'image = `<VERSION>-<n° de build>` |
| `Jenkinsfile` | pipeline Multibranch : qualité en parallèle → build → Trivy → push → staging → validation → prod |
| `ci/` | image outil Ansible + kubectl, script de déploiement |
| `ansible/provision.yml` | installe Docker, Jenkins, Minikube |
| `ansible/deploy.yml` | déploie dans `legeni-staging` / `legeni-prod`, smoke test, rollback automatique |
| `docs/rapport.md` | rapport final |
