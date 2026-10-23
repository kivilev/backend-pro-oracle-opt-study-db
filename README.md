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
docker run -d --name oracle-opt-study-db -p 127.0.0.1:1521:1521 -p 127.0.0.1:2222:2222 --cpus=2 --shm-size=1g --memory=3g -v oracle-opt-study-data:/opt/oracle/oradata ghcr.io/kivilev/oracle-opt-study-db:latest
```

Порт `1521` — база, порт `2222` — вход на стенд по SSH/SFTP (раздел 6). Оба открыты только на вашем компьютере (`127.0.0.1`).

`--cpus=2` обязателен: Oracle Free использует 2 ядра, и с этим лимитом время запросов (и упражнение с «шумным соседом») одинаково у всех.
Не подключайте каталог трейсов к папке Windows/Mac через `-v`: запись трейса на диск хоста замедляет трассируемую сессию в разы. Трейсы забирайте командой `get-trace` или по SFTP (разделы 5 и 6).

Сначала Docker скачает образ (около 3–4 ГБ, зависит от интернета). Сам первый запуск занимает **2–5 минут**: готовая база копируется на ваш диск, и даты платежей подстраиваются под сегодняшний день. Следить за ходом:

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

Трейс-файлы создаются внутри стенда, там же есть `tkprof`. Чтобы потом найти свой трейс, перед включением трассировки задайте ему метку:

```
alter session set tracefile_identifier = 'МОЙ_ТЕСТ';
alter session set events '10046 trace name context forever, level 12';
-- ваш код
alter session set events '10046 trace name context off';
```

**Забрать трейс и отчёт tkprof** (2 команды, в терминале на вашем компьютере):

```
docker exec oracle-opt-study-db get-trace МОЙ_ТЕСТ
docker cp oracle-opt-study-db:/tmp/trace-out/. .
```

В текущей папке появятся сам трейс (`*.trc`, его можно открыть в orasrp) и отчёт tkprof (`*.trc.txt`). Без метки `get-trace` берёт самый свежий трейс.

**Без терминала, прямо из IDE.** Сразу после трассировки, в той же сессии:

```
select payload
  from v$diag_trace_file_contents
 where trace_filename = (select regexp_substr(value, '[^/]+$') from v$diag_info where name = 'Default Trace File')
 order by line_number;
```

Результат сохраните в файл средствами IDE (экспорт результата запроса). Так вы получите сырой трейс; tkprof запускается только на стенде.

Ещё трейсы можно забирать мышкой по SFTP (WinSCP), см. раздел 6.

## 6. Вход на стенд по SSH и SFTP (как на сервер)

На стенде работает SSH-сервер. Можно зайти на него, как DBA заходит на сервер базы: консоль Linux, `sqlplus / as sysdba`, `adrci`, `tkprof`, alert log, `top`, `vmstat`.

| | |
|---|---|
| Host / Port | `localhost` / `2222` |
| Пользователь / пароль | `oracle` / `booble34` |
| Протокол в WinSCP | SFTP |

- **Консоль:** `ssh -p 2222 oracle@localhost` (Windows PowerShell, Mac Terminal) или PuTTY.
- **Файлы:** WinSCP (Windows), Cyberduck или FileZilla (Mac). Сразу после входа вы в домашнем каталоге `/opt/oracle`.
  Папка `trace` в нём ведёт к трейсам базы (`/opt/oracle/diag/rdbms/free/FREE/trace`).
- Полезное на стенде:
  ```
  sqlplus / as sysdba                     # вход под SYS без пароля, как у DBA
  ls -lt ~/trace/*.trc | head             # свежие трейсы
  tkprof ~/trace/ИМЯ.trc /tmp/out.txt sys=no sort=prsela,fchela,exeela
  tail -f ~/trace/alert_FREE.log          # alert log
  ```

Пароль учебный и опубликован здесь, поэтому порт `2222` открыт только для вашего компьютера (`127.0.0.1` в команде из шага 2). Не меняйте это на `-p 2222:2222`: тогда на стенд сможет зайти кто угодно из вашей сети.

Если стенд создан до появления SSH, в контейнере нет порта 2222. Пересоздайте контейнер, данные при этом сохранятся (они на томе `oracle-opt-study-data`):

```
docker pull ghcr.io/kivilev/oracle-opt-study-db:latest
docker rm -f oracle-opt-study-db
```

Затем снова команда из шага 2 (без `docker volume rm`).

## 7. Чем стенд отличается от сервера из лекций

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

## 8. Если что-то не так

- **Порт 1521 занят** другой базой: в команде из шага 2 замените `127.0.0.1:1521:1521` на `127.0.0.1:1522:1521` и подключайтесь к порту 1522.
  Так же для SSH: порт 2222 занят → `127.0.0.1:2223:2222`, подключайтесь к 2223.
- **В логе нет `STAND IS READY` дольше 15 минут** или видно `ОШИБКА`: пришлите преподавателю вывод команды
  `docker logs oracle-opt-study-db`.
- **Проверить, что стенд «правильный»** (до выполнения ДЗ, около 3 минут):
  ```
  docker exec oracle-opt-study-db sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @/opt/stand/sql/verify_stand.sql
  ```
  В конце должно быть `STAND CHECK PASSED`.
