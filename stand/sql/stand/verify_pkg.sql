/*
  Пакет самопроверки стенда. Вызывать под kivi:  exec stand.verify.run
  Что проверяет:
    ENV/PARAM  — версия, платформа, параметры экземпляра, автосбор статистики, системная статистика;
    DATA       — число строк и «отпечаток» (сумма ora_hash) данных учебных таблиц;
    STATS      — num_rows / blocks / блокировка статистики;
    Cxx        — учебные запросы из пакетов kivi: план и число прочитанных блоков должны совпадать с эталоном;
  Метрики кейса: PHV (plan_hash_value), PLAN (операции плана), BUFFERS (cr+cu верхнего шага),
  ROWS (A-rows), STARTS, DISK_READS / ELAPSED_MS (только информативно — зависят от железа).
*/
create or replace package stand.verify authid current_user is
  procedure run;
  -- для расширений проверки (вызывать в той же сессии после run)
  procedure measure(p_tag varchar2);
  procedure ratio(p_bad varchar2, p_good varchar2);
end verify;
/

create or replace package body stand.verify is

  g_run_id  number;
  g_seq     number := 0;
  g_profile varchar2(10);
  g_arch    varchar2(10);

  type t_case_metrics is record (
    sql_id     varchar2(13),
    phv        number,
    plan_ops   varchar2(4000),
    buffers    number,
    out_rows   number,
    starts     number,
    disk_reads number,
    elapsed_ms number);

  type t_case_tab is table of t_case_metrics index by varchar2(10);
  g_cases t_case_tab;

  ------------------------------------------------------------------------------
  -- Кейсы. Тексты повторяют запросы из пакетов kivi (как их видит трейс: верхний регистр, :Bn),
  -- плюс hint gather_plan_statistics и метка. plan_hash_value от текста не зависит.

  c_terr      constant varchar2(500) := q'[SELECT /*+ index_ffs(t TERRORIST_FLB_I) gather_plan_statistics */ /* STAND:#TAG# */ COUNT(*) FROM TERRORIST T WHERE T.BIRTHDAY = TO_DATE(:B3 , 'YYYY-MM-DD') AND T.LAST_NAME = :B2 AND T.FIRST_NAME = :B1]';
  c_cd        constant varchar2(500) := q'[SELECT /*+ gather_plan_statistics */ /* STAND:#TAG# */ CL.CLIENT_ID ,CL.IS_ACTIVE FROM CLIENT_DATA CD JOIN CLIENT CL ON CL.CLIENT_ID = CD.CLIENT_ID WHERE CD.FIELD_ID = :B3 AND CD.FIELD_VALUE = :B2 AND CL.IS_ACTIVE = :B1 FOR UPDATE OF CL.CLIENT_ID NOWAIT]';
  c_pass      constant varchar2(500) := q'[SELECT /*+ gather_plan_statistics */ /* STAND:#TAG# */ COUNT(*) CNT FROM PASSPORT_BLACK_LIST T WHERE T.PASSPORT_SERIES = :B2 AND T.PASSPORT_NUMBER = :B1]';
  c_wal       constant varchar2(500) := q'[SELECT /*+ index(w1 WALLET_CLIENT_FK) index(w2 WALLET_CLIENT_FK) gather_plan_statistics */ /* STAND:#TAG# */ CL.IS_ACTIVE ,CL.IS_BLOCKED ,W.WALLET_ID ,W.STATUS_ID FROM CLIENT CL LEFT JOIN WALLET W ON W.CLIENT_ID = CL.CLIENT_ID WHERE CL.CLIENT_ID = :B1]';
  c_pi        constant varchar2(500) := q'[SELECT /*+ cardinality(pi 1000) leading(p pi) gather_plan_statistics */ /* STAND:#TAG# */ P.PAYMENT_ID ,P.CURRENCY_ID ,P.SUMMA ,P.FROM_CLIENT_ID ,P.TO_CLIENT_ID FROM TABLE(:B1 ) PI JOIN PAYMENT P ON P.PAYMENT_ID = VALUE(PI)]';
  c_sel       constant varchar2(500) := q'[SELECT /*+ gather_plan_statistics */ /* STAND:#TAG# */ P.PAYMENT_ID FROM PAYMENT P WHERE P.STATUS = :B2 AND ROWNUM <= :B1 FOR UPDATE SKIP LOCKED]';


  ------------------------------------------------------------------------------
  function is_match(p_act varchar2, p_exp varchar2, p_tol number) return boolean is
    v_a number;
    v_e number;
  begin
    if p_tol is null then
      return nvl(p_act, '~') = nvl(p_exp, '~');
    end if;
    v_a := to_number(p_act);
    v_e := to_number(p_exp);
    return abs(v_a - v_e) <= abs(v_e) * p_tol / 100;
  exception
    when value_error or invalid_number then
      return false;
  end;

  procedure put(p_check varchar2, p_metric varchar2, p_value varchar2) is
    v_exp    stand.expected.exp_value%type;
    v_tol    stand.expected.tol_pct%type;
    v_sev    stand.expected.severity%type;
    v_status varchar2(5);
  begin
    begin
      select exp_value, tol_pct, severity
        into v_exp, v_tol, v_sev
        from (select e.*
                from stand.expected e
               where e.profile in (g_profile, 'ANY')
                 and e.arch in (g_arch, 'ANY')
                 and e.check_id = p_check
                 and e.metric = p_metric
               order by case when e.arch = 'ANY' then 2 else 1 end,
                        case when e.profile = 'ANY' then 2 else 1 end)
       where rownum = 1;

      v_status := case
                    when v_sev = 'INFO' then 'INFO'
                    when is_match(p_value, v_exp, v_tol) then 'OK'
                    else v_sev
                  end;
    exception
      when no_data_found then
        -- информативные метрики (зависят от машины) эталона не имеют; для остальных эталона ещё нет
        v_status := case when p_metric in ('SQL_ID', 'DISK_READS', 'ELAPSED_MS', 'ELAPSED_RATIO') then 'INFO' else 'NEW' end;
    end;

    g_seq := g_seq + 1;
    insert into stand.result (run_id, seq, check_id, metric, act_value, exp_value, tol_pct, status)
    values (g_run_id, g_seq, p_check, p_metric, p_value, v_exp, v_tol, v_status);
    commit;
  end;

  function q1(p_sql varchar2) return varchar2 is
    v varchar2(4000);
  begin
    execute immediate p_sql into v;
    return v;
  exception
    when others then
      return 'ERR: ' || substr(sqlerrm, 1, 200);
  end;

  procedure flush is
  begin
    execute immediate 'begin flush_all; end;';
  end;

  ------------------------------------------------------------------------------
  procedure check_env is
    type t_list is table of varchar2(60);
    v_params t_list := t_list('optimizer_features_enable', 'optimizer_adaptive_plans', 'optimizer_adaptive_statistics',
                              'optimizer_dynamic_sampling', 'optimizer_mode', 'cpu_count', 'sga_target',
                              'pga_aggregate_target', 'db_block_size',
                              'db_file_multiblock_read_count', 'statistics_level', 'control_management_pack_access',
                              'job_queue_processes', 'processes',
                              'filesystemio_options', 'max_dump_file_size');
  begin
    put('ENV', 'VERSION',  q1('select version_full from v$instance'));
    put('ENV', 'PLATFORM', q1('select platform_name from v$database'));
    put('ENV', 'PROFILE',  g_profile);
    put('ENV', 'AUTOTASK_STATS',
        q1('select status from dba_autotask_client where client_name = ''auto optimizer stats collection'''));
    put('ENV', 'CPUSPEEDNW',
        q1('select to_char(pval1) from sys.aux_stats$ where sname = ''SYSSTATS_MAIN'' and pname = ''CPUSPEEDNW'''));
    -- db_cache_size / shared_pool_size в PDB показываются как 0 — берём фактические размеры пулов
    put('ENV', 'BUFFER_CACHE_MB', q1('select to_char(current_size / 1048576) from v$sga_dynamic_components where component = ''DEFAULT buffer cache'''));
    put('ENV', 'SHARED_POOL_MB',  q1('select to_char(current_size / 1048576) from v$sga_dynamic_components where component = ''shared pool'''));
    put('ENV', 'PARTITION_LARGE_EXTENTS', q1('select value from v$parameter where name = ''_partition_large_extents'''));
    put('ENV', 'FIX_CONTROLS_ON', q1('select to_char(count(*)) from v$system_fix_control where value = 1'));
    put('ENV', 'INVALID_OBJECTS',
        q1('select to_char(count(*)) from dba_objects where owner in (''KIVI'', ''HR'', ''STAND'') and status <> ''VALID'''));
    put('ENV', 'KIVI_JOBS_ENABLED',
        q1('select to_char(count(*)) from dba_scheduler_jobs where owner = ''KIVI'' and enabled = ''TRUE'''));

    for i in 1 .. v_params.count loop
      put('PARAM', upper(v_params(i)), q1('select value from v$parameter where name = ''' || v_params(i) || ''''));
    end loop;
  end;

  procedure check_data is
    procedure fp(p_table varchar2, p_expr varchar2) is
    begin
      put('DATA', p_table || '.ROWS', q1('select to_char(count(*)) from ' || p_table));
      put('DATA', p_table || '.HASH', q1('select to_char(sum(ora_hash(' || p_expr || '))) from ' || p_table));
    end;
  begin
    fp('CLIENT',              q'[client_id || '|' || is_active || '|' || is_blocked]');
    fp('CLIENT_DATA',         q'[client_id || '|' || field_id || '|' || field_value]');
    fp('WALLET',              q'[wallet_id || '|' || client_id || '|' || status_id]');
    fp('ACCOUNT',             q'[account_id || '|' || wallet_id || '|' || currency_id || '|' || balance]');
    fp('TERRORIST',           q'[first_name || '|' || last_name || '|' || to_char(birthday, 'YYYYMMDD') || '|' || reason]');
    fp('PASSPORT_BLACK_LIST', q'[passport_series || '|' || passport_number || '|' || to_char(add_dtime, 'YYYYMMDD')]');
    -- даты платежей зависят от дня установки => в отпечаток не входят
    fp('PAYMENT',             q'[payment_id || '|' || summa || '|' || from_client_id || '|' || to_client_id || '|' || status]');
    fp('PAYMENT_DETAIL',      q'[payment_id || '|' || field_id || '|' || field_value]');
    put('DATA', 'PAYMENT.DAYS', q1('select to_char(count(distinct trunc(create_dtime))) from payment'));
  end;

  procedure check_stats is
  begin
    for t in (select 'CLIENT' tn from dual union all select 'CLIENT_DATA' from dual union all
              select 'WALLET' from dual union all select 'ACCOUNT' from dual union all
              select 'TERRORIST' from dual union all select 'PASSPORT_BLACK_LIST' from dual union all
              select 'PAYMENT' from dual union all select 'PAYMENT_DETAIL' from dual) loop
      put('STATS', t.tn || '.NUM_ROWS', q1('select to_char(num_rows) from dba_tab_statistics where owner = ''KIVI'' and table_name = ''' || t.tn || ''' and object_type = ''TABLE'''));
      put('STATS', t.tn || '.BLOCKS',   q1('select to_char(blocks) from dba_tab_statistics where owner = ''KIVI'' and table_name = ''' || t.tn || ''' and object_type = ''TABLE'''));
      put('STATS', t.tn || '.LOCKED',   q1('select nvl(stattype_locked, ''NO'') from dba_tab_statistics where owner = ''KIVI'' and table_name = ''' || t.tn || ''' and object_type = ''TABLE'''));
    end loop;
    for i in (select 'TERRORIST_FLB_I' idx from dual union all select 'CLIENT_DATA_FIELD_I' from dual
              union all select 'PAYMENT_PK' from dual) loop
      put('STATS', i.idx || '.LEAF_BLOCKS', q1('select to_char(leaf_blocks) from dba_ind_statistics where owner = ''KIVI'' and index_name = ''' || i.idx || ''' and object_type = ''INDEX'''));
    end loop;
    put('STATS', 'PAYMENT.PARTITIONS', q1('select to_char(count(*)) from dba_tab_partitions where table_owner = ''KIVI'' and table_name = ''PAYMENT'''));
  end;

  ------------------------------------------------------------------------------
  -- Снимает метрики последнего выполнения запроса с меткой /* STAND:<tag> */
  procedure measure(p_tag varchar2) is
    m       t_case_metrics;
    v_child number;
  begin
    execute immediate
      'select sql_id, child_number, plan_hash_value
         from (select sql_id, child_number, plan_hash_value
                 from v$sql
                where sql_text like :t
                  and sql_text not like ''%v$sql%''
                  and command_type in (2, 3, 6, 7)
                order by last_active_time desc)
        where rownum = 1'
      into m.sql_id, v_child, m.phv
      using '%/* STAND:' || p_tag || ' */%';

    execute immediate
      'select last_cr_buffer_gets + last_cu_buffer_gets, last_output_rows, last_starts,
              last_disk_reads, round(last_elapsed_time / 1000)
         from v$sql_plan_statistics_all
        where sql_id = :s and child_number = :c and id = 1'
      into m.buffers, m.out_rows, m.starts, m.disk_reads, m.elapsed_ms
      using m.sql_id, v_child;

    execute immediate
      'select substr(listagg(id || '':'' || operation || nvl2(options, '' '' || options, null)
                             || nvl2(object_name, '' '' || object_name, null), '' / '')
                     within group (order by id), 1, 4000)
         from v$sql_plan
        where sql_id = :s and child_number = :c and id > 0'
      into m.plan_ops
      using m.sql_id, v_child;

    g_cases(p_tag) := m;

    put(p_tag, 'SQL_ID',     m.sql_id);
    put(p_tag, 'PHV',        to_char(m.phv));
    put(p_tag, 'PLAN',       m.plan_ops);
    put(p_tag, 'BUFFERS',    to_char(m.buffers));
    put(p_tag, 'ROWS',       to_char(m.out_rows));
    put(p_tag, 'STARTS',     to_char(m.starts));
    put(p_tag, 'DISK_READS', to_char(m.disk_reads));
    put(p_tag, 'ELAPSED_MS', to_char(m.elapsed_ms));
  exception
    when others then
      put(p_tag, 'ERROR', substr(sqlerrm, 1, 400));
  end;

  procedure ratio(p_bad varchar2, p_good varchar2) is
  begin
    if g_cases.exists(p_bad) and g_cases.exists(p_good) then
      put(p_bad || '/' || p_good, 'BUFFERS_RATIO',
          to_char(round(g_cases(p_bad).buffers / nullif(g_cases(p_good).buffers, 0))));
      put(p_bad || '/' || p_good, 'ELAPSED_RATIO',
          to_char(round(g_cases(p_bad).elapsed_ms / nullif(greatest(g_cases(p_good).elapsed_ms, 1), 0))));
    end if;
  end;

  function t(p_sql varchar2, p_tag varchar2) return varchar2 is
  begin
    return replace(p_sql, '#TAG#', p_tag);
  end;

  -- Каждый кейс: прогрев (очистка блоков после загрузки), flush, измеряемый прогон.
  procedure case_count3(p_tag varchar2, p_sql varchar2, b3 varchar2, b2 varchar2, b1 varchar2) is
    v number;
  begin
    for i in 1 .. 2 loop
      flush;
      execute immediate t(p_sql, p_tag) into v using b3, b2, b1;
    end loop;
    measure(p_tag);
  end;

  procedure case_passport(p_tag varchar2) is
    v number;
  begin
    for i in 1 .. 2 loop
      flush;
      execute immediate t(c_pass, p_tag) into v using 'ABCD', '123456';
    end loop;
    measure(p_tag);
  end;

  procedure case_client_data(p_tag varchar2) is
    rc   sys_refcursor;
    v1   number;
    v2   number;
  begin
    for i in 1 .. 2 loop
      flush;
      -- 7 = c_mobile_phone_field_id; такого телефона в данных нет
      open rc for t(c_cd, p_tag) using 7, '+19000000000', 1;
      loop
        fetch rc into v1, v2;
        exit when rc%notfound;
      end loop;
      close rc;
      rollback;
    end loop;
    measure(p_tag);
  end;

  procedure case_wallet(p_tag varchar2, p_sql varchar2) is
    v1 number; v2 number; v3 number; v4 number;
  begin
    for i in 1 .. 2 loop
      flush;
      execute immediate t(p_sql, p_tag) into v1, v2, v3, v4 using 1000;
    end loop;
    measure(p_tag);
  end;

  procedure case_table_bind(p_tag varchar2, p_sql varchar2) is
    v_ids kivi.t_number_array;
    rc    sys_refcursor;
    v1 number; v2 number; v3 number; v4 number; v5 number;
  begin
    execute immediate 'select payment_id from (select payment_id from payment where status = 0 order by payment_id) where rownum <= 10'
      bulk collect into v_ids;
    for i in 1 .. 2 loop
      flush;
      open rc for t(p_sql, p_tag) using v_ids;
      loop
        fetch rc into v1, v2, v3, v4, v5;
        exit when rc%notfound;
      end loop;
      close rc;
    end loop;
    measure(p_tag);
  end;

  procedure case_select_status(p_tag varchar2, p_sql varchar2) is
    rc sys_refcursor;
    v  number;
  begin
    for i in 1 .. 2 loop
      flush;
      open rc for t(p_sql, p_tag) using 0, 10;
      loop
        fetch rc into v;
        exit when rc%notfound;
      end loop;
      close rc;
      rollback;
    end loop;
    measure(p_tag);
  end;

  procedure run_cases is
  begin
    -- ДЗ: регистрация клиента
    case_count3('C01', c_terr, '1982-01-21', 'Smith', 'John');
    case_client_data('C02');
    case_passport('C03');
    -- финальная работа: обработка платежей
    case_wallet('C04', c_wal);
    case_table_bind('C05', c_pi);
    case_select_status('C06', c_sel);
  end;

  ------------------------------------------------------------------------------
  procedure run is
    v_ok   number;
    v_fail number;
    v_warn number;
    v_new  number;
  begin
    select stand.run_seq.nextval into g_run_id from dual;
    g_seq := 0;
    g_cases.delete;
    begin
      select value into g_profile from stand.config where param = 'PROFILE';
    exception when no_data_found then g_profile := 'small';
    end;
    begin
      select value into g_arch from stand.config where param = 'ARCH';
    exception when no_data_found then g_arch := 'ANY';
    end;

    check_env;
    check_data;
    check_stats;
    run_cases;

    select count(case when status = 'OK' then 1 end), count(case when status = 'FAIL' then 1 end),
           count(case when status = 'WARN' then 1 end), count(case when status = 'NEW' then 1 end)
      into v_ok, v_fail, v_warn, v_new
      from stand.result where run_id = g_run_id;

    dbms_output.put_line('RUN_ID=' || g_run_id || ' profile=' || g_profile || ' arch=' || g_arch ||
                         ' OK=' || v_ok || ' FAIL=' || v_fail || ' WARN=' || v_warn || ' NEW=' || v_new);
    dbms_output.put_line(case when v_fail = 0 then 'STAND CHECK PASSED' else 'STAND CHECK FAILED' end);
  end;

end verify;
/
show errors
