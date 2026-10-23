#!/bin/bash
# Точка входа стенда: поднимает sshd (вход по SSH/SFTP, раздел 6 README) и передаёт управление
# entrypoint-у gvenzl/oracle-free. sshd стартует до БД, чтобы на стенд можно было зайти, даже если база не поднялась.
# STAND_SSH=0 отключает sshd. При запекании образа (STAND_BAKING=1) sshd не нужен, а ключ хоста не должен попасть в образ.
KEY_DIR=/opt/oracle/oradata/.stand/ssh

if [ "${STAND_SSH:-1}" = "1" ] && [ "${STAND_BAKING:-0}" != "1" ]; then
  # Ключ хоста свой у каждого стенда и лежит на томе: переживает пересоздание контейнера
  if [ ! -f "$KEY_DIR/ssh_host_ed25519_key" ]; then
    mkdir -p "$KEY_DIR" && chmod 700 "$KEY_DIR"
    ssh-keygen -q -t ed25519 -N "" -f "$KEY_DIR/ssh_host_ed25519_key"
  fi
  # syslog в контейнере нет: журнал входов (в т.ч. неудачных) пишется в /tmp/sshd.log
  if /usr/sbin/sshd -f /opt/stand/ssh/sshd_config -E /tmp/sshd.log; then
    echo "STAND: SSH/SFTP: oracle@localhost, порт 2222"
  else
    echo "STAND: sshd не запустился, вход по SSH недоступен (база работает как обычно)"
  fi
fi

exec /opt/oracle/container-entrypoint.sh "$@"
