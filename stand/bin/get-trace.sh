#!/bin/bash
# Забрать свой трейс: последний *.trc с подстрокой в имени (tracefile_identifier) + отчёт tkprof.
# Результат кладётся в /tmp/trace-out, оттуда его копирует к себе docker cp (раздел 5 README):
#   docker exec oracle-opt-study-db get-trace МОЙ_ТЕСТ
#   docker cp oracle-opt-study-db:/tmp/trace-out/. .
set -u -o pipefail

TRACE_DIR=/opt/oracle/diag/rdbms/free/FREE/trace
OUT=/tmp/trace-out
ID=${1:-}

TRC=$(ls -t "$TRACE_DIR"/*"${ID}"*.trc 2>/dev/null | head -1)
if [ -z "$TRC" ]; then
  echo "Трейс *${ID}*.trc не найден в $TRACE_DIR"
  echo "Последние трейсы:"; ls -t "$TRACE_DIR"/*.trc 2>/dev/null | head -5
  exit 1
fi

NAME=$(basename "$TRC")
rm -rf "$OUT" && mkdir -p "$OUT"
cp "$TRC" "$OUT/" || { echo "не удалось скопировать $TRC"; exit 1; }
tkprof "$TRC" "$OUT/$NAME.txt" sys=no sort=prsela,fchela,exeela > /dev/null || { echo "tkprof завершился с ошибкой"; exit 1; }
echo "Готово: $OUT/$NAME и $OUT/$NAME.txt (tkprof)"
