/*
  Шаг 2: выключаем всё, что само по себе меняет статистику и планы. Запуск: sqlplus / as sysdba после рестарта.
*/
whenever sqlerror exit failure
set serveroutput on

-- автозадачи (в CDB и в PDB)
begin
  dbms_auto_task_admin.disable(client_name => 'auto optimizer stats collection', operation => null, window_name => null);
  dbms_auto_task_admin.disable(client_name => 'sql tuning advisor',             operation => null, window_name => null);
  dbms_auto_task_admin.disable(client_name => 'auto space advisor',             operation => null, window_name => null);
end;
/

-- Redo: в образе gvenzl 2 группы по 20 МБ. На массовых вставках (загрузка, джобы платежей) база постоянно ждёт
-- "Checkpoint not complete". Ставим 3 группы по 100 МБ, старые удаляем.
declare
  v_cnt number;
begin
  for g in 3 .. 5 loop
    select count(*) into v_cnt from v$log where group# = g;
    if v_cnt = 0 then
      execute immediate 'alter database add logfile group ' || g ||
                        ' (''/opt/oracle/oradata/FREE/redo0' || g || '.log'') size 100m reuse';
    end if;
  end loop;
  for i in 1 .. 20 loop
    select count(*) into v_cnt from v$log where group# in (1, 2) and status in ('CURRENT', 'ACTIVE');
    exit when v_cnt = 0;
    execute immediate 'alter system switch logfile';
    execute immediate 'alter system checkpoint';
  end loop;
  for g in (select group# from v$log where group# in (1, 2)) loop
    execute immediate 'alter database drop logfile group ' || g.group#;
  end loop;
end;
/

alter session set container = &&1;

begin
  dbms_auto_task_admin.disable(client_name => 'auto optimizer stats collection', operation => null, window_name => null);
  dbms_auto_task_admin.disable(client_name => 'sql tuning advisor',             operation => null, window_name => null);
  dbms_auto_task_admin.disable(client_name => 'auto space advisor',             operation => null, window_name => null);
end;
/

-- Системная статистика: по умолчанию CPUSPEEDNW меряется при старте экземпляра => на каждой машине своя
-- стоимость CPU в планах. Фиксируем noworkload-значения явно (хранятся в aux_stats$, переживают рестарт).
begin
  dbms_stats.delete_system_stats;
  dbms_stats.set_system_stats(pname => 'CPUSPEEDNW', pvalue => 2000);
  dbms_stats.set_system_stats(pname => 'IOSEEKTIM',  pvalue => 10);
  dbms_stats.set_system_stats(pname => 'IOTFRSPEED', pvalue => 4096);
end;
/

-- Глобальные настройки сбора статистики: одинаковый результат при любом (даже ручном) сборе
begin
  dbms_stats.set_global_prefs('ESTIMATE_PERCENT', 'DBMS_STATS.AUTO_SAMPLE_SIZE');
  dbms_stats.set_global_prefs('METHOD_OPT',       'FOR ALL COLUMNS SIZE 1');
  dbms_stats.set_global_prefs('DEGREE',           '1');
  dbms_stats.set_global_prefs('INCREMENTAL',      'FALSE');
  dbms_stats.set_global_prefs('NO_INVALIDATE',    'FALSE');
  dbms_stats.set_global_prefs('AUTO_STAT_EXTENSIONS', 'OFF');
end;
/

-- Статистика словаря — для стабильных рекурсивных запросов
exec dbms_stats.gather_dictionary_stats;

exit
