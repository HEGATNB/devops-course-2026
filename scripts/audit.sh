#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0
check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  [OK]   $desc"; ((PASS+=1))
    else
        echo "  [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL+=1))
    fi
}
run_status() { "$@" >/dev/null 2>&1; echo "$?"; }
echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"
echo "[1] SSH и межсетевой экран"
check "SSH активен" "active" "$(systemctl is-active ssh || true)"
check "Вход root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольный вход отключён" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"
check "Ключевой вход разрешён" "yes" "$(sudo sshd -T | awk '/^pubkeyauthentication/{print $2}')"
check "Лимит попыток равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"
check "Гостевой SSH-порт соответствует NAT 2222→22" "22" "$(sudo sshd -T | awk '/^port/{print $2; exit}')"
check "UFW активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
check "Политика входящего трафика deny" "deny" "$(sudo ufw status verbose | awk '/^Default:/{print $2}')"
check "Для devops включена группа docker" "yes" "$(id -nG devops | tr ' ' '
' | grep -qx docker && echo yes || echo no)"
echo "[2] Nginx и TLS"
check "Nginx активен" "active" "$(systemctl is-active nginx || true)"
check "Конфигурация Nginx корректна" "0" "$(run_status sudo nginx -t)"
check "Сертификат действителен ещё 30 дней" "0" "$(run_status openssl x509 -in /etc/ssl/certs/devops.crt -checkend 2592000 -noout)"
check "Ключ TLS имеет права 600" "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"
check "Нет файлов, доступных на запись всем" "0" "$(find /var/www/devops-site -type f -perm -o+w -print | wc -l | tr -d ' ')"
echo "[3] Docker Compose"
check "Docker активен" "active" "$(systemctl is-active docker || true)"
check "PostgreSQL healthy" "healthy" "$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || true)"
check "Публикация приложения только на loopback" "127.0.0.1" "$(docker inspect -f '{{(index (index .NetworkSettings.Ports "5000/tcp") 0).HostIp}}' app-app-1 2>/dev/null || true)"
check "Файл .env имеет права 600" "600" "$(stat -c '%a' /home/devops/app/.env 2>/dev/null || true)"
check "Проверка HTTPS приложения" "ok" "$(curl --silent --show-error --cacert /etc/ssl/certs/devops.crt --resolve devops.local:443:127.0.0.1 https://devops.local/app/health 2>/dev/null || true)"
echo "[5] Контейнеризация"
check "Служба Docker активна" "active" "$(systemctl is-active docker || true)"
check "Контейнер PostgreSQL healthy" "healthy" "$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || true)"
unsafe_ports="$(ss -tlnH 2>/dev/null | awk '$4 ~ /:(5000|5432)$/ && $4 !~ /^127\.0\.0\.1:/ {print $4}')"
if [[ -z "$unsafe_ports" ]]; then port_status="safe"; else port_status="${unsafe_ports//$'\n'/, }"; fi
check "Порты 5000 и 5432 не опубликованы вне loopback" "safe" "$port_status"
check "Файл /home/devops/app/.env имеет права 600" "600" "$(stat -c '%a' /home/devops/app/.env 2>/dev/null || true)"
echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
