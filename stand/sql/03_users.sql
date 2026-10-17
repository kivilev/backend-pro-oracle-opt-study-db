/*
  Шаг 3: роль, схемы kivi/hr, служебная схема stand, служебные процедуры SYS.
  Копия oracle_dbd_optimization_sql/install/create_users.sql + sys_objs.sql (роль раскомментирована,
  пользователь stand добавлен). Запуск: sqlplus / as sysdba, параметр 1 — имя PDB.
*/
whenever sqlerror exit failure
alter session set container = &&1;

create role student_role;
grant connect to student_role;
grant resource to student_role;
grant debug connect session to student_role;
grant create view to student_role;
grant create materialized view to student_role;
grant create job to student_role;

create user kivi identified by booble12 default tablespace users temporary tablespace temp;
create user hr   identified by booble12 default tablespace users temporary tablespace temp;

begin
  for u in (select column_value un from table(sys.odcivarchar2list('KIVI', 'HR'))) loop
    execute immediate 'grant student_role to ' || u.un;
    execute immediate 'grant select_catalog_role to ' || u.un;
    execute immediate 'grant select any dictionary to ' || u.un;
    execute immediate 'grant alter session to ' || u.un;
  end loop;
end;
/

alter user kivi quota 11500M on users;
alter user hr   quota 400M   on users;

-- Служебная схема стенда: таблицы эталонов и пакет самопроверки. Без входа (no authentication).
create user stand no authentication default tablespace users temporary tablespace temp;
alter user stand quota 50M on users;
grant create table, create procedure to stand;

-- sys_objs.sql (копия)
create or replace noneditionable procedure sys.flush_all
is
begin
  execute immediate 'alter system flush buffer_cache';
  execute immediate 'alter system flush shared_pool';
end;
/

create or replace noneditionable procedure sys.kill_session(sid number, serial number)
is
  v_sql varchar2(1000);
begin
  v_sql := 'ALTER SYSTEM KILL SESSION '''||sid||','||serial ||''' IMMEDIATE';
  execute immediate v_sql;
end;
/

create or replace public synonym flush_all for sys.flush_all;
create or replace public synonym kill_session for sys.kill_session;

grant execute on sys.kill_session to kivi, hr;
grant execute on sys.flush_all to kivi, hr;

exit
