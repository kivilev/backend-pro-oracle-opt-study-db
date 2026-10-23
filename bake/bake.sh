#!/usr/bin/env bash
# Запекание образа стенда: установка → проверка → финализация → docker commit.
# Использование: bash bake/bake.sh <итоговый_тег> [профиль]
#   локально:  bash bake/bake.sh oracle-opt-study-db:baked
#   в CI:      bash bake/bake.sh ghcr.io/kivilev/oracle-opt-study-db:latest-amd64
# Время: ~15–25 минут (установка стенда внутри контейнера).
set -euo pipefail

TARGET=${1:?укажите тег итогового образа}
PROFILE=${2:-small}
HERE=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER=oracle-opt-study-installer:local
NAME=oracle-opt-study-bake-$$

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== 1/5 сборка установочного образа"
docker build -t "$INSTALLER" "$HERE"

echo "== 2/5 установка стенда (профиль $PROFILE), без тома: данные остаются в слое контейнера"
docker run -d --name "$NAME" --shm-size=1g --memory=3g \
  -e STAND_PROFILE="$PROFILE" -e STAND_BAKING=1 "$INSTALLER" >/dev/null

# grep без -q: с -q он выходит на первом совпадении, docker logs получает SIGPIPE,
# и при pipefail проверка «проваливается» на длинном логе, хотя строка в нём есть
until docker logs "$NAME" 2>&1 | grep -E "STAND IS READY|STAND: .*FAILED|FAILED [0-9]" > /dev/null; do
  if ! docker ps -q --filter "name=$NAME" | grep -q .; then
    echo "контейнер остановился"; docker logs --tail 50 "$NAME"; exit 1
  fi
  sleep 20
done
docker logs "$NAME" 2>&1 | grep -E "^STAND" | tail -15
docker logs "$NAME" 2>&1 | grep "STAND CHECK PASSED" > /dev/null || { echo "самопроверка не прошла — образ не запекаем"; exit 1; }

echo "== 3/5 финализация: UNDO/TEMP, остановка БД"
docker cp "$HERE/bake/finalize.sql" "$NAME:/tmp/finalize.sql"
docker exec "$NAME" bash -c 'sqlplus -s / as sysdba @/tmp/finalize.sql'
docker exec "$NAME" bash -c 'rm -f /opt/oracle/oradata/.stand_first_start_done; du -sh /opt/oracle/oradata'
docker exec -u root "$NAME" rm -f /tmp/finalize.sql
docker stop -t 120 "$NAME" >/dev/null

echo "== 4/5 docker commit -> $TARGET"
docker commit \
  --change 'ENV STAND_BAKING=0' \
  --change "LABEL org.opencontainers.image.description=\"Oracle 26ai Free со схемами kivi и hr (готовая база, профиль $PROFILE) для курса «Оптимизация Oracle SQL»\"" \
  "$NAME" "$TARGET" >/dev/null

echo "== 5/5 готово"
docker image inspect "$TARGET" --format 'образ {{.RepoTags}}: {{.Size}} байт, {{.Architecture}}'
