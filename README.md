# Учебный стенд курса «Оптимизация Oracle SQL»

Ваша личная база Oracle в Docker со схемами курса **kivi** (платёжная система) и **hr**.
Данные, статистика и настройки у всех студентов одинаковые. Медленные запросы из домашних заданий будут медленными
**тем же планом** и с **тем же числом прочитанных блоков**, что у преподавателя.

Внутри — Oracle AI Database 26ai Free. Это бесплатная версия от Oracle, ничего скачивать с сайта Oracle и регистрироваться не нужно.

## 1. Установите Docker (один раз)

Скачайте и установите **Docker Desktop**: https://www.docker.com/products/docker-desktop/ (Windows, Mac, Linux).
Запустите его и дождитесь зелёного статуса «Engine running».

Нужно: 4 ГБ свободной памяти и 20 ГБ места на диске (образ ≈ 3 ГБ, база ≈ 9 ГБ).

## 2. Запустите стенд (одна команда)

Откройте терминал (Windows: PowerShell; Mac: Terminal) и выполните:

```
docker run -d --name oracle-opt-study-db -p 127.0.0.1:1521:1521 --shm-size=1g --memory=3g -v oracle-opt-study-data:/opt/oracle/oradata ghcr.io/kivilev/oracle-opt-study-db:latest
```

Первый запуск занимает **около 25–40 минут**: создаются схемы и генерируются данные (на тестовой машине — 25 минут). Следить за ходом можно так:

```
docker logs -f oracle-opt-study-db
```

Стенд готов, когда в конце лога появится:

```
STAND IS READY (profile=small)
STAND: STAND CHECK PASSED
```

Выйти из просмотра лога: `Ctrl+C` (стенд при этом продолжит работать).

## 3. Подключитесь

| Параметр | Значение |
|---|---|
| Host | `localhost` |
| Port | `1521` |
| Service name | `FREEPDB1` |
| Пользователь / пароль | `kivi` / `booble12` (схема курса), `hr` / `booble12` |
| SYS (as SYSDBA) | `sys` / `booble34` |

Строка подключения: `kivi/booble12@//localhost:1521/FREEPDB1`. Подходят SQL Developer, DBeaver, PL/SQL Developer, Toad.

## 4. Каждый день

| Что сделать | Команда |
|---|---|
| Остановить стенд | `docker stop oracle-opt-study-db` |
| Запустить снова (1–2 минуты) | `docker start oracle-opt-study-db` |
| Проверить, что стенд «правильный» (≈3 мин) | `docker exec oracle-opt-study-db sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @/opt/stand/sql/verify_stand.sql` |
| Посмотреть учебные кейсы последней проверки | `docker exec oracle-opt-study-db sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @/opt/stand/sql/tools/show_cases.sql` |
| Включить «шумного соседа» в БД | `docker exec oracle-opt-study-db sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @/opt/stand/sql/install/kivi/noisy_neighbor.sql on` (выключить: `off`) |
| Нагрузить CPU и диск | `docker exec oracle-opt-study-db bash /opt/stand/noise/start_noise.sh`; остановить: `docker exec oracle-opt-study-db bash /opt/stand/noise/stop_noise.sh` |
| Освежить платежи под сегодняшнюю дату | `docker exec oracle-opt-study-db bash -c "cd /opt/stand/sql/tools && sqlplus -s kivi/booble12@//localhost:1521/FREEPDB1 @reset_payments.sql"` |
| Начать с нуля (всё удалится!) | `docker rm -f oracle-opt-study-db` и `docker volume rm oracle-opt-study-data`, затем снова команда из шага 2 |

## 5. Трейсы и tkprof

Трейс-файлы лежат внутри контейнера, `tkprof` там тоже есть:

```
docker exec oracle-opt-study-db bash -c "ls -t /opt/oracle/diag/rdbms/free/FREE/trace/*.trc | head -5"
docker exec oracle-opt-study-db tkprof /opt/oracle/diag/rdbms/free/FREE/trace/<файл>.trc /tmp/out.txt sys=no sort=prsela,fchela,exeela
docker cp oracle-opt-study-db:/tmp/out.txt .
```

## 6. Что важно знать

- **Время** выполнения у всех разное, оно зависит от компьютера. Сравнивайте план, Buffers, A-Rows и отношение «до/после».
- Статистика схемы `kivi` **заблокирована**, автосбор выключен, поэтому планы сами не меняются.
  Если в ДЗ вы создали индекс, соберите по нему статистику: `exec dbms_stats.gather_index_stats('KIVI', 'ИМЯ_ИНДЕКСА', force => true)`.
- Оптимизатор работает на уровне Oracle 19c (`optimizer_features_enable = 19.1.0`), как на слайдах курса.
- В бесплатной версии Oracle **нет параллельного выполнения** (хинт `parallel` игнорируется) и SQL Quarantine.
  Эти темы бонусных уроков разбираются по готовым отчётам из материалов курса.

## 7. Если что-то пошло не так

- Порт 1521 занят другой базой: замените в команде `127.0.0.1:1521:1521` на `127.0.0.1:1522:1521` и подключайтесь к порту 1522.
- Лог установки: `docker exec oracle-opt-study-db cat /opt/oracle/oradata/stand_setup.log`.
- Установку можно продолжить с упавшего шага: `docker exec oracle-opt-study-db bash /opt/stand/bin/stand_setup.sh`.
- Самопроверка выдала `STAND CHECK FAILED`: пришлите её вывод преподавателю.
