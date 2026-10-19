/*
  Сдвинуть окно платежей к сегодняшней дате и включить джобы платежей. Под kivi.
  Вызывается при каждом старте контейнера (startdb/01_stand_start.sh): если стенд был выключен несколько дней,
  clear_payments удаляет секции старше 45 дней, а fill_payments догенерирует пропущенные дни.
  Дальше то же самое каждый час делают FILL_PAYMENT_JOB и CLEAR_PAYMENTS_JOB.
  Вручную:
    docker exec oracle-opt-study-db sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @/opt/stand/sql/tools/payments_catchup.sql
*/
whenever sqlerror exit failure
set serveroutput on
exec clear_payments
exec fill_payments
begin
  dbms_scheduler.enable('CLEAR_PAYMENTS_JOB');
  dbms_scheduler.enable('FILL_PAYMENT_JOB');
end;
/
exit
