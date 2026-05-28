#!/usr/bin/env bash
# Привязка ServiceAccount (пользователей) к ролям Kubernetes.

set -euo pipefail

if ! kubectl cluster-info &>/dev/null; then
  echo "Ошибка: kubectl не подключается к кластеру. Проверьте контекст."
  exit 1
fi

echo ">>> devops-admin → propdev-cluster-admin"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-devops-admin
subjects:
  - kind: ServiceAccount
    name: devops-admin
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: propdev-cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo ">>> devops-admin → secrets-reader"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-devops-secrets
subjects:
  - kind: ServiceAccount
    name: devops-admin
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: secrets-reader
  apiGroup: rbac.authorization.k8s.io
EOF

echo ">>> ib-auditor → secrets-reader"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-ib-secrets
subjects:
  - kind: ServiceAccount
    name: ib-auditor
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: secrets-reader
  apiGroup: rbac.authorization.k8s.io
EOF

echo ">>> bi-analyst → cluster-viewer"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-bi-cluster-viewer
subjects:
  - kind: ServiceAccount
    name: bi-analyst
    namespace: data
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

echo ">>> bi-analyst → namespace-viewer (data)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdev-bi-data-viewer
  namespace: data
subjects:
  - kind: ServiceAccount
    name: bi-analyst
    namespace: data
roleRef:
  kind: Role
  name: namespace-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

echo ">>> dev-sales → namespace-admin (sales)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdev-dev-sales-admin
  namespace: sales
subjects:
  - kind: ServiceAccount
    name: dev-sales
    namespace: sales
roleRef:
  kind: Role
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo ">>> dev-tenant → namespace-admin (tenant)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdev-dev-tenant-admin
  namespace: tenant
subjects:
  - kind: ServiceAccount
    name: dev-tenant
    namespace: tenant
roleRef:
  kind: Role
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo ">>> dev-finance → namespace-admin (finance)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdev-dev-finance-admin
  namespace: finance
subjects:
  - kind: ServiceAccount
    name: dev-finance
    namespace: finance
roleRef:
  kind: Role
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo ">>> dev-data → namespace-admin (data)"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdev-dev-data-admin
  namespace: data
subjects:
  - kind: ServiceAccount
    name: dev-data
    namespace: data
roleRef:
  kind: Role
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
EOF
