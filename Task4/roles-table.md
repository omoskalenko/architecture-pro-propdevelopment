# Роли и полномочия доступа к Kubernetes (PropDevelopment)

Модель согласована с доменной структурой компании (задания 1–3): изоляция по namespace, минимальные привилегии, отдельный доступ к secrets для ИБ и DevOps.

Аутентификация: **ServiceAccount + Bearer-токен** (`kubectl create token`). Привязка RBAC — на конкретный ServiceAccount.

| Роль | Права роли | Группы пользователей (организация) |
| --- | --- | --- |
| `propdev-cluster-admin` (ClusterRole) | Полное управление кластером: все API-ресурсы и nonResourceURLs (`*` / `*`) | DevOps-инженеры продуктовых команд (`platform-devops`) |
| `secrets-reader` (ClusterRole) | `get`, `list`, `watch` для `secrets` во всех namespace; `get`, `list`, `watch` для `pods`, `events` | Специалист по ИБ (`security-ib`); DevOps (`platform-devops`) |
| `cluster-viewer` (ClusterRole) | `get`, `list`, `watch` ресурсов кластера **без secrets** | Аналитики и операционные менеджеры (`cluster-viewers`) |
| `namespace-admin` (Role, `sales`) | Управление ресурсами в namespace продаж; `secrets` — только `create`, `update`, `patch` | Разработчики домена продаж (`sales-dev`) |
| `namespace-admin` (Role, `tenant`) | То же в namespace ЖКУ и «Умный дом» | Разработчики ЖКУ (`tenant-dev`) |
| `namespace-admin` (Role, `finance`) | То же в namespace финансов | Разработчики финансов (`finance-dev`) |
| `namespace-admin` (Role, `data`) | То же в namespace данных | Инженеры данных (`data-dev`) |
| `namespace-viewer` (Role, `data`) | Просмотр ресурсов в `data` без secrets | BI-аналитики (`cluster-viewers`) |

## ServiceAccount (пользователи кластера)

| ServiceAccount | Namespace | Роли RBAC | Организационная группа |
| --- | --- | --- | --- |
| devops-admin | kube-system | `propdev-cluster-admin`, `secrets-reader` | platform-devops |
| ib-auditor | kube-system | `secrets-reader` | security-ib |
| bi-analyst | data | `cluster-viewer`, `namespace-viewer` | cluster-viewers |
| dev-sales | sales | `namespace-admin` | sales-dev |
| dev-tenant | tenant | `namespace-admin` | tenant-dev |
| dev-finance | finance | `namespace-admin` | finance-dev |
| dev-data | data | `namespace-admin` | data-dev |

## Namespaces по доменам

| Namespace | Домен | Сервисы |
| --- | --- | --- |
| sales | Продажи | client-mart-app, client-crm-app, витрина |
| tenant | ЖКУ | tenant-core-app, smart-home-service, integration-gateway |
| finance | Финансы | accountant-service-1 |
| data | Дата | DWH, CDC, BI |

## Принципы

- Три уровня доступа: **просмотр**, **настройка namespace**, **привилегированный** (secrets, cluster-admin)
- Токены хранятся локально в `tokens/` (не коммитить) или в kubeconfig-контекстах `propdev-*`
- Секреты партнёрских API и mTLS (задание 3) — только ИБ и DevOps
