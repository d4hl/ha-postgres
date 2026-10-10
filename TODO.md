# TODO — ha-postgres

Стек: etcd + Patroni/PostgreSQL + HAProxy/Keepalived, CentOS Stream 10, TLS из HashiCorp Vault PKI.

---

## P4 — Бэкапы и DR

### P4.1 — etcd

- [ ] снапшоты etcd (`etcdctl snapshot save`) по расписанию
- [ ] процедура restore + проверка на стенде
- [ ] мониторинг размера backend (`quota-backend-bytes`)

### P4.2 — PostgreSQL

- [ ] выбрать инструмент: pgBackRest / WAL-G / barman
- [ ] full + incremental + WAL archiving (PITR)
- [ ] хранение вне кластера (S3/MinIO/NFS)
- [ ] регулярный тест restore (иначе бэкап не считается)
- [ ] Patroni `archive_mode`/`archive_command` согласовать с выбранным инструментом

### P4.3 — Runbook

- [ ] восстановление после потери VIP
- [ ] восстановление etcd из снапшота
- [ ] замена упавшей ноды с нуля
- [ ] ротация сертов
- [ ] восстановление PG из бэкапа

---

## P5 — Мониторинг и логи

- [ ] node_exporter на всех нодах
- [ ] postgres_exporter + patroni metrics (8008 `/metrics`)
- [ ] etcd metrics (`listen-metrics-urls`) — сейчас не включено
- [ ] HAProxy stats → Prometheus (haproxy_exporter)
- [ ] алерты: `patroni_cluster_has_leader`, `etcd_server_has_leader`, лаг репликации,
      `pg_up`, срок жизни сертов, VIP-владелец
- [ ] алерт на «нет кворума etcd»
- [ ] логи: journald → централизованно (опционально)
