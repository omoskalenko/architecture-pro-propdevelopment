# Task 7 — Pod Security + OPA Gatekeeper

Аудит и блокировка небезопасных Pod в namespace `audit-zone`.

## Структура

| Путь | Назначение |
|------|------------|
| `01-create-namespace.yaml` | Namespace с `pod-security.kubernetes.io/enforce: restricted` |
| `insecure-manifests/` | 3 Pod с нарушениями (privileged, hostPath, root UID) |
| `secure-manifests/` | Исправленные манифесты |
| `gatekeeper/` | ConstraintTemplate + Constraint для audit-zone |
| `verify/` | Скрипты проверки |
| `audit-policy.yaml` | Политика audit для pods в audit-zone и Gatekeeper CR |

## Быстрый старт (Minikube)

```bash
export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"   # если Colima (у меня она)

minikube start --kubernetes-version=v1.30.5 --cpus=2 --memory=4096

cd Task7
chmod +x verify/*.sh
./verify/validate-security.sh    # Gatekeeper + namespace + constraints
./verify/verify-admission.sh     # DENY insecure / ALLOW secure
```

## Что проверяется

**Pod Security Admission (restricted)** на namespace `audit-zone`:
- запрет privileged, hostPath, root и др.

**OPA Gatekeeper** (только `audit-zone`):
| Constraint | Правило |
|------------|---------|
| `deny-privileged-audit-zone` | `privileged: true` запрещён |
| `deny-hostpath-audit-zone` | `hostPath` volumes запрещены |
| `require-runasnonroot-audit-zone` | `runAsNonRoot: true` и `readOnlyRootFilesystem: true` |

## Ожидаемый результат verify-admission.sh

```
DENY 01-privileged-pod.yaml ... OK
DENY 02-hostpath-pod.yaml ... OK
DENY 03-root-user-pod.yaml ... OK
ALLOW 01-secure.yaml ... OK
ALLOW 02-secure.yaml ... OK
ALLOW 03-secure.yaml ... OK
```

## Audit (опционально)

Политика `audit-policy.yaml` логирует create/update/delete Pod в `audit-zone` и изменения Gatekeeper CR.  
Подключение — как в Task6 (`~/.minikube/files/` + `--extra-config=apiserver.audit-policy-file=...`).
