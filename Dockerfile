# syntax=docker/dockerfile:1
# ---------- Étape 1 : dépendances communes ----------
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
# requirements.txt seul d'abord : cette couche reste en cache tant que les dépendances ne changent pas
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---------- Étape 2 : qualité (docker build --target test) ----------
# Si flake8 ou un test échoue (ou couverture < 80 %), le build s'arrête : aucune image n'est produite.
FROM base AS test
COPY requirements-dev.txt .
RUN pip install --no-cache-dir -r requirements-dev.txt
COPY . .
RUN mkdir -p /reports \
 && flake8 --tee --output-file=/reports/flake8.txt . \
 && pytest -q --junitxml=/reports/junit.xml \
      --cov=app --cov-report=xml:/reports/coverage.xml --cov-report=term \
      --cov-fail-under=80

# ---------- Étape 3 : image finale de production ----------
FROM base AS runtime
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="legeni-webapp" \
      org.opencontainers.image.version="${APP_VERSION}"
ENV APP_VERSION=${APP_VERSION}
RUN useradd -l --create-home --uid 10001 appuser
COPY app.py .
USER 10001
EXPOSE 5000
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=2)"]
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
