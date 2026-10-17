/*
  Учебные кейсы последнего прогона verify: план, Buffers, A-Rows, время. Под kivi.
    docker exec oracle-opt-study-db sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @/opt/stand/sql/tools/show_cases.sql
*/
set linesize 300 pagesize 500 feedback off verify off
column check_id  format a10
column metric    format a14
column act_value format a220 word_wrapped

select check_id, metric, act_value
  from stand.result
 where run_id = (select max(run_id) from stand.result)
   and (regexp_like(check_id, '^C[0-9]') or metric like '%RATIO' or metric = 'ERROR')
   and metric in ('PHV', 'PLAN', 'BUFFERS', 'ROWS', 'DISK_READS', 'ELAPSED_MS', 'BUFFERS_RATIO', 'ELAPSED_RATIO', 'ERROR')
 order by seq;
exit
