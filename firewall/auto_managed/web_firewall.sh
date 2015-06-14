#!/bin/sh

MESRIPT=$(basename $0)
MYLOCKFILE="/var/run/${MESRIPT}.pid"

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

SSH_PORT="24"
IPTABLES_STORE="/etc/iptables"
DATE=$(date "+%Y%m%d%H%M")

while true 
do
	sleep 15

	# create a temporary file for storing firewall data
	TMP_FIREWALL=$(mktemp -t "${MESRIPT}XXXXXXX")
	echo "${STATIC_HEADER}" >> "${TMP_FIREWALL}"
	WEB_IPS=`ls /var/www/web_firewall/*.ACTIVE | sed -e 's#.ACTIVE##g' | sed -e 's#/var/www/web_firewall/##g'`

	# compile new firewall
	if [ -n "${WEB_IPS}" ]; then
		# if there are active IPs, we have to add them
		for IP in ${WEB_IPS}; do
			echo "-A INPUT -s ${IP} -p tcp -m tcp --dport ${SSH_PORT} -j ACCEPT" >> "${TMP_FIREWALL}"
		done
	fi

	echo "${STATIC_FOOTER}" >> "${TMP_FIREWALL}"

	NEW_FIREWALL=`cat ${TMP_FIREWALL}`
	CUR_FIREWALL=`cat ${IPTABLES_STORE}`

	echo "NEW_FIREWALL: ${NEW_FIREWALL}"
	echo "CUR_FIREWALL: ${CUR_FIREWALL}"

	if [ "${NEW_FIREWALL}" = "${CUR_FIREWALL}" ]; then
		echo "nothing to do"
		continue
	else
		# check correctness of new rules
		if [ -z "`echo "${NEW_FIREWALL}" | iptables-restore --test`" ]; then
			echo "create new firewall"
			# the new firewall is OK, we can write it as production
			touch "${IPTABLES_STORE}"
			# create backup of existing config
			cp -a "${IPTABLES_STORE}" "${IPTABLES_STORE}_${DATE}"
			cat "${TMP_FIREWALL}" > "${IPTABLES_STORE}"
			iptables-restore "${IPTABLES_STORE}"
			rm -f "${TMP_FIREWALL}"
		else
			echo "ERROR: ${MESRIPT} FAILED !!"
			echo "${NEW_FIREWALL}" | mail -s "ERROR: ${MESRIPT} FAILED !!" wojtosz@gmail.com
			continue
		fi
	fi

done 

# cleanup; removing old PID file
rm -f "/var/run/${MESRIPT}.pid"

