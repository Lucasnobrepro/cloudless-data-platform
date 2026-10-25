#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
MINIKUBE_MIN_VERSION="1.39.0"
KUBECTL_MIN_VERSION="1.36.0"
HELM_MIN_VERSION="3.19.0"
ARGOCD_VERSION="v3.5.6"
ARGOCD_CHART_VERSION="10.11.1"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"
  printf 'Criei %s. Edite as senhas locais antes de executar novamente.\n' "${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${MINIKUBE_PROFILE:=cloudless-data-platform}"
: "${MINIKUBE_CPUS:=6}"
: "${MINIKUBE_MEMORY:=12288}"
: "${KUBERNETES_VERSION:=v1.37.1}"
: "${AIRFLOW_ADMIN_PASSWORD:?Defina AIRFLOW_ADMIN_PASSWORD no .env}"
: "${GRAFANA_ADMIN_PASSWORD:?Defina GRAFANA_ADMIN_PASSWORD no .env}"
: "${ARGOCD_ADMIN_PASSWORD:?Defina ARGOCD_ADMIN_PASSWORD no .env}"

for password in "${AIRFLOW_ADMIN_PASSWORD}" "${GRAFANA_ADMIN_PASSWORD}" "${ARGOCD_ADMIN_PASSWORD}"; do
  if [[ "${password}" == "change-this-local-password" ]]; then
    printf 'Troque as senhas de exemplo no .env antes de iniciar os servicos.\n' >&2
    exit 1
  fi
done

version_gte() {
  local actual="${1#v}"
  local minimum="${2#v}"
  [[ "$(printf '%s\n' "${minimum}" "${actual}" | sort -V | head -n 1)" == "${minimum}" ]]
}

require_version() {
  local tool="$1"
  local actual="$2"
  local minimum="$3"
  if ! version_gte "${actual}" "${minimum}"; then
    printf 'Versao insuficiente de %s: encontrada %s; necessaria >= %s.\n' "${tool}" "${actual}" "${minimum}" >&2
    exit 1
  fi
}

for tool in docker minikube kubectl helm curl git python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    printf 'Dependencia ausente: %s\n' "${tool}" >&2
    exit 1
  fi
done

MINIKUBE_VERSION="$(minikube version --short)"
KUBECTL_VERSION="$(kubectl version --client -o yaml | awk '/gitVersion:/ {gsub(/^v/, "", $2); print $2; exit}')"
HELM_VERSION="$(helm version --short | sed -E 's/^v//; s/\\+.*$//')"
require_version minikube "${MINIKUBE_VERSION}" "${MINIKUBE_MIN_VERSION}"
require_version kubectl "${KUBECTL_VERSION}" "${KUBECTL_MIN_VERSION}"
require_version helm "${HELM_VERSION}" "${HELM_MIN_VERSION}"

if ! docker info >/dev/null 2>&1; then
  printf 'O daemon do Docker nao esta acessivel. Inicie o Docker e tente novamente.\n' >&2
  exit 1
fi

if ! git ls-remote --exit-code https://github.com/Lucasnobrepro/cloudless-data-platform.git \
  refs/heads/main >/dev/null 2>&1; then
  printf 'O branch main do repositorio GitOps nao esta acessivel. Publique as alteracoes nele antes de iniciar.\n' >&2
  exit 1
fi

ARGOCD_BIN="$(mktemp)"
ARGOCD_CONFIG="$(mktemp)"
PORT_FORWARD_LOG="$(mktemp)"
PORT_FORWARD_PID=""

cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]]; then
    kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    wait "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi
  rm -f "${ARGOCD_BIN}" "${ARGOCD_CONFIG}" "${PORT_FORWARD_LOG}"
}
trap cleanup EXIT

case "$(uname -m)" in
  x86_64) ARGOCD_ARCH="amd64" ;;
  aarch64|arm64) ARGOCD_ARCH="arm64" ;;
  *)
    printf 'Arquitetura nao suportada para o CLI do Argo CD: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

curl --fail --silent --show-error --location \
  "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${ARGOCD_ARCH}" \
  --output "${ARGOCD_BIN}"
chmod 700 "${ARGOCD_BIN}"

printf 'Iniciando Minikube (perfil %s)...\n' "${MINIKUBE_PROFILE}"
minikube start \
  --profile="${MINIKUBE_PROFILE}" \
  --driver=docker \
  --cpus="${MINIKUBE_CPUS}" \
  --memory="${MINIKUBE_MEMORY}" \
  --kubernetes-version="${KUBERNETES_VERSION}"
kubectl config use-context "${MINIKUBE_PROFILE}"

helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl get deployment argocd-server --namespace argocd >/dev/null 2>&1; then
  if ! kubectl get secret argocd-secret --namespace argocd >/dev/null 2>&1; then
    ARGOCD_ADMIN_HASH="$("${ARGOCD_BIN}" account bcrypt --password "${ARGOCD_ADMIN_PASSWORD}")"
    ARGOCD_SERVER_KEY="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
    kubectl create secret generic argocd-secret \
      --namespace argocd \
      --from-literal="admin.password=${ARGOCD_ADMIN_HASH}" \
      --from-literal="admin.passwordMtime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --from-literal="server.secretkey=${ARGOCD_SERVER_KEY}" \
      --dry-run=client -o yaml | kubectl apply -f -
  fi

  printf 'Instalando Argo CD pelo Helm chart %s (bootstrap)...\n' "${ARGOCD_CHART_VERSION}"
  helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --version "${ARGOCD_CHART_VERSION}" \
    --values "${ROOT_DIR}/argocd/values.yaml" \
    --wait \
    --timeout 10m
else
  printf 'Argo CD ja existe; preservando a instalacao atual para a adocao pelo GitOps.\n'
fi
kubectl wait --for=condition=Available deployment --all --namespace argocd --timeout=10m

kubectl create namespace airflow --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic airflow-admin \
  --namespace airflow \
  --from-literal="password=${AIRFLOW_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic grafana-admin \
  --namespace monitoring \
  --from-literal=admin-user=admin \
  --from-literal="admin-password=${GRAFANA_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl delete application argocd-self \
  --namespace argocd \
  --ignore-not-found=true \
  --wait=true

kubectl -n argocd port-forward svc/argocd-server 18443:443 >"${PORT_FORWARD_LOG}" 2>&1 &
PORT_FORWARD_PID="$!"
for attempt in $(seq 1 30); do
  if curl --insecure --silent --fail https://127.0.0.1:18443/healthz >/dev/null; then
    break
  fi
  if [[ "${attempt}" -eq 30 ]]; then
    printf 'Argo CD nao ficou acessivel pelo port-forward. Logs do port-forward:\n' >&2
    cat "${PORT_FORWARD_LOG}" >&2
    exit 1
  fi
  sleep 1
done

"${ARGOCD_BIN}" --config "${ARGOCD_CONFIG}" login localhost:18443 \
  --username admin \
  --password "${ARGOCD_ADMIN_PASSWORD}" \
  --insecure \
  --grpc-web

kubectl apply -f "${ROOT_DIR}/argocd/root-app.yaml"
"${ARGOCD_BIN}" --config "${ARGOCD_CONFIG}" app wait platform-root \
  --sync \
  --timeout 900 \
  --grpc-web
"${ARGOCD_BIN}" --config "${ARGOCD_CONFIG}" app wait argocd \
  --sync \
  --health \
  --timeout 1800 \
  --grpc-web
"${ARGOCD_BIN}" --config "${ARGOCD_CONFIG}" app wait airflow \
  --sync \
  --health \
  --timeout 1800 \
  --grpc-web
"${ARGOCD_BIN}" --config "${ARGOCD_CONFIG}" app wait monitoring \
  --sync \
  --health \
  --timeout 1800 \
  --grpc-web

printf '\nGitOps instalado. Argo CD gerencia a si proprio, Airflow e monitoramento.\n'
printf 'Acesse os servicos usando port-forward:\n'
printf '  kubectl -n airflow port-forward svc/airflow-api-server 8080:8080\n'
printf '  kubectl -n argocd port-forward svc/argocd-server 8443:443\n'
printf '  kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80\n'
printf '  kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090\n'
printf '\nAirflow e Grafana: usuario admin e senha do .env. Argo CD: admin e ARGOCD_ADMIN_PASSWORD.\n'
printf 'Para excluir o cluster e os dados, execute: ./scripts/stop.sh\n'
