# syntax=docker/dockerfile:1
# Image outil du pipeline : Ansible + module kubernetes.core + kubectl.
# Construite avec le dossier ansible/ comme contexte :
#   docker build -f ci/deployer.Dockerfile -t legeni-deployer ansible
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    KUBECONFIG=/tmp/kubeconfig \
    ANSIBLE_FORCE_COLOR=1
WORKDIR /ansible
RUN pip install --no-cache-dir ansible-core==2.22.0 kubernetes==37.0.2
COPY requirements.yml .
RUN ansible-galaxy collection install --no-cache -r requirements.yml
ADD --chmod=755 https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl /usr/local/bin/kubectl
COPY . .
