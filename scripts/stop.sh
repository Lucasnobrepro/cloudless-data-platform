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

if ! command -v minikube >/dev/null 2>&1; then
  printf 'Dependencia ausente: minikube\n' >&2
  exit 1
fi

printf 'O perfil Minikube "%s" sera excluido, junto com os recursos e dados armazenados nele.\n' "${MINIKUBE_PROFILE}" >&2
printf 'Outros perfis, arquivos do projeto, .env e cache de imagens Docker serao preservados.\n' >&2

if [[ "${1:-}" != "--yes" ]]; then
  printf 'Confirmar exclusao permanente? [s/N] ' >&2
  if ! IFS= read -r confirmation; then
    printf '\nCancelado; o cluster nao foi alterado.\n' >&2
    exit 1
  fi
  case "${confirmation}" in
    s|S|sim|SIM|y|Y|yes|YES) ;;
    *)
      printf 'Cancelado; o cluster nao foi alterado.\n' >&2
      exit 1
      ;;
  esac
fi

minikube delete --profile="${MINIKUBE_PROFILE}"
printf 'Perfil %s excluido.\n' "${MINIKUBE_PROFILE}"
printf 'Encerre com Ctrl+C eventuais port-forwards ou dashboards abertos em outros terminais.\n'
