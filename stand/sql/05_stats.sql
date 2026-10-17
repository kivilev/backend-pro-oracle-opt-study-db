/*
  Шаг: статистика. Собираем один раз при установке с фиксированными настройками (global prefs из 02_maintenance_off.sql)
  и блокируем статистику kivi. Данные детерминированы => статистика у всех одинаковая (сверяет verify, раздел STATS).
  Запуск: sqlplus / as sysdba @05_stats.sql <PDB>
*/
whenever sqlerror exit failure
set serveroutput on
alter session set container = &&1;

begin
  dbms_stats.unlock_schema_stats('KIVI');
  dbms_stats.gather_schema_stats(ownname => 'KIVI', cascade => true, granularity => 'AUTO', no_invalidate => false);
  dbms_stats.gather_schema_stats(ownname => 'HR',   cascade => true, no_invalidate => false);
  dbms_stats.lock_schema_stats('KIVI');
  -- HR не блокируем: на hr идут демо уроков 4–8 и бонусного урока про статистику, где её пересобирают.
end;
/

-- Базовый AWR-снимок «чистого» стенда
exec dbms_workload_repository.create_snapshot;

exit
