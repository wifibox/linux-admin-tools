#!/bin/sh

# author: wojtosz // Wojciech Błaszkowski

MESRIPT=$(basename $0)
MYLOCKFILE="/var/run/${MESRIPT}.pid"

SSH_PORT="22"
IPTABLES_STORE="/etc/iptables"
ADMIN_EMAIL="bogus@example.com"
DATE=$(date "+%Y%m%d%H%M")

if [ ! -f "${MYLOCKFILE}" ]; then
	# "no previous session detected, let's run!"
	echo $$ > "${MYLOCKFILE}"
else
	# "there is a lockfile, let's check is this an old one"
	LOCKFILEPID=`cat "${MYLOCKFILE}"`
	SEARCH=`ps -a | grep "${MESRIPT}" | grep "${LOCKFILEPID}"`
	if [ -n "${SEARCH}" ]; then
		echo "another session of this script already running!"
		exit 0
	else
		# " overwrite the old pid in lock file to current one"
		echo $$ > "${MYLOCKFILE}"
	fi
fi

STATIC_HEADER_FILE='/root/web_firewall/STATIC_HEADER'
STATIC_FOOTER_FILE='/root/web_firewall/STATIC_FOOTER'
IP_DIR='/var/www/web_firewall/'

if [ -f "${STATIC_HEADER_FILE}" ]; then
	STATIC_HEADER=`cat "${STATIC_HEADER_FILE}"`
else
	echo "file ${STATIC_HEADER_FILE} missing"
	exit 1
fi

if [ -f "${STATIC_FOOTER_FILE}" ]; then
	STATIC_FOOTER=`cat "${STATIC_FOOTER_FILE}"`
else
	echo "file ${STATIC_FOOTER_FILE} missing"
	exit 1
fi


while true 
do
	sleep 15

	# create a temporary file for storing firewall data
	TMP_FIREWALL=$(mktemp -t "${MESRIPT}XXXXXXX")

	# add header
	echo "${STATIC_HEADER}" >> "${TMP_FIREWALL}"

	# disable IPs older than 3 days
	find "${IP_DIR}" -type f -name "*.ACTIVE" -mtime +3 -exec mv "{}" "{}_DISABLED" \;

	WEB_IPS=`ls "${IP_DIR}"*.ACTIVE | sed -e 's#.ACTIVE##g' | sed -e "s#${IP_DIR}##g"`

	# add allowed IPs
	if [ -n "${WEB_IPS}" ]; then
		# if there are active IPs, we have to add them
		for IP in ${WEB_IPS}; do
			echo "-A INPUT -s ${IP} -p tcp -m tcp --dport ${SSH_PORT} -j ACCEPT" >> "${TMP_FIREWALL}"
		done
	fi
	
	# add footer
	echo "${STATIC_FOOTER}" >> "${TMP_FIREWALL}"

	if [ -z "`diff ${TMP_FIREWALL} ${IPTABLES_STORE}`" ]; then
		continue
	else
		# check correctness of new rules
		if [ -z "`echo "${NEW_FIREWALL}" | iptables-restore --test`" ]; then
			# the new firewall is OK, we can write it as production
			touch "${IPTABLES_STORE}"
			# create backup of existing config
			cp -a "${IPTABLES_STORE}" "${IPTABLES_STORE}_${DATE}"
			cat "${TMP_FIREWALL}" > "${IPTABLES_STORE}"
			iptables-restore "${IPTABLES_STORE}"
			rm -f "${TMP_FIREWALL}"
		else
			echo "ERROR: ${MESRIPT} FAILED !!"
			echo "${NEW_FIREWALL}" | mail -s "ERROR: ${MESRIPT} FAILED !!" "${ADMIN_EMAIL}"
			continue
		fi
	fi

done 

# cleanup; removing old PID file
rm -f "/var/run/${MESRIPT}.pid"

