#!/bin/bash
# Выполняется entrypoint-ом gvenzl/oracle-free один раз при первом старте (новая БД).
# Вся логика — в /opt/stand/bin/stand_setup.sh; лог дублируется в том данных.
bash /opt/stand/bin/stand_setup.sh 2>&1 | tee -a /opt/oracle/oradata/stand_setup.log
