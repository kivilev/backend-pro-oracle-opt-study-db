/*
  Установка схемы HR (копия oracle_dbd_optimization_sql/install/hr_objects/hr_install.sql без spool и проверочного вывода).
  Запуск: sqlplus / as sysdba @hr_install.sql <PDB>
*/
whenever sqlerror exit failure
alter session set container = &&1;
ALTER SESSION SET CURRENT_SCHEMA=HR;
ALTER SESSION SET NLS_LANGUAGE=American;
ALTER SESSION SET NLS_TERRITORY=America;

@@hr_create.sql
@@hr_populate.sql
@@hr_code.sql

SELECT 'employees' AS "Table", 107 AS "provided", count(1) AS "actual" FROM hr.employees;
exit
