# HA Postgres

Конфигурация terraform и ansible для автоматизированного развертывания HA кластера PostgreSQL
с ssl шифрованием и HA проксированием через haproxy на виртуальных машинах libvirt.

Запуск рассчитан на любое количество машин на 3 разных слоях: etcd, postgres, haproxy.
В качестве ОС используется cloud-init образ CentOS 10 Stream.

## Стек:
- postgres
- patroni (управляет реплицированием)
- etcd (DCS состояния кластера)
- haproxy (основной прокси)
- keepalived (демон удерживающий VIP)
- Hashicorp Vault PKI (внешний сервис для выдачи сертификатов)

## Шифрование

В кластере реализовано e2e шифрование между всеми участниками системы:
- Patroni - etcd
- node - node в postgres
- node - client, с tls passthrough на haproxy

## Запуск

Окружение в flake + direnv (hvac для community.hashi_vault и переменные Vault из .env),
работать из корня репозитория.

```bash
cd terraform
terraform init
terraform output -raw ansible_inventory  # строки для секции [all] в ansible/inventory.ini
terraform apply
```

```bash
cd ansible
ansible-playbook site.yml
# или конкретный тег
ansible-playbook site.yml --tags common | etcd | postgresql,patroni,haproxy
```


## Проверка

```
ansible postgres -b -m shell -a '/usr/local/bin/patronictl -c /etc/patroni/patroni.yml list'
psql "host=192.168.100.100 port=5432 dbname=postgres user=postgres sslmode=verify-full"   # primary
psql "host=192.168.100.100 port=5434 dbname=postgres user=postgres sslmode=verify-full"   # replica
```

## Ротация сертов (TTL 30 дней)

```
ansible-playbook rotate-pki.yml                                # только истекающее
ansible-playbook rotate-pki.yml -e vault_pki_force_renew=true  # после смены CN/SAN/CA
```

serial: 1 - без downtime
рестарт только тех хостов, где серт реально перевыпущен
postgres — только reload, без failover.

## Клиенты

files/root-ca.crt — корень PKI. В дефолтном месте libpq его указывать не нужно:

```
mkdir -p ~/.postgresql && cp ansible/files/root-ca.crt ~/.postgresql/root.crt
```

DBeaver: LibPQFactory, sslrootcert = ~/.postgresql/root.crt, sslmode = verify-full, клиентские
серт и ключ пустые. Хост 192.168.100.100, порты 5432 / 5434.
