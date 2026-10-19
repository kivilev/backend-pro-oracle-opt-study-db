#!/bin/bash
# Установка учебного стенда внутри контейнера gvenzl/oracle-free (Oracle AI Database 26ai Free).
# Вызывается из /container-entrypoint-initdb.d/01_stand.sh один раз при первом старте (новая БД).
# Шаги идемпотентны: выполненный шаг отмечается файлом в $MARK_DIR, повторный запуск продолжит с места сбоя:
#   docker exec -it oracle-opt-study-db bash /opt/stand/bin/stand_setup.sh
set -u -o pipefail

STAND_HOME=/opt/stand
SQL=$STAND_HOME/sql
PDB=${STAND_PDB:-FREEPDB1}
PROFILE=${STAND_PROFILE:-small}
SEED=${STAND_SEED:-20260919}
MARK_DIR=/opt/oracle/oradata/.stand
LOG_DIR=/opt/oracle/oradata/stand_logs
KIVI_CONN="kivi/booble12@//localhost:1521/${PDB}"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8   # иначе кириллица в комментариях объектов kivi превратится в "?"

mkdir -p "$MARK_DIR" "$LOG_DIR"

case "$PROFILE" in
  small) CLIENTS=2000000; TERRORISTS=5000000; PASSPORTS=4000000; PAY_PER_DAY=50000;  DAYS=45 ;;
  mini)  CLIENTS=100000;  TERRORISTS=500000;  PASSPORTS=400000;  PAY_PER_DAY=2500;   DAYS=45 ;;  # для отладки стенда
  full)  CLIENTS=4000000; TERRORISTS=5000000; PASSPORTS=4000000; PAY_PER_DAY=100000; DAYS=45 ;;
  *) echo "STAND: unknown STAND_PROFILE=$PROFILE (mini|small|full)"; exit 1 ;;
esac

log() { echo "STAND [$(date '+%F %T')] $*"; }

# sys_sql <file> [args...] — под SYSDBA в CDB$ROOT
sys_sql() { local f=$1; shift; echo exit | sqlplus -s -l / as sysdba @"$f" "$@"; }
# kivi_sql <file> [args...] — под kivi в PDB
kivi_sql() { local f=$1; shift; echo exit | sqlplus -s -l "$KIVI_CONN" @"$f" "$@"; }

# step <name> <command...> — выполнить шаг, если он ещё не выполнен
step() {
  local name=$1; shift
  if [ -f "$MARK_DIR/$name.done" ]; then log "skip $name (done)"; return 0; fi
  log "start $name"
  local t0=$SECONDS
  if "$@" > "$LOG_DIR/$name.log" 2>&1; then
    touch "$MARK_DIR/$name.done"
    log "done  $name in $((SECONDS - t0)) s"
  else
    log "FAILED $name — см. $LOG_DIR/$name.log"
    tail -30 "$LOG_DIR/$name.log"
    exit 1
  fi
}

restart_db() {
  sqlplus -s -l / as sysdba <<EOF
whenever sqlerror exit failure
shutdown immediate
startup
whenever sqlerror continue
alter pluggable database all open;
exit
EOF
}

kivi_objects() {
  cd "$SQL/install/kivi" || return 1
  kivi_sql 1_all_objects.sql
  kivi_sql 2_dict_data.sql
  kivi_sql client_wallet_analysis_proc.sql
  kivi_sql noisy_neighbor.sql create
  # перекомпиляция и контроль: в схеме не должно остаться невалидных объектов
  sqlplus -s -l "$KIVI_CONN" <<'EOF'
whenever sqlerror exit failure
exec dbms_utility.compile_schema(user, compile_all => false)
set heading off
select 'INVALID: ' || object_type || ' ' || object_name from user_objects where status <> 'VALID';
declare v number; begin
  select count(*) into v from user_objects where status <> 'VALID';
  if v > 0 then raise_application_error(-20001, v || ' invalid objects in KIVI'); end if;
end;
/
exit
EOF
}

fill_data() {
  cd "$SQL/install/kivi/fill" || return 1
  kivi_sql fill_kivi.sql "$CLIENTS" "$TERRORISTS" "$PASSPORTS" "$PAY_PER_DAY" "$DAYS" "$SEED"
}

stand_schema() {
  cd "$SQL/stand" || return 1
  sys_sql stand_objects.sql "$PDB" || return 1
  sqlplus -s -l / as sysdba <<EOF
whenever sqlerror exit failure
alter session set container = ${PDB};
set define off
@${SQL}/stand/expected/expected_any.sql
@${SQL}/stand/expected/expected_${PROFILE}.sql
set define on
insert into stand.config values ('PROFILE', '${PROFILE}');
insert into stand.config values ('SEED', '${SEED}');
insert into stand.config values ('ARCH', '$(uname -m)');
insert into stand.config values ('INSTALL_DATE', to_char(sysdate, 'YYYY-MM-DD'));
insert into stand.config values ('CLIENTS', '${CLIENTS}');
insert into stand.config values ('PAY_PER_DAY', '${PAY_PER_DAY}');
insert into stand.config values ('DAYS', '${DAYS}');
commit;
exit
EOF
}

verify() {
  kivi_sql "$SQL/verify_stand.sql"
}

log "profile=$PROFILE seed=$SEED pdb=$PDB arch=$(uname -m)"
log "clients=$CLIENTS terrorists=$TERRORISTS passports=$PASSPORTS payments/day=$PAY_PER_DAY days=$DAYS"

step 10_params      sys_sql "$SQL/01_params.sql"
step 15_restart     restart_db
step 20_maintenance sys_sql "$SQL/02_maintenance_off.sql" "$PDB"
rm -f /opt/oracle/oradata/FREE/redo01.log /opt/oracle/oradata/FREE/redo02.log  # группы 1–2 удалены в 02_maintenance_off.sql
step 30_users       sys_sql "$SQL/03_users.sql" "$PDB"
step 40_kivi        kivi_objects
step 50_hr          bash -c "cd '$SQL/install/hr' && echo exit | sqlplus -s -l / as sysdba @hr_install.sql '$PDB'"
step 60_fill        fill_data
step 70_stats       sys_sql "$SQL/05_stats.sql" "$PDB"
step 80_stand       stand_schema
step 90_verify      verify

touch /opt/oracle/oradata/.stand_ready
log "======================================================"
log "STAND IS READY (profile=$PROFILE). Итог самопроверки: $LOG_DIR/90_verify.log"
grep -E "STAND CHECK|RUN_ID" "$LOG_DIR/90_verify.log" | sed 's/^/STAND: /'
log "======================================================"
