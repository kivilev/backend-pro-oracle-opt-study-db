#!/bin/bash
# Выполняется entrypoint-ом gvenzl/oracle-free при КАЖДОМ старте контейнера (после открытия БД).
# Образ «запечён»: база с данными уже внутри. При первом старте на новом томе пересоздаём платежи
# относительно сегодняшней даты (пакеты курса работают от sysdate), дальше — только сообщаем о готовности.
MARK=/opt/oracle/oradata/.stand_first_start_done
LOG=/opt/oracle/oradata/stand_logs/first_start.log
PDB=${STAND_PDB:-FREEPDB1}

if [ ! -f /opt/oracle/oradata/.stand_ready ]; then
  echo "STAND: установка не завершена — см. /opt/oracle/oradata/stand_setup.log"
elif [ "${STAND_BAKING:-0}" = "1" ]; then
  echo "STAND: режим запекания образа — первый старт не выполняется"
else
  if [ ! -f "$MARK" ]; then
    echo "STAND: первый запуск — обновляю даты платежей (около минуты)..."
    mkdir -p "$(dirname "$LOG")"
    if (cd /opt/stand/sql/tools && echo exit | sqlplus -s -l "kivi/booble12@//localhost:1521/${PDB}" @reset_payments.sql) > "$LOG" 2>&1; then
      touch "$MARK"
    else
      echo "STAND: ОШИБКА при обновлении платежей, см. $LOG"
      tail -20 "$LOG"
    fi
  fi
  echo "STAND IS READY. Подключение: kivi/booble12@//localhost:1521/${PDB}"
fi
