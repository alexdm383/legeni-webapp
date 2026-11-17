#!/bin/bash
# Lance deploy.yml dans le conteneur "deployer", branché sur le réseau Docker de Minikube.
# Usage (depuis Jenkins) : ci/run-deploy.sh <staging|prod> <tag_image>
# Variables attendues (fournies par les credentials Jenkins) : KCFG (fichier), VAULT_PASS (texte)
set -euo pipefail
TARGET=${1:?usage: $0 <staging|prod> <tag>}
TAG=${2:?usage: $0 <staging|prod> <tag>}
: "${KCFG:?credential kubeconfig manquant}"
: "${VAULT_PASS:?credential ansible-vault-pass manquant}"
DEPLOYER="legeni-deployer:ci-${BUILD_NUMBER:-local}"

# On crée le conteneur sans le démarrer, on y copie les secrets, puis on le lance.
# (docker cp passe par l'API Docker : pas de montage de dossier, donc pas de chemin hôte à connaître.)
cid=$(docker create --network minikube "$DEPLOYER" \
      ansible-playbook deploy.yml -e target_env="$TARGET" -e image_tag="$TAG" \
      --vault-password-file /tmp/vault-pass)
cleanup() { docker rm -f "$cid" >/dev/null 2>&1 || true; rm -f .vault-pass; }
trap cleanup EXIT

docker cp "$KCFG" "$cid:/tmp/kubeconfig"
( umask 077; printf '%s' "$VAULT_PASS" > .vault-pass )
docker cp .vault-pass "$cid:/tmp/vault-pass"
rm -f .vault-pass

docker start -a "$cid"
