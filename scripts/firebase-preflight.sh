#!/usr/bin/env bash
# Inspeção somente leitura. Não habilita APIs, altera IAM ou faz deploy.
set -euo pipefail
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
LEVITICUS_PROJECT_ID="${1:-}"
if [[ ! "$LEVITICUS_PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
  printf '%s\n' 'Uso: bash scripts/firebase-preflight.sh ID_DO_PROJETO' >&2
  exit 2
fi
command -v gcloud >/dev/null || { printf '%s\n' 'Execute no Google Cloud Shell, que já possui gcloud.' >&2; exit 2; }
printf '\nProjeto selecionado (somente leitura)\n'
gcloud projects describe "$LEVITICUS_PROJECT_ID" --format='table(projectId,projectNumber,name,lifecycleState)'
LEVITICUS_PROJECT_NUMBER="$(gcloud projects describe "$LEVITICUS_PROJECT_ID" --format='value(projectNumber)')"
printf '\nFaturamento\n'
gcloud billing projects describe "$LEVITICUS_PROJECT_ID" --format='value(billingEnabled)' || printf '%s\n' 'Não foi possível consultar faturamento; conferir na console.'
printf '\nAPIs habilitadas relevantes\n'
gcloud services list --enabled --project="$LEVITICUS_PROJECT_ID" --filter='config.name:(firebase.googleapis.com firestore.googleapis.com identitytoolkit.googleapis.com cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com firebasehosting.googleapis.com firebaserules.googleapis.com iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com)' --format='table(config.name)'
printf '\nBancos Firestore (não consulta documentos)\n'
gcloud firestore databases list --project="$LEVITICUS_PROJECT_ID" --format='table(name,locationId,type)' || printf '%s\n' 'Conferir existência/região do banco na console; a API ou permissão pode faltar.'
printf '\nContas de serviço (não consulta chaves)\n'
gcloud iam service-accounts list --project="$LEVITICUS_PROJECT_ID" --format='table(email,displayName,disabled)'
printf '\nProvider de deploy, se já existir\n'
gcloud iam workload-identity-pools providers describe github --location=global --workload-identity-pool=github-leviticus --project="$LEVITICUS_PROJECT_ID" --format='yaml(name,state,attributeCondition)' || printf '%s\n' 'Provider não encontrado ou sem permissão de leitura; nenhuma criação foi feita.'
printf '\nPróximo passo\n'
printf '%s\n' 'Conferir dados/apps em uso na console e seguir docs/PRIMEIRO-DEPLOY.md.'
printf 'Número público do projeto: %s\n' "$LEVITICUS_PROJECT_NUMBER"
printf '%s\n' 'Esta inspeção não prova ausência de dados nem readiness de deploy.'
