#!/bin/sh

#set -x

BAZY="db01 db02 db03"
BACKUP_DIR="/home/backup/pgsql"
HOW_MANY=20

DATE=$(date "+%Y%m%d%H%M")
for BAZA in ${BAZY}; do
	echo "${DATE} rozpoczynam backup bazy ${BAZA}"
	su - postgres -c "pg_dump ${BAZA}  > /var/lib/pgsql/9.2/backups/${DATE}-${BAZA}.sql"
	echo "kopia wykonana, przenoszę do bezpiecznego katalogu..."
	mv -v "/var/lib/pgsql/9.2/backups/${DATE}-${BAZA}.sql" /home/backup/pgsql/
	echo "$(date "+%Y%m%d%H%M") rozpoczęcie kompresji kopii bazy.."
	nice -20 xz /home/backup/pgsql/${DATE}-${BAZA}.sql
	echo "$(date "+%Y%m%d%H%M") zakończenie kompresję kopii bazy ${BAZA}"
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
