# Отчёт по результатам анализа Kubernetes Audit Log

## Ключевые события симуляции (из audit-extract.json)

| Время (UTC) | Действие | Субъект | Код | Комментарий |
|-------------|----------|---------|-----|-------------|
| 07:47:39 | `SelfSubjectAccessReview` (secrets) | `minikube-user` → **impersonation** `monitoring` | 201 | Разведка прав перед атакой |
| 07:47:39 | `get secret` `bootstrap-token-6bjvo5` в `kube-system` | impersonation `monitoring` | **403** | RBAC заблокировал, попытка зафиксирована |
| 07:47:39 | `create pod` `privileged-pod` | `minikube-user` | 201 | `securityContext.privileged: true`, PSS: `privileged:latest` |
| 07:47:39 | `exec` в `coredns` | `minikube-user` | 101 | Lateral movement в системный pod (`/coredns -version`) |
| 07:47:40 | `delete configmap/audit-policy` | impersonation `admin` | **403** | Anti-forensics — отклонено |
| 07:47:40 | `create RoleBinding` `escalate-binding` | `minikube-user` | 201 | `monitoring` → `cluster-admin` |

---

## Подозрительные события

### 1. Доступ к секретам

- **Кто:** `system:serviceaccount:secure-ops:monitoring` через **impersonation** (`kubectl --as=...`); в логе — `impersonatedUser.username`.
- **Где:** namespace `kube-system`, secret `bootstrap-token-6bjvo5`.
- **Результат:** **403 Forbidden** — RBAC сработал, но попытка видна в audit.

### 2. Привилегированные поды

- **Кто:** `minikube-user` (аналог cluster-admin с kubeconfig).
- **Где:** namespace `secure-ops`, pod `privileged-pod`.
- **Комментарий:** `securityContext.privileged: true`, в annotations — `pod-security.kubernetes.io/enforce-policy: privileged:latest`. Обход контейнерной изоляции; для PropDevelopment критично на нодах с client-mart-app и DWH.

### 3. Использование kubectl exec в чужом поде

- **Кто:** `minikube-user`.
- **Что делал:** `kubectl exec` в pod `coredns-55cb58b774-t7mt7` (namespace `kube-system`) — в audit: `GET .../exec?command=/coredns&command=-version`, код **101** (upgrade to SPDY/WebSocket).
- **Почему подозрительно:** exec в инфраструктурные pod'ы вне своего namespace — типичный шаг после первичной компрометации. RBAC не ограничил exec для «обычного» пользователя.

### 4. Создание RoleBinding с правами cluster-admin

- **Кто:** `minikube-user` (создание `escalate-binding`).
- **Результат:** **201 Created** — ServiceAccount `monitoring` в `secure-ops` получил `ClusterRole/cluster-admin`.
- **Связь с кейсом:** нарушение принципа минимальных привилегий (чеклист задания 2, п. I.4) — назначение прав без согласования ИБ.

### 5. Удаление audit-policy.yaml

- **Кто:** `minikube-user` с `--as=admin` (impersonation).
- **Результат:** **403** на `delete configmap/audit-policy` — попытка anti-forensics зафиксирована, доступ запрещён.

### 6. Прочие события симуляции

| Действие | Риск |
|----------|------|
| Создание ns `secure-ops`, SA `monitoring`, pod `attacker-pod` | Подготовка плацдарма |
| `kubectl run attacker-pod` | База для дальнейшего exec / pivot |

---

## Что можно считать компрометацией кластера

1. **Подтверждённая:** RoleBinding `monitoring` → `cluster-admin` — персистентный backdoor.
2. **Смягчённый риск:** чтение Secret в `kube-system` от SA `monitoring` — **заблокировано (403)**, но попытка есть в логе.
3. **Высокий риск:** `privileged-pod` — потенциальный escape на ноду.
4. **Средний риск:** exec в `coredns` — разведка; при наличии cluster-admin — шаг к полному контролю.
5. **Индикатор атаки:** попытка удалить/отключить audit-policy — сокрытие следов.

---

## Ошибки и пробелы RBAC (релевантно PropDevelopment)

| Проблема | Проявление в симуляции |
|----------|-------------------------|
| Нет deny по умолчанию для SA | `monitoring` прошёл SSAR; `get secret` в `kube-system` — **403**, но разведка разрешена |
| Нет ограничения на `escalate` / `bind` ClusterRole admin | Создан `escalate-binding` без approval |
| Cluster-admin у человека с kubeconfig | Все шаги симуляции от имени админа — нет разделения обязанностей |
| Нет Policy / PSS | `privileged-pod` создан |
| Нет алерта на audit tampering | Попытка delete audit-policy только в логе |
| Нет MFA / break-glass для критичных verb | exec, secrets get без доп. фактора |

Рекомендации для PropDevelopment: RBAC как в Task4 (`secrets-reader` только ИБ/DevOps), запрет `privileged` через Pod Security, отдельный break-glass с журналированием, экспорт audit в SIEM, регулярный пересмотр RoleBinding (чеклист 2, п. I.3).

---

## Вывод

Симуляция воспроизводила цепочку реальной атаки: разведка прав → доступ к secrets → привилегированный workload → exec в системный pod → закрепление через `cluster-admin` RoleBinding → попытка отключить аудит.

Текущая модель RBAC в учебном кластере (широкий admin + отсутствие ограничений на SA) **не соответствует** требованиям аудита PropDevelopment. Audit log позволяет установить **кто, когда и что** сделал; для продакшена нужны политика аудита (как `audit-policy.yaml`), хранение логов вне кластера и автоматические алерты на события из `audit-extract.json`.

Повторный анализ после прогона на своём Minikube:

```bash
./setup-minikube-audit.sh      # кластер с audit
./simulate-incident.sh
./export-audit.sh audit.log
./filter-audit.sh audit.log audit-extract.json
```
