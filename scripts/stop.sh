#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
MINIKUBE_PROFILE="cloudless-data-platform"

if [[ "$#" -gt 1 || ( "$#" -eq 1 && "${1}" != "--yes" ) ]]; then
  printf 'Uso: %s [--yes]\n' "$0" >&2
  exit 2
fi

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
  : "${MINIKUBE_PROFILE:=cloudless-data-platform}"
fi

if [[ "${1:-}" != "--yes" ]]; then
  printf 'Isto vai excluir o perfil Minikube "%s" e todos os dados dentro dele.\n' "${MINIKUBE_PROFILE}" >&2
  read -r -p 'Digite DELETE cloudless-data-platform para continuar: ' confirmation
  if [[ "${confirmation}" != "DELETE cloudless-data-platform" ]]; then
    printf 'Cancelado; o cluster nao foi alterado.\n'
    exit 1
  fi
fi

if ! command -v minikube >/dev/null 2>&1; then
  printf 'Dependencia ausente: minikube\n' >&2
  exit 1
fi

minikube delete --profile="${MINIKUBE_PROFILE}"
printf 'Perfil %s excluido.\n' "${MINIKUBE_PROFILE}"
