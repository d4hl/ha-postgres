# ===========================================================================
# Vault PKI: аутентификация control node'а по AppRole
# ===========================================================================
#
# Зачем: статичный токен из `.env` живёт ~24h и протухает — из-за этого не
# работает автоматический перевыпуск по таймеру (TODO P1.5). AppRole даёт
# не истекающие креды: на каждый прогон playbook'а выполняется login и берётся
# короткоживущий токен. Плюс политика сужается до «выпустить серт» вместо
# root-токена.
#
# Честно про выигрыш: secret_id — это такой же статичный секрет на диске, как
# и токен. Выигрыш не в «секретности», а в (1) отсутствии истечения,
# (2) отзываемости/ротации, (3) узкой policy, (4) следе в audit log.
# Если таймер не нужен — проще `vault login` (OIDC/userpass + MFA), модуль сам
# прочитает `~/.vault-token`; тогда в `.env` вообще нет секретов.
#
# ---------------------------------------------------------------------------
# 1. Vault: policy + AppRole (нужен админский токен)
# ---------------------------------------------------------------------------
#
#   export VAULT_ADDR=https://vault.mishin.pw
#   export VAULT_TOKEN=<admin>
#
#   # политика: только выпуск сертов по нужной роли (mount/role — из
#   # group_vars/all/main.yml: vault_pki_mount / vault_pki_role_name)
#   cat > /tmp/pki-issue.hcl <<'HCL'
#   path "pki/issue/any-domain" {
#     capabilities = ["create", "update"]
#   }
#   HCL
#   vault policy write pki-issue /tmp/pki-issue.hcl
#
#   # роль: короткоживущий токен, secret_id без TTL позволяет таймеру работать
#   # без человека. Ротация — перевыпуск secret_id (шаг 3).
#   vault write auth/approle/role/ansible-pki \
#     token_policies=pki-issue \
#     token_ttl=1h token_max_ttl=4h \
#     secret_id_ttl=0 \
#     bind_secret_id=true
#
#   # опционально сузить, откуда можно логиниться:
#   #   vault write auth/approle/role/ansible-pki secret_id_bound_cidrs=<ip>/32
#
# ---------------------------------------------------------------------------
# 2. Получить креды и положить в ansible
# ---------------------------------------------------------------------------
#
#   vault read -field=role_id auth/approle/role/ansible-pki/role-id
#   vault write -f -field=secret_id auth/approle/role/ansible-pki/secret-id
#
#   # ansible/group_vars/all/vault.yml (git-ignored):
#   #   vault_pki_role_id: "..."
#   #   vault_pki_secret_id: "..."
#
#   # ansible/group_vars/all/main.yml:
#   vault_pki_auth_method: approle
#
# Важно: модули community.hashi_vault НЕ читают ANSIBLE_HASHI_VAULT_ROLE_ID /
# _SECRET_ID (эти env-переменные работают только у lookup-плагинов коллекции),
# поэтому креды должны быть Ansible-переменными, а не строками в `.env`.
# Проверено на community.hashi_vault 7.1.0: с заполненным окружением модуль
# всё равно отвечает "No Vault Token specified or discovered".
#
# ---------------------------------------------------------------------------
# 3. Проверка и ротация
# ---------------------------------------------------------------------------
#
#   # выпустить тестовый серт в /tmp, не трогая реальные пути:
#   ansible-playbook site.yml --tags pki --limit pg-01 \
#     -e '{"vault_pki_certs":[{"name":"smoke","common_name":"smoke.local",
#          "dir":"/tmp/vault-pki-smoke","cert":"s.crt","key":"s.key"}]}'
#
#   # отозвать старый токен из `.env` (если он ещё жив):
#   vault token revoke <token>
#
#   # ротация secret_id: выпустить новый, обновить vault.yml, старый — убить
#   vault write -f -field=secret_id auth/approle/role/ansible-pki/secret-id
#   vault list auth/approle/role/ansible-pki/secret-id-accessor
#   vault write auth/approle/role/ansible-pki/secret-id-accessor/destroy \
#     secret_id_accessor=<accessor>
