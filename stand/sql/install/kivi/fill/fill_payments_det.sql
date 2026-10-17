/*
  Детерминированная генерация платежей (копия fill_data/payment.sql с правками). Под kivi.
  @fill_payments_det.sql <clients> <payments_per_day> <days> <seed>
  Используется при установке и в tools/reset_payments.sql («освежить» платежи под текущую дату).
*/
declare
  v_payment_ids   t_number_array;
  v_data_value    payment_detail.field_value%type;
  v_field_ids     t_number_array := t_number_array(1, 2, 3, 4);
  v_payment_dtime payment.create_dtime%type;
  c_days_count        constant number := &3;
  v_payment_per_day   number := &2;
  v_diff_date_per_day number := 25;
  v_bulk_size         number := v_payment_per_day / v_diff_date_per_day;
  v_client_cnt        number := &1;
  v_a number;
  v_b number;
  v_client_id_min client.client_id%type;
  v_client_id_max client.client_id%type;
  v_today constant date := trunc(sysdate);
begin
  dbms_random.seed(&4 + 6);
  common_pack.enable_manual_changes;

  for i in 1 .. c_days_count loop
    for dd in 1 .. v_diff_date_per_day loop
      v_payment_dtime := (v_today - i + 1) + dbms_random.value(1, 24) / 24;

      select payment_seq.nextval bulk collect into v_payment_ids from dual connect by level <= v_bulk_size;

      -- вместо "client sample(1) order by dbms_random.value()": два случайных клиента через seed-генератор
      v_a := trunc(dbms_random.value(1, v_client_cnt));
      v_b := trunc(dbms_random.value(1, v_client_cnt));
      v_client_id_min := least(v_a, v_b);
      v_client_id_max := greatest(v_a, v_b);

      insert into payment
        (payment_id, create_dtime, summa, currency_id, from_client_id, to_client_id, status_change_reason, status)
        select value(t), v_payment_dtime, round(dbms_random.value(0, 100), 2), 840,
               trunc(dbms_random.value(v_client_id_min, v_client_id_max)),
               trunc(dbms_random.value(v_client_id_min, v_client_id_max)),
               decode(mod(rownum, 10), 1, 'reason', 2, 'reason', null),
               -- [stand] «новые» (status = 0) только за сегодня; старые платежи уже обработаны (0 -> 1),
               -- как на живой системе и на сервере курса.
               case when i = 1 then decode(mod(rownum, 10), 0, 0, 1, 2, 2, 3, 1)
                    else decode(mod(rownum, 10), 1, 2, 2, 3, 1) end
          from table(v_payment_ids) t;

      v_data_value := dbms_random.string(opt => 'A', len => 10);
      insert into payment_detail (payment_id, payment_create_dtime, field_id, field_value)
        select value(p), v_payment_dtime, value(pd), v_data_value
          from table(v_payment_ids) p cross join table(v_field_ids) pd;

      commit;
    end loop;
  end loop;
end;
/
