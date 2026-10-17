# check=skip=SecretsUsedInArgOrEnv
# Учебный стенд курса «Оптимизация Oracle SQL» на Oracle AI Database 26ai Free.
# Это УСТАНОВОЧНЫЙ образ: база курса ставится при первом старте контейнера.
# Студентам публикуется «запечённый» образ с готовой базой — см. bake/bake.sh.
# Пароли стенда учебные и намеренно публичные; порт публикуется только на localhost (см. README).
FROM gvenzl/oracle-free:23.26.2

LABEL org.opencontainers.image.title="Oracle Database Free — учебный стенд (курс «Оптимизация Oracle SQL»)"
LABEL org.opencontainers.image.description="Oracle 26ai Free со схемами kivi и hr, фиксированными параметрами и статистикой для курса по оптимизации SQL"
LABEL org.opencontainers.image.source="https://github.com/kivilev/backend-pro-oracle-opt-study-db"

ENV ORACLE_PASSWORD=booble34 \
    STAND_PROFILE=small \
    STAND_SEED=20260919 \
    STAND_PDB=FREEPDB1 \
    NLS_LANG=AMERICAN_AMERICA.AL32UTF8

USER root
COPY stand/   /opt/stand/
COPY initdb/  /container-entrypoint-initdb.d/
COPY startdb/ /container-entrypoint-startdb.d/
RUN find /opt/stand /container-entrypoint-initdb.d /container-entrypoint-startdb.d -type f \( -name '*.sh' -o -name '*.sql' \) -exec sed -i 's/\r$//' {} + \
    && chmod +x /container-entrypoint-initdb.d/*.sh /container-entrypoint-startdb.d/*.sh /opt/stand/bin/*.sh /opt/stand/noise/*.sh \
    && chown -R oracle:oinstall /opt/stand /container-entrypoint-initdb.d /container-entrypoint-startdb.d
USER oracle
