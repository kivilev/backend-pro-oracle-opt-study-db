-- Эталоны, не зависящие от профиля данных: окружение и параметры. Известны заранее (задаются установкой).
-- Метрики данных, статистики и кейсов — в expected_<profile>.sql (снимаются tools/capture_expected.sql).
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'VERSION', null, null, 'INFO', 'Oracle AI Database 26ai Free 23.26.x (одинаковая на amd64 и arm64)');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'PLATFORM', null, null, 'INFO', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'PROFILE', null, null, 'INFO', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'AUTOTASK_STATS', 'DISABLED', null, 'FAIL', 'автосбор статистики выключен');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'CPUSPEEDNW', '2000', null, 'FAIL', 'системная статистика зафиксирована');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'FIX_CONTROLS_ON', null, null, 'INFO', 'различается между 19.3 и 19.19 — смотреть при расхождении планов');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'INVALID_OBJECTS', '0', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'KIVI_JOBS_ENABLED', '2', null, 'WARN', 'включены FILL_PAYMENT_JOB и CLEAR_PAYMENTS_JOB, шумный сосед выключен');

insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'OPTIMIZER_FEATURES_ENABLE', '19.1.0', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'OPTIMIZER_ADAPTIVE_PLANS', 'TRUE', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'OPTIMIZER_ADAPTIVE_STATISTICS', 'FALSE', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'OPTIMIZER_DYNAMIC_SAMPLING', '2', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'OPTIMIZER_MODE', 'ALL_ROWS', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'CPU_COUNT', '2', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'SGA_TARGET', '0', null, 'FAIL', 'ручное управление SGA');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'BUFFER_CACHE_MB', '300', null, 'FAIL', 'db_cache_size=320M, округление до гранулы');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'SHARED_POOL_MB', '480', null, 'WARN', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'ENV', 'PARTITION_LARGE_EXTENTS', 'FALSE', null, 'FAIL', 'без 8-МБ экстентов на каждую интервальную секцию');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'JOB_QUEUE_PROCESSES', '10', null, 'WARN', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'PROCESSES', '300', null, 'INFO', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'PGA_AGGREGATE_TARGET', '268435456', null, 'FAIL', '256M');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'DB_BLOCK_SIZE', '8192', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'DB_FILE_MULTIBLOCK_READ_COUNT', null, null, 'INFO', 'выводится Oracle; при расхождении — смотреть причину');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'STATISTICS_LEVEL', 'TYPICAL', null, 'FAIL', null);
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'CONTROL_MANAGEMENT_PACK_ACCESS', 'DIAGNOSTIC+TUNING', null, 'WARN', 'нужно для AWR/ASH/SQL Monitor');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'FILESYSTEMIO_OPTIONS', 'SETALL', null, 'WARN', 'прямой I/O: физические чтения действительно с диска');
insert into stand.expected (profile, arch, check_id, metric, exp_value, tol_pct, severity, note) values ('ANY', 'ANY', 'PARAM', 'MAX_DUMP_FILE_SIZE', 'UNLIMITED', null, 'FAIL', 'иначе трейс режется на *_1.trc, *_2.trc, а сверх лимита теряется');
commit;
