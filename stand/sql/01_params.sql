/*
  Стенд курса «Оптимизация Oracle SQL». Шаг 1: фиксированные параметры экземпляра.
  Запуск: sqlplus / as sysdba (CDB$ROOT). Oracle AI Database 26ai Free: SGA+PGA не больше 2 ГБ, 2 CPU, 12 ГБ данных. После скрипта нужен рестарт экземпляра (делает stand_setup.sh).

  Зачем: чтобы оптимизатор и исполнение вели себя одинаково на любой машине,
  всё, что Oracle по умолчанию вычисляет «от железа», задаём явно. Обоснование — DESIGN.md, раздел 4.
*/
whenever sqlerror exit failure

-- Память: ручное управление SGA (без ASMM), иначе buffer cache «плавает» и меняется число физических чтений
alter system set sga_target             = 0     scope=spfile;
alter system set sga_max_size           = 1200M scope=spfile;
alter system set shared_pool_size       = 480M  scope=spfile;
-- намеренно меньше данных учебных таблиц => физические чтения
alter system set db_cache_size          = 320M  scope=spfile;
alter system set large_pool_size        = 32M   scope=spfile;
alter system set java_pool_size         = 64M   scope=spfile;
-- для Data Pump
alter system set streams_pool_size      = 32M   scope=spfile;
-- небольшой PGA, одинаковый у всех: большие сортировки и соединения уходят в temp
alter system set pga_aggregate_target   = 256M  scope=spfile;
-- минимум, который разрешает Oracle
alter system set pga_aggregate_limit    = 2G    scope=spfile;

-- Прямой ввод-вывод: после flush buffer_cache блоки читаются с диска, а не из page cache Linux внутри VM Docker,
-- иначе «физические» чтения почти бесплатны и разница плохо/хорошо по времени смазывается.
-- Датафайлы лежат в именованном томе Docker (ext4 в VM) — O_DIRECT там поддерживается.
-- Если БД не стартует с ORA-27041/ORA-27054 (нет O_DIRECT) — вернуть NONE.
alter system set filesystemio_options = SETALL scope=spfile;

-- CPU: не зависит от числа ядер машины студента (2 — потолок Oracle Free).
-- Параллельное выполнение в Free отключено лицензионно (v$option 'Parallel execution' = FALSE).
alter system set cpu_count              = 2     scope=spfile;

-- Оптимизатор: уровень 19c, под который написан курс (слайды, эталонные трейсы). Free 26ai = 23.26,
-- OFE='19.1.0' отключает новые трансформации 21c–26ai. Вернуть родное поведение: alter session set optimizer_features_enable='23.1.0'
alter system set optimizer_features_enable     = '19.1.0' scope=spfile;
-- как в 19c по умолчанию и на VPS курса
alter system set optimizer_adaptive_plans      = TRUE     scope=spfile;
alter system set optimizer_adaptive_statistics = FALSE    scope=spfile;
alter system set optimizer_dynamic_sampling    = 2        scope=spfile;
alter system set optimizer_mode                = ALL_ROWS scope=spfile;
alter system set optimizer_index_cost_adj      = 100      scope=spfile;
alter system set optimizer_index_caching       = 0        scope=spfile;
-- Как на VPS курса (трейс 10053: db_file_multiblock_read_count = 4, _db_file_optimizer_read_count = 4):
-- FTS читает по 4 блока за вызов, и CBO считает стоимость с тем же MBRC => планы как на VPS
-- (запросы по CLIENT_DATA идут через INDEX RANGE SCAN CLIENT_DATA_FIELD_I, а не HASH JOIN двух FTS).
alter system set db_file_multiblock_read_count = 4 scope=spfile;

-- Диагностика (EE): AWR / ASH / SQL Monitor нужны урокам 2–3
alter system set statistics_level               = TYPICAL scope=spfile;
alter system set control_management_pack_access = 'DIAGNOSTIC+TUNING' scope=spfile;

-- Resource Manager в Free недоступен (v$option) — планы окон обслуживания CPU не режут.

-- Интервальные секции без «больших» начальных экстентов (8 МБ на секцию): иначе FTS по PAYMENT
-- читает в разы больше блоков, чем занимают данные (так же сделано в стенде курса по секционированию)
alter system set "_partition_large_extents" = FALSE scope=spfile;
alter system set "_index_partition_large_extents" = FALSE scope=spfile;

-- Прочее
alter system set processes           = 300 scope=spfile;
alter system set open_cursors        = 500 scope=spfile;
-- нужен для «шумного соседа»
alter system set job_queue_processes = 10  scope=spfile;
alter system set deferred_segment_creation = TRUE scope=spfile;

exit
