/*
  Для автора курса: превращает последний прогон verify в файл эталонов expected_<profile>.sql.
  Запуск под kivi внутри контейнера (spool пишет файл в контейнере):
    docker exec -it oracle-stand bash -c "sqlplus -s kivi/booble12@//localhost:1521/ORCLPDB1 @/opt/stand/sql/tools/capture_expected.sql"
    docker cp oracle-stand:/opt/oracle/oradata/stand_logs/expected_small.sql docker-stand/stand/sql/stand/expected/

  Допуски по умолчанию:
    PHV, ROWS, STARTS, DATA.*, NUM_ROWS, LOCKED, PARTITIONS — точное совпадение (FAIL);
    BUFFERS и LEAF_BLOCKS — 10 % (FAIL), BLOCKS — 5 % (FAIL), BUFFERS_RATIO — 30 % (WARN);
    PLAN — WARN (дублирует PHV в читаемом виде);
    SQL_ID, DISK_READS, ELAPSED_MS, ELAPSED_RATIO, ENV.* и PARAM.* — не попадают (их задаёт expected_any.sql).
  Если x86 и ARM дают разные значения, снять эталон на обеих и вручную продублировать строки с arch = 'x86_64' / 'aarch64'.
*/
set heading off feedback off pagesize 0 linesize 4000 trimspool on verify off termout off
column prof new_value v_prof noprint
select value prof from stand.config where param = 'PROFILE';

spool /opt/oracle/oradata/stand_logs/expected_&v_prof..sql
select '-- Эталоны профиля &v_prof, сняты ' || to_char(sysdate, 'YYYY-MM-DD HH24:MI') ||
       ' на ' || (select value from stand.config where param = 'ARCH') ||
       ', run_id=' || (select max(run_id) from stand.result) from dual;
select 'insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values (' ||
       '''&v_prof'', ''ANY'', ' ||
       '''' || check_id || ''', ''' || metric || ''', ' ||
       '''' || replace(act_value, '''', '''''') || ''', ' ||
       nvl(to_char(case
                     when metric = 'BUFFERS' then 10
                     -- листовые блоки индексов, обслуживаемых при загрузке, плавают между установками на ±5–6 %
                     when metric like '%.LEAF_BLOCKS' then 10
                     when metric in ('BLOCKS') or metric like '%.BLOCKS' then 5
                     when metric = 'BUFFERS_RATIO' then 30
                   end), 'null') || ', ' ||
       '''' || case when metric in ('PLAN', 'BUFFERS_RATIO') then 'WARN' else 'FAIL' end || ''', null);'
  from stand.result
 where run_id = (select max(run_id) from stand.result)
   and check_id not in ('ENV', 'PARAM')
   and metric not in ('SQL_ID', 'DISK_READS', 'ELAPSED_MS', 'ELAPSED_RATIO', 'ERROR')
 order by seq;
select 'commit;' from dual;
spool off
set termout on
prompt Готово: /opt/oracle/oradata/stand_logs/expected_&v_prof..sql
exit
