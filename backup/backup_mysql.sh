#!/bin/bash

# author: wojtosz // Wojciech Błaszkowski

# you can invoke many MYSQL_SERVERS, one after another,
# as a backup queue
MYSQL_SERVERS=$@
BACKUP_DIR="/home/backup/mysql"
LOG_DIR="/var/log"
SKIP_DBS="information_schema performance_schema"
DEL_OLDER_THAN=15
DUMP_AND_COMPRESS=false
IGNORED_TABLES_FILE="/etc/backup_mysql_ignored_tables.cfg"

DATE=$(date "+%Y%m%d%H%M")

umask 022

for SERVER in $MYSQL_SERVERS; do
	echo "$(date '+%Y-%m-%d %H:%M:%S'): backup of $SERVER started" >> "$LOG_DIR/backup_mysql_$SERVER.log"
	for MYSQL_DBASE in `echo "show databases" | /usr/bin/mysql --defaults-file=/root/.my.cnf-$SERVER -B -s -h $SERVER`; do
		# skip system databases
		for SKIP_DB in $SKIP_DBS; do
			[ "${MYSQL_DBASE}" = "${SKIP_DB}" ] && continue 2
		done
		# if the backup dir does not exist, create new one
		[ ! -d "$BACKUP_DIR/$SERVER/$DATE" ] && mkdir -p "$BACKUP_DIR/$SERVER/$DATE"
		RETRY=50
		while [ "${RETRY}" -gt 0 ]; do
			echo "$(date '+%Y-%m-%d %H:%M:%S'): dumping $SERVER: $MYSQL_DBASE... retry: $RETRY" >> "$LOG_DIR/backup_mysql_$SERVER.log"
				IGNORED_TABLES=""
				for IGNORED_TABLE in `cat $IGNORED_TABLES_FILE | paste -sd ' '`; do
					IGNORED_TABLES+=" --ignore-table=${MYSQL_DBASE}.${IGNORED_TABLE}"
				done
			nice -n 20 /usr/bin/mysqldump --defaults-file=/root/.my.cnf-$SERVER -h $SERVER --quick $IGNORED_TABLES --quote-names --lock-tables --routines -f "$MYSQL_DBASE" 2> "$BACKUP_DIR/$SERVER/$DATE/mysql-$MYSQL_DBASE.sql.log" > "$BACKUP_DIR/$SERVER/$DATE/mysql-$MYSQL_DBASE.sql";
			if ! grep -q "connect to" "$BACKUP_DIR/$SERVER/$DATE/mysql-${MYSQL_DBASE}.sql.log"; then
				break
			fi
			sleep 10
			RETRY=$(($RETRY-1))
		done
		# delete log file if zero size (no errors)
		[ -s "$BACKUP_DIR/$SERVER/$DATE/mysql-${MYSQL_DBASE}.sql.log" ] || rm -f "$BACKUP_DIR/$SERVER/$DATE/mysql-${MYSQL_DBASE}.sql.log"
		if $DUMP_AND_COMPRESS; then
			nice -n 20 zstd -17 -q --rm "$SQL_FILE";
		fi
	done
	echo "$(date '+%Y-%m-%d %H:%M:%S'): backup of $SERVER finished" >> "$LOG_DIR/backup_mysql_$SERVER.log"
done

# now let's delete old backups
for SERVER in $MYSQL_SERVERS; do
	find $BACKUP_DIR/$SERVER/ -type d -ctime +$DEL_OLDER_THAN -exec rm -rf {} \;
done

if $DUMP_AND_COMPRESS; then
	exit 0;
fi

# now let's compress those dumps..
for SERVER in $MYSQL_SERVERS; do
	echo "$(date '+%Y-%m-%d %H:%M:%S'): compression of $SERVER backups started" >> "$LOG_DIR/backup_mysql_$SERVER.log"
	for SQL_FILE in $BACKUP_DIR/$SERVER/$DATE/*.sql; do
		echo "$(date '+%Y-%m-%d %H-%M:%S'): $SERVER: $SQL_FILE compression start" >> "$LOG_DIR/backup_mysql_$SERVER.log"
		nice -n 20 zstd -17 -q --rm "$SQL_FILE";
		echo "$(date '+%Y-%m-%d %H-%M:%S'): $SERVER: $SQL_FILE compression finished" >> "$LOG_DIR/backup_mysql_$SERVER.log"
	done
	echo "$(date '+%Y-%m-%d %H:%M:%S'): compression of $SERVER backups finished" >> "$LOG_DIR/backup_mysql_$SERVER.log"
done

