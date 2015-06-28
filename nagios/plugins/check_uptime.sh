#!/bin/sh                                                                                                                                                                 

# check servers uptime - pure and simple

UPTIME=`awk {'print $1'} /proc/uptime | sed 's/\..*$//'`

if [ ${UPTIME} -lt 1800 ]; then
  echo "${HOSTNAME} was rebooted ${UPTIME} seconds ago"
  exit 2
elif [ ${UPTIME} -ge 1800 ]; then
  echo "${HOSTNAME} uptime OK (${UPTIME} sec)"
  exit 0
fi
