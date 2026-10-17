#!/bin/bash
# «Шумный сосед» на уровне ОС (копия oracle_dbd_optimization_sql/install/system_load.sh с правками для контейнера):
#  - процент CPU и каталог для файлов задаются переменными окружения;
#  - файлы пишутся в том с данными (/opt/oracle/oradata), а не в /tmp: overlayfs контейнера
#    не везде поддерживает O_DIRECT.
# Запуск и остановка — обёртками start_noise.sh / stop_noise.sh (в образе нет pkill):
#   docker exec oracle-opt-study-db bash /opt/stand/noise/start_noise.sh [процент_CPU]
#   docker exec oracle-opt-study-db bash /opt/stand/noise/stop_noise.sh
# Нагрузка ограничена лимитами контейнера (cpus: 2 в docker-compose.yml) => конкурирует именно с Oracle.

declare -a CPU_PIDS=()
declare -a DISK_PIDS=()

CPU_LOAD_PERCENT=${CPU_LOAD_PERCENT:-50}
NOISE_DIR=${NOISE_DIR:-/opt/oracle/oradata/noise}
mkdir -p "$NOISE_DIR"

cleanup() {
    echo "Завершение работы..."
    for pid in "${CPU_PIDS[@]}" "${DISK_PIDS[@]}"; do
        kill -TERM $pid 2>/dev/null
    done
    rm -f "$NOISE_DIR"/testfile*
    exit 0
}

trap cleanup SIGINT SIGTERM

cpu_load() {
    while true; do
        :
    done
}

disk_load() {
    local file_num=$1
    while true; do
        dd if=/dev/zero of="$NOISE_DIR/testfile_${file_num}" bs=1M count=100 oflag=direct &>/dev/null
        sync
        rm -f "$NOISE_DIR/testfile_${file_num}"
    done
}

# nproc в контейнере показывает ядра хоста, а не лимит cpus => берём лимит из cgroup, если он есть
cpu_cores=$(nproc)
if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max
    if [ "$quota" != "max" ]; then cpu_cores=$(( (quota + period - 1) / period )); fi
fi
cpu_processes=$(( (cpu_cores * CPU_LOAD_PERCENT + 99) / 100 ))
echo "Запуск $cpu_processes процессов CPU нагрузки (${CPU_LOAD_PERCENT}% от $cpu_cores ядер)"

for i in $(seq 1 $cpu_processes); do
    cpu_load &
    CPU_PIDS+=($!)
done

echo "Запуск процессов дисковой нагрузки"
for i in {1..2}; do
    disk_load $i &
    DISK_PIDS+=($!)
done

echo "Нагрузка запущена. Остановка: bash /opt/stand/noise/stop_noise.sh"
echo "CPU PIDs: ${CPU_PIDS[*]}"
echo "Disk PIDs: ${DISK_PIDS[*]}"

wait
