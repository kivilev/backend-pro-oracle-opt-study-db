# check=skip=SecretsUsedInArgOrEnv
# Учебный стенд курса «Оптимизация Oracle SQL» на Oracle AI Database 26ai Free.
# Это УСТАНОВОЧНЫЙ образ: база курса ставится при первом старте контейнера.
# Студентам публикуется «запечённый» образ с готовой базой — см. bake/bake.sh.
# Пароли стенда учебные и намеренно публичные; порты публикуются только на localhost (см. README).

# В gvenzl/oracle-free нет dnf: пакеты openssh скачиваются в отдельной стадии той же архитектуры
FROM oraclelinux:8 AS sshpkgs
RUN dnf -y install dnf-plugins-core \
    && mkdir /rpms \
    && dnf download --destdir=/rpms openssh openssh-server

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
# SSH/SFTP на стенд «как на сервер» (раздел 6 README). --nodeps: systemd и /sbin/nologin нужны пакетам
# только для unit-файла и служебного пользователя sshd, а sshd здесь запускается от oracle без systemd.
COPY --from=sshpkgs /rpms /tmp/rpms
RUN rpm -Uvh --nodeps /tmp/rpms/*.rpm \
    && rm -rf /tmp/rpms \
    && echo 'oracle:booble34' | chpasswd

COPY stand/   /opt/stand/
COPY initdb/  /container-entrypoint-initdb.d/
COPY startdb/ /container-entrypoint-startdb.d/
RUN find /opt/stand /container-entrypoint-initdb.d /container-entrypoint-startdb.d -type f \( -name '*.sh' -o -name '*.sql' -o -name sshd_config -o -name bashrc \) -exec sed -i 's/\r$//' {} + \
    && chmod +x /container-entrypoint-initdb.d/*.sh /container-entrypoint-startdb.d/*.sh /opt/stand/bin/*.sh /opt/stand/noise/*.sh \
    && ln -s /opt/stand/bin/get-trace.sh /usr/local/bin/get-trace \
    && install -o oracle -g oinstall -m 644 /opt/stand/ssh/bashrc /opt/oracle/.bashrc \
    && ln -s /opt/oracle/diag/rdbms/free/FREE/trace /opt/oracle/trace \
    && chown -h oracle:oinstall /opt/oracle/trace \
    && chown -R oracle:oinstall /opt/stand /container-entrypoint-initdb.d /container-entrypoint-startdb.d
USER oracle

EXPOSE 2222
ENTRYPOINT ["/opt/stand/bin/stand-entrypoint.sh"]
