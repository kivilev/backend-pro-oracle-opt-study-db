#!/bin/bash
# Запустить «шумного соседа» ОС в фоне: docker exec oracle-opt-study-db bash /opt/stand/noise/start_noise.sh [процент_CPU]
PID_FILE=/opt/oracle/oradata/noise.pid
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then echo "Уже запущен (pid $(cat "$PID_FILE"))"; exit 0; fi
CPU_LOAD_PERCENT=${1:-50} nohup bash /opt/stand/noise/system_load.sh > /opt/oracle/oradata/noise.log 2>&1 < /dev/null &
disown
echo $! > "$PID_FILE"
sleep 1; cat /opt/oracle/oradata/noise.log
