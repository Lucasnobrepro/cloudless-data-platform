#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi
: "${MINIKUBE_PROFILE:=cloudless-data-platform}"

for tool in minikube kubectl; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    printf 'Dependencia ausente: %s\n' "${tool}" >&2
    exit 1
  fi
done

pids=()
cleanup() {
  local pid
  trap - EXIT INT TERM
  for pid in "${pids[@]}"; do
    kill "${pid}" 2>/dev/null || true
  done
  for pid in "${pids[@]}"; do
    wait "${pid}" 2>/dev/null || true
  done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Iniciando acessos no perfil %s. Use Ctrl+C para encerrar todos.\n' "${MINIKUBE_PROFILE}"
minikube dashboard --profile "${MINIKUBE_PROFILE}" --url &
pids+=("$!")

kubectl --context "${MINIKUBE_PROFILE}" -n airflow port-forward svc/airflow-api-server 8080:8080 &
pids+=("$!")
kubectl --context "${MINIKUBE_PROFILE}" -n argocd port-forward svc/argocd-server 8443:443 &
pids+=("$!")
kubectl --context "${MINIKUBE_PROFILE}" -n monitoring port-forward svc/monitoring-grafana 3000:80 &
pids+=("$!")
kubectl --context "${MINIKUBE_PROFILE}" -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 &
pids+=("$!")

printf 'Aguarde as mensagens de encaminhamento; o dashboard imprimira sua URL.\n'
printf 'Airflow: http://localhost:8080 | Argo CD: https://localhost:8443\n'
printf 'Grafana: http://localhost:3000 | Prometheus: http://localhost:9090\n'

if wait -n "${pids[@]}"; then
  printf 'Um dos acessos terminou; encerrando os demais.\n' >&2
else
  printf 'Um dos acessos falhou; verifique as mensagens acima. Encerrando os demais.\n' >&2
fi
exit 1
