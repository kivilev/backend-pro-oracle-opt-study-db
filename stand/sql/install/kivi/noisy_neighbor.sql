/*
  «Шумный сосед» внутри БД: фоновая аналитическая джоба CLIENT_WALLET_ANALYSIS_JOB
  (копия install/kivi_objects/create_analysis_job.sql). Под kivi.

    @noisy_neighbor.sql create   -- создать выключенной (делает установка)
    @noisy_neighbor.sql on       -- включить (раз в час) и сразу запустить один прогон в фоне
    @noisy_neighbor.sql off      -- выключить и остановить текущий прогон

  Нагрузку на CPU/диск контейнера даёт отдельный скрипт noise/system_load.sh (см. README).
*/
set serveroutput on
define p_mode = &1

declare
  c_job constant varchar2(30) := 'CLIENT_WALLET_ANALYSIS_JOB';
  v_cnt number;
begin
  select count(*) into v_cnt from user_scheduler_jobs where job_name = c_job;

  if '&p_mode' = 'create' then
    if v_cnt > 0 then
      dbms_scheduler.drop_job(job_name => c_job, force => true);
    end if;
    dbms_scheduler.create_job(job_name        => c_job,
                              job_type        => 'STORED_PROCEDURE',
                              job_action      => 'client_wallet_analysis_proc',
                              start_date      => systimestamp,
                              repeat_interval => 'FREQ=HOURLY; INTERVAL=1',
                              end_date        => null,
                              enabled         => false,  -- [stand] по умолчанию выключена
                              auto_drop       => false,
                              comments        => 'Job to analyze client wallet data hourly for business intelligence');
    dbms_output.put_line('Job ' || c_job || ' created (disabled)');
  elsif '&p_mode' = 'on' then
    dbms_scheduler.enable(c_job);
    dbms_scheduler.run_job(job_name => c_job, use_current_session => false);
    dbms_output.put_line('Job ' || c_job || ' enabled and started');
  elsif '&p_mode' = 'off' then
    dbms_scheduler.disable(c_job, force => true);
    begin
      dbms_scheduler.stop_job(c_job, force => false);
    exception
      when others then null;  -- не запущена
    end;
    dbms_output.put_line('Job ' || c_job || ' disabled');
  else
    raise_application_error(-20001, 'mode must be create | on | off');
  end if;
end;
/
