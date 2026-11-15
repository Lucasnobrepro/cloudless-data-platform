#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CHART="${1:-apache-airflow/airflow}"

check_job() {
  local template="$1"
  local phase="$2"
  local rendered
  rendered="$(helm template airflow "${CHART}" --version 1.22.0 \
    --namespace airflow -f "${ROOT_DIR}/airflow/values.yaml" \
    --show-only "templates/jobs/${template}")"
  if ! grep -Fq "argocd.argoproj.io/hook: ${phase}" <<< "${rendered}" ||
    ! grep -Fq 'argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded' <<< "${rendered}" ||
    grep -Fq 'helm.sh/hook:' <<< "${rendered}"; then
    printf 'Hooks incorretos no job %s.\n' "${template}" >&2
    exit 1
  fi
}

check_job migrate-database-job.yaml Sync
check_job create-user-job.yaml PostSync

kubectl create --dry-run=client -f "${ROOT_DIR}/argocd/apps/airflow.yaml" -o json |
  python3 -c '
import json
import sys

spec = json.load(sys.stdin)["spec"]
assert "RespectIgnoreDifferences=true" in spec["syncPolicy"]["syncOptions"]
assert any(
    rule.get("group") == ""
    and rule.get("kind") == "Secret"
    and rule.get("name") == "airflow-fernet-key"
    and rule.get("namespace") == "airflow"
    and "/data" in rule.get("jsonPointers", [])
    for rule in spec["ignoreDifferences"]
)
'
printf 'Testes dos jobs e da chave Fernet passaram.\n'
