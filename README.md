# Учебный стенд курса «Оптимизация Oracle SQL»

Стенд — это ваша личная база Oracle со схемами курса `kivi` и `hr`. Он работает у вас на компьютере в Docker.
У всех студентов данные и настройки одинаковые, поэтому планы запросов и число прочитанных блоков совпадают с тем, что показывает преподаватель.

## 1. Установите Docker (один раз)

1. Скачайте и установите **Docker Desktop**: https://www.docker.com/products/docker-desktop/
2. Запустите его и дождитесь статуса «Engine running».

Нужно: 4 ГБ свободной оперативной памяти и 20 ГБ места на диске.

## 2. Запустите стенд (одна команда, один раз)

Откройте терминал (Windows — PowerShell, Mac — Terminal) и выполните:

```
docker run -d --name oracle-opt-study-db -p 127.0.0.1:1521:1521 --shm-size=1g --memory=3g -v oracle-opt-study-data:/opt/oracle/oradata ghcr.io/kivilev/oracle-opt-study-db:latest
```

Первый запуск занимает **15–30 минут**: создаётся база и загружаются данные. Следить за ходом:

```
docker logs -f oracle-opt-study-db
```

Стенд готов, когда в конце появится строка `STAND IS READY`. Выйти из просмотра лога — `Ctrl+C`.

## 3. Подключитесь

| | |
|---|---|
| Host / Port | `localhost` / `1521` |
| Service name | `FREEPDB1` |
| Пользователь / пароль | `kivi` / `booble12` (основная схема курса) |
| Схема hr | `hr` / `booble12` |
| SYS | `sys` / `booble34`, роль SYSDBA |

Строка подключения: `kivi/booble12@//localhost:1521/FREEPDB1` (SQL Developer, DBeaver, PL/SQL Developer, Toad).

## 4. Каждый день

| Что сделать | Команда |
|---|---|
| Выключить стенд | `docker stop oracle-opt-study-db` |
| Включить стенд (1–2 минуты) | `docker start oracle-opt-study-db` |

Всё, что вы сделали в базе (индексы, изменения, результаты ДЗ), **сохраняется** между выключениями и перезагрузками компьютера.

Начать с чистого стенда (всё ваше удалится!):

```
docker rm -f oracle-opt-study-db
docker volume rm oracle-opt-study-data
```

Затем снова команда из шага 2.

## 5. Трассировка и tkprof

Трейс-файлы создаются внутри стенда, там же есть `tkprof`.

1. Список последних трейсов:
   ```
   docker exec oracle-opt-study-db bash -c "ls -t /opt/oracle/diag/rdbms/free/FREE/trace/*.trc | head -5"
   ```
2. Разобрать трейс (подставьте имя файла):
   ```
   docker exec oracle-opt-study-db tkprof /opt/oracle/diag/rdbms/free/FREE/trace/ИМЯ.trc /tmp/out.txt sys=no sort=prsela,fchela,exeela
   ```
3. Скопировать результат к себе в текущую папку:
   ```
   docker cp oracle-opt-study-db:/tmp/out.txt .
   ```

Так же копируется и сам трейс: `docker cp oracle-opt-study-db:/opt/oracle/diag/rdbms/free/FREE/trace/ИМЯ.trc .`

## 6. Чем стенд отличается от сервера из лекций

- **Время** выполнения зависит от вашего компьютера, и тормоза короче, чем на слайдах. Сравнивайте план, Buffers (query/cr) и разницу «до/после».
  Перед замерами вызывайте `exec flush_all`.
- **SQL Monitor** сам записывает только запросы дольше 5 секунд. Чтобы получить отчёт по запросу, включите мониторинг по его sql_id и выполните код ещё раз:
  ```
  alter session set events 'sql_monitor [sql: ВАШ_SQL_ID] force=true';
  ```
- **AWR:** при получении плана из AWR укажите `awr_location`:
  ```
  select * from table(dbms_xplan.display_workload_repository(sql_id => 'ВАШ_SQL_ID', awr_location => 'AWR_PDB'));
  ```
- Статистика схемы `kivi` **заблокирована**. Если вы создали индекс, соберите по нему статистику:
  `exec dbms_stats.gather_index_stats('KIVI', 'ИМЯ_ИНДЕКСА', force => true)`
- Параллельного выполнения в бесплатной версии Oracle нет: хинт `parallel` игнорируется.

## 7. Если что-то не так

- **Порт 1521 занят** другой базой: в команде из шага 2 замените `127.0.0.1:1521:1521` на `127.0.0.1:1522:1521` и подключайтесь к порту 1522.
- **В логе нет `STAND IS READY` дольше часа** или видно `FAILED`: пришлите преподавателю вывод команды
  `docker exec oracle-opt-study-db cat /opt/oracle/oradata/stand_setup.log`.
- **Проверить, что стенд «правильный»** (до выполнения ДЗ, около 3 минут):
  ```
  docker exec oracle-opt-study-db sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @/opt/stand/sql/verify_stand.sql
  ```
  В конце должно быть `STAND CHECK PASSED`.
