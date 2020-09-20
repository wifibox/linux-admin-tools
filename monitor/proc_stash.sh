#!/bin/sh
#set -x
umask 077

LOGDIR=/var/log/ps

[ -f /var/run/proc.lock ] && exit 0
touch /var/run/proc.lock
                                                                                                                                                                            
LOAD=$(cat /proc/loadavg | awk -F '.' ' { print $1 } ')
DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H-%M-%S")

[ ! -d "${LOGDIR}/${DATE}" ] && mkdir -p "${LOGDIR}/${DATE}"

FILE="${LOGDIR}/${DATE}/${TIME}.${LOAD}.txt"
uptime > "$FILE" 2>&1
echo "# ps aux #################################" >> "$FILE"
ps aux >> "$FILE" 2>&1
echo "# ps arx -O wchan ########################" >> "$FILE"
ps arx -O wchan >> "$FILE"  2>&1
echo "# grep "" /proc/*/attr/current ###########" >> "$FILE"
grep "" /proc/*/attr/current >> "$FILE" 2>&1
echo "# vmstat --stats #########################" >> "$FILE"
vmstat --stats >> "$FILE" 2>&1
echo "# vmstat --active ########################" >> "$FILE"
vmstat --active >> "$FILE" 2>&1
echo "# vmstat --slabs #########################" >> "$FILE"
vmstat --slabs >> "$FILE" 2>&1
echo "# mpstat -P ALL ##########################" >> "$FILE"
mpstat -P ALL >> "$FILE" 2>&1
echo "# iostat -k -p ALL #######################" >> "$FILE"
iostat -k -p ALL >> "$FILE" 2>&1
echo "# finger -l ##############################" >> "$FILE"
finger -l >> "$FILE" 2>&1
echo "# slabtop -o #############################" >> "$FILE"
slabtop -o >> "$FILE" 2>&1
echo "# dmesg -T ###############################" >> "$FILE"
dmesg -T >> "$FILE" 2>&1

if [ "$LOAD" -gt 30 ]; then
  :> "${FILE}.WARNING"
else
    gzip "$FILE"
fi

rm -f /var/run/proc.lock
