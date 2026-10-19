/*
  «Освежить» платежи: пересоздать PAYMENT / PAYMENT_DETAIL относительно сегодняшней даты тем же seed,
  пересобрать и заблокировать их статистику. Нужен, если стенд живёт дольше нескольких дней:
  запросы пакетов работают от sysdate (последние 30/45 дней), и со временем данные «уезжают» в прошлое.
  Запуск под kivi, обязательно из каталога tools (скрипт генерации подключается относительным путём @@../install/...):
    docker exec -it oracle-opt-study-db bash -c "cd /opt/stand/sql/tools && sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @reset_payments.sql"
  ВНИМАНИЕ: удаляет все платежи (в т.ч. обработанные студентом в финальной работе).
  Пока скрипт работает, джобы платежей выключены; в конце они включаются снова.
*/
whenever sqlerror exit failure
whenever oserror exit failure
set serveroutput on verify off
column c new_value v_clients noprint
column p new_value v_ppd noprint
column d new_value v_days noprint
column s new_value v_seed noprint
select max(case when param = 'CLIENTS' then value end) c,
       max(case when param = 'PAY_PER_DAY' then value end) p,
       max(case when param = 'DAYS' then value end) d,
       max(case when param = 'SEED' then value end) s
  from stand.config;

begin
  dbms_scheduler.disable('FILL_PAYMENT_JOB', force => true);
  dbms_scheduler.disable('CLEAR_PAYMENTS_JOB', force => true);
end;
/

exec dbms_stats.unlock_table_stats(user, 'PAYMENT')
exec dbms_stats.unlock_table_stats(user, 'PAYMENT_DETAIL')

begin
  execute immediate 'truncate table payment';
  execute immediate 'truncate table payment_detail';
  -- убираем все интервальные секции, остаётся только PMIN — как после установки
  for p in (select table_name, partition_name from user_tab_partitions
             where table_name in ('PAYMENT', 'PAYMENT_DETAIL') and partition_name <> 'PMIN') loop
    execute immediate 'alter table ' || p.table_name || ' drop partition ' || p.partition_name || ' update global indexes';
  end loop;
  execute immediate 'alter sequence payment_seq restart start with 1';
  for t in (select table_name from user_tables where table_name in ('PAYMENT', 'PAYMENT_DETAIL')) loop
    execute immediate 'alter table ' || t.table_name || ' disable all triggers';
  end loop;
end;
/

@@../install/kivi/fill/fill_payments_det.sql &v_clients &v_ppd &v_days &v_seed

begin
  for t in (select table_name from user_tables where table_name in ('PAYMENT', 'PAYMENT_DETAIL')) loop
    execute immediate 'alter table ' || t.table_name || ' enable all triggers';
    dbms_stats.gather_table_stats(user, t.table_name, cascade => true, no_invalidate => false);
    dbms_stats.lock_table_stats(user, t.table_name);
  end loop;
  dbms_scheduler.enable('FILL_PAYMENT_JOB');
  dbms_scheduler.enable('CLEAR_PAYMENTS_JOB');
end;
/
prompt Платежи пересозданы относительно trunc(sysdate). Проверка: @/opt/stand/sql/verify_stand.sql
exit
