/*
  Служебная схема STAND: конфигурация стенда, эталоны и результаты самопроверки, пакет verify.
  Запуск: sqlplus / as sysdba @stand_objects.sql <PDB>
*/
whenever sqlerror exit failure
alter session set container = &&1;

-- повторный запуск шага: убрать то, что успело создаться
begin
  for o in (select object_name, object_type from dba_objects
             where owner = 'STAND' and object_type in ('TABLE', 'SEQUENCE', 'PACKAGE')) loop
    execute immediate 'drop ' || o.object_type || ' stand.' || o.object_name ||
                      case when o.object_type = 'TABLE' then ' cascade constraints purge' end;
  end loop;
end;
/

create table stand.config
( param varchar2(30)  primary key
, value varchar2(200)
);

create table stand.expected
( profile   varchar2(10)  default 'ANY' not null   -- small | full | ANY
, arch      varchar2(10)  default 'ANY' not null   -- x86_64 | aarch64 | ANY
, check_id  varchar2(60)  not null
, metric    varchar2(60)  not null
, exp_value varchar2(4000)
, tol_pct   number                                  -- null = точное совпадение, иначе допуск в %
, severity  varchar2(5)   default 'FAIL' not null   -- FAIL | WARN | INFO
, note      varchar2(400)
, constraint expected_pk primary key (profile, arch, check_id, metric)
, constraint expected_sev_chk check (severity in ('FAIL', 'WARN', 'INFO'))
);

create table stand.result
( run_id    number        not null
, run_dtime date          default sysdate not null
, seq       number        not null
, check_id  varchar2(60)  not null
, metric    varchar2(60)  not null
, act_value varchar2(4000)
, exp_value varchar2(4000)
, tol_pct   number
, status    varchar2(5)   not null                  -- OK | FAIL | WARN | INFO | NEW
);

create sequence stand.run_seq;

-- verify работает с правами вызывающего (kivi): запросы кейсов парсятся в схеме kivi, как у студента.
grant execute on kivi.t_number_array to stand;

grant select on stand.config   to kivi;
grant select on stand.expected to kivi;
grant select, insert, delete on stand.result to kivi;
grant select on stand.run_seq  to kivi;

@@verify_pkg.sql

-- "created with compilation errors" не вызывает sqlerror => проверяем явно
declare
  v number;
begin
  select count(*) into v from dba_errors where owner = 'STAND';
  if v > 0 then
    raise_application_error(-20001, 'STAND.VERIFY compiled with ' || v || ' errors');
  end if;
end;
/

grant execute on stand.verify to kivi;

exit
