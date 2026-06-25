#!/usr/bin/env bash
# Создание пользователей Kubernetes (ServiceAccount) и Bearer-токенов.

# Переменные (опционально):
#   TOKEN_DURATION — срок токена (по умолчанию 8760h = ~1 год)
#   K8S_CLUSTER_NAME — имя cluster в kubeconfig
#
# Формат USERS: serviceaccount-name:namespace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKENS_DIR="${SCRIPT_DIR}/tokens"
CONTEXT_PREFIX="propdev"
TOKEN_DURATION="${TOKEN_DURATION:-8760h}"

if ! kubectl cluster-info &>/dev/null; then
  echo "Ошибка: kubectl не подключается к кластеру. Проверьте контекст."
  exit 1
fi

CLUSTER_NAME="${K8S_CLUSTER_NAME:-$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')}"

USERS=(
  "devops-admin:kube-system"
  "ib-auditor:kube-system"
  "bi-analyst:data"
  "dev-sales:sales"
  "dev-tenant:tenant"
  "dev-finance:finance"
  "dev-data:data"
)

mkdir -p "${TOKENS_DIR}"

echo "Кластер: ${CLUSTER_NAME}"
echo "Токены сохраняются в: ${TOKENS_DIR}/"
echo ""

for entry in "${USERS[@]}"; do
  IFS=':' read -r username namespace <<< "${entry}"

  echo ">>> ServiceAccount: ${username} (namespace: ${namespace})"

  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${username}
  namespace: ${namespace}
  labels:
    app.kubernetes.io/part-of: propdevelopment
    propdev.access/role: user
EOF

  token="$(kubectl create token "${username}" -n "${namespace}" --duration="${TOKEN_DURATION}")"
  printf '%s' "${token}" > "${TOKENS_DIR}/${username}.token"
  chmod 600 "${TOKENS_DIR}/${username}.token"

  kubectl config set-credentials "${username}" --token="${token}"

  context_name="${CONTEXT_PREFIX}-${username}"
  default_ns="${namespace}"
  if [[ "${namespace}" == "kube-system" ]]; then
    default_ns=""
  fi

  if [[ -n "${default_ns}" && "${default_ns}" != "kube-system" ]]; then
    kubectl config set-context "${context_name}" \
      --cluster="${CLUSTER_NAME}" \
      --user="${username}" \
      --namespace="${default_ns}"
  else
    kubectl config set-context "${context_name}" \
      --cluster="${CLUSTER_NAME}" \
      --user="${username}"
  fi

  echo "    Контекст: ${context_name}"
  echo "    Токен:    ${TOKENS_DIR}/${username}.token"
done
