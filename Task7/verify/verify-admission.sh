#!/usr/bin/env bash
# Проверка: небезопасные Pod отклоняются, безопасные — принимаются.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -S "${HOME}/.colima/default/docker.sock" ]]; then
  export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
fi

expect_deny() {
  local file="$1"
  local name
  name="$(basename "${file}")"
  echo -n "  DENY ${name} ... "
  if kubectl apply -f "${file}" --dry-run=server -o name &>/dev/null; then
    if kubectl apply -f "${file}" -o name &>/dev/null; then
      echo "FAIL (под создан, ожидался отказ)"
      kubectl delete -f "${file}" --ignore-not-found --wait=false &>/dev/null || true
      return 1
    fi
  fi
  echo "OK"
}

expect_allow() {
  local file="$1"
  local name
  name="$(basename "${file}")"
  echo -n "  ALLOW ${name} ... "
  if ! kubectl apply -f "${file}" -o name &>/dev/null; then
    echo "FAIL (ожидалось создание)"
    return 1
  fi
  echo "OK"
  kubectl delete -f "${file}" --ignore-not-found --wait=false &>/dev/null || true
}

echo ">>> PodSecurity + Gatekeeper: небезопасные манифесты"
FAIL=0
for f in "${SCRIPT_DIR}"/insecure-manifests/*.yaml; do
  expect_deny "${f}" || FAIL=1
done

echo ""
echo ">>> Безопасные манифесты"
for f in "${SCRIPT_DIR}"/secure-manifests/*.yaml; do
  expect_allow "${f}" || FAIL=1
done

echo ""
if [[ "${FAIL}" -eq 0 ]]; then
  echo "Все проверки admission пройдены."
else
  echo "Есть ошибки. Убедитесь, что выполнен: ./verify/validate-security.sh"
  exit 1
fi
