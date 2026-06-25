#!/usr/bin/env bash
# Создание namespaces и RBAC-ролей для PropDevelopment.

set -euo pipefail

if ! kubectl cluster-info &>/dev/null; then
  echo "Ошибка: kubectl не подключается к кластеру. Проверьте контекст."
  exit 1
fi

echo ">>> Создание namespaces по доменам"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: sales
  labels:
    domain: sales
---
apiVersion: v1
kind: Namespace
metadata:
  name: tenant
  labels:
    domain: tenant
---
apiVersion: v1
kind: Namespace
metadata:
  name: finance
  labels:
    domain: finance
---
apiVersion: v1
kind: Namespace
metadata:
  name: data
  labels:
    domain: data
EOF

echo ">>> ClusterRole: cluster-viewer (просмотр без secrets)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "namespaces", "nodes", "events", "persistentvolumeclaims", "persistentvolumes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch"]
EOF

echo ">>> ClusterRole: secrets-reader (привилегированный доступ к secrets)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secrets-reader
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods", "events"]
    verbs: ["get", "list", "watch"]
EOF

echo ">>> ClusterRole: cluster-admin (управление кластером)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-cluster-admin
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
EOF

echo ">>> Role: namespace-admin (управление ресурсами в namespace)"
for ns in sales tenant finance data; do
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-admin
  namespace: ${ns}
rules:
  - apiGroups: ["", "apps", "batch", "networking.k8s.io", "autoscaling"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "update", "patch"]
EOF
  echo "    Role namespace-admin создан в ${ns}"
done

echo ">>> Role: namespace-viewer (только просмотр в namespace)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-viewer
  namespace: data
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "events", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
EOF