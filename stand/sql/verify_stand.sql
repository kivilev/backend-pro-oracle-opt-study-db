/*
  Самопроверка стенда. Запуск под kivi:
    docker exec oracle-opt-study-db sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @/opt/stand/sql/verify_stand.sql
  или из любого клиента (SQL Developer / PL/SQL Developer / DBeaver) под kivi — выполнить как скрипт.

  Длительность: 2–5 минут (сканирование учебных таблиц после flush buffer cache).
*/
set serveroutput on size unlimited
set linesize 250 pagesize 200 verify off feedback off timing off
column check_id  format a14
column metric    format a22
column act_value format a45 word_wrapped
column exp_value format a45 word_wrapped
column status    format a5

begin
  stand.verify.run;
end;
/

prompt
prompt ===== Расхождения с эталоном (FAIL / WARN) и новые метрики (NEW)
select check_id, metric, act_value, exp_value, status
  from stand.result
 where run_id = (select max(run_id) from stand.result)
   and status in ('FAIL', 'WARN', 'NEW')
   and metric not in ('PLAN')
 order by seq;

prompt
prompt ===== Учебные кейсы (Buffers и план одинаковы у всех; время зависит от компьютера)
select r.check_id, r.metric, r.act_value, r.status
  from stand.result r
 where r.run_id = (select max(run_id) from stand.result)
   and (r.metric in ('PHV', 'BUFFERS', 'ROWS', 'ELAPSED_MS') or r.metric like '%RATIO')
   and regexp_like(r.check_id, '^C[0-9]')
 order by r.seq;

prompt
select case when count(case when status = 'FAIL' then 1 end) = 0
            then 'STAND CHECK PASSED: стенд совпадает с эталоном'
            else 'STAND CHECK FAILED: ' || count(case when status = 'FAIL' then 1 end) || ' расхождений — пришлите вывод преподавателю'
       end as result
  from stand.result
 where run_id = (select max(run_id) from stand.result);

exit
