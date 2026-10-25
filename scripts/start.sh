#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
MINIKUBE_MIN_VERSION="1.39.0"
KUBECTL_MIN_VERSION="1.36.0"
HELM_MIN_VERSION="3.19.0"
ARGOCD_VERSION="v3.5.6"
AIRFLOW_CHART_VERSION="1.22.0"
PROMETHEUS_CHART_VERSION="92.13.1"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"
  printf 'Criei %s. Edite as senhas e confirme o branch remoto antes de executar novamente.\n' "${ENV_FILE}" >&2
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
: "${AIRFLOW_DAGS_REPO_URL:?Defina AIRFLOW_DAGS_REPO_URL no .env}"
: "${AIRFLOW_GIT_BRANCH:=$(git -C "${ROOT_DIR}" branch --show-current)}"

if [[ "${AIRFLOW_ADMIN_PASSWORD}" == "change-this-local-password" ||
      "${GRAFANA_ADMIN_PASSWORD}" == "change-this-local-password" ||
      "${ARGOCD_ADMIN_PASSWORD}" == "change-this-local-password" ]]; then
  printf 'Troque as senhas de exemplo no .env antes de iniciar os servicos.\n' >&2
  exit 1
fi

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

if ! git -C "${ROOT_DIR}" ls-remote --exit-code "${AIRFLOW_DAGS_REPO_URL}" "refs/heads/${AIRFLOW_GIT_BRANCH}" >/dev/null 2>&1; then
  printf 'O branch %s nao foi encontrado no remoto %s. Publique-o ou ajuste AIRFLOW_GIT_BRANCH no .env.\n' \
    "${AIRFLOW_GIT_BRANCH}" "${AIRFLOW_DAGS_REPO_URL}" >&2
  exit 1
fi

AIRFLOW_OVERRIDE="$(mktemp)"
MONITORING_OVERRIDE="$(mktemp)"
ARGOCD_BIN="$(mktemp)"
ARGOCD_CONFIG="$(mktemp)"
PORT_FORWARD_LOG="$(mktemp)"
PORT_FORWARD_PID=""

cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]]; then
    kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    wait "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi
  rm -f "${AIRFLOW_OVERRIDE}" "${MONITORING_OVERRIDE}" "${ARGOCD_BIN}" "${ARGOCD_CONFIG}" "${PORT_FORWARD_LOG}"
}
trap cleanup EXIT

yaml_quote() {
  python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"
}

cat >"${AIRFLOW_OVERRIDE}" <<EOF
createUserJob:
  defaultUser:
    username: admin
    password: $(yaml_quote "${AIRFLOW_ADMIN_PASSWORD}")
dags:
  gitSync:
    repo: $(yaml_quote "${AIRFLOW_DAGS_REPO_URL}")
    branch: $(yaml_quote "${AIRFLOW_GIT_BRANCH}")
    ref: $(yaml_quote "${AIRFLOW_GIT_BRANCH}")
    rev: HEAD
EOF

cat >"${MONITORING_OVERRIDE}" <<EOF
grafana:
  adminUser: admin
  adminPassword: $(yaml_quote "${GRAFANA_ADMIN_PASSWORD}")
EOF

printf 'Iniciando Minikube (perfil %s)...\n' "${MINIKUBE_PROFILE}"
minikube start \
  --profile="${MINIKUBE_PROFILE}" \
  --driver=docker \
  --cpus="${MINIKUBE_CPUS}" \
  --memory="${MINIKUBE_MEMORY}" \
  --kubernetes-version="${KUBERNETES_VERSION}"
kubectl config use-context "${MINIKUBE_PROFILE}"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=10m

helm repo add apache-airflow https://airflow.apache.org --force-update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update

printf 'Instalando Airflow %s...\n' "${AIRFLOW_CHART_VERSION}"
helm upgrade --install airflow apache-airflow/airflow \
  --namespace airflow \
  --create-namespace \
  --version "${AIRFLOW_CHART_VERSION}" \
  --values "${ROOT_DIR}/airflow/values.yaml" \
  --values "${AIRFLOW_OVERRIDE}" \
  --wait \
  --timeout 20m

printf 'Instalando kube-prometheus-stack %s...\n' "${PROMETHEUS_CHART_VERSION}"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --version "${PROMETHEUS_CHART_VERSION}" \
  --values "${ROOT_DIR}/monitoring/values.yaml" \
  --values "${MONITORING_OVERRIDE}" \
  --wait \
  --timeout 20m

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

if ! "${ARGOCD_BIN}" --config "${ARGOCD_CONFIG}" login localhost:18443 \
  --username admin \
  --password "${ARGOCD_ADMIN_PASSWORD}" \
  --insecure \
  --grpc-web >/dev/null 2>&1; then
  INITIAL_ARGOCD_PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode)"
  "${ARGOCD_BIN}" --config "${ARGOCD_CONFIG}" login localhost:18443 \
    --username admin \
    --password "${INITIAL_ARGOCD_PASSWORD}" \
    --insecure \
    --grpc-web
  "${ARGOCD_BIN}" --config "${ARGOCD_CONFIG}" account update-password \
    --current-password "${INITIAL_ARGOCD_PASSWORD}" \
    --new-password "${ARGOCD_ADMIN_PASSWORD}" \
    --server localhost:18443 \
    --insecure \
    --grpc-web
fi

printf '\nFase 1 instalada. Acesse os servicos usando port-forward:\n'
printf '  kubectl -n airflow port-forward svc/airflow-api-server 8080:8080\n'
printf '  kubectl -n argocd port-forward svc/argocd-server 8443:443\n'
printf '  kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80\n'
printf '  kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090\n'
printf '\nAirflow e Grafana: usuario admin e a senha local do .env. Argo CD: admin e ARGOCD_ADMIN_PASSWORD.\n'
printf 'Para excluir o cluster e os dados, execute: ./scripts/stop.sh\n'
