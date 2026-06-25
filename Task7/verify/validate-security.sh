#!/usr/bin/env bash
# Установка Gatekeeper, namespace audit-zone и применение constraint templates/constraints.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-v3.15.1}"

if [[ -S "${HOME}/.colima/default/docker.sock" ]]; then
  export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
fi

echo ">>> Gatekeeper ${GATEKEEPER_VERSION}"
if ! kubectl get ns gatekeeper-system &>/dev/null; then
  kubectl apply -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml"
fi

echo ">>> Ожидание Gatekeeper"
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=180s
kubectl wait --for=condition=Ready pod -l gatekeeper.sh/operation=webhook -n gatekeeper-system --timeout=180s

echo ">>> Namespace audit-zone (Pod Security restricted)"
kubectl apply -f "${SCRIPT_DIR}/01-create-namespace.yaml"

echo ">>> ConstraintTemplates"
kubectl apply -f "${SCRIPT_DIR}/gatekeeper/constraint-templates/"

echo ">>> Ожидание CRD ConstraintTemplates"
for _ in $(seq 1 30); do
  READY="$(kubectl get constrainttemplate -o json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
items=d.get('items',[])
print('ok' if items and all(ct.get('status',{}).get('created',False) for ct in items) else 'wait')
" 2>/dev/null || echo wait)"
  [[ "${READY}" == "ok" ]] && break
  sleep 2
done

echo ">>> Constraints"
kubectl apply -f "${SCRIPT_DIR}/gatekeeper/constraints/"

sleep 5
kubectl get constrainttemplate,constraints -A 2>/dev/null || kubectl get constrainttemplate,constraints

echo ""
echo "Окружение готово. Запустите: ./verify/verify-admission.sh"
