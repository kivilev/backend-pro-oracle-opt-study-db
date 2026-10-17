/*
  Детерминированное наполнение схемы kivi (копия install/kivi_objects/fill_data/*.sql с правками для стенда).
  Запуск под kivi:  @fill_kivi.sql <clients> <terrorists> <passports> <payments_per_day> <days> <seed>

  Отличия от оригинала (см. DESIGN.md, раздел 3):
   - перед каждой таблицей dbms_random.seed(seed + N) => одинаковые значения на всех машинах;
   - "client sample(1) order by dbms_random.value()" заменён на выбор двух client_id через dbms_random
     (SAMPLE использует свой генератор, seed на него не действует);
   - дни рождения клиентов считаются от фиксированной даты, а не от sysdate;
   - платежи, как и в оригинале, строятся от trunc(sysdate): пакеты курса (payment_check_pack,
     fill/clear_payments, финальная работа) работают относительно текущей даты;
   - объёмы берутся из профиля стенда (small/full), а не зашиты в код;
   - триггеры на время загрузки выключаются (быстрее; значения тех. полей задают DEFAULT-ы).
   - insert без /*+ append */: direct-path пачками по 10 тыс. строк каждый раз пишет выше HWM в новом экстенте,
     и таблицы «раздуваются» в разы (TERRORIST 5 млн строк -> 9 ГБ на 26ai Free; похоже, отсюда и 381 тыс. блоков
     TERRORIST_FLB_I и 108 тыс. блоков PASSPORT_BLACK_LIST на VPS курса). Обычный insert даёт компактные сегменты.
*/
whenever sqlerror exit failure
set serveroutput on
set timing on
define p_clients    = &1
define p_terrorists = &2
define p_passports  = &3
define p_pay_per_day = &4
define p_days       = &5
define p_seed       = &6

begin
  for t in (select table_name from user_tables where table_name in ('CLIENT','CLIENT_DATA','WALLET','ACCOUNT','PAYMENT','PAYMENT_DETAIL')) loop
    execute immediate 'alter table ' || t.table_name || ' disable all triggers';
  end loop;
end;
/

prompt === CLIENT / CLIENT_DATA / WALLET / ACCOUNT
declare
  c_client_count constant number := &p_clients;
  c_step_count   constant number := 10000;
  c_birth_anchor constant date   := date '2026-01-01';
  v_client_ids  t_number_array;
  v_currency_id currency.currency_id%type := 643;
  v_client_data t_client_data_array;
  v_wallets     t_number_pair_array;

  function get_random_client_email return client_data.field_value%type is
  begin
    return dbms_random.string('l', 10) || '@' || dbms_random.string('l', 10) || '.com';
  end;

  function get_random_client_mobile_phone return client_data.field_value%type is
  begin
    return '+' || trunc(dbms_random.value(79000000000, 79999999999));
  end;
begin
  dbms_random.seed(&p_seed + 1);
  common_pack.enable_manual_changes;

  for i in 1 .. c_client_count / c_step_count loop
    -- как в оригинале: один набор данных на пачку из 10 000 клиентов
    v_client_data := t_client_data_array(t_client_data(client_api_pack.c_first_name_field_id, dbms_random.string(opt => 'A', len => 6)),
                                         t_client_data(client_api_pack.c_last_name_field_id, dbms_random.string(opt => 'A', len => 8)),
                                         t_client_data(client_api_pack.c_birthday_field_id,
                                                       to_char(c_birth_anchor - trunc(dbms_random.value(7000, 15000)), 'YYYY-MM-DD')),
                                         t_client_data(client_api_pack.c_passport_series_field_id, dbms_random.string(opt => 'U', len => 4)),
                                         t_client_data(client_api_pack.c_passport_number_field_id, dbms_random.string(opt => 'U', len => 20)),
                                         t_client_data(client_api_pack.c_email_field_id, get_random_client_email()),
                                         t_client_data(client_api_pack.c_mobile_phone_field_id, get_random_client_mobile_phone()));

    select client_seq.nextval bulk collect into v_client_ids from dual connect by level <= c_step_count;

    insert into client (client_id, is_active, is_blocked)
      select value(t), client_api_pack.c_active, client_api_pack.c_not_blocked from table(v_client_ids) t;

    insert into client_data
      select value(c), value(t).field_id, value(t).field_value
        from table(v_client_ids) c, table(v_client_data) t;

    select t_number_pair(value(c), wallet_seq.nextval) bulk collect into v_wallets from table(v_client_ids) c;

    insert into wallet (wallet_id, client_id, status_id)
      select value(c).second, value(c).first, wallet_api_pack.c_wallet_status_active from table(v_wallets) c;

    insert into account (account_id, client_id, wallet_id, currency_id, balance)
      select account_seq.nextval, value(c).first, value(c).second, v_currency_id, 0 from table(v_wallets) c;

    commit;
  end loop;
end;
/

prompt === TERRORIST
declare
  v_total number := &p_terrorists;
  v_step  number := 10000;
  v_first_name varchar2(200);
  v_last_name  varchar2(200);
  v_first_names t_string_array := t_string_array('Oliver','Jake','Noah','James','Jack','Connor','Liam','John',
  'Harry','Callum','Mason','Robert','Jacob','Jacob','Jacob','Michael','Charlie','Kyle','William','William',
  'Thomas','Joe','Ethan','David','George','Reece','Michael','Richard','Oscar','Rhys','Alexander','Joseph',
  'James','Charlie','James','Charles','William','Damian','Daniel','Thomas','Amelia','Margaret','Emma','Mary',
  'Olivia','Samantha','Olivia','Patricia','Isla','Bethany','Sophia','Jennifer','Emily','Elizabeth','Isabella','Elizabeth',
  'Poppy','Joanne','Ava','Linda','Ava','Megan','Mia','Barbara','Isabella','Victoria','Emily','Susan',
  'Jessica','Lauren','Abigail','Margaret','Lily','Michelle','Madison','Jessica','Sophie','Tracy','Charlotte','Sarah');
  v_nums t_number_array;
  c_created_anchor constant date := date '2026-01-01';
begin
  dbms_random.seed(&p_seed + 2);
  select level bulk collect into v_nums from dual connect by level <= v_step;

  for i in 1 .. v_total / v_step loop
    v_first_name := v_first_names(trunc(dbms_random.value(1, v_first_names.count)));
    v_last_name  := dbms_random.string(opt => 'U', len => 10);

    insert into terrorist (first_name, last_name, birthday, reason, created_dtime)
      select /*+ cardinality(t 100000)*/ v_first_name, v_last_name,
             date '1984-01-21' + mod(rownum, 10000),
             'some reason ' || mod(rownum, 40),
             c_created_anchor - 1/24/60*rownum
        from table(v_nums) t;
    commit;
  end loop;
end;
/

prompt === PASSPORT_BLACK_LIST
declare
  v_total number := &p_passports;
  v_step  number := 10000;
begin
  dbms_random.seed(&p_seed + 3);
  for i in 1 .. v_total / v_step loop
    insert into passport_black_list (passport_series, passport_number, add_dtime)
      select trunc(dbms_random.value(1000, 9999)), trunc(dbms_random.value(100000, 999999)), date '2023-01-21' + mod(level, 100)
        from dual connect by level <= v_step;
    commit;
  end loop;
end;
/

prompt === IP_LIST / WORD_BLACK_LIST
exec dbms_random.seed(&p_seed + 4)
insert into ip_list
select level, dbms_random.string(opt => 'u', len => 10), decode(mod(level, 2), 0, 'W', 'B')
  from dual connect by level <= 10000;
commit;
exec dbms_random.seed(&p_seed + 5)
insert into word_black_list
select level, dbms_random.string(opt => 'x', len => 20)
  from dual connect by level <= 10000;
commit;

prompt === PAYMENT / PAYMENT_DETAIL (относительно trunc(sysdate))
@@fill_payments_det.sql &p_clients &p_pay_per_day &p_days &p_seed

begin
  for t in (select table_name from user_tables where table_name in ('CLIENT','CLIENT_DATA','WALLET','ACCOUNT','PAYMENT','PAYMENT_DETAIL')) loop
    execute immediate 'alter table ' || t.table_name || ' enable all triggers';
  end loop;
end;
/
