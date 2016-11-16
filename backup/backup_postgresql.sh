#!/bin/sh
# for PostgreSQL 9.x (use custom-format archive)

DBASES="pgdb01 pgdb02 pgdb03"
BACKUP_DIR="/mnt/storage/backup/postgres"
BACKUP_LOG="/var/log/pg_dump.log"
HOW_MANY=20

DATE=$(date "+%Y%m%d%H%M")
for DBASE in ${DBASES}; do
	echo "${DATE} database: ${DBASE} backup START" >> "${BACKUP_LOG}"
	su - postgres -c "/usr/bin/pg_dump -Fc ${DBASE} > ${BACKUP_DIR}/${DATE}-${DBASE}.fc"
	echo "$(date "+%Y%m%d%H%M") database: ${DBASE} backup STOP" >> "${BACKUP_LOG}"
done

# kasowanie starego backupu
COUNT=0
for FILE in `ls -tr ${BACKUP_DIR}/`;
do
        FILE_PREV=${BACKUP_DIR}/${FILE}
        if [ ${COUNT} -eq 0 ]; then
                FIRST_FILE=${BACKUP_DIR}/${FILE}
                COUNT=$((COUNT + 1))
                continue;
        fi

        if [ ${COUNT} -eq ${HOW_MANY} ]; then
                echo "Usuwam najstarszy plik backupu"
                rm -rf ${FIRST_FILE};
        fi
        COUNT=$((COUNT +1));
done

exit $?
