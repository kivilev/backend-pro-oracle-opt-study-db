/*
  Финализация установленного стенда перед `docker commit` (запекание образа). Под SYSDBA в CDB$ROOT:
  ужимаем UNDO и TEMP после загрузки данных, чтобы образ был меньше, и останавливаем БД.
*/
whenever sqlerror exit failure
set serveroutput on feedback on

alter session set container = FREEPDB1;

-- UNDO PDB после загрузки ~3 ГБ: создаём маленький, переключаемся, старый удаляем
create undo tablespace undo_stand datafile '/opt/oracle/oradata/FREE/FREEPDB1/undo_stand01.dbf'
  size 128M autoextend on next 64M maxsize 4G;
alter system set undo_tablespace = undo_stand;

declare
  v_name varchar2(128);
begin
  for t in (select tablespace_name from dba_tablespaces
             where contents = 'UNDO' and tablespace_name <> 'UNDO_STAND') loop
    v_name := t.tablespace_name;
    for i in 1 .. 30 loop
      begin
        execute immediate 'drop tablespace ' || v_name || ' including contents and datafiles';
        dbms_output.put_line('dropped ' || v_name);
        exit;
      exception
        when others then
          -- ORA-30013: сегменты отката ещё заняты — ждём
          if i = 30 then raise; end if;
          dbms_session.sleep(10);
      end;
    end loop;
  end loop;
end;
/

alter tablespace temp shrink space keep 64M;

select tablespace_name, round(sum(bytes) / 1048576) mb from dba_data_files group by tablespace_name order by 1;

alter session set container = CDB$ROOT;
alter tablespace temp shrink space keep 64M;
shutdown immediate
exit
