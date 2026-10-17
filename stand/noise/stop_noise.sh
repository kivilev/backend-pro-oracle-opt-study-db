#!/bin/bash
# Остановить «шумного соседа» ОС: docker exec oracle-opt-study-db bash /opt/stand/noise/stop_noise.sh
PID_FILE=/opt/oracle/oradata/noise.pid
if [ -f "$PID_FILE" ]; then
  kill -TERM "$(cat "$PID_FILE")" 2>/dev/null
  rm -f "$PID_FILE"
  echo "Нагрузка остановлена"
else
  echo "Нагрузка не запущена"
fi
